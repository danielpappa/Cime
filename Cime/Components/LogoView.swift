import SwiftUI

public enum PeakStatus: Equatable {
    case todo
    case done
}

public struct LogoPalette {
    public var done: Color
    public var todo: Color
    public var overlapShade: Double

    public static let theme = LogoPalette(
        done: Theme.summit, todo: Theme.secondary, overlapShade: 0.15)
}


public struct LogoView: View {
    public var statuses: [PeakStatus]
    public var height: CGFloat = 220
    public var palette: LogoPalette = .theme

    public init(statuses: [PeakStatus], height: CGFloat = 220, palette: LogoPalette = .theme) {
        self.statuses = statuses
        self.height = height
        self.palette = palette
    }

    public init(done: [Bool], height: CGFloat = 220, palette: LogoPalette = .theme) {
        self.init(statuses: (0..<3).map { done.indices.contains($0) && done[$0] ? .done : .todo },
                  height: height, palette: palette)
    }

    private func status(_ i: Int) -> PeakStatus { statuses.indices.contains(i) ? statuses[i] : .todo }

    private func color(_ i: Int) -> Color {
        switch status(i) {
        case .todo: palette.todo
        case .done: palette.done
        }
    }
    
    private enum OverlapStyle { case overlap, todo, done }

    private var isDone: [Bool] { (0..<3).map { status($0) == .done } }

    private var leftOverlap: OverlapStyle {
        isDone[0] && !isDone[1] ? .done : .overlap
    }

    private var rightOverlap: OverlapStyle {
        isDone[2] ? .overlap : (isDone[1] ? .done : .todo)
    }

    private func overlapShape(_ v: [Vertex], _ style: OverlapStyle) -> some View {
        ZStack {
            PolyShape(vertices: v).fill(style == .done ? palette.done : palette.todo)
            PolyShape(vertices: v).fill(Color.black.opacity(style == .overlap ? palette.overlapShade : 0))
        }
    }

    public var body: some View {
        ZStack {
            PolyShape(vertices: Geo.right).fill(color(2))
            PolyShape(vertices: Geo.right)
                .fill(Color.black.opacity(status(2) == .todo ? palette.overlapShade : 0))
            PolyShape(vertices: Geo.centre).fill(color(1))
            PolyShape(vertices: Geo.left).fill(color(0))
            overlapShape(Geo.overlapRight, rightOverlap)
            overlapShape(Geo.overlapLeft, leftOverlap)
        }
        .aspectRatio(Geo.size.width / Geo.size.height, contentMode: .fit)
        .frame(height: height)
        .animation(.easeInOut(duration: 0.35), value: statuses)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\((0..<3).filter { status($0) == .done }.count) of 3 peaks reached")
    }
}

private struct Vertex {
    var x: CGFloat
    var y: CGFloat
    var r: CGFloat = 0
    init(_ x: CGFloat, _ y: CGFloat, r: CGFloat = 0) { self.x = x; self.y = y; self.r = r }
}

private enum Geo {
    static let origin = CGPoint(x: 9, y: 97)
    static let size = CGSize(width: 858, height: 503)

    static let left    = [Vertex(207, 196, r: 20), Vertex(449, 600), Vertex(-35, 600, r: 60)]
    static let centre  = [Vertex(438, 80, r: 20),  Vertex(750, 600), Vertex(126, 600)]
    static let right   = [Vertex(669, 196, r: 20), Vertex(911, 600, r: 60), Vertex(427, 600)]

    static let overlapRight = [Vertex(588.3, 330.5), Vertex(750, 600), Vertex(427, 600)]
    static let overlapLeft  = [Vertex(287.7, 330.5), Vertex(449, 600), Vertex(126, 600)]
}


private struct PolyShape: Shape {
    let vertices: [Vertex]

    func path(in rect: CGRect) -> Path {
        let k = rect.width / Geo.size.width
        let pts = vertices.map {
            (p: CGPoint(x: rect.minX + ($0.x - Geo.origin.x) * k,
                        y: rect.minY + ($0.y - Geo.origin.y) * k),
             r: $0.r * k)
        }
        let n = pts.count
        var path = Path()
        path.move(to: CGPoint(x: (pts[n - 1].p.x + pts[0].p.x) / 2,
                              y: (pts[n - 1].p.y + pts[0].p.y) / 2))
        for i in 0..<n {
            let next = pts[(i + 1) % n].p
            if pts[i].r > 0 {
                path.addArc(tangent1End: pts[i].p, tangent2End: next, radius: pts[i].r)
            } else {
                path.addLine(to: pts[i].p)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview("Theme match") {
    VStack(spacing: 28) {
        LogoView(statuses: [.done, .done, .done], height: 200, palette: .theme)
        LogoView(statuses: [.done, .done, .todo], height: 120, palette: .theme)
        LogoView(done: [true, false, false], height: 120, palette: .theme)
        LogoView(done: [false, false, false], height: 120, palette: .theme)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

