import SwiftUI

struct CimeView: View {
    let done: [Bool]
    var color: Color?

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 270
            let sy = size.height / 150
            context.scaleBy(x: sx, y: sy)
            
            
            let towers: [Path] = [
                cima1ombra,
                cima2ombra,
                cima3ombra
            ]
            
            for (index, path) in towers.enumerated() {
                if color != nil {
                    context.fill(path, with: .color(color!))
                } else {
                    let reached = done.indices.contains(index) && done[index]
                    
                    let baseColor = reached ? Theme.summit.opacity(0.5) :  Theme.secondary.opacity(0.3)
                    context.fill(path, with: .color(baseColor))
                    context.stroke(path, with: .color(Theme.border.opacity(0.5)), lineWidth: 1)
                }
            }
        }
        .frame(height: 220)
        .accessibilityLabel("Your three peaks")
    }

    private var cima1ombra: Path {
            Path { p in
                p.move(to: CGPoint(x: 85, y: 44))
                p.addLine(to: CGPoint(x: 77, y: 45))
                p.addLine(to: CGPoint(x: 75, y: 48))
                p.addLine(to: CGPoint(x: 75, y: 53))
                p.addLine(to: CGPoint(x: 70, y: 54))
                p.addLine(to: CGPoint(x: 66, y: 52))
                p.addLine(to: CGPoint(x: 63, y: 43))
                p.addLine(to: CGPoint(x: 61, y: 43))
                p.addLine(to: CGPoint(x: 58, y: 48))
                p.addLine(to: CGPoint(x: 56, y: 57))
                p.addLine(to: CGPoint(x: 46, y: 57))
                p.addLine(to: CGPoint(x: 39, y: 61))
                p.addLine(to: CGPoint(x: 34, y: 61))
                p.addLine(to: CGPoint(x: 30, y: 79))
                p.addLine(to: CGPoint(x: 31, y: 94))
                p.addLine(to: CGPoint(x: 29, y: 97))
                p.addLine(to: CGPoint(x: 27, y: 97))
                p.addLine(to: CGPoint(x: 27, y: 101))
                p.addLine(to: CGPoint(x: 22, y: 111))
                p.addLine(to: CGPoint(x: 16, y: 116))
                p.addLine(to: CGPoint(x: 13, y: 116))
                p.addLine(to: CGPoint(x: 14, y: 118))
                p.addLine(to: CGPoint(x: 25, y: 119))
                p.addLine(to: CGPoint(x: 34, y: 116))
                p.addLine(to: CGPoint(x: 33, y: 107))
                p.addLine(to: CGPoint(x: 35, y: 104))
                p.addLine(to: CGPoint(x: 39, y: 104))
                p.addLine(to: CGPoint(x: 39, y: 111))
                p.addLine(to: CGPoint(x: 41, y: 112))
                p.addLine(to: CGPoint(x: 43, y: 117))
                p.addLine(to: CGPoint(x: 51, y: 117))
                p.addLine(to: CGPoint(x: 56, y: 121))
                p.addLine(to: CGPoint(x: 65, y: 120))
                p.addLine(to: CGPoint(x: 78, y: 126))
                p.addLine(to: CGPoint(x: 90, y: 124))
                p.addLine(to: CGPoint(x: 93, y: 122))
                p.addLine(to: CGPoint(x: 93, y: 107))
                p.addLine(to: CGPoint(x: 90, y: 94))
                p.addLine(to: CGPoint(x: 91, y: 87))
                p.addLine(to: CGPoint(x: 89, y: 86))
                p.addLine(to: CGPoint(x: 89, y: 60))
                p.addLine(to: CGPoint(x: 88, y: 51))
                p.closeSubpath()
            }
        }

        private var cima1sole: Path {
            Path { p in
                p.move(to: CGPoint(x: 66, y: 51))
                p.addLine(to: CGPoint(x: 61, y: 54))
                p.addLine(to: CGPoint(x: 59, y: 65))
                p.addLine(to: CGPoint(x: 52, y: 72))
                p.addLine(to: CGPoint(x: 50, y: 58))
                p.addLine(to: CGPoint(x: 47, y: 61))
                p.addLine(to: CGPoint(x: 42, y: 99))
                p.addLine(to: CGPoint(x: 43, y: 117))
                p.addLine(to: CGPoint(x: 49, y: 117))
                p.addLine(to: CGPoint(x: 48, y: 115))
                p.addLine(to: CGPoint(x: 43, y: 117))
                p.addLine(to: CGPoint(x: 51, y: 117))
                p.addLine(to: CGPoint(x: 56, y: 121))
                p.addLine(to: CGPoint(x: 65, y: 120))
                p.addLine(to: CGPoint(x: 78, y: 126))
                p.addLine(to: CGPoint(x: 90, y: 124))
                p.addLine(to: CGPoint(x: 93, y: 122))
                p.addLine(to: CGPoint(x: 93, y: 107))
                p.addLine(to: CGPoint(x: 93, y: 109))
                p.addLine(to: CGPoint(x: 85, y: 99))
                p.addLine(to: CGPoint(x: 81, y: 87))
                p.addLine(to: CGPoint(x: 81, y: 79))
                p.addLine(to: CGPoint(x: 77, y: 72))
                p.addLine(to: CGPoint(x: 73, y: 55))
                p.closeSubpath()
            }
        }

        private var cima2ombra: Path {
            Path { p in
                p.move(to: CGPoint(x: 137, y: 26))
                p.addLine(to: CGPoint(x: 130, y: 26))
                p.addLine(to: CGPoint(x: 123, y: 32))
                p.addLine(to: CGPoint(x: 110, y: 51))
                p.addLine(to: CGPoint(x: 105, y: 54))
                p.addLine(to: CGPoint(x: 102, y: 67))
                p.addLine(to: CGPoint(x: 101, y: 68))
                p.addLine(to: CGPoint(x: 100, y: 70))
                p.addLine(to: CGPoint(x: 98, y: 79))
                p.addLine(to: CGPoint(x: 95, y: 82))
                p.addLine(to: CGPoint(x: 96, y: 87))
                p.addLine(to: CGPoint(x: 96, y: 95))
                p.addLine(to: CGPoint(x: 95, y: 115))
                p.addLine(to: CGPoint(x: 102, y: 115))
                p.addLine(to: CGPoint(x: 103, y: 121))
                p.addLine(to: CGPoint(x: 113, y: 128))
                p.addLine(to: CGPoint(x: 137, y: 128))
                p.addLine(to: CGPoint(x: 162, y: 125))
                p.addLine(to: CGPoint(x: 163, y: 123))
                p.addLine(to: CGPoint(x: 173, y: 124))
                p.addLine(to: CGPoint(x: 174, y: 71))
                p.addLine(to: CGPoint(x: 166, y: 83))
                p.addLine(to: CGPoint(x: 161, y: 82))
                p.addLine(to: CGPoint(x: 157, y: 59))
                p.addLine(to: CGPoint(x: 154, y: 56))
                p.addLine(to: CGPoint(x: 153, y: 51))
                p.addLine(to: CGPoint(x: 151, y: 50))
                p.addLine(to: CGPoint(x: 151, y: 48))
                p.addLine(to: CGPoint(x: 150, y: 46))
                p.addLine(to: CGPoint(x: 145, y: 42))
                p.addLine(to: CGPoint(x: 144, y: 36))
                p.addLine(to: CGPoint(x: 141, y: 35))
                p.addLine(to: CGPoint(x: 141, y: 31))
                p.addLine(to: CGPoint(x: 137, y: 30))
                p.closeSubpath()
            }
        }

        private var cima2sole: Path {
            Path { p in
                p.move(to: CGPoint(x: 130, y: 10))
                p.move(to: CGPoint(x: 128, y: 27))
                p.move(to: CGPoint(x: 126, y: 30))
                p.addLine(to: CGPoint(x: 106, y: 91))
                p.addLine(to: CGPoint(x: 103, y: 121))
                p.addLine(to: CGPoint(x: 113, y: 128))
                p.addLine(to: CGPoint(x: 173, y: 124))
                p.addLine(to: CGPoint(x: 166, y: 111))
                p.addLine(to: CGPoint(x: 163, y: 91))
                p.addLine(to: CGPoint(x: 157, y: 59))
                p.addLine(to: CGPoint(x: 153, y: 57))
                p.addLine(to: CGPoint(x: 157, y: 96))
                p.addLine(to: CGPoint(x: 154, y: 98))
                p.addLine(to: CGPoint(x: 152, y: 95))
                p.addLine(to: CGPoint(x: 147, y: 51))
                p.addLine(to: CGPoint(x: 141, y: 31))
                p.addLine(to: CGPoint(x: 140, y: 48))
                p.addLine(to: CGPoint(x: 138, y: 53))
                p.addLine(to: CGPoint(x: 136, y: 69))
                p.addLine(to: CGPoint(x: 133, y: 71))
                p.addLine(to: CGPoint(x: 132, y: 67))
                p.addLine(to: CGPoint(x: 131, y: 34))
                p.closeSubpath()
            }
        }

        private var cima3ombra: Path {
            Path { p in
                p.move(to: CGPoint(x: 185, y: 53))
                p.addLine(to: CGPoint(x: 181, y: 57))
                p.addLine(to: CGPoint(x: 181, y: 63))
                p.addLine(to: CGPoint(x: 176, y: 66))
                p.addLine(to: CGPoint(x: 175, y: 70))
                p.addLine(to: CGPoint(x: 177, y: 124))
                p.addLine(to: CGPoint(x: 181, y: 127))
                p.addLine(to: CGPoint(x: 188, y: 127))
                p.addLine(to: CGPoint(x: 194, y: 131))
                p.addLine(to: CGPoint(x: 202, y: 132))
                p.addLine(to: CGPoint(x: 212, y: 136))
                p.addLine(to: CGPoint(x: 216, y: 136))
                p.addLine(to: CGPoint(x: 229, y: 131))
                p.addLine(to: CGPoint(x: 232, y: 127))
                p.addLine(to: CGPoint(x: 237, y: 127))
                p.addLine(to: CGPoint(x: 248, y: 133))
                p.addLine(to: CGPoint(x: 254, y: 133))
                p.addLine(to: CGPoint(x: 255, y: 123))
                p.addLine(to: CGPoint(x: 252, y: 123))
                p.addLine(to: CGPoint(x: 246, y: 115))
                p.addLine(to: CGPoint(x: 246, y: 109))
                p.addLine(to: CGPoint(x: 242, y: 107))
                p.addLine(to: CGPoint(x: 235, y: 107))
                p.addLine(to: CGPoint(x: 234, y: 104))
                p.addLine(to: CGPoint(x: 232, y: 104))
                p.addLine(to: CGPoint(x: 231, y: 101))
                p.addLine(to: CGPoint(x: 227, y: 99))
                p.addLine(to: CGPoint(x: 227, y: 88))
                p.addLine(to: CGPoint(x: 219, y: 75))
                p.addLine(to: CGPoint(x: 216, y: 75))
                p.addLine(to: CGPoint(x: 215, y: 71))
                p.addLine(to: CGPoint(x: 214, y: 67))
                p.addLine(to: CGPoint(x: 209, y: 67))
                p.addLine(to: CGPoint(x: 207, y: 65))
                p.addLine(to: CGPoint(x: 205, y: 64))
                p.addLine(to: CGPoint(x: 203, y: 62))
                p.addLine(to: CGPoint(x: 202, y: 63))
                p.addLine(to: CGPoint(x: 201, y: 61))
                p.addLine(to: CGPoint(x: 200, y: 57))
                p.addLine(to: CGPoint(x: 192, y: 49))
                p.addLine(to: CGPoint(x: 189, y: 53))
                p.closeSubpath()
            }
        }

        private var cima3sole: Path {
            Path { p in
                p.move(to: CGPoint(x: 199, y: 55))
                p.addLine(to: CGPoint(x: 198, y: 69))
                p.addLine(to: CGPoint(x: 203, y: 91))
                p.addLine(to: CGPoint(x: 199, y: 100))
                p.addLine(to: CGPoint(x: 199, y: 114))
                p.addLine(to: CGPoint(x: 197, y: 114))
                p.addLine(to: CGPoint(x: 195, y: 115))
                p.addLine(to: CGPoint(x: 196, y: 127))
                p.addLine(to: CGPoint(x: 205, y: 134))
                p.addLine(to: CGPoint(x: 216, y: 136))
                p.addLine(to: CGPoint(x: 235, y: 127))
                p.addLine(to: CGPoint(x: 231, y: 125))
                p.addLine(to: CGPoint(x: 228, y: 119))
                p.addLine(to: CGPoint(x: 227, y: 88))
                p.addLine(to: CGPoint(x: 221, y: 77))
                p.addLine(to: CGPoint(x: 215, y: 74))
                p.addLine(to: CGPoint(x: 215, y: 71))
                p.addLine(to: CGPoint(x: 214, y: 78))
                p.addLine(to: CGPoint(x: 224, y: 107))
                p.addLine(to: CGPoint(x: 222, y: 114))
                p.addLine(to: CGPoint(x: 220, y: 107))
                p.addLine(to: CGPoint(x: 219, y: 75))
                p.addLine(to: CGPoint(x: 216, y: 75))
                p.addLine(to: CGPoint(x: 215, y: 71))
                p.addLine(to: CGPoint(x: 214, y: 67))
                p.addLine(to: CGPoint(x: 209, y: 67))
                p.addLine(to: CGPoint(x: 207, y: 65))
                p.addLine(to: CGPoint(x: 205, y: 64))
                p.addLine(to: CGPoint(x: 203, y: 62))
                p.addLine(to: CGPoint(x: 202, y: 63))
                p.closeSubpath()
            }
        }

}

#Preview {
    CimeView(done: [true, true, true])
}
