///  Records a short voice note with AVAudioRecorder and reports a level for the bar view

import AVFoundation
import Observation
import UIKit

/// Records audio to a temp .m4a file
@MainActor
@Observable
final class VoiceRecorder: NSObject {

    /// How a recording ended
    enum Outcome {
        case recorded(Data, peak: Float)   // peak = loudest moment (0...100), used to detect silence
        case tooShort
        case failed
    }

    private(set) var isRecording = false
    private(set) var elapsed = 0              // seconds
    private(set) var level: CGFloat = 0       // 0...1, drives the meter bars

    /// Called once per recording with the result
    @ObservationIgnored var onFinish: ((Outcome) -> Void)?

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var meterTimer: Timer?
    private var interruptionTask: Task<Void, Never>?
    private var peak: Float = 0
    private var limit = 30

    /// Starts recording. Returns false if the recorder couldn't start
    func start(limit: Int) -> Bool {
        guard !isRecording else { return false }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            let newRecorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 22_050,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 48_000            // small file, roughly 350 KB for 30 s
            ])
            newRecorder.delegate = self
            newRecorder.isMeteringEnabled = true       // needed to read the loudness
            guard newRecorder.record() else { return false }

            recorder = newRecorder
            fileURL = url
            self.limit = limit
            peak = 0
            elapsed = 0
            level = 0
            isRecording = true

            // Check the loudness 20 times per second.
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.tick() }   // Timer isn't main-actor, so hop back
            }
            // A phone call etc. can interrupt us without any delegate callback, so listen for it.
            interruptionTask = Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: AVAudioSession.interruptionNotification) {
                    self?.handleInterruption()
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Stops normally. The delegate callback below then delivers the result
    func stop() {
        isRecording = false
        recorder?.stop()
    }

    /// Stops and throws the recording away without calling `onFinish`
    func cancel() {
        guard let url = fileURL else { return }
        fileURL = nil                       // finish() sees nil and does nothing
        recorder?.stop()                    // stop first, delete second
        resetState()
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    /// Runs every 0.05 s while recording
    private func tick() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        // averagePower is in dB (-160...0). Only care about -50...0 and map that to 0...1.
        let normalized = max(0, min(1, (recorder.averagePower(forChannel: 0) + 50) / 50))
        level = CGFloat(normalized)
        peak = max(peak, normalized * 100)
        elapsed = Int(recorder.currentTime)
        if elapsed >= limit { stop() }
    }

    private func handleInterruption() {
        guard recorder != nil else { return }
        recorder?.stop()
        finish(success: true)           // keep everything so far
    }

    /// Reads the finished file, cleans up and reports the outcome
    private func finish(success: Bool) {
        guard let url = fileURL else { return }
        fileURL = nil
        resetState()
        defer { try? FileManager.default.removeItem(at: url) }   // always delete the temp file

        // Measure the length from the finished file, not from old state.
        let duration = (try? AVAudioPlayer(contentsOf: url))?.duration ?? 0
        guard success, let data = try? Data(contentsOf: url) else { onFinish?(.failed); return }
        guard duration >= 1 else { onFinish?(.tooShort); return }
        onFinish?(.recorded(data, peak: peak))
    }

    private func resetState() {
        meterTimer?.invalidate()
        meterTimer = nil
        interruptionTask?.cancel()
        interruptionTask = nil
        recorder = nil
        isRecording = false
        elapsed = 0
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension VoiceRecorder: AVAudioRecorderDelegate {
    // The delegate is called from a background thread, so hop to the main actor
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in self.finish(success: flag) }
    }
}
