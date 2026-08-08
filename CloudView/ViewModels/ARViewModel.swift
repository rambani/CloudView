import SwiftUI
import RealityKit
import ARKit
import Combine
import CoreMotion
import CoreLocation
import AVFoundation

class ARViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var detectedClouds: [CloudRegion] = []
    @Published var currentDrawingName: String?
    @Published var lastDrawingName: String? // Persists for quirky weather statements
    /// Base creature label behind `lastDrawingName` (a "Skateboarding
    /// Elephant" is still, at heart, an elephant). Drives quip personality.
    @Published var lastDrawingSubject: String?
    @Published var appState: AppState = .scanning

    /// The most recent finished drawing, held in memory only for the
    /// instant-share affordance on the drawing capsule. Nothing is ever
    /// persisted — the moment passes unless the user shares it.
    @Published var latestShareable: ShareableDrawing?

    /// One-time community-notifications invite, offered after the user has
    /// made a few drawings (the earned moment) — otherwise the feature only
    /// exists behind Settings and nobody ever finds it.
    @Published var showCommunityInvite = false

    struct ShareableDrawing: Identifiable {
        let id = UUID()
        let image: UIImage
        let label: String
        let caption: String
    }

    var arView: ARView?
    private let cloudDetector = CloudDetector()
    private let recognitionService: CloudRecognitionService = OnDeviceCloudRecognitionService.shared
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

#if DEBUG
    /// Desk-testing mode: bypasses the point-at-sky and daylight gates so
    /// the full detect→match→assemble pipeline can be exercised against a
    /// photo of clouds on a monitor. Persisted so it survives relaunches
    /// during a tuning session. Compiled out of Release entirely.
    static var deskTestingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "cloudoodle.deskTesting") }
        set { UserDefaults.standard.set(newValue, forKey: "cloudoodle.deskTesting") }
    }
