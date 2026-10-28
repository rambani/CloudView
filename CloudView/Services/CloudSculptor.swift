import Foundation
import CoreGraphics
import CoreImage
import UIKit

/// "Develop" a cloud: carve the creature into the real photo using the
/// cloud's own light, so the keepsake is still a genuine picture of a
/// genuine cloud that now unmistakably looks like something.
///
/// The recipe (mirrored exactly by `tools/sculpt_preview.py`, which is how
/// to iterate on the look without a device):
///
///   stroke mask ─► narrow + wide blurs, mixed by local luminance ─► SHADOW
///   (inside the cloud)   shifted up ─► RIM LIGHT above each crease
///   (over sky)           wide blur  ─► WISP: thin cloud where an ear overhangs
///   local contrast inside the cloud, soft vignette toward it
///
/// Small closed paths (eyes, a nose) fill as solid pools: an outlined
/// diamond reads as a drawing, a dark pool reads as an eye. Nothing here is
/// generative — no model, no network, ~100 ms on the GPU.
struct SculptRecipe {
    /// Sculpt width as a fraction of the cloud's short side …
    var strokeWidthCloudFraction: CGFloat = 0.030
    /// … but never thinner than this many ink widths.
    var strokeWidthMinInkFactor: CGFloat = 2.4
    /// Closed paths with area ≤ this × box area fill as pools.
    var poolMaxAreaFraction: CGFloat = 0.02
    var shadowBlurFactor: CGFloat = 0.8
    var shadowWideFactor: CGFloat = 2.4
    var shadowWideGain: CGFloat = 0.8
    /// How much bright puff softens the narrow crease (0 = none).
    var brightFade: CGFloat = 0.3
    var shadowStrength: CGFloat = 0.78
    /// Cloud shade is blue-grey, never black.
    var shadowTint = CIColor(red: 0.42, green: 0.50, blue: 0.64)
    var rimOffsetFactor: CGFloat = 0.8
    var rimStrength: CGFloat = 0.45
    var rimBrighten: CGFloat = 0.35
    var wispBlurFactor: CGFloat = 1.2
    var wispStrength: CGFloat = 0.85
    var wispTint = CIColor(red: 0.97, green: 0.98, blue: 1.0)
    /// Feather of the cloud region, as a fraction of its short side.
    var cloudFeather: CGFloat = 0.04
    var luminanceBlurFactor: CGFloat = 3.0
    var localContrastRadius: CGFloat = 0.08
    var localContrast: CGFloat = 0.35
    var vignette: CGFloat = 0.22
    /// Work at most this many pixels on the long side.
    var maxSide: CGFloat = 1600
}

/// Pure geometry for the sculpt pass — unit-tested, no Core Image.
enum SculptGeometry {
    static func sculptWidth(cloudShortSide: CGFloat, inkWidth: CGFloat, recipe: SculptRecipe = SculptRecipe()) -> CGFloat {
        max(cloudShortSide * recipe.strokeWidthCloudFraction, inkWidth * recipe.strokeWidthMinInkFactor)
    }

    /// Normalized (0–1 within the cloud box, y-down) → image pixels (y-down).
    static func pixelPoints(_ normalized: [CGPoint], in box: CGRect) -> [CGPoint] {
        normalized.map {
            CGPoint(x: box.minX + $0.x * box.width, y: box.minY + $0.y * box.height)
        }
    }

    /// Shoelace area of a closed polygon.
    static func polygonArea(_ pts: [CGPoint]) -> CGFloat {
        guard pts.count >= 3 else { return 0 }
        var s: CGFloat = 0
        for i in 0..<pts.count {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            s += a.x * b.y - b.x * a.y
        }
        return abs(s) / 2
    }

    /// Whether a closed path is small enough to render as a solid pool.
    static func isPool(_ pts: [CGPoint], closed: Bool, boxArea: CGFloat, recipe: SculptRecipe = SculptRecipe()) -> Bool {
        closed && pts.count >= 3 && polygonArea(pts) <= recipe.poolMaxAreaFraction * boxArea
    }

    /// Where the rim light sits relative to the crease: straight up
    /// (negative y in image space — light comes from above).
    static func rimOffset(sculptWidth: CGFloat, recipe: SculptRecipe = SculptRecipe()) -> CGVector {
        CGVector(dx: 0, dy: -sculptWidth * recipe.rimOffsetFactor)
    }

