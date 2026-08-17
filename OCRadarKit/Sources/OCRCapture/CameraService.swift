import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Observation

/// Owns the app's `AVCaptureSession`: permission, configuration, lifecycle,
/// and still capture.
///
/// All session work — configuration, `startRunning`, `stopRunning`, and photo
/// capture — happens on a private serial queue so the main thread never
/// blocks; the observable `state` is only ever mutated on the main actor.
/// The host app must declare `NSCameraUsageDescription` in its Info.plist.
@Observable @MainActor
public final class CameraService {
    /// Lifecycle of the capture pipeline, driven by `start()`, `stop()`, and
    /// session notifications.
    public enum State: Equatable, Sendable {
        /// Not yet started, or stopped via `stop()`.
        case idle
        /// Requesting permission, building the capture graph, or starting
        /// the session.
        case configuring
        /// The session is delivering frames; `capturePhoto()` is available.
        case running
        /// Camera permission was denied by the user or is restricted by
        /// policy.
        case denied
        /// The device has no usable back camera (for example, the
        /// Simulator).
        case unavailable
        /// The session failed or was interrupted; the payload is a
        /// human-readable reason.
        case failed(String)
    }

    /// Current pipeline state. Updated only on the main actor.
    public private(set) var state: State = .idle

    /// Backing capture session. `CameraPreview` attaches its preview layer
    /// to this, which AVFoundation supports from any thread; every
    /// configuration and lifecycle call stays on `sessionQueue`.
    nonisolated(unsafe) let captureSession = AVCaptureSession()

    /// Dedicated serial queue on which every session mutation runs.
    private let sessionQueue = DispatchQueue(label: "app.ocradar.capture.session")

    /// Still-photo output. Added to the session during configuration; only
    /// touched on `sessionQueue` afterwards.
    private nonisolated(unsafe) let photoOutput = AVCapturePhotoOutput()

    /// Whether the capture graph has been built. Only touched on
    /// `sessionQueue`.
    @ObservationIgnored private nonisolated(unsafe) var isSessionConfigured = false

    /// Supplies gravity-aligned rotation angles at capture time. Created
    /// during configuration; only touched on `sessionQueue`.
    @ObservationIgnored private nonisolated(unsafe) var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    /// Strong references to in-flight photo delegates, keyed by
    /// `AVCapturePhotoSettings.uniqueID`. `AVCapturePhotoOutput` does not
    /// retain its delegate, so each entry lives here until the delegate's
    /// final callback has fired. Only touched on `sessionQueue`.
    @ObservationIgnored private nonisolated(unsafe) var inFlightCaptureDelegates: [Int64: PhotoCaptureDelegate] = [:]

    /// Notification-center tokens for the session observers; removed on
    /// deinit. Only touched from `init` and `deinit`.
    @ObservationIgnored private nonisolated(unsafe) var notificationTokens: [any NSObjectProtocol] = []

    /// Incremented by `stop()` so an overlapping `start()` cannot publish
    /// `.running` after the session has been told to stop.
    @ObservationIgnored private var startGeneration = 0

    /// True while the session is paused by a system interruption (phone
    /// call, Split View, system pressure, …).
    @ObservationIgnored private var isInterrupted = false

    public init() {
        registerSessionObservers()
    }

    deinit {
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Lifecycle

    /// Requests camera permission if needed, builds the capture graph on
    /// first use, and starts the session.
    ///
    /// Idempotent: calling this while `.configuring` or `.running` is a
    /// no-op, and calling it again after `stop()` — or after a failure —
    /// retries cleanly.
    public func start() async {
        if state == .running || state == .configuring { return }

        // Terminal states that cannot have changed resolve synchronously,
        // without passing through `.configuring` — otherwise re-entering the
        // Scan tab would flash the live-camera layer over the denied or
        // unavailable screen before landing back on it.
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            state = .denied
            return
        default:
            break
        }
        if state == .unavailable {
            // No usable back camera was found previously (for example, the
            // Simulator); camera hardware does not appear at runtime.
            return
        }

        // `.configuring` doubles as the reentrancy gate for overlapping calls.
        state = .configuring
        let generation = startGeneration

        guard await Self.ensureAuthorization() else {
            state = .denied
            return
        }
        // stop() may have been called while the permission prompt was up;
        // stay idle rather than resurrecting the session.
        guard generation == startGeneration else { return }

        let failure: CaptureError? = await withCheckedContinuation { continuation in
            sessionQueue.async {
                if !self.isSessionConfigured {
                    if let error = self.configureSession() {
                        continuation.resume(returning: error)
                        return
                    }
                    self.isSessionConfigured = true
                }
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
                continuation.resume(
                    returning: self.captureSession.isRunning
                        ? nil
                        : .configurationFailed("The camera session did not start.")
                )
            }
        }

        // stop() won the race while the session queue was working; its
        // stopRunning is already enqueued behind the block above.
        guard generation == startGeneration else { return }

        switch failure {
        case nil:
            state = .running
        case .cameraUnavailable?:
            state = .unavailable
        case let error?:
            state = .failed(error.localizedDescription)
        }
    }

