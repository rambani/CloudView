import SwiftUI

/// Procedural sky panel — gradient + a handful of soft cloud blobs.
/// Used as the hero image on the permission pages and as the demo
/// backdrop. Avoids shipping bitmap assets that would need designer
/// touch later; this draws fine on any size class.
struct SkyBackdrop: View {
    enum Palette {
        case day        // light blue + white clouds
        case sunset     // warm orange + lifted cream clouds
        case dusk       // deep teal + lavender clouds

        var topColor: Color {
            switch self {
            case .day:    return Color(red: 0.55, green: 0.78, blue: 0.96)
            case .sunset: return Color(red: 0.99, green: 0.74, blue: 0.50)
            case .dusk:   return Color(red: 0.20, green: 0.31, blue: 0.50)
            }
        }
        var bottomColor: Color {
            switch self {
            case .day:    return Color(red: 0.82, green: 0.91, blue: 0.99)
            case .sunset: return Color(red: 0.98, green: 0.88, blue: 0.75)
            case .dusk:   return Color(red: 0.38, green: 0.48, blue: 0.66)
            }
        }
        var cloudColor: Color {
            switch self {
            case .day:    return .white
            case .sunset: return Color(red: 1.0, green: 0.96, blue: 0.90)
            case .dusk:   return Color(red: 0.90, green: 0.88, blue: 0.96)
            }
        }
    }

    var palette: Palette = .day
    var cornerRadius: CGFloat = 24

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.topColor, palette.bottomColor],
                startPoint: .top, endPoint: .bottom
            )
            CloudShapes(color: palette.cloudColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct CloudShapes: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Blob(color: color.opacity(0.92), x: w * 0.20, y: h * 0.30, r: w * 0.18)
                Blob(color: color.opacity(0.85), x: w * 0.36, y: h * 0.42, r: w * 0.22)
                Blob(color: color.opacity(0.95), x: w * 0.62, y: h * 0.36, r: w * 0.25)
                Blob(color: color.opacity(0.80), x: w * 0.82, y: h * 0.30, r: w * 0.16)
                Blob(color: color.opacity(0.78), x: w * 0.50, y: h * 0.62, r: w * 0.30)
                Blob(color: color.opacity(0.72), x: w * 0.18, y: h * 0.72, r: w * 0.20)
                Blob(color: color.opacity(0.72), x: w * 0.78, y: h * 0.72, r: w * 0.22)
            }
        }
    }

    /// Soft puffy circle. Two overlaid disks at different blurs sells the
    /// volumetric 3D look from the mocks without needing a real render.
    private struct Blob: View {
        let color: Color
        let x: CGFloat
        let y: CGFloat
        let r: CGFloat

        var body: some View {
            ZStack {
                Circle().fill(color.opacity(0.65)).frame(width: r * 2.6, height: r * 2.6).blur(radius: 24)
                Circle().fill(color).frame(width: r * 1.8, height: r * 1.8).blur(radius: 8)
            }
            .position(x: x, y: y)
        }
    }
}
