import SwiftUI

/// The Figma frames are 1080×2400 (portrait) and 2400×1080 (landscape) at @3x, i.e. a 360×800 pt
/// design. Screens are laid out in those design points and scaled uniformly to the safe area,
/// so the composition holds on every device instead of being pinned to pixel positions.
struct CanvasMetrics: Equatable {
    static let portrait = CGSize(width: 360, height: 800)
    static let landscape = CGSize(width: 800, height: 360)

    var scale: CGFloat
    var isLandscape: Bool
    var designSize: CGSize

    /// Design points to screen points.
    func callAsFunction(_ value: CGFloat) -> CGFloat { value * scale }

    static let `default` = CanvasMetrics(scale: 1, isLandscape: false, designSize: portrait)
}

private struct CanvasMetricsKey: EnvironmentKey {
    static let defaultValue = CanvasMetrics.default
}

extension EnvironmentValues {
    var canvas: CanvasMetrics {
        get { self[CanvasMetricsKey.self] }
        set { self[CanvasMetricsKey.self] = newValue }
    }
}

/// Hosts a design-point canvas centred in the safe area.
struct DesignCanvas<Content: View>: View {
    @ViewBuilder var content: (CanvasMetrics) -> Content

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            let design = landscape ? CanvasMetrics.landscape : CanvasMetrics.portrait
            let scale = min(geometry.size.width / design.width, geometry.size.height / design.height)
            let metrics = CanvasMetrics(scale: scale, isLandscape: landscape, designSize: design)
            ZStack(alignment: .topLeading) {
                content(metrics)
            }
            .frame(width: design.width * scale, height: design.height * scale, alignment: .topLeading)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .environment(\.canvas, metrics)
        }
    }
}

extension View {
    /// Places the view at a rectangle given in design points (Figma pixels ÷ 3).
    func place(_ rect: CGRect, _ metrics: CanvasMetrics) -> some View {
        frame(width: metrics(rect.width), height: metrics(rect.height))
            .position(x: metrics(rect.midX), y: metrics(rect.midY))
    }

    /// Places the view centred on a design point with a design-point size.
    func place(center: CGPoint, size: CGSize, _ metrics: CanvasMetrics) -> some View {
        frame(width: metrics(size.width), height: metrics(size.height))
            .position(x: metrics(center.x), y: metrics(center.y))
    }
}

extension CGRect {
    /// A rectangle from Figma @3x pixels.
    static func figma(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x / 3, y: y / 3, width: width / 3, height: height / 3)
    }
}
