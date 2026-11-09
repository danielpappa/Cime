import AVFoundation
import Foundation

/// Runs `AVCaptureSession` start/stop off the main thread (Swift 6–safe).
enum CameraSessionQueue {
    private static let queue = DispatchQueue(label: "club.cime.camera.session", qos: .userInitiated)

    static func startRunning(_ session: AVCaptureSession) {
        queue.async {
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    static func stopRunning(_ session: AVCaptureSession) {
        queue.async {
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }
}
