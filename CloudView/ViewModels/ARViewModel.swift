import SwiftUI
import RealityKit
import ARKit
import Combine

class ARViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var detectedClouds: [CloudRegion] = []
    @Published var currentDrawingName: String?

    var arView: ARView?
    private let cloudDetector = CloudDetector()
    private let drawingLibrary = DrawingLibrary()
    private var cancellables = Set<AnyCancellable>()
    private var activeDrawings: [UUID: DrawingAnchor] = [:]

    // Frame processing throttle
    private var lastProcessTime: Date = .distantPast
    private let processingInterval: TimeInterval = 1.0 // Process every 1 second

    // Camera stability tracking
    private var cameraStabilityTimer: Timer?
    private var currentCloudRegion: CloudRegion?
    private var stableFrameCount = 0
    private let requiredStableFrames = 15 // ~0.5 seconds at 30fps

    struct CloudRegion: Identifiable {
        let id = UUID()
        let center: simd_float3
        let boundingBox: CGRect
        let shape: CloudShape
        var hasDrawing = false
    }

    struct DrawingAnchor {
        let anchor: AnchorEntity
        let drawing: DrawingConcept
        let cloudRegion: CloudRegion
    }

    func processFrame(_ frame: ARFrame) {
        // Throttle processing
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= processingInterval else {
            return
        }
        lastProcessTime = now

        // Detect clouds in frame
        Task {
            await detectClouds(in: frame)
        }
    }

    @MainActor
    private func detectClouds(in frame: ARFrame) async {
        guard !isProcessing else { return }
        isProcessing = true

        defer { isProcessing = false }

        // Use Vision to detect bright regions (potential clouds)
        let cloudShapes = await cloudDetector.detectClouds(in: frame.capturedImage)

        // Check camera stability
        let isStable = isCameraStable(frame)

        if isStable, let primaryCloud = cloudShapes.first {
            stableFrameCount += 1

            // If camera has been stable long enough, create drawing
            if stableFrameCount >= requiredStableFrames {
                await createDrawingForCloud(primaryCloud, frame: frame)
                stableFrameCount = 0
            }
        } else {
            stableFrameCount = 0
        }
    }

    private func isCameraStable(_ frame: ARFrame) -> Bool {
        // Check if camera movement is minimal
        let camera = frame.camera
        let transform = camera.transform

        // Simple stability check based on camera transform
        // In a real app, you'd track transform delta between frames
        return true // Simplified for now
    }

    @MainActor
    private func createDrawingForCloud(_ cloudShape: CloudShape, frame: ARFrame) async {
        guard let arView = arView else { return }

        // Check if we already have a drawing near this location
        let cloudCenter = cloudShape.center
        let hasNearbyDrawing = activeDrawings.values.contains { drawing in
            let distance = simd_distance(drawing.cloudRegion.center, cloudCenter)
            return distance < 2.0 // Within 2 meters
        }

        guard !hasNearbyDrawing else { return }

        // Select a random drawing concept based on cloud shape
        guard let concept = drawingLibrary.selectDrawing(for: cloudShape) else {
            return
        }

        // Update UI with drawing name
        currentDrawingName = concept.name

        // Create AR anchor at cloud position
        let raycastQuery = arView.makeRaycast(
            from: cloudShape.screenPosition,
            allowing: .estimatedPlane,
            alignment: .any
        )

        // Create anchor in the sky direction
        let anchor = AnchorEntity()
        let distance: Float = 50.0 // Place drawing 50 meters away

        let cameraTransform = frame.camera.transform
        let screenPoint = cloudShape.screenPosition

        // Convert screen point to world direction
        let direction = screenPointToWorldDirection(screenPoint, camera: frame.camera)
        let position = simd_float3(
            cameraTransform.columns.3.x + direction.x * distance,
            cameraTransform.columns.3.y + direction.y * distance,
            cameraTransform.columns.3.z + direction.z * distance
        )

        anchor.position = position
        arView.scene.addAnchor(anchor)

        // Create animated drawing entity
        let drawingEntity = await createAnimatedDrawing(concept: concept, cloudShape: cloudShape)
        anchor.addChild(drawingEntity)

        // Store the drawing
        let cloudRegion = CloudRegion(
            center: position,
            boundingBox: cloudShape.boundingBox,
            shape: cloudShape,
            hasDrawing: true
        )

        let drawingAnchor = DrawingAnchor(
            anchor: anchor,
            drawing: concept,
            cloudRegion: cloudRegion
        )

        activeDrawings[cloudRegion.id] = drawingAnchor
    }

    private func screenPointToWorldDirection(_ screenPoint: CGPoint, camera: ARCamera) -> simd_float3 {
        // Convert screen point to normalized device coordinates
        let viewportSize = camera.imageResolution
        let normalizedX = Float(screenPoint.x / viewportSize.width) * 2.0 - 1.0
        let normalizedY = Float(screenPoint.y / viewportSize.height) * 2.0 - 1.0

        // Get direction from camera
        let cameraTransform = camera.transform
        let forward = simd_float3(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        let right = simd_float3(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z)
        let up = simd_float3(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z)

        let direction = normalize(forward + right * normalizedX - up * normalizedY)
        return direction
    }

    @MainActor
    private func createAnimatedDrawing(concept: DrawingConcept, cloudShape: CloudShape) async -> ModelEntity {
        let entity = ModelEntity()

        // Create animated line drawing
        let animatedDrawing = AnimatedDrawing(
            concept: concept,
            size: cloudShape.size,
            duration: 2.5 // 2.5 seconds for full animation
        )

        // Generate mesh from paths
        let mesh = animatedDrawing.generateMesh()
        let material = SimpleMaterial(color: .white, isMetallic: false)

        entity.model = ModelComponent(mesh: mesh, materials: [material])

        // Start animation
        animatedDrawing.animate(entity: entity)

        return entity
    }

    func clearAllDrawings() {
        for (_, drawing) in activeDrawings {
            drawing.anchor.removeFromParent()
        }
        activeDrawings.removeAll()
    }
}