#endif

    /// True when environment gates (daylight, camera pitch) should be
    /// skipped. Always false in Release builds.
    private var bypassEnvironmentGates: Bool {
#if DEBUG
        return Self.deskTestingEnabled
#else
        return false
#endif
    }

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

    /// Real camera-authorization check. Called on launch and whenever the
    /// app becomes active (so returning from Settings recovers). Denied
    /// camera means the app fundamentally cannot work — surface the one
    /// state with an actionable path instead of a silent black screen.
    /// (.notDetermined is fine: ARKit presents the system prompt when the
    /// session starts.)
    func checkPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            switch status {
            case .denied, .restricted:
                self.hasRequiredPermissions = false
                self.appState = .permissionsNeeded
            default:
                self.hasRequiredPermissions = true
                if self.appState == .permissionsNeeded {
                    self.appState = .scanning
                }
            }
        }
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
        // Camera denied: nothing below can help; keep the actionable
        // permission screen up rather than letting scan states replace it.
        guard appState != .permissionsNeeded else { return }
        isProcessing = true

        defer { isProcessing = false }

        // Environment gates (skipped in DEBUG desk-testing mode so the
        // pipeline can run against a cloud photo on a monitor).
        if !bypassEnvironmentGates {
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

            // After ~5 seconds of genuinely no clouds, tell the user WHY
            // via the weather: a clear blue day gets the cheerful "no
            // clouds to doodle yet" message instead of scanning forever.
            if consecutiveNoCloudFrames >= noCloudThreshold {
                appState = Self.noCloudState(
                    condition: weatherService?.currentWeather?.weather.first?.main
                )
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

    /// Map the current weather condition to the right "no clouds found"
    /// state. Static + condition-string-in so it stays trivially testable.
    static func noCloudState(condition: String?) -> AppState {
        guard let condition = condition?.lowercased(), !condition.isEmpty else {
            return .noWeatherData
        }
        if condition.contains("clear") || condition.contains("sun") {
            return .noCloudsClearSky
        }
        return .noCloudsOvercast
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

        // Quiet "I see something" cue while recognition runs.
        FeedbackService.shared.fire(.sightingBegan)

        guard let cluster = CloudClusteringService.cluster([cloudShape]).first else {
            FeedbackService.shared.fire(.noMatch)
            return
        }

        // Deterministic variation seed: cloud shape + city-scale region are
        // the shared components (what strangers at the same cloud can agree
        // on); device salt + 6-hour time bucket are the personal ones. See
        // docs/GENERATIVE_DRAWING_DESIGN.md for the policy.
        let variation = VariationSeed(
            cloudShapeKey: cluster.signature.cacheKey,
            regionKey: Self.regionKey(for: weatherService?.currentLocation),
            timeBucket: UInt64(Date().timeIntervalSince1970 / (6 * 3600)),
            deviceSalt: Self.deviceSalt
        )

        // Primary path: shape retrieval against the drawing-template library.
        // The cloud's contour is matched (Hu moments) to a real creature
        // whose art is then warped onto the cloud — so the pick is *caused
        // by* the cloud's shape and the drawing is a genuine creature, not
        // the cloud's own outline with dots. Returns nil when nothing is a
        // confident enough fit, and we fall back below.
        let concept: DrawingConcept
        if let templated = DrawingTemplateLibrary.shared.makeDrawing(
            forCloudContour: cloudShape.normalizedContour,
            variation: variation,
            aspectRatio: Double(cloudShape.aspectRatio)
        ) {
            concept = templated
        } else {
            // Fallback: CLIP interpretation (or deterministic stub when the
            // model isn't bundled) rendered as the cloud outline + minimal
            // annotation marks. Keeps the app producing something for clouds
            // that don't resemble any template.
            let interpretations = (try? await recognitionService.recognize(cluster)) ?? []
            guard let interpretation = interpretations.first else {
                // No good match — soft haptic so the user knows we tried, no
                // sound. UI's existing nil-name state shows "Cool cloud!".
                FeedbackService.shared.fire(.noMatch)
                return
            }
            concept = RecognitionToDrawingAdapter.makeDrawingConcept(
                from: interpretation,
                cloudShape: cloudShape
            )
        }

        // Update UI with the recognized label
        currentDrawingName = concept.name
        lastDrawingName = concept.name // Persist for quirky weather statements
        lastDrawingSubject = concept.subject

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
        maybeOfferCommunityInvite()

        // Haptic + audio cue: "look what we made"
        FeedbackService.shared.fire(.drawingRevealed)

        // Capture a snapshot for instant sharing once the line-drawing
        // animation has had time to render: the (seeded) reveal duration
        // + a little buffer gives a satisfying complete image. The image
        // lives only in memory; there is deliberately no saved archive.
        let captureDelay = concept.style.revealDuration + 0.3
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(captureDelay * 1_000_000_000))
            captureForSharing(
                label: concept.name,
                subject: concept.subject,
                anchorPosition: position
            )
        }
    }

    // MARK: - Community invite

    /// Lifetime drawing count, persisted so the invite threshold survives
    /// relaunches (the in-memory counter resets with "clear all").
    private static let drawingsCountKey = "cloudoodle.totalDrawings"
    private static let inviteShownKey = "cloudoodle.communityInviteShown"

    private func maybeOfferCommunityInvite() {
        let defaults = UserDefaults.standard
        let total = defaults.integer(forKey: Self.drawingsCountKey) + 1
        defaults.set(total, forKey: Self.drawingsCountKey)

        guard total >= 3,
              !defaults.bool(forKey: Self.inviteShownKey),
              !ScanReportingService.shared.isEnabled
        else { return }

        // One shot: mark shown when offered. Settings remains the
        // always-available opt-in path if they tap "Not now".
        defaults.set(true, forKey: Self.inviteShownKey)
        withAnimation(.spring()) {
            showCommunityInvite = true
        }
    }

    // MARK: - Variation seed inputs

    /// Random 64-bit salt minted once per install — the "personal" component
    /// that makes two neighbors' drawings of the same cloud differ.
    private static let deviceSalt: UInt64 = {
        let key = "cloudoodle.deviceSalt"
        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: key) as? NSNumber {
            return stored.uint64Value
        }
        let salt = UInt64.random(in: .min ... .max)
        defaults.set(NSNumber(value: salt), forKey: key)
        return salt
    }()

    /// City-scale region bucket from the coarse location the weather service
    /// already holds: 0.2° grid (~20 km) — enough for "shared across a city"
    /// without adding any location precision the app doesn't already use.
    private static func regionKey(for location: CLLocation?) -> String {
        guard let coordinate = location?.coordinate else { return "unknown" }
        let lat = (coordinate.latitude * 5).rounded() / 5
        let lon = (coordinate.longitude * 5).rounded() / 5
        return "\(lat):\(lon)"
    }

    @MainActor
    private func captureForSharing(label: String, subject: String?, anchorPosition: simd_float3) {
        guard let arView = arView else { return }

        // Only offer the share button if the drawing is actually in frame —
        // the user may have panned away during the reveal, and a keepsake
        // photo of empty sky is worse than no share button. project() is
        // nil when the point is behind the camera.
        let margin: CGFloat = 40
        guard let screenPoint = arView.project(anchorPosition),
              arView.bounds.insetBy(dx: -margin, dy: -margin).contains(screenPoint)
        else { return }

        arView.snapshot(saveToHDR: false) { [weak self] image in
            guard let image = image else { return }
            Task { @MainActor in
                self?.latestShareable = ShareableDrawing(
                    image: image,
                    label: label,
                    caption: QuipEngine.caption(
                        creature: label,
                        subject: subject,
                        seed: QuipEngine.seed(
                            for: label,
                            hourBucket: QuipEngine.currentHourBucket()
                        )
                    )
                )
            }
        }
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
        // The container entity carries no mesh of its own. Previously it was
        // given a solid white quad, which rendered as an opaque white card
        // *in front of* the drawing and hid the white line strokes entirely.
        // The visible geometry is the set of animated line children that
        // `animate(entity:)` adds and reveals in sequence.
        let entity = ModelEntity()

        let animatedDrawing = AnimatedDrawing(
            concept: concept,
            size: cloudShape.size,
            duration: concept.style.revealDuration // seeded per drawing
        )

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