    /// Stops the session and returns the service to `.idle`.
    ///
    /// Safe to call in any state; a `start()` still in flight is superseded
    /// and will not resurrect the session.
    public func stop() {
        startGeneration &+= 1
        isInterrupted = false
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
        if state == .running || state == .configuring {
            state = .idle
        }
    }

    // MARK: - Capture

    /// Captures a still photo and returns it as an upright `CGImage`.
    ///
    /// The result is orientation-normalized: the EXIF rotation recorded at
    /// capture time is baked into the pixel data, so consumers (classifier,
    /// thumbnails) never need to consult orientation metadata.
    ///
    /// - Returns: The captured photo, upright as photographed.
    /// - Throws: `CaptureError.notRunning` when the session is not running;
    ///   `CaptureError.captureFailed` or `CaptureError.noImageData` when the
    ///   capture itself fails.
    public func capturePhoto() async throws -> CGImage {
        guard state == .running else { throw CaptureError.notRunning }

        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                guard self.captureSession.isRunning else {
                    continuation.resume(throwing: CaptureError.notRunning)
                    return
                }

                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = self.photoOutput.maxPhotoQualityPrioritization

                // Stamp the gravity-aligned rotation into the connection so
                // the photo's EXIF orientation reflects how the device was
                // actually held.
                if let coordinator = self.rotationCoordinator,
                   let connection = self.photoOutput.connection(with: .video) {
                    let angle = coordinator.videoRotationAngleForHorizonLevelCapture
                    if connection.isVideoRotationAngleSupported(angle) {
                        connection.videoRotationAngle = angle
                    }
                }

                let captureID = settings.uniqueID
                let delegate = PhotoCaptureDelegate { result in
                    // The delegate guarantees exactly one completion; release
                    // the strong reference afterwards, back on the session
                    // queue. The strong capture of `self` here matches the
                    // enclosing closure's implicit strong capture and only
                    // lasts until this single completion fires, at which
                    // point the delegate entry (and the cycle) is cleared.
                    continuation.resume(with: result)
                    self.sessionQueue.async {
                        self.inFlightCaptureDelegates[captureID] = nil
                    }
                }
                self.inFlightCaptureDelegates[captureID] = delegate
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    // MARK: - Session configuration

    /// Builds the capture graph: back wide-angle input, `.photo` preset,
    /// photo output. Must be called on `sessionQueue`.
    ///
    /// - Returns: The failure, or `nil` on success.
    private nonisolated func configureSession() -> CaptureError? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return .cameraUnavailable
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            return .configurationFailed(error.localizedDescription)
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Strip any leftovers from a previous partial failure so retries
        // always build the graph from a clean slate.
        for existing in captureSession.inputs {
            captureSession.removeInput(existing)
        }
        for existing in captureSession.outputs {
            captureSession.removeOutput(existing)
        }

        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        }

        guard captureSession.canAddInput(input) else {
            return .configurationFailed("The back camera input could not be added to the session.")
        }
        captureSession.addInput(input)

