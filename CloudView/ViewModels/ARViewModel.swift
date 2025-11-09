import SwiftUI
import RealityKit
import ARKit
import Combine
import CoreMotion

// App state for contextual feedback
enum AppState {
    case scanning // Normal scanning mode
    case noCloudsClearSky // No clouds but weather is clear/sunny
    case noCloudsOvercast // No clouds but weather is cloudy/rainy
    case pointAtSky // Camera not pointing upward
    case nightTime // Too dark / nighttime
    case movingTooFast // Camera moving too much
    case noWeatherData // Can't determine weather context
    case permissionsNeeded // Camera/Location permissions required
    case arNotSupported // Device doesn't support ARKit
    case arSessionError // AR session failed or interrupted
}

class ARViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var detectedClouds: [CloudRegion] = []
    @Published var currentDrawingName: String?
    @Published var lastDrawingName: String? // Persists for quirky weather statements
    @Published var appState: AppState = .scanning

    var arView: ARView?
    private let cloudDetector = CloudDetector()
    private let drawingLibrary = DrawingLibrary()
    private var cancellables = Set<AnyCancellable>()
    private var activeDrawings: [UUID: DrawingAnchor] = []

    // Services for privacy-preserving notifications
    weak var weatherService: WeatherService? // To get current location for scan reporting

    // Motion tracking for camera orientation
    private let motionManager = CMMotionManager()
    private var currentCameraAngle: Double = 0 // Angle from horizontal

    // Frame processing throttle
    private var lastProcessTime: Date = .distantPast
    private let processingInterval: TimeInterval = 1.0 // Process every 1 second

    // No cloud detection tracking
    private var consecutiveNoCloudFrames = 0
    private let noCloudThreshold = 5 // 5 seconds without clouds

    // Camera stability tracking
    private var cameraStabilityTimer: Timer?
    private var currentCloudRegion: CloudRegion?
    private var stableFrameCount = 0
    private let requiredStableFrames = 15 // ~0.5 seconds at 30fps

    // Performance limits
    private let maxDrawings = 20 // Max concurrent drawings to prevent memory issues
    private var drawingCreationCount = 0 // Track total drawings created

    // Permission tracking
    @Published var hasRequiredPermissions = false

    init() {
        startMotionTracking()
        checkARSupport()
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - Permissions & AR Support

    private func checkARSupport() {
        // Check if device supports ARKit
        if !ARWorldTrackingConfiguration.isSupported {
            DispatchQueue.main.async {
                self.appState = .arNotSupported
            }
        }
    }

    func checkPermissions() {
        // In production, you'd check actual permission status
        // For now, assume they'll be requested by system
        // ARKit automatically requests camera permission
        // Location will be requested by WeatherService
        hasRequiredPermissions = true
    }

    // MARK: - Motion Tracking

    private func startMotionTracking() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 0.2 // Update 5 times per second
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }

            // Calculate angle from horizontal
            // gravity.z is the component pointing away from device screen
            // When phone is flat (horizontal), z ≈ -1
            // When phone is vertical pointing up, z ≈ 0
            let pitch = motion.attitude.pitch // Rotation around x-axis
            let angle = pitch * 180 / .pi // Convert to degrees

            self?.currentCameraAngle = angle
        }
    }

    private func isCameraPointingAtSky() -> Bool {
        // Phone should be tilted upward (positive pitch)
        // Typically > 30 degrees from horizontal indicates pointing at sky
        return currentCameraAngle > 30
    }

    // MARK: - Time of Day Check

    private func isDaytime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        // Consider 6 AM to 8 PM as daytime
        return hour >= 6 && hour < 20
    }

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

        // Check time of day first
        if !isDaytime() {
            appState = .nightTime
            consecutiveNoCloudFrames = 0
            stableFrameCount = 0
            return
        }

        // Check camera orientation
        if !isCameraPointingAtSky() {
            appState = .pointAtSky
            consecutiveNoCloudFrames = 0
            stableFrameCount = 0
            return
        }

        // Use Vision to detect bright regions (potential clouds)
        let cloudShapes = await cloudDetector.detectClouds(in: frame.capturedImage)

        // Check camera stability
        let isStable = isCameraStable(frame)

        if !isStable {
            appState = .movingTooFast
            stableFrameCount = 0
            return
        }

        // Check if we found clouds
        if cloudShapes.isEmpty {
            consecutiveNoCloudFrames += 1

            // After 5 seconds of no clouds, update state
            if consecutiveNoCloudFrames >= noCloudThreshold {
                // State will be determined by weather panel (clear sky vs overcast)
                // For now, set to scanning and let weather panel provide context
                appState = .scanning
            }
            stableFrameCount = 0
        } else {
            // Found clouds - reset counter and process normally
            consecutiveNoCloudFrames = 0
            appState = .scanning

            if let primaryCloud = cloudShapes.first {
                stableFrameCount += 1

                // If camera has been stable long enough, create drawing
                if stableFrameCount >= requiredStableFrames {
                    await createDrawingForCloud(primaryCloud, frame: frame)
                    stableFrameCount = 0
                }
            }
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

        // Performance limit: Check max drawings
        if activeDrawings.count >= maxDrawings {
            // Remove oldest drawing to make room
            if let oldestDrawing = activeDrawings.values.min(by: { _ , _ in true }) {
                oldestDrawing.anchor.removeFromParent()
                if let key = activeDrawings.first(where: { $0.value.anchor == oldestDrawing.anchor })?.key {
                    activeDrawings.removeValue(forKey: key)
                }
            }
        }

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
        lastDrawingName = concept.name // Persist for quirky weather statements

        // Report scan anonymously for community notifications (privacy-preserving)
        ScanReportingService.shared.reportScan(
            drawingName: concept.name,
            location: weatherService?.currentLocation
        )

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
        drawingCreationCount += 1

        // Trigger haptic feedback for drawing creation
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
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
        drawingCreationCount = 0
    }

    // MARK: - AR Session Management

    func handleARSessionError(_ error: Error) {
        print("AR Session Error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.appState = .arSessionError
        }
    }

    func handleARSessionInterruption() {
        print("AR Session was interrupted")
        DispatchQueue.main.async {
            self.appState = .arSessionError
        }
    }

    func handleARSessionInterruptionEnded() {
        print("AR Session interruption ended")
        DispatchQueue.main.async {
            // Resume normal scanning if it was previously working
            if self.appState == .arSessionError {
                self.appState = .scanning
            }
        }
    }
}
