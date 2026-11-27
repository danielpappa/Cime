///  All logic lives in CameraModel; this file is only layout

import SwiftUI

struct LiveCameraView: View {
    let goal: String
    let modes: [ProofKind]
    let onClose: () -> Void
    let onProof: (Data, ProofKind) -> Void

    // @State keeps the model alive between re-renders of this view
    @State private var model: CameraModel
    @Environment(\.scenePhase) private var scenePhase     // when the app goes to background

    init(goal: String,
         modes: [ProofKind] = ProofKind.allCases,
         onClose: @escaping () -> Void,
         onProof: @escaping (Data, ProofKind) -> Void) {
        self.goal = goal
        self.modes = modes
        self.onClose = onClose
        self.onProof = onProof
        // Start in the first mode that was offered
        _model = State(initialValue: CameraModel(mode: modes.first ?? .photo))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 12)

                Text(liveLabel)
                    .monoCaps(14)
                    .foregroundStyle(Theme.summit)
                    .padding(.bottom, 8)

                Text("\"\(goal)\"")
                    .displayFont(24, weight: .bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 24)

                previewArea
                    .padding(20)
                    .frame(maxHeight: .infinity)

                if let err = model.errorMessage {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(Theme.snow)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.destructive.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 24)
                }

                if model.pending != nil {
                    ReviewBar(onRetake: model.retake, onConfirm: model.confirm)
                } else {
                    controls
                }
            }
        }
        .riseOnAppear()
        .task {                                   // runs when the view appears, cancelled when it disappears
            model.bind(onProof: onProof)
            await model.configure()
        }
        .onDisappear { model.stopSession() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background { model.suspend() }
            else if newPhase == .active { model.resume() }
        }
    }

    // MARK: - Pieces

    /// The framed area in the middle: preview or meter, review overlay, and the "verifying" overlay
    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))

            Group {
                if model.mode == .audio {
                    AudioMeter(level: model.audioLevel, isRecording: model.isRecording)
                } else {
                    CameraPreview(session: model.session)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if let proof = model.pending {
                Group {
                    if proof.kind == .audio {
                        LocalAudioSlide(data: proof.data, autoplay: true)     // plays back right away
                    } else {
                        ProofMediaView(data: proof.data, kind: proof.kind)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if model.isChecking {
                Theme.background.opacity(0.7)
                Text("Verifying summit…")
                    .monoCaps(13)
                    .foregroundStyle(Theme.glacier)
            }
        }
    }

    /// Mode picker (if more than one mode) plus close / record / flip buttons
    private var controls: some View {
        let locked = model.isRecording || model.isChecking
        let flipDisabled = model.mode == .audio || locked

        return VStack(spacing: 0) {
            if modes.count > 1 {
                ModePicker(modes: modes, current: model.mode, disabled: locked, onSelect: model.setMode)
                    .padding(.bottom, 12)
            }

            HStack(spacing: 40) {
                CircleIconButton(systemName: "xmark", label: "Close", action: onClose)

                CaptureButton(mode: model.mode, isRecording: model.isRecording, action: model.captureOrToggleRecord)
                    .disabled(model.isChecking)

                CircleIconButton(systemName: "arrow.triangle.2.circlepath",
                                 label: "Flip camera",
                                 dimmed: flipDisabled,
                                 action: model.flipCamera)
                    .disabled(flipDisabled)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var liveLabel: String {
        if model.pending != nil { return "Review" }
        if model.isRecording, model.mode != .photo {
            return "● Live · \(model.recordingElapsed)s / \(model.mode.recordLimitSeconds)s"
        }
        return "● Live"
    }
}

// MARK: - Small subviews

/// Round icon button used for close and flip (they used to be copy-pasted)
private struct CircleIconButton: View {
    let systemName: String
    let label: String              // read out by VoiceOver
    var dimmed = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(dimmed ? Theme.mutedForeground : Theme.foreground)
                .frame(width: 48, height: 48)
                .background(Theme.card)
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
        .opacity(dimmed ? 0.3 : 1)
    }
}

/// Row of capsule buttons to pick photo / video / voice.
private struct ModePicker: View {
    let modes: [ProofKind]
    let current: ProofKind
    let disabled: Bool
    let onSelect: (ProofKind) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(modes, id: \.self) { m in
                Button(m.label) { onSelect(m) }
                    .monoCaps(11)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(current == m ? Theme.secondary : Color.clear)
                    .foregroundStyle(current == m ? Theme.foreground : Theme.mutedForeground)
                    .clipShape(Capsule())
                    .disabled(disabled)
            }
        }
    }
}

/// The big shutter button
private struct CaptureButton: View {
    let mode: ProofKind
    let isRecording: Bool
    let action: () -> Void

    private var label: String {
        if mode == .photo { return "Take photo" }
        return isRecording ? "Stop recording" : "Start recording"
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(Theme.snow, lineWidth: 4).frame(width: 80, height: 80)
                Circle().fill(Theme.summit).frame(width: 68, height: 68)
                if mode != .photo {
                    // red rounded square while idle, white square while recording
                    RoundedRectangle(cornerRadius: isRecording ? 4 : 12)
                        .fill(isRecording ? Theme.snow : Theme.destructive)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .emberGlow()
        .accessibilityLabel(label)
    }
}

/// "Retake" and "Use this" buttons shown while reviewing
private struct ReviewBar: View {
    let onRetake: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onRetake) {
                Label("Retake", systemImage: "arrow.counterclockwise")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Theme.card).foregroundStyle(Theme.foreground)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button(action: onConfirm) {
                Text("Use this")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Theme.primary).foregroundStyle(Theme.primaryForeground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .emberGlow()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

/// Animated bars for voice notes. `level` is 0...1 from the microphone
private struct AudioMeter: View {
    let level: CGFloat
    let isRecording: Bool

    var body: some View {
        // TimelineView redraws every frame, which gives the wave movement.
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            VStack(spacing: 24) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<12, id: \.self) { i in
                        let wave = 0.5 + 0.5 * abs(sin(t * 6 + Double(i) * 0.7))   // each bar is slightly out of phase
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.summit)
                            .frame(width: 12, height: 10 + (isRecording ? level * 90 * wave : 0))
                    }
                }
                .frame(height: 100)

                Text(isRecording ? "Recording… tap to finish" : "Tap to record a voice note about what you did")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }
}

#Preview {
    LiveCameraView(goal: "Reach the Summit", modes: [.audio, .video, .photo], onClose: {}, onProof: { _, _ in })
}
