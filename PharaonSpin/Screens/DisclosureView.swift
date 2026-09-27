import SwiftUI

/// First-launch disclosure. Shown once, before the menu, and cannot be skipped.
struct DisclosureView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            BackgroundArt(name: .bgMenu)
            Color.black.opacity(0.55).ignoresSafeArea()
            DesignCanvas { metrics in
                let width: CGFloat = metrics.isLandscape ? 420 : 280
                VStack(spacing: metrics(16)) {
                    GoldTitle(text: "Welcome", size: metrics(34))
                    VStack(spacing: metrics(14)) {
                        Text("17+")
                            .font(.game(metrics(22)))
                            .foregroundColor(.white)
                            .padding(.horizontal, metrics(14))
                            .padding(.vertical, metrics(4))
                            .background(Capsule().stroke(Palette.gold, lineWidth: metrics(2)))
                        Text("This is a game for entertainment only.\nNo real money can be won or lost.")
                            .font(.game(metrics(metrics.isLandscape ? 16 : 17), .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Coins have no cash value and cannot be withdrawn, transferred or exchanged.")
                            .font(.game(metrics(12), .semibold))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        BarButton(title: "I Understand", style: .green, height: metrics(46)) {
                            model.feedback.tap()
                            model.acceptDisclosure()
                        }
                        .frame(width: metrics(200))
                        .padding(.top, metrics(4))
                    }
                    .padding(.horizontal, metrics(26))
                    .padding(.vertical, metrics(28))
                    .frame(width: metrics(width))
                    .background(PanelBackground())
                }
                .frame(width: metrics(metrics.designSize.width), height: metrics(metrics.designSize.height))
            }
        }
    }
}
