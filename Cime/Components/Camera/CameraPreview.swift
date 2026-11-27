///  Shows the live camera picture inside SwiftUI.
import AVFoundation
import SwiftUI
import UIKit

/// SwiftUI wrapper around `AVCaptureVideoPreviewLayer`
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var cornerRadius: CGFloat = 16

    /// Called once when SwiftUI creates the UIKit view
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.layer.masksToBounds = true            // needed so cornerRadius actually clips
        view.layer.cornerRadius = cornerRadius
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    /// Whenever Swift re-renders
    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {   // !== compares object identity
            uiView.previewLayer.session = session
        }
        uiView.layer.cornerRadius = cornerRadius
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