    /// Scale factor that brings the long side down to `maxSide` (never up).
    static func workingScale(imageSize: CGSize, recipe: SculptRecipe = SculptRecipe()) -> CGFloat {
        let long = max(imageSize.width, imageSize.height)
        guard long > 0 else { return 1 }
        return min(1, recipe.maxSide / long)
    }
}

/// Everything the sculpt needs, captured at drawing time (the AR frame is
/// recycled immediately, so the image is converted up front). Geometry is in
/// upright image pixels, matching `CloudShape`.
struct SculptJob {
    let frame: CGImage
    /// `frame` pixels per original upright-frame pixel (≤ 1 — the frame may
    /// have been scaled down on capture; the geometry was not).
    let frameScale: CGFloat
    let cloudContour: [CGPoint]
    let cloudBox: CGRect
    let paths: [DrawingConcept.DrawingPath]
    let inkWidthPixels: CGFloat
}

enum CloudSculptor {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// Upright CGImage from an ARKit capture buffer (landscape-right), scaled
    /// to the recipe's working size. Call promptly — it retains the buffer.
    static func uprightImage(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = CameraFrameGeometry.uprightOrientation,
        recipe: SculptRecipe = SculptRecipe()
    ) -> CGImage? {
        let upright = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        let k = SculptGeometry.workingScale(imageSize: upright.extent.size, recipe: recipe)
        let scaled = k < 1 ? upright.transformed(by: CGAffineTransform(scaleX: k, y: k)) : upright
        return context.createCGImage(scaled, from: scaled.extent.integral)
    }