        guard captureSession.canAddOutput(photoOutput) else {
            return .configurationFailed("The photo output could not be added to the session.")
        }
        captureSession.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality

        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        return nil
    }

    /// Resolves camera authorization, prompting the user when it has not
    /// been determined yet.
    private static func ensureAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Session notifications

    /// Subscribes to interruption and runtime-error notifications so
    /// external events (phone calls, Split View, media-services resets, …)
    /// are reflected in `state`.
    private func registerSessionObservers() {
        let center = NotificationCenter.default

        notificationTokens.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: captureSession,
            queue: .main
        ) { [weak self] notification in
            let reason = (notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int)
                .flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
            MainActor.assumeIsolated {
                self?.handleInterruption(reason: reason)
            }
        })

        notificationTokens.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: captureSession,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleInterruptionEnded()
            }
        })

        notificationTokens.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: captureSession,
            queue: .main
        ) { [weak self] notification in
            let message = (notification.userInfo?[AVCaptureSessionErrorKey] as? AVError)?.localizedDescription
            MainActor.assumeIsolated {
                self?.handleRuntimeError(message: message)
            }
        })
    }

    private func handleInterruption(reason: AVCaptureSession.InterruptionReason?) {
        guard state == .running || state == .configuring else { return }
        isInterrupted = true
        state = .failed(Self.interruptionMessage(for: reason))
    }

    private func handleInterruptionEnded() {
        guard isInterrupted else { return }
        isInterrupted = false
        // `isRunning` must be consulted on `sessionQueue` — reading it here
        // would race a concurrent `startRunning`/`stopRunning` on that queue.
        // Hop over, read, then publish back on the main actor, skipping the
        // publish when a `stop()` (generation change) or a `start()` (state
        // no longer `.failed`) got there first.
        let generation = startGeneration
        sessionQueue.async {
            let isRunning = self.captureSession.isRunning
            Task { @MainActor in
                guard generation == self.startGeneration else { return }
                guard case .failed = self.state else { return }
                self.state = isRunning ? .running : .idle
            }
        }
    }

    private func handleRuntimeError(message: String?) {
        guard state == .running || state == .configuring else { return }
        isInterrupted = false
        state = .failed(message ?? "The camera session failed unexpectedly.")
    }

    /// Human-readable copy for an interruption reason, suitable for
    /// `State.failed`.
    private static func interruptionMessage(for reason: AVCaptureSession.InterruptionReason?) -> String {
        guard let reason else { return "The camera session was interrupted." }
        return switch reason {
        case .videoDeviceInUseByAnotherClient:
            "The camera is in use by another app."
        case .videoDeviceNotAvailableInBackground:
            "The camera is not available while the app is in the background."
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            "The camera is not available while the app is in Split View."
        case .videoDeviceNotAvailableDueToSystemPressure:
            "The camera paused because the device is under heavy load."
        case .audioDeviceInUseByAnotherClient:
            "The camera session was interrupted by another audio client."
        case .sensitiveContentMitigationActivated:
            "The camera was paused by a sensitive-content protection setting."
        @unknown default:
            "The camera session was interrupted."
        }
    }
}

// MARK: - PhotoCaptureDelegate

/// Bridges one `AVCapturePhotoOutput` capture to a single completion
/// callback.
///
/// `AVCapturePhotoOutput` does not retain photo-capture delegates, so
/// `CameraService` keeps each instance alive in `inFlightCaptureDelegates`
/// until `photoOutput(_:didFinishCaptureFor:error:)` — the guaranteed final
/// callback on every path, success or failure — has fired. The completion is
/// invoked exactly once; all delegate callbacks arrive on the photo output's
/// own serial queue, so the mutable state below is never accessed
/// concurrently.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: @Sendable (Result<CGImage, CaptureError>) -> Void
    private var photo: AVCapturePhoto?
    private var processingError: (any Error)?
    private var didComplete = false

    init(completion: @escaping @Sendable (Result<CGImage, CaptureError>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        self.photo = photo
        self.processingError = error
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: (any Error)?
    ) {
        guard !didComplete else { return }
        didComplete = true

        if let error = processingError ?? error {
            completion(.failure(.captureFailed(error.localizedDescription)))
            return
        }
        guard let photo else {
            completion(.failure(.noImageData))
            return
        }
        completion(Self.uprightImage(from: photo))
    }

    /// Decodes `photo` into a `CGImage` with its EXIF rotation baked into
    /// the pixels, so the result renders upright as photographed.
    /// (`cgImageRepresentation()` alone returns the sensor-native rotation.)
    private static func uprightImage(from photo: AVCapturePhoto) -> Result<CGImage, CaptureError> {
        let orientation = (photo.metadata[kCGImagePropertyOrientation as String] as? UInt32)
            .flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up

        if let cgImage = photo.cgImageRepresentation() {
            if orientation == .up {
                return .success(cgImage)
            }
            return rendered(CIImage(cgImage: cgImage).oriented(orientation))
        }

        // Fall back to decoding the encoded container, honoring its EXIF
        // orientation tag.
        guard let data = photo.fileDataRepresentation(),
              let decoded = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            return .failure(.noImageData)
        }
        return rendered(decoded)
    }

    private static func rendered(_ image: CIImage) -> Result<CGImage, CaptureError> {
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return .failure(.captureFailed("The captured photo could not be orientation-normalized."))
        }
        return .success(cgImage)
    }
}
