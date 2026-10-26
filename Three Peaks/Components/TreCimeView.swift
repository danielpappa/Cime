import SwiftUI

struct TreCimeView: View {
    let done: [Bool]

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 270
            let sy = size.height / 150
            context.scaleBy(x: sx, y: sy)

            let towers: [(Path, Path?)] = [
                (tower1, done.indices.contains(0) && done[0] ? snow1 : nil),
                (tower2, done.indices.contains(1) && done[1] ? snow2 : nil),
                (tower3, done.indices.contains(2) && done[2] ? snow3 : nil),
            ]

            for (index, pair) in towers.enumerated() {
                let reached = done.indices.contains(index) && done[index]
                context.fill(pair.0, with: .color(reached ? Theme.summit : Theme.secondary))
                context.stroke(pair.0, with: .color(Theme.background.opacity(0.4)), lineWidth: 1)
                if let snow = pair.1 {
                    context.fill(snow, with: .color(Theme.snow))
                }
            }
        }
        .frame(height: 150)
        .accessibilityLabel("Your three peaks")
    }

    private var tower1: Path {
        Path { p in
            p.move(to: CGPoint(x: 18, y: 150))
            p.addLine(to: CGPoint(x: 30, y: 92))
            p.addLine(to: CGPoint(x: 36, y: 70))
            p.addLine(to: CGPoint(x: 44, y: 52))
            p.addLine(to: CGPoint(x: 52, y: 46))
            p.addLine(to: CGPoint(x: 58, y: 58))
            p.addLine(to: CGPoint(x: 64, y: 84))
            p.addLine(to: CGPoint(x: 72, y: 118))
            p.addLine(to: CGPoint(x: 80, y: 150))
            p.closeSubpath()
        }
    }

    private var snow1: Path {
        Path { p in
            p.move(to: CGPoint(x: 44, y: 52))
            p.addLine(to: CGPoint(x: 52, y: 46))
            p.addLine(to: CGPoint(x: 58, y: 58))
            p.addLine(to: CGPoint(x: 50, y: 60))
            p.closeSubpath()
        }
    }

    private var tower2: Path {
        Path { p in
            p.move(to: CGPoint(x: 76, y: 150))
            p.addLine(to: CGPoint(x: 88, y: 96))
            p.addLine(to: CGPoint(x: 96, y: 54))
            p.addLine(to: CGPoint(x: 104, y: 22))
            p.addLine(to: CGPoint(x: 114, y: 12))
            p.addLine(to: CGPoint(x: 132, y: 10))
            p.addLine(to: CGPoint(x: 144, y: 16))
            p.addLine(to: CGPoint(x: 152, y: 40))
            p.addLine(to: CGPoint(x: 160, y: 82))
            p.addLine(to: CGPoint(x: 170, y: 150))
            p.closeSubpath()
        }
    }

    private var snow2: Path {
        Path { p in
            p.move(to: CGPoint(x: 104, y: 22))
            p.addLine(to: CGPoint(x: 114, y: 12))
            p.addLine(to: CGPoint(x: 132, y: 10))
            p.addLine(to: CGPoint(x: 144, y: 16))
            p.addLine(to: CGPoint(x: 136, y: 24))
            p.addLine(to: CGPoint(x: 112, y: 26))
            p.closeSubpath()
        }
    }

    private var tower3: Path {
        Path { p in
            p.move(to: CGPoint(x: 162, y: 150))
            p.addLine(to: CGPoint(x: 172, y: 104))
            p.addLine(to: CGPoint(x: 180, y: 66))
            p.addLine(to: CGPoint(x: 190, y: 38))
            p.addLine(to: CGPoint(x: 204, y: 30))
            p.addLine(to: CGPoint(x: 222, y: 34))
            p.addLine(to: CGPoint(x: 232, y: 58))
            p.addLine(to: CGPoint(x: 242, y: 104))
            p.addLine(to: CGPoint(x: 252, y: 150))
            p.closeSubpath()
        }
    }

    private var snow3: Path {
        Path { p in
            p.move(to: CGPoint(x: 190, y: 38))
            p.addLine(to: CGPoint(x: 204, y: 30))
            p.addLine(to: CGPoint(x: 222, y: 34))
            p.addLine(to: CGPoint(x: 214, y: 42))
            p.addLine(to: CGPoint(x: 196, y: 44))
            p.closeSubpath()
        }
    }
}
