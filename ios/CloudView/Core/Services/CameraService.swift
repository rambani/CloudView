import AVFoundation
import UIKit

enum CameraError: LocalizedError {
    case notAuthorized
    case setupFailed
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Camera access denied. Enable it in Settings."
        case .setupFailed: return "Couldn't set up the camera."
        case .captureFailed: return "Photo capture failed."
        }
    }
}

@MainActor
final class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var capturedImage: UIImage?
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var error: CameraError?

    private var photoOutput = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<UIImage, Error>?

    override init() {
        super.init()
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestPermissionAndSetup() async throws {
        let status = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = status ? .authorized : .denied
        guard status else { throw CameraError.notAuthorized }
        try await setup()
    }

    private func setup() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { cont.resume(throwing: CameraError.setupFailed); return }
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                guard
                    let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                    let input = try? AVCaptureDeviceInput(device: device),
                    self.session.canAddInput(input)
                else {
                    self.session.commitConfiguration()
                    cont.resume(throwing: CameraError.setupFailed)
                    return
                }

                self.session.addInput(input)

                guard self.session.canAddOutput(self.photoOutput) else {
                    self.session.commitConfiguration()
                    cont.resume(throwing: CameraError.setupFailed)
                    return
                }
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotosPerCapture = 1
                self.session.commitConfiguration()
                self.session.startRunning()
                cont.resume()
            }
        }
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { [weak self] cont in
            guard let self else { cont.resume(throwing: CameraError.captureFailed); return }
            self.continuation = cont
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func stop() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // Build the result nonisolated — UIImage construction is safe off MainActor.
        // Only the continuation (a @MainActor property) must be touched on MainActor.
        let result: Result<UIImage, Error>
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            result = .success(image)
        } else {
            result = .failure(CameraError.captureFailed)
        }

        Task { @MainActor [weak self] in
            self?.continuation?.resume(with: result)
            self?.continuation = nil
        }
    }
}
