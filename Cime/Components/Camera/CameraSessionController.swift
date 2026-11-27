///  Owns the AVCaptureSession and does all changes to it on one background queue (which should not run on main thread)

import AVFoundation

// `nonisolated` = not tied to the main actor (needed if the project defaults to MainActor)
// `@unchecked Sendable` = promises it is thread safe because every access goes through the queue.
nonisolated final class CameraSessionController: @unchecked Sendable {

    /// What the session should be set up for (voice notes dont need it)
    enum Setup { case photo, video }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "club.cime.camera.session", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()

    func configure(for setup: Setup, useFront: Bool, maxVideoSeconds: Int) {
        queue.async { [self] in
            session.beginConfiguration()                 // batch all changes together
            session.sessionPreset = (setup == .photo) ? .photo : .high
            for input in session.inputs { session.removeInput(input) }
            for output in session.outputs { session.removeOutput(output) }

            let position: AVCaptureDevice.Position = useFront ? .front : .back
            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
               let input = try? AVCaptureDeviceInput(device: camera),
               session.canAddInput(input) {
                session.addInput(input)
            }

            switch setup {
            case .photo:
                if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            case .video:
                if let mic = AVCaptureDevice.default(for: .audio),
                   let input = try? AVCaptureDeviceInput(device: mic),
                   session.canAddInput(input) {
                    session.addInput(input)
                }
                if maxVideoSeconds > 0 {
                    movieOutput.maxRecordedDuration = CMTime(seconds: Double(maxVideoSeconds), preferredTimescale: 600)
                }
                if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
            }

            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
        }
    }

    func start() {
        queue.async { [self] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Takes one photo: `onNotReady` is called if the camera has no active connection yet
    func capturePhoto(delegate: AVCapturePhotoCaptureDelegate, onNotReady: @escaping @Sendable () -> Void) {
        // The delegate isn't Sendable, but we only hand it to AVFoundation, so this is fine.
        nonisolated(unsafe) let delegate = delegate
        queue.async { [self] in
            guard photoOutput.connection(with: .video) != nil else { onNotReady(); return }
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }

    func startMovie(to url: URL, delegate: AVCaptureFileOutputRecordingDelegate, onNotReady: @escaping @Sendable () -> Void) {
        nonisolated(unsafe) let delegate = delegate
        queue.async { [self] in
            guard !movieOutput.isRecording, movieOutput.connection(with: .video) != nil else { onNotReady(); return }
            movieOutput.startRecording(to: url, recordingDelegate: delegate)
        }
    }

    func stopMovie() {
        queue.async { [self] in
            if movieOutput.isRecording { movieOutput.stopRecording() }
        }
    }
}
