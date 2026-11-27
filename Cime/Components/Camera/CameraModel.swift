///  Logic behind LiveCameraView: permissions, taking a photo, recording video or a voice note,
///  checking the result and holding it until the user confirms.

import AVFoundation
import Observation
import UIKit

/// View model for the live proof camera. Main actor only; the heavy camera work happens
/// on the queue inside `CameraSessionController`
@MainActor
@Observable
final class CameraModel: NSObject {

    /// A captured proof waiting for the user to confirm or retake
    struct PendingProof: Equatable {
        let data: Data
        let kind: ProofKind
    }

    /// What the screen is doing right now
    enum Phase: Equatable {
        case idle
        case recording
        case checking                    // compressing / validating
        case review(PendingProof)
    }

    // MARK: State the view reads

    private(set) var phase: Phase = .idle
    private(set) var mode: ProofKind = .photo
    private(set) var useFrontCamera = false
    var errorMessage: String?            // user facing, shown in a red box

    var isRecording: Bool { phase == .recording }
    var isChecking: Bool { phase == .checking }
    var pending: PendingProof? {
        if case .review(let proof) = phase { return proof }   // pull the value out of the enum case
        return nil
    }
    var recordingElapsed: Int { mode == .audio ? voice.elapsed : videoElapsed }
    var audioLevel: CGFloat { voice.level }
    var session: AVCaptureSession { controller.session }

    // MARK: Private

    private let controller = CameraSessionController()
    private let voice = VoiceRecorder()
    private var videoElapsed = 0
    private var videoTimer: Timer?
    private var configTask: Task<Void, Never>?
    private var interruptionTask: Task<Void, Never>?
    private var onProof: ((Data, ProofKind) -> Void)?

    init(mode: ProofKind = .photo) {
        super.init()
        self.mode = mode
        voice.onFinish = { [weak self] outcome in self?.handleVoice(outcome) }   // weak = no retain cycle
    }

    // MARK: Setup

    /// Registers the callback that receives the proof
    func bind(onProof: @escaping (Data, ProofKind) -> Void) {
        self.onProof = onProof
    }

    /// Asks for only the permissions the current mode needs, then (re)starts the camera
    func configure() async {
        errorMessage = nil
        observeInterruptions()

        let needsCamera = mode != .audio
        let needsMic = mode != .photo
        if needsCamera {
            let granted = await Self.requestAccess(for: .video)
            if !granted { errorMessage = "Camera access is needed — proof must be captured live."; return }
        }
        if needsMic {
            let granted = await Self.requestAccess(for: .audio)
            if !granted { errorMessage = "Microphone access is needed — proof must be recorded live."; return }
        }
        guard !Task.isCancelled else { return }       // the user may have switched mode meanwhile

        switch mode {
        case .photo: controller.configure(for: .photo, useFront: useFrontCamera, maxVideoSeconds: 0)
        case .video: controller.configure(for: .video, useFront: useFrontCamera, maxVideoSeconds: mode.recordLimitSeconds)
        case .audio: controller.stop()                // voice notes don't need the camera
        }
    }

    /// Switches photo / video / audio
    func setMode(_ newMode: ProofKind) {
        guard phase == .idle, newMode != mode else { return }
        mode = newMode
        reconfigure()
    }

    func flipCamera() {
        guard phase == .idle else { return }
        useFrontCamera.toggle()
        reconfigure()
    }

    // MARK: Capturing

    /// The big round button: photo mode takes a photo, other modes start/stop recording
    func captureOrToggleRecord() {
        switch mode {
        case .photo: takePhoto()
        case .video, .audio: isRecording ? stopRecording() : startRecording()
        }
    }

    /// The user accepted the proof
    func confirm() {
        guard let proof = pending else { return }
        phase = .idle
        onProof?(proof.data, proof.kind)
    }

    /// Throws the proof away and goes back to the camera
    func retake() {
        phase = .idle
        errorMessage = nil
        if mode != .audio { controller.start() }
    }

    // MARK: Lifecycle

    /// Pauses everything
    func suspend() {
        configTask?.cancel()
        stopVideoTimer()
        voice.cancel()
        if phase == .recording {
            if mode != .audio { controller.stopMovie() }
            phase = .idle                    // the movie delegate sees .idle and drops the file
        }
        controller.stop()
    }

    /// Restarts the camera after `suspend()`
    func resume() {
        if case .review = phase { return }
        reconfigure()
    }

    /// Full cleanup when leaving the screen
    func stopSession() {
        suspend()
        interruptionTask?.cancel()
        interruptionTask = nil
        phase = .idle                        // pending results from late callbacks get ignored
    }

    // MARK: - Private helpers

    /// Cancels any older configure call so quick taps don't stack up
    private func reconfigure() {
        configTask?.cancel()
        configTask = Task { await configure() }
    }

