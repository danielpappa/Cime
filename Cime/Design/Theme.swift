import SwiftUI

/// Namespace for application cover palette
enum Theme {
    static let background = Color(red: 0.12, green: 0.16, blue: 0.16)
    static let card = Color(red: 0.18, green: 0.22, blue: 0.22)
    static let muted = Color(red: 0.20, green: 0.24, blue: 0.24)
    static let secondary = Color(red: 0.22, green: 0.26, blue: 0.26)
    static let border = Color(red: 0.28, green: 0.32, blue: 0.32)

    static let foreground = Color(red: 0.95, green: 0.94, blue: 0.90)
    static let mutedForeground = Color(red: 0.62, green: 0.68, blue: 0.68)

    static let snow = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let summit = Color(red: 0.92, green: 0.58, blue: 0.35)
    static let glacier = Color(red: 0.72, green: 0.88, blue: 0.92)

    static let primary = summit
    static let primaryForeground = background
    static let accent = glacier
    static let accentForeground = background
    static let destructive = Color(red: 0.78, green: 0.35, blue: 0.28)
}

/// Main application background, extending to edges with a light gradient
struct TopoBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Theme.background
                    RadialGradient(
                        colors: [Theme.summit.opacity(0.35), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 400
                    )
                }
                .ignoresSafeArea()
            }
    }
}

/// Animate a View fading in and rising up
struct RiseTransition: ViewModifier {
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.5)) {
                    appeared = true
                }
            }
    }
}

/// Convenience methods to style views
extension View {
    /// Set standard background
    func topoBackground() -> some View {
        modifier(TopoBackground())
    }

    /// Add glowing effect from behind
    func emberGlow() -> some View {
        shadow(color: Theme.summit.opacity(0.55), radius: 20, y: 8)
    }

    /// Set monospaced, capitalized font
    func monoCaps(_ size: CGFloat = 10) -> some View {
        font(.system(size: size, weight: .medium, design: .monospaced))
            .textCase(.uppercase)
            .tracking(2)
    }

    /// Set maint title font
    func displayFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        font(.system(size: size, weight: weight, design: .rounded))
    }
    
    /// Let View rise from below
    func riseOnAppear() -> some View {
        modifier(RiseTransition())
    }
}
