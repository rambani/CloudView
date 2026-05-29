import SwiftUI
import RealityKit
import ARKit
import Combine
import CoreMotion

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
    private var activeDrawings: [UUID: DrawingAnchor] = [:]
    // Insertion order of drawing IDs so we can evict the actual oldest.
    private var drawingOrder: [UUID] = []

    // Services for privacy-preserving notifications
    weak var weatherService: WeatherService? // To get current location for scan reporting

    // Motion tracking for camera orientation
    private let motionManager = CMMotionManager()
    private var currentCameraAngle: Double = 0 // Angle from horizontal

    // Frame processing throttle
    private var lastProcessTime: Date = .distantPast
    private let processingInterval: TimeInterval = 0.25 // Process 4 frames per second

    // No cloud detection tracking
    private var consecutiveNoCloudFrames = 0
    // Frames before declaring "no clouds" — 20 frames * 0.25s = ~5 seconds.
    private let noCloudThreshold = 20

    // Camera stability tracking — measured against actual camera transforms.
    private var cameraStabilityTimer: Timer?
    private var currentCloudRegion: CloudRegion?
    private var stableFrameCount = 0
    // 8 frames * 0.25s = ~2 seconds of "hold still" before we draw.
    private let requiredStableFrames = 8
    private var lastCameraTransform: simd_float4x4?
    private let stabilityTranslationThreshold: Float = 0.03 // meters / frame
    private let stabilityRotationThreshold: Float = 0.05    // radians / frame

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
        // Prefer the astronomical sunrise/sunset for the user's location and date.
        if let location = weatherService?.currentLocation {
            let now = Date()
            let solar = SolarCalculator.sunriseSunset(
                for: location.coordinate,
                date: now
            )
            if let sunrise = solar.sunrise, let sunset = solar.sunset {
                return now >= sunrise && now <= sunset
            }
        }

        // Fallback when no location is available yet: widened to 5–21 to be
        // less wrong at high latitudes and during DST changes.
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 5 && hour < 21
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
            lastCameraTransform = nil
            return
        }

        // Check camera orientation
        if !isCameraPointingAtSky() {
            appState = .pointAtSky
            consecutiveNoCloudFrames = 0
            stableFrameCount = 0
            lastCameraTransform = nil
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
        let transform = frame.camera.transform
        defer { lastCameraTransform = transform }

        guard let previous = lastCameraTransform else {
            // First frame — no baseline, assume stable.
            return true
        }

        // Translation delta (camera position columns.3 holds tx/ty/tz).
        let dx = transform.columns.3.x - previous.columns.3.x
        let dy = transform.columns.3.y - previous.columns.3.y
        let dz = transform.columns.3.z - previous.columns.3.z
        let translation = sqrtf(dx * dx + dy * dy + dz * dz)

        // Rotation delta via forward vector (camera looks down -Z).
        let prevForward = -simd_float3(previous.columns.2.x, previous.columns.2.y, previous.columns.2.z)
        let currForward = -simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        let dot = simd_dot(simd_normalize(prevForward), simd_normalize(currForward))
        let cosAngle = max(Float(-1), min(Float(1), dot))
        let rotation = acosf(cosAngle)

        return translation < stabilityTranslationThreshold
            && rotation < stabilityRotationThreshold
    }

    @MainActor
    private func createDrawingForCloud(_ cloudShape: CloudShape, frame: ARFrame) async {
        guard let arView = arView else { return }

        // Performance limit: evict the actual oldest drawing if we're at the cap.
        while activeDrawings.count >= maxDrawings, let oldestID = drawingOrder.first {
            if let oldest = activeDrawings.removeValue(forKey: oldestID) {
                oldest.anchor.removeFromParent()
            }
            drawingOrder.removeFirst()
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

        // Create anchor in the sky direction. We don't raycast — clouds aren't
        // surfaces, so the AR session has nothing to hit — and instead place
        // the drawing along the unprojected camera ray at a fixed distance.
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
        drawingOrder.append(cloudRegion.id)
        drawingCreationCount += 1

        // Trigger haptic feedback for drawing creation
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    private func screenPointToWorldDirection(_ screenPoint: CGPoint, camera: ARCamera) -> simd_float3 {
        // Unproject an image-space pixel into a world-space ray direction
        // using the camera's pinhole intrinsics. The old implementation used
        // the camera's basis vectors as if it were a unit-FOV orthographic
        // camera, which dropped the lens FOV entirely and placed drawings
        // off-axis from the actual cloud.
        //
        // Convention:
        //   - `screenPoint` is in top-left image-pixel coordinates
        //     (matches what CloudDetector now produces).
        //   - `camera.intrinsics` is the pinhole matrix in image space.
        //   - ARKit's camera transform has +X right, +Y up, looks down -Z.
        let K = camera.intrinsics
        let fx = K.columns.0.x
        let fy = K.columns.1.y
        let cx = K.columns.2.x
        let cy = K.columns.2.y

        // Inverse pinhole: image pixel → camera-space ray (+Z forward, +Y down).
        let u = Float(screenPoint.x)
        let v = Float(screenPoint.y)
        let rayImage = simd_float3((u - cx) / fx, (v - cy) / fy, 1.0)

        // Camera-image convention → ARKit camera convention (+Y up, looks down -Z).
        let rayCamera = simd_float3(rayImage.x, -rayImage.y, -rayImage.z)

        // Camera-space → world-space via the rotation part of the transform.
        let t = camera.transform
        let right   = simd_float3(t.columns.0.x, t.columns.0.y, t.columns.0.z)
        let up      = simd_float3(t.columns.1.x, t.columns.1.y, t.columns.1.z)
        let back    = simd_float3(t.columns.2.x, t.columns.2.y, t.columns.2.z)
        let worldRay = right * rayCamera.x + up * rayCamera.y + back * rayCamera.z

        return simd_normalize(worldRay)
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
        drawingOrder.removeAll()
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
