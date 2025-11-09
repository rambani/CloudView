import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ARViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []
        configuration.worldAlignment = .gravity

        // Enable high-quality video capture for better cloud detection
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }

        arView.session.run(configuration)

        // Set the session delegate
        context.coordinator.arView = arView
        arView.session.delegate = context.coordinator

        // Store reference in view model
        viewModel.arView = arView

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Updates handled by view model
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        let viewModel: ARViewModel
        var arView: ARView?

        init(viewModel: ARViewModel) {
            self.viewModel = viewModel
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Pass frame to view model for cloud detection
            viewModel.processFrame(frame)
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            // Handle AR session errors
            viewModel.handleARSessionError(error)
        }

        func sessionWasInterrupted(_ session: ARSession) {
            // Handle session interruption (e.g., phone call, app switch)
            viewModel.handleARSessionInterruption()
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            // Resume session after interruption ends
            viewModel.handleARSessionInterruptionEnded()
        }
    }
}
