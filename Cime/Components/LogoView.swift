import SwiftUI

/// Main enumeration used deciding how to color the logo
public enum PeakStatus: Equatable {
    case todo
    case done
}

/// Struct collecting the possible colors for the logo
public struct LogoPalette {
    public var done: Color
    public var todo: Color
    public var overlapShade: Double     // opacity applied to overlapping peaks in the logo

    /// Default cime palette using theme summit and secondary colors
    public static let theme = LogoPalette(
        done: Theme.summit,
        todo: Theme.secondary,
        overlapShade: 0.15
    )
}

/// View displaying the iconic three mountain peaks - the logo of cime
/// Assumes different styling depenging on `statuses`, `height` and `palette`
public struct LogoView: View {
    public var statuses: [PeakStatus]
    public var height: CGFloat = 220
    public var palette: LogoPalette = .theme

    /// Creates a logo view from an explicit array of peak statuses
    public init(statuses: [PeakStatus], height: CGFloat = 220, palette: LogoPalette = .theme) {
        self.statuses = statuses
        self.height = height
        self.palette = palette
    }
    
    /// Shading for overlapping triangles
    private enum OverlapStyle {
        case overlap
        case todo
        case done
    }

    /// Creates a logo view from boolean completion flags for up to three peaks
    public init(done: [Bool], height: CGFloat = 220, palette: LogoPalette = .theme) {
        self.init(statuses: (0..<3).map { done.indices.contains($0) && done[$0] ? .done : .todo },
                  height: height, palette: palette)
    }
    
    /// Number of completed peaks among the three displayed peaks
    private var doneCount: Int {
        (0..<3).filter { status($0) == .done }.count
    }

    /// Boolean completion array for all three peaks
    private var isDone: [Bool] {
        (0..<3).map { status($0) == .done }
    }

    /// Overlap style for the left peak's intersection region
    private var leftOverlap: OverlapStyle {
        isDone[0] && !isDone[1] ? .done : .overlap
    }

    /// Overlap style for the right peak's intersection region
    private var rightOverlap: OverlapStyle {
        if isDone[2] { return .overlap }
        return isDone[1] ? .done : .todo
    }

    /// Returns the status for peak `index`, defaulting to ``PeakStatus/todo`` if out of bounds
    private func status(_ i: Int) -> PeakStatus {
        statuses.indices.contains(i) ? statuses[i] : .todo
    }

    /// Returns the color corresponding to the peak status
    private func color(_ i: Int) -> Color {
        switch status(i) {
        case .todo: palette.todo
        case .done: palette.done
        }
    }
    
    /// Maps an ``OverlapStyle`` to its underlying color and optional opacity
    private func styleAppearance(_ style: OverlapStyle) -> (color: Color, shadeOpacity: Double) {
        switch style {
        case .done:
            (palette.done, 0)
        case .todo:
            (palette.todo, 0)
        case .overlap:
            (palette.todo, palette.overlapShade)
        }
    }

    /// Renders a polygon filled with `baseColor` and an optional dark layer
    private func shadedPolygon(
        _ vertices: [Vertex],
        baseColor: Color,
        shadeOpacity: Double = 0
    ) -> some View {
        ZStack {
            PolyShape(vertices: vertices).fill(baseColor)
            if shadeOpacity > 0 {
                PolyShape(vertices: vertices).fill(Color.black.opacity(shadeOpacity))
            }
        }
    }

    /// The actual view declaration
    public var body: some View {
        let rightShade = status(2) == .todo ? palette.overlapShade : 0
        let leftAppearance = styleAppearance(leftOverlap)
        let rightAppearance = styleAppearance(rightOverlap)

        ZStack {
            shadedPolygon(Geo.right, baseColor: color(2), shadeOpacity: rightShade)
            PolyShape(vertices: Geo.centre).fill(color(1))
            PolyShape(vertices: Geo.left).fill(color(0))
            shadedPolygon(
                Geo.overlapRight,
                baseColor: rightAppearance.color,
                shadeOpacity: rightAppearance.shadeOpacity
            )
            shadedPolygon(
                Geo.overlapLeft,
                baseColor: leftAppearance.color,
                shadeOpacity: leftAppearance.shadeOpacity
            )
        }
        .aspectRatio(Geo.size.width / Geo.size.height, contentMode: .fit)
        .frame(height: height)
        .animation(.easeInOut(duration: 0.35), value: statuses)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(doneCount) of 3 peaks reached")
    }
}

/// A 2D point with a corner radius in source space
private struct Vertex {
    var x: CGFloat
    var y: CGFloat
    var r: CGFloat

    /// Creates a vertex at `(x, y)` with an optional corner radius (0 means sharp)
    init(_ x: CGFloat, _ y: CGFloat, r: CGFloat = 0) {
        self.x = x
        self.y = y
        self.r = r
    }
}

/// Source coordinates and polygon definitions for the logo
/// AI generated....and adjusted
private enum Geo {
    static let origin = CGPoint(x: 9, y: 97)
    static let size = CGSize(width: 858, height: 503)

    /// Vertices for the left mountain peak.
    static let left = [Vertex(207, 196, r: 20), Vertex(449, 600), Vertex(-35, 600, r: 60)]
    /// Vertices for the central, tallest mountain peak.
    static let centre = [Vertex(438, 80, r: 20), Vertex(750, 600), Vertex(126, 600)]
    /// Vertices for the right mountain peak.
    static let right = [Vertex(669, 196, r: 20), Vertex(911, 600, r: 60), Vertex(427, 600)]

    /// Vertices for the right overlap wedge between peaks.
    static let overlapRight = [Vertex(588.3, 330.5), Vertex(750, 600), Vertex(427, 600)]
    /// Vertices for the left overlap wedge between peaks.
    static let overlapLeft = [Vertex(287.7, 330.5), Vertex(449, 600), Vertex(126, 600)]
}

/// Closed polygon shape that scales coordinates into the target `CGRect`
private struct PolyShape: Shape {
    /// Ordered vertices defining the closed polygon
    let vertices: [Vertex]

    /// Builds a scaled path
    func path(in rect: CGRect) -> Path {
        guard !vertices.isEmpty else { return Path() }

        let scale = rect.width / Geo.size.width
        let points: [(point: CGPoint, radius: CGFloat)] = vertices.map { vertex in
            let scaledPoint = CGPoint(
                x: rect.minX + (vertex.x - Geo.origin.x) * scale,
                y: rect.minY + (vertex.y - Geo.origin.y) * scale
            )
            return (point: scaledPoint, radius: vertex.r * scale)
        }

        let count = points.count
        var path = Path()
        let firstMidpoint = CGPoint(
            x: (points[count - 1].point.x + points[0].point.x) / 2,
            y: (points[count - 1].point.y + points[0].point.y) / 2
        )
        path.move(to: firstMidpoint)

        for i in 0..<count {
            let current = points[i]
            let next = points[(i + 1) % count].point
            if current.radius > 0 {
                path.addArc(tangent1End: current.point, tangent2End: next, radius: current.radius)
            } else {
                path.addLine(to: current.point)
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
