import SwiftUI

/// Figma "Loading" (4989:211). The bar tracks real progress: one step per decoded image set.
struct LoadingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            BackgroundArt(name: .bgLoading)
            DesignCanvas { metrics in
                let center = CGPoint(x: metrics.designSize.width / 2, y: metrics.designSize.height / 2)
                ArtImage(.loadingTitle) {
                    GoldTitle(text: "Loading", size: 40)
                }
                .place(center: CGPoint(x: center.x, y: center.y - 20), size: CGSize(width: 187.7, height: 47.8), metrics)

                ProgressBar(progress: model.loadProgress)
                    .place(center: CGPoint(x: center.x, y: center.y + 32), size: CGSize(width: 210, height: 16), metrics)
            }
        }
        .task { await model.load() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading, \(Int(model.loadProgress * 100)) percent")
    }
}

struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.6))
                Capsule()
                    .fill(Palette.goldGradient)
                    .frame(width: max(geometry.size.height, geometry.size.width * progress))
                    .animation(.linear(duration: 0.1), value: progress)
                Capsule().stroke(Palette.gold, lineWidth: 1.5)
            }
        }
    }
}
