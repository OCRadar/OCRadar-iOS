import AVFoundation
import QuartzCore
import SwiftUI
import UIKit

/// Live camera feed for a `CameraService`, rendered aspect-fill.
///
/// The preview attaches an `AVCaptureVideoPreviewLayer` to the service's
/// capture session, so frames appear automatically once
/// `CameraService.start()` brings the session up — no state plumbing
/// required. The layer draws nothing while the session is not running.
public struct CameraPreview: View {
    private let service: CameraService

    /// - Parameter service: The camera service whose session feeds the
    ///   preview.
    public init(service: CameraService) {
        self.service = service
    }

    public var body: some View {
        PreviewLayerRepresentable(session: service.captureSession)
    }
}

/// Hosts the `AVCaptureVideoPreviewLayer` inside SwiftUI.
private struct PreviewLayerRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

/// `UIView` whose only job is to keep an `AVCaptureVideoPreviewLayer` sized
/// to its bounds without implicit animation.
private final class PreviewHostView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PreviewHostView does not support NSCoder.")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }
}
