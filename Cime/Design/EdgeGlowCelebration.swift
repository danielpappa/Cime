import SwiftUI
import UIKit

/// Apple Intelligence styled glowing border around the phone
/// Invoced whenever the three goals are achieved as a celebration
struct EdgeGlowCelebration: View {
    let trigger: Int                    // Triggers celebration on change
    var cornerRadius: CGFloat = 56      // Face ID iPhones are roughly 47–62

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var intensity = 0.0
    @State private var running: Task<Void, Never>?

    /// Repeating gradient stops; first and last colors match to prevent a visible seam.
    private let colors: [Color] = [Theme.summit, Theme.glacier, Theme.snow, Theme.summit.opacity(0.9), Theme.glacier, Theme.summit]

    var body: some View {
        ZStack {
            if visible {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    glow(angle: .degrees(reduceMotion ? 0 : (t * 110).truncatingRemainder(dividingBy: 360)))
                }
                .opacity(intensity)

            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)    // Does not intercept touches meant for underlying views
        .onChange(of: trigger) { _, _ in
            running?.cancel()
            running = Task { await play() }
        }
    }

    /// Renders three stacked, blurred stroke borders to create a layered neon edge glow
    private func glow(angle: Angle) -> some View {
        let gradient = AngularGradient(colors: colors, center: .center, angle: angle)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            shape.strokeBorder(gradient, lineWidth: 28).blur(radius: 28).opacity(0.55)   // haze
            shape.strokeBorder(gradient, lineWidth: 12).blur(radius: 10).opacity(0.80)   // glow
            shape.strokeBorder(gradient, lineWidth: 4).blur(radius: 1.5)                 // line
        }
        .compositingGroup()
        .blendMode(.plusLighter)
    }

    /// Sequences the delay, haptic feedback, fade-in, hold, and fade-out lifecycle
    @MainActor private func play() async {
        try? await Task.sleep(for: .milliseconds(350))      // let the camera sheet close
        guard !Task.isCancelled else { return }
        
        visible = true;
        intensity = 0
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        
        withAnimation(.easeOut(duration: 0.7)) { intensity = 1 }

        try? await Task.sleep(for: .seconds(2.6))
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 1.1)) { intensity = 0 }

        try? await Task.sleep(for: .seconds(1.1))
        guard !Task.isCancelled else { return }

        visible = false
    }
}

#Preview {
    @Previewable @State var trigger = 0

    ZStack {
        // Use a dark background to make the edge glow pop
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            Button("Trigger Celebration") {
                trigger += 1
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 50)
        }

        // The celebration view
        EdgeGlowCelebration(trigger: trigger)
    }
}
