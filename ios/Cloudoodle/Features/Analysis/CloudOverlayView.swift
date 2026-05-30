import SwiftUI

// Renders Vision-detected cloud contours onto the photo.
// Paths come from Apple Vision (real cloud edges), label position from saliency detection.
struct CloudOverlayView: View {
    let drawingElements: [CloudAnalysis.DrawingElement]
    let labelPosition: CGPoint // normalized 0-1
    let shapeName: String
    var animationProgress: Double = 1.0 // 0→1 animates stroke draw-in

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                ForEach(drawingElements) { element in
                    CloudPathView(
                        element: element,
                        size: size,
                        progress: animationProgress
                    )
                    .accessibilityHidden(true)
                }

                ShapeNameLabel(name: shapeName)
                    .position(
                        x: labelPosition.x * size.width,
                        y: labelPosition.y * size.height
                    )
                    .opacity(animationProgress > 0.8 ? (animationProgress - 0.8) / 0.2 : 0)
            }
        }
        .accessibilityLabel("AI-identified shape: \(shapeName)")
    }
}

// Convenience init accepting a CloudSighting directly
extension CloudOverlayView {
    init(sighting: CloudSighting, animationProgress: Double = 1.0) {
        self.drawingElements = sighting.drawingElements
        self.labelPosition = CGPoint(x: sighting.drawingLabelX, y: sighting.drawingLabelY)
        self.shapeName = sighting.shapeName
        self.animationProgress = animationProgress
    }
}

// MARK: - Individual path renderer
private struct CloudPathView: View {
    let element: CloudAnalysis.DrawingElement
    let size: CGSize
    let progress: Double

    var body: some View {
        buildPath()
            .trim(from: 0, to: progress)
            .stroke(
                Color.white,
                style: StrokeStyle(
                    lineWidth: element.strokeWidth * size.width / 375, // scale to screen
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .shadow(color: .white.opacity(0.5), radius: 4)
            .animation(.easeOut(duration: 1.2), value: progress)
    }

    private func buildPath() -> Path {
        guard !element.points.isEmpty else { return Path() }

        let pts = element.points.map { pair -> CGPoint in
            let x = (pair.count > 0 ? pair[0] : 0) * size.width
            let y = (pair.count > 1 ? pair[1] : 0) * size.height
            return CGPoint(x: x, y: y)
        }

        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)

        if element.smooth && pts.count >= 3 {
            // Catmull-Rom spline through the control points
            for i in 1..<pts.count {
                let prev = pts[max(0, i - 1)]
                let curr = pts[i]
                let next = pts[min(pts.count - 1, i + 1)]

                let cp1 = CGPoint(
                    x: prev.x + (curr.x - (i >= 2 ? pts[i-2].x : prev.x)) / 6,
                    y: prev.y + (curr.y - (i >= 2 ? pts[i-2].y : prev.y)) / 6
                )
                let cp2 = CGPoint(
                    x: curr.x - (next.x - prev.x) / 6,
                    y: curr.y - (next.y - prev.y) / 6
                )
                path.addCurve(to: curr, control1: cp1, control2: cp2)
            }
        } else {
            for pt in pts.dropFirst() {
                path.addLine(to: pt)
            }
        }

        return path
    }

}

// MARK: - Shape label
private struct ShapeNameLabel: View {
    let name: String

    var body: some View {
        Text(name.uppercased())
            .font(CV.Font.shapeName)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(.black.opacity(0.35))
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Preview

#Preview {
    let mockElements = [
        CloudAnalysis.DrawingElement(
            points: [[0.2, 0.5], [0.35, 0.35], [0.5, 0.3], [0.65, 0.38], [0.75, 0.5], [0.65, 0.62], [0.5, 0.65]],
            smooth: false,
            strokeWidth: 2.5,
            label: "body"
        )
    ]
    let mockSighting = CloudSighting(
        analysis: CloudAnalysis(
            shapeName: "Dragon",
            quip: "A sleepy dragon banks left toward the horizon.",
            cloudType: "Cumulonimbus",
            weatherMood: "Brooding",
            watchabilityScore: 9
        ),
        drawingElements: mockElements,
        drawingLabelX: 0.5,
        drawingLabelY: 0.22
    )

    ZStack {
        LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)
        CloudOverlayView(
            drawingElements: mockSighting.drawingElements,
            labelPosition: CGPoint(x: mockSighting.drawingLabelX, y: mockSighting.drawingLabelY),
            shapeName: mockSighting.shapeName,
            animationProgress: 1.0
        )
    }
    .ignoresSafeArea()
}

