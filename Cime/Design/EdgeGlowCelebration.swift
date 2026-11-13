//
//  EdgeGlowCelebration.swift
//  Cime
//
//  Created by Daniel Pappalardo on 07/11/2026.
//

import SwiftUI
import UIKit

struct EdgeGlowCelebration: View {
    let trigger: Int
    var cornerRadius: CGFloat = 56          // Face ID iPhones are roughly 47–62; tune to taste

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var intensity = 0.0
    @State private var running: Task<Void, Never>?

    // first == last so the angular gradient has no seam
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
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            running?.cancel()
            running = Task { await play() }
        }
    }

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

    @MainActor private func play() async {
        try? await Task.sleep(for: .milliseconds(350))      // let the camera sheet finish dismissing
        guard !Task.isCancelled else { return }
        visible = true; intensity = 0
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        withAnimation(.easeOut(duration: 0.7)) { intensity = 1 }
        try? await Task.sleep(for: .seconds(2.6))
        try? await Task.sleep(for: .seconds(1.1))
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