    private func takePhoto() {
        guard phase == .idle else { return }
        errorMessage = nil
        phase = .checking
        controller.capturePhoto(delegate: self) { [weak self] in
            Task { @MainActor [weak self] in self?.fail("Camera isn't ready yet.") }
        }
    }

    private func startRecording() {
        guard phase == .idle else { return }
        errorMessage = nil

        if mode == .audio {
            if voice.start(limit: mode.recordLimitSeconds) { phase = .recording }
            else { errorMessage = "Couldn't start recording." }
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        videoElapsed = 0
        phase = .recording
        controller.startMovie(to: url, delegate: self) { [weak self] in
            Task { @MainActor [weak self] in self?.fail("Camera isn't ready yet.") }
        }
        // The timer only updates the label. The movie output stops itself at the time limit.
        videoTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.phase == .recording else { return }
                self.videoElapsed += 1
            }
        }
    }

    /// Locks the UI right away (phase = .checking) so the mode can't change while the file finishes
    private func stopRecording() {
        guard phase == .recording else { return }
        phase = .checking
        stopVideoTimer()
        if mode == .audio { voice.stop() } else { controller.stopMovie() }
    }

    private func stopVideoTimer() {
        videoTimer?.invalidate()
        videoTimer = nil
    }

    /// Shows an error and goes back to idle.
    private func fail(_ message: String?) {
        stopVideoTimer()
        errorMessage = message
        phase = .idle
    }

    /// Checks the captured media, then moves to the review phase
    private func verifyAndDeliver(data: Data, kind: ProofKind, frameJPEG: Data?) {
        phase = .checking
        Task {
            try? await Task.sleep(for: .milliseconds(300))        // short pause so "Verifying…" is visible
            if kind != .audio {
                let jpeg = frameJPEG ?? data
                // Run the check off the main thread. ProofValidator.checkJPEG must be `nonisolated`.
                let result = await Task.detached(priority: .userInitiated) { ProofValidator.checkJPEG(jpeg) }.value
                guard phase == .checking else { return }          // screen was closed meanwhile
                if !result.ok { fail(result.reason); return }
            }
            guard phase == .checking else { return }
            errorMessage = nil
            phase = .review(PendingProof(data: data, kind: kind))
            controller.stop()                                     // no need to run the camera behind the review
        }
    }

    /// Compresses a finished video and sends it into the check
    private func processRecording(_ url: URL, error: Error?) async {
        defer { try? FileManager.default.removeItem(at: url) }    // runs on every exit path: no leaked .mov
        guard phase == .recording || phase == .checking else { return }   // cancelled or screen closed
        stopVideoTimer()
        phase = .checking

        // Hitting the max duration reports an "error" but still saved the file fine.
        if let error, (error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool != true {
            fail("Recording failed. Try again.")
            return
        }
        do {
            let frame = await ProofCompressor.firstFrameJPEG(url)
            let data = try await ProofCompressor.compress(url, kind: .video)
            guard phase == .checking else { return }
            verifyAndDeliver(data: data, kind: .video, frameJPEG: frame)
        } catch {
            fail("Couldn't process the recording.")
        }
    }

    /// Result from the voice recorder
    private func handleVoice(_ outcome: VoiceRecorder.Outcome) {
        guard phase == .recording || phase == .checking else { return }
        switch outcome {
        case .recorded(let data, let peak):
            if peak < 12 {                    // 12 is about -44 dB; normal speech peaks at 40–70
                fail("We couldn't hear anything. Say what you did.")
            } else {
                verifyAndDeliver(data: data, kind: .audio, frameJPEG: nil)   // already AAC, no re-encode
            }
        case .tooShort: fail("Too short. Say a bit more.")
        case .failed: fail("Recording failed. Try again.")
        }
    }

    /// Stops a recording if the camera gets interrupted (phone call, another app takes the camera)
    private func observeInterruptions() {
        guard interruptionTask == nil else { return }
        interruptionTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVCaptureSession.wasInterruptedNotification) {
                self?.stopRecording()
            }
        }
    }

    private static func requestAccess(for media: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .authorized: true
        case .notDetermined:
            // Turns the old callback style into async/await.
            await withCheckedContinuation { cont in
                AVCaptureDevice.requestAccess(for: media) { cont.resume(returning: $0) }
            }
        default: false
        }
    }
}

// MARK: - AVFoundation delegates
// These are called on background threads, so they are `nonisolated` and hop back with Task { @MainActor }.

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Shrink the photo here on the background thread (UIImage.draw keeps the orientation)
        let small = error == nil
            ? photo.fileDataRepresentation()?.jpegDownscaled(maxSide: 1080, quality: 0.8)
            : nil
        Task { @MainActor in
            guard phase == .checking else { return }
            guard let small else { fail("Couldn't take the photo. Try again."); return }
            verifyAndDeliver(data: small, kind: .photo, frameJPEG: small)
        }
    }
}

extension CameraModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL,
                                from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in await processRecording(url, error: error) }
    }
}
