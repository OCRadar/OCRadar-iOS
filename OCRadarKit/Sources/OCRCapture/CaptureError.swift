import Foundation

/// Failures surfaced by `CameraService` while building the capture graph or
/// taking a photo.
public enum CaptureError: LocalizedError, Equatable, Sendable {
    /// The device has no usable back wide-angle camera — for example, the
    /// Simulator.
    case cameraUnavailable
    /// The capture graph could not be assembled, or the session refused to
    /// start. The payload is a human-readable reason.
    case configurationFailed(String)
    /// `CameraService.capturePhoto()` was called while the session was not
    /// running.
    case notRunning
    /// The system reported an error while taking or processing the photo.
    case captureFailed(String)
    /// The capture finished but produced no decodable image data.
    case noImageData

    public var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            "No back camera is available on this device."
        case .configurationFailed(let detail):
            "The camera could not be set up: \(detail)"
        case .notRunning:
            "The camera is not running."
        case .captureFailed(let detail):
            "The photo could not be captured: \(detail)"
        case .noImageData:
            "The captured photo contained no usable image data."
        }
    }
}