    /// The developed photo. Pure function of the job; safe off the main thread.
    static func develop(_ job: SculptJob, recipe: SculptRecipe = SculptRecipe()) -> UIImage? {
        let w = job.frame.width, h = job.frame.height
        guard w > 0, h > 0, job.cloudContour.count >= 3, !job.paths.isEmpty else { return nil }

        // Geometry arrives in the original upright frame's pixels; the frame
        // itself may have been scaled on capture.
        let k = job.frameScale > 0 ? job.frameScale : 1
        let box = job.cloudBox.applying(CGAffineTransform(scaleX: k, y: k))
        let contour = job.cloudContour.map { CGPoint(x: $0.x * k, y: $0.y * k) }
        let short = min(box.width, box.height)
        guard short > 1 else { return nil }
        let sw = SculptGeometry.sculptWidth(cloudShortSide: short, inkWidth: job.inkWidthPixels * k, recipe: recipe)
        let boxArea = box.width * box.height

        let size = CGSize(width: w, height: h)
        guard let strokeCG = rasterizeStrokes(job.paths, box: box, width: sw, boxArea: boxArea, size: size, recipe: recipe),
              let cloudCG = rasterizePolygon(contour, size: size)
        else { return nil }

        let base = CIImage(cgImage: job.frame)
        let extent = base.extent
        func blur(_ img: CIImage, _ sigma: CGFloat) -> CIImage {
            img.clampedToExtent().applyingGaussianBlur(sigma: Double(sigma)).cropped(to: extent)
        }
        func scale(_ img: CIImage, _ g: CGFloat) -> CIImage {
            img.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: g, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: g, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: g, w: 0),
            ])
        }
        func multiply(_ a: CIImage, _ b: CIImage) -> CIImage {
            a.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: b])
        }
        func lighter(_ a: CIImage, _ b: CIImage) -> CIImage {
            a.applyingFilter("CILightenBlendMode", parameters: [kCIInputBackgroundImageKey: b])
        }
        func invert(_ a: CIImage) -> CIImage { a.applyingFilter("CIColorInvert") }
        /// `a` where mask is white, `b` where black.
        func composite(_ a: CIImage, _ b: CIImage, mask: CIImage) -> CIImage {
            a.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: b,
                kCIInputMaskImageKey: mask,
            ])
        }
        func tinted(_ img: CIImage, _ c: CIColor) -> CIImage {
            img.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: c.red, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: c.green, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: c.blue, w: 0),
            ])
        }
        func brightened(_ img: CIImage, _ amount: CGFloat) -> CIImage {
            img.applyingFilter("CIColorMatrix", parameters: [
                "inputBiasVector": CIVector(x: amount, y: amount, z: amount, w: 0),
            ])
        }
        func solid(_ c: CIColor) -> CIImage { CIImage(color: c).cropped(to: extent) }

        let stroke = CIImage(cgImage: strokeCG)
        let cloud = blur(CIImage(cgImage: cloudCG), recipe.cloudFeather * short)
        let notCloud = invert(cloud)

        let luminance = blur(
            base.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0),
                "inputGVector": CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0),
                "inputBVector": CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0),
            ]),
            sw * recipe.luminanceBlurFactor
        )

        // Shadow: the crease, faded a little on bright puff, plus a soft
        // spread — so a feature on a white dome is broader, not fainter.
        let narrow = blur(stroke, sw * recipe.shadowBlurFactor)
        let wide = scale(blur(stroke, sw * recipe.shadowWideFactor), recipe.shadowWideGain)
        let faded = composite(scale(narrow, 1 - recipe.brightFade), narrow, mask: luminance)
        let shadowIn = multiply(lighter(faded, wide), cloud)

        var out = composite(tinted(base, recipe.shadowTint), base, mask: scale(shadowIn, recipe.shadowStrength))

        // Rim light just above each crease (light comes from above). CI's
        // y axis points up, so "up" is a positive translation.
        let rimShift = SculptGeometry.rimOffset(sculptWidth: sw, recipe: recipe)
        let rimSource = narrow.transformed(by: CGAffineTransform(translationX: rimShift.dx, y: -rimShift.dy)).cropped(to: extent)
        let rim = multiply(multiply(rimSource, invert(narrow)), cloud)
        out = composite(brightened(out, recipe.rimBrighten), out, mask: scale(rim, recipe.rimStrength))

        // Wisp: strokes over sky become thin cloud.
        let wisp = multiply(blur(stroke, sw * recipe.wispBlurFactor), notCloud)
        out = composite(solid(recipe.wispTint), out, mask: scale(wisp, recipe.wispStrength))

        // Local contrast inside the cloud.
        let sharp = out.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: recipe.localContrastRadius * short,
            kCIInputIntensityKey: recipe.localContrast,
        ]).cropped(to: extent)
        out = composite(sharp, out, mask: cloud)

        // Soft vignette toward the cloud. CI coordinates: y up.
        let center = CIVector(x: box.midX, y: CGFloat(h) - box.midY)
        out = out.applyingFilter("CIVignetteEffect", parameters: [
            kCIInputCenterKey: center,
            kCIInputRadiusKey: max(CGFloat(w), CGFloat(h)) * 0.8,
            kCIInputIntensityKey: recipe.vignette,
            "inputFalloff": 0.5,
        ]).cropped(to: extent)

        guard let cg = context.createCGImage(out, from: extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Rasterization (CoreGraphics, y-down to match image pixels)

    private static func grayContext(_ size: CGSize) -> CGContext? {
        let w = Int(size.width), h = Int(size.height)
        guard w > 0, h > 0,
              let ctx = CGContext(
                data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
              )
        else { return nil }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(origin: .zero, size: size))
        // Flip so y grows downward like the image's pixel rows.
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        return ctx
    }

    private static func rasterizeStrokes(
        _ paths: [DrawingConcept.DrawingPath], box: CGRect, width: CGFloat,
        boxArea: CGFloat, size: CGSize, recipe: SculptRecipe
    ) -> CGImage? {
        guard let ctx = grayContext(size) else { return nil }
        ctx.setStrokeColor(gray: 1, alpha: 1)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for path in paths {
            let pts = SculptGeometry.pixelPoints(path.points, in: box)
            guard pts.count >= 2 else { continue }
            if SculptGeometry.isPool(pts, closed: path.closed, boxArea: boxArea, recipe: recipe) {
                ctx.beginPath()
                ctx.addLines(between: pts)
                ctx.closePath()
                ctx.fillPath()
            }
            ctx.beginPath()
            ctx.addLines(between: pts)
            if path.closed { ctx.closePath() }
            ctx.strokePath()
        }
        return ctx.makeImage()
    }

    private static func rasterizePolygon(_ pts: [CGPoint], size: CGSize) -> CGImage? {
        guard pts.count >= 3, let ctx = grayContext(size) else { return nil }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.beginPath()
        ctx.addLines(between: pts)
        ctx.closePath()
        ctx.fillPath()
        return ctx.makeImage()
    }
}
