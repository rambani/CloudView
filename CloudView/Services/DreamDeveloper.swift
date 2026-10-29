import Foundation
import CoreGraphics
import CoreImage
import UIKit

#if canImport(StableDiffusion)
import StableDiffusion
#endif

/// Dream mode (experimental, $0 per image, on-device): Stable Diffusion
/// 1.5 + ControlNet, guided by the real cloud's edges and the app's own
/// sketch of the creature, prompted for fine white ink line art, then
/// composited over the photo. The reference image's method, run on the
/// phone. See docs/DREAM_MODE.md — and run tools/dream_experiment.py on a
/// Mac first; this is the same recipe.
///
/// Honest expectations: a ~2 GB model (On-Demand Resources), 15–40 s per
/// image, the phone runs hot, and output swings between striking and
/// unusable. The sculpt keepsake is always produced first and remains the
/// fallback; the dream replaces it only when generation succeeds.
enum DreamDeveloper {

    struct Request {
        let frame: CGImage            // upright photo (CloudSculptor working size)
        let frameScale: CGFloat       // frame px per original upright px
        let cloudContour: [CGPoint]   // original upright px
        let cloudBox: CGRect
        let paths: [DrawingConcept.DrawingPath]
        let creature: String
    }

    enum Style {
        /// White line art generated on black, composited as ink over the photo.
        case ink
        /// img2img: the cloud itself becomes the creature.
        case creature
    }

    static let generationSize = 512
    static let stepCount = 18
    static let guidanceScale: Float = 7.5
    static let controlStrength: Float = 0.9

    /// Hardware gate: SD 1.5 wants ~3 GB of headroom. Below this the
    /// feature is hidden rather than offered and failing.
    static var deviceIsCapable: Bool {
        ProcessInfo.processInfo.physicalMemory >= 6 * 1024 * 1024 * 1024
    }

    static let enabledKey = "cloudoodle.dreamMode"
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static func prompt(for creature: String, style: Style) -> (prompt: String, negative: String) {
        switch style {
        case .ink:
            return (
                "fine white ink line drawing of a \(creature), single-weight pen illustration, elegant, " +
                "highly detailed, children's book illustration, white lines on pure black background",
                "color, colorful, photo, blurry, low quality, text, watermark, scary, gore, extra limbs, deformed"
            )
        case .creature:
            return (
                "a majestic \(creature) made of white cumulus clouds in a blue sky, the cloud is shaped like a \(creature), " +
                "natural photograph, soft daylight, realistic",
                "blurry, low quality, text, scary, deformed"
            )
        }
    }

    // MARK: - Control image (pure CoreGraphics + Core Image; testable geometry)

