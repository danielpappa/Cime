import SwiftUI

struct LiveCameraView: View {
    let goal: String
    var modes: [ProofKind] = ProofKind.allCases
    let onClose: () -> Void
    let onProof: (Data, ProofKind) -> Void

    @State private var model = CameraModel()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("Close") { onClose() }
                        .monoCaps(11)
                        .foregroundStyle(Theme.mutedForeground)
                    Spacer()
                    Text(liveLabel)
                        .monoCaps(11)
                        .foregroundStyle(Theme.summit)
                    Spacer()
                    Button("Flip") { model.flipCamera() }
                        .monoCaps(11)
                        .foregroundStyle(Theme.mutedForeground)
                        .disabled(model.mode == .audio || model.isRecording)
                        .opacity(model.mode == .audio || model.isRecording ? 0.3 : 1)
                }
                .padding(20)

                Text("\"\(goal)\"")
                    .displayFont(22, weight: .regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.border)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))

                    Group {
                        if model.mode == .audio {
                            audioMeter
                        } else {
                            CameraPreview(session: model.session)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if model.isChecking {
                        Theme.background.opacity(0.7)
                        Text("Verifying summit…")
                            .monoCaps(13)
                            .foregroundStyle(Theme.glacier)
                    }
                }
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

                if modes.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(modes, id: \.self) { m in
                            Button(m.label) {
                                model.setMode(m)
                            }
                            .monoCaps(11)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(model.mode == m ? Theme.secondary : Color.clear)
                            .foregroundStyle(model.mode == m ? Theme.foreground : Theme.mutedForeground)
                            .clipShape(Capsule())
                            .disabled(model.isRecording || model.isChecking)
                        }
                    }
                    .padding(.bottom, 12)
                }

                Button {
                    model.captureOrToggleRecord()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Theme.snow, lineWidth: 4)
                            .frame(width: 80, height: 80)
                        Circle()
                            .fill(Theme.summit)
                            .frame(width: 68, height: 68)
                        if model.mode != .photo {
                            RoundedRectangle(cornerRadius: model.isRecording ? 4 : 12)
                                .fill(model.isRecording ? Theme.snow : Theme.destructive)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                .emberGlow()
                .disabled(model.isChecking)
                .padding(.bottom, 40)
            }
        }
        .riseOnAppear()
        .onAppear {
            model.bind(onProof: onProof)
            Task { await model.configure() }
        }
        .onDisappear { model.stopSession() }
    }

    private var liveLabel: String {
        if model.isRecording, model.mode != .photo {
            let limit = model.mode.recordLimitSeconds
            let elapsed = max(0, model.recordingElapsed - 1)
            return "● Live · \(elapsed)s / \(limit)s"
        }
        return "● Live"
    }

    private var audioMeter: some View {
        VStack(spacing: 24) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<12, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.summit)
                        .frame(width: 12, height: barHeight(index: i))
                }
            }
            .frame(height: 96)
            Text(model.isRecording ? "Recording… tap to finish" : "Tap to record a voice note about what you did")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func barHeight(index: Int) -> CGFloat {
        let wave = abs(sin(Double(index) * 1.7 + Double(model.recordingElapsed)))
        return 10 + model.audioLevel * 90 * (0.5 + wave)
    }
}
