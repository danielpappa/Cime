import AVFoundation
import Observation
import UIKit

@MainActor
@Observable
final class CameraModel: NSObject {
    var errorMessage: String?
    var isChecking = false
    var isRecording = false
    var recordingElapsed = 0
    var audioLevel: CGFloat = 0
    var mode: ProofKind = .photo
    var useFrontCamera = false

    /// Session is configured on the main actor; start/stop runs on `CameraSessionQueue`.
    nonisolated(unsafe) let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var recordingURL: URL?
    private var recordingTimer: Timer?
    private var peakAudio: Float = 0
    private var onProof: ((Data, ProofKind) -> Void)?

    func configure() async {
        let videoGranted = await Self.requestAccess(for: .video)
        let audioGranted = await Self.requestAccess(for: .audio)
        guard videoGranted || mode == .audio else {
            errorMessage = "Camera access is needed — proof must be captured live."
            return
        }
        if mode == .video || mode == .audio || mode == .loop {
            guard audioGranted else {
                errorMessage = "Microphone access is needed — proof must be recorded live."
                return
            }
        }
        rebuildSession()
    }

    func setMode(_ mode: ProofKind) {
        self.mode = mode
        Task { await configure() }
    }

    func flipCamera() {
        useFrontCamera.toggle()
        rebuildSession()
    }

    func bind(onProof: @escaping (Data, ProofKind) -> Void) {
        self.onProof = onProof
    }

    func captureOrToggleRecord() {
        switch mode {
        case .photo:
            capturePhoto()
        default:
            isRecording ? stopRecording() : startRecording()
        }
    }

    private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func startRecording() {
        guard !movieOutput.isRecording else { return }
        peakAudio = 0
        recordingElapsed = 1
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        recordingURL = url
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                self.recordingElapsed += 1
                if self.recordingElapsed > self.mode.recordLimitSeconds + 1 {
                    self.stopRecording()
                }
            }
        }
    }

    private func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        recordingElapsed = 0
        audioLevel = 0
    }

    private func rebuildSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }

        let wantVideo = mode != .audio
        if wantVideo, let device = cameraDevice(front: useFrontCamera) {
            if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                videoInput = input
                session.addInput(input)
            }
        }
        if mode == .video || mode == .audio || mode == .loop,
           let mic = AVCaptureDevice.default(for: .audio),
           let input = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(input) {
            audioInput = input
            session.addInput(input)
        }

        if wantVideo, session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if mode != .photo, session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }

        session.commitConfiguration()
        CameraSessionQueue.startRunning(session)
    }

    private func cameraDevice(front: Bool) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back)
    }

    private static func requestAccess(for media: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .authorized: true
        case .notDetermined:
            await withCheckedContinuation { cont in
                AVCaptureDevice.requestAccess(for: media) { cont.resume(returning: $0) }
            }
        default: false
        }
    }

    private func verifyAndDeliver(data: Data, kind: ProofKind, frameJPEG: Data?) {
        isChecking = true
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            if kind == .photo || kind == .loop || kind == .video {
                let checkData = frameJPEG ?? data
                let result = ProofValidator.checkJPEG(checkData)
                if !result.ok {
                    errorMessage = result.reason
                    isChecking = false
                    return
                }
            }
            if kind == .audio, peakAudio < 10 {
                errorMessage = "We couldn't hear anything. Say what you did."
                isChecking = false
                return
            }
            isChecking = false
            onProof?(data, kind)
        }
    }

    func stopSession() {
        recordingTimer?.invalidate()
        CameraSessionQueue.stopRunning(session)
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in
            verifyAndDeliver(data: data, kind: .photo, frameJPEG: data)
        }
    }
}

extension CameraModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        guard error == nil, let data = try? Data(contentsOf: outputFileURL) else { return }
        Task { @MainActor in
            let kind = mode
            verifyAndDeliver(data: data, kind: kind, frameJPEG: nil)
        }
    }
}