    /// Square crop around the cloud, like CloudCropRenderer, in frame px.
    static func cropRect(_ request: Request) -> CGRect {
        let k = request.frameScale
        let box = request.cloudBox.applying(CGAffineTransform(scaleX: k, y: k))
        return CloudCropRenderer.cropRect(for: box, in: CGSize(width: request.frame.width, height: request.frame.height))
    }

    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// What ControlNet sees: Canny-like edges of the cloud (inside its
    /// feathered mask) plus the app's sketch, white on black, 512×512.
    static func controlImage(_ request: Request) -> CGImage? {
        let k = request.frameScale
        let crop = cropRect(request)
        guard crop.width > 0 else { return nil }
        let size = CGSize(width: generationSize, height: generationSize)
        let scale = CGFloat(generationSize) / crop.width

        // Edges: CIEdges on the luminance, thresholded, masked to the cloud.
        let base = CIImage(cgImage: request.frame)
        let h = CGFloat(request.frame.height)
        let ciCrop = CGRect(x: crop.minX, y: h - crop.maxY, width: crop.width, height: crop.height)
        var edges = base
            .cropped(to: ciCrop)
            .transformed(by: CGAffineTransform(translationX: -ciCrop.minX, y: -ciCrop.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .applyingGaussianBlur(sigma: 1.2)
            .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 4.0])
            .applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.25])
            .cropped(to: CGRect(origin: .zero, size: size))

        if let maskCG = polygonMask(request.cloudContour.map { CGPoint(x: ($0.x * k - crop.minX) * scale, y: ($0.y * k - crop.minY) * scale) }, size: size) {
            let mask = CIImage(cgImage: maskCG).clampedToExtent().applyingGaussianBlur(sigma: 6).cropped(to: CGRect(origin: .zero, size: size))
            edges = edges.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: mask])
        }
        guard let edgesCG = context.createCGImage(edges, from: CGRect(origin: .zero, size: size)) else { return nil }

        // Sketch on top, slightly bolder than the edges.
        guard let ctx = CGContext(data: nil, width: generationSize, height: generationSize, bitsPerComponent: 8,
                                  bytesPerRow: generationSize * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        ctx.draw(edgesCG, in: CGRect(origin: .zero, size: size))
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.setLineWidth(max(2, size.width * 0.003))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let pixelBox = request.cloudBox.applying(CGAffineTransform(scaleX: k, y: k))
        for path in request.paths {
            let pts = SculptGeometry.pixelPoints(path.points, in: pixelBox).map {
                CGPoint(x: ($0.x - crop.minX) * scale, y: ($0.y - crop.minY) * scale)
            }
            guard pts.count >= 2 else { continue }
            ctx.beginPath()
            ctx.addLines(between: pts)
            if path.closed { ctx.closePath() }
            ctx.strokePath()
        }
        return ctx.makeImage()
    }

    private static func polygonMask(_ pts: [CGPoint], size: CGSize) -> CGImage? {
        guard pts.count >= 3,
              let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                  bytesPerRow: Int(size.width), space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.beginPath()
        ctx.addLines(between: pts)
        ctx.closePath()
        ctx.fillPath()
        return ctx.makeImage()
    }

    // MARK: - Compositing

    /// Generated ink (white on black) → white line over the photo crop,
    /// pasted back into the full frame. Pure Core Image; testable by eye.
    static func composite(ink: CGImage, onto request: Request, threshold: Float = 0.6, opacity: CGFloat = 0.9) -> UIImage? {
        let crop = cropRect(request)
        guard crop.width > 0 else { return nil }
        let frame = CIImage(cgImage: request.frame)
        let h = CGFloat(request.frame.height)
        let ciCrop = CGRect(x: crop.minX, y: h - crop.maxY, width: crop.width, height: crop.height)
        let scale = crop.width / CGFloat(ink.width)

        let mask = CIImage(cgImage: ink)
            .applyingFilter("CIColorThreshold", parameters: ["inputThreshold": threshold])
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: ciCrop.minX, y: ciCrop.minY))
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: opacity, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: opacity, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: opacity, w: 0),
            ])
            .cropped(to: frame.extent)
        // Outside the crop the mask is empty (transparent → treated as black).
        let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: frame.extent)
        let out = white.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: frame,
            kCIInputMaskImageKey: mask.composited(over: CIImage(color: .black).cropped(to: frame.extent)),
        ])
        guard let cg = context.createCGImage(out, from: frame.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Generation

    /// Where the Core ML resources live: the main bundle (dev) or the
    /// On-Demand Resource packs (see docs/DREAM_MODE.md).
    static var resourcesURL: URL? {
        Bundle.main.url(forResource: "DreamModel", withExtension: nil)
    }

    static var isAvailable: Bool {
        #if canImport(StableDiffusion)
        return deviceIsCapable && isEnabled && resourcesURL != nil
        #else
        return false
        #endif
    }

    /// Run the dream. Returns nil on any failure (missing package or model,
    /// memory pressure, cancelled). Long: call off the main thread.
    static func dream(_ request: Request, style: Style = .ink, progress: ((Double) -> Void)? = nil) -> UIImage? {
        #if canImport(StableDiffusion)
        guard isAvailable, let resources = resourcesURL,
              let control = controlImage(request)
        else { return nil }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            let pipeline = try StableDiffusionPipeline(
                resourcesAt: resources,
                controlNet: ["LineartControlNet"],
                configuration: config,
                disableSafety: false,
                reduceMemory: true
            )
            try pipeline.loadResources()

            let (promptText, negative) = prompt(for: request.creature, style: style)
            var cfg = StableDiffusionPipeline.Configuration(prompt: promptText)
            cfg.negativePrompt = negative
            cfg.stepCount = stepCount
            cfg.guidanceScale = guidanceScale
            cfg.seed = UInt32.random(in: 0...UInt32.max)
            cfg.schedulerType = .dpmSolverMultistepScheduler
            cfg.controlNetInputs = [control]
            if style == .creature {
                // img2img from the crop
                let crop = cropRect(request)
                if let cropCG = request.frame.cropping(to: crop),
                   let scaled = resize(cropCG, to: generationSize) {
                    cfg.startingImage = scaled
                    cfg.strength = 0.55
                }
            }
            let images = try pipeline.generateImages(configuration: cfg) { p in
                progress?(Double(p.step) / Double(p.stepCount))
                return true
            }
            guard let result = images.first ?? nil else { return nil }
            switch style {
            case .ink:
                return composite(ink: result, onto: request)
            case .creature:
                return pasteBack(result, onto: request)
            }
        } catch {
            print("ℹ️  Dream failed: \(error.localizedDescription)")
            return nil
        }
        #else
        return nil
        #endif
    }

    /// img2img result pasted back into the crop region of the frame.
    static func pasteBack(_ generated: CGImage, onto request: Request) -> UIImage? {
        let crop = cropRect(request)
        guard crop.width > 0 else { return nil }
        let h = CGFloat(request.frame.height)
        let ciCrop = CGRect(x: crop.minX, y: h - crop.maxY, width: crop.width, height: crop.height)
        let frame = CIImage(cgImage: request.frame)
        let scale = crop.width / CGFloat(generated.width)
        let gen = CIImage(cgImage: generated)
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: ciCrop.minX, y: ciCrop.minY))
        // Feather the seam so the paste doesn't show as a square.
        let feather = CIImage(color: .white).cropped(to: ciCrop.insetBy(dx: crop.width * 0.06, dy: crop.width * 0.06))
            .clampedToExtent().applyingGaussianBlur(sigma: Double(crop.width * 0.05)).cropped(to: frame.extent)
        let out = gen.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: frame,
            kCIInputMaskImageKey: feather,
        ])
        guard let cg = context.createCGImage(out, from: frame.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func resize(_ image: CGImage, to side: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return ctx.makeImage()
    }
}
