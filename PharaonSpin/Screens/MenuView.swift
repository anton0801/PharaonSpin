import SwiftUI

/// Figma "Menu" (4571:1794). The COMING SOON tile is removed: App Review rejects placeholder content.
struct MenuView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore

    /// The gift painted into Background 01, in background pixels.
    private static let giftInBackground = CGRect(x: 660, y: 2016, width: 552, height: 384)

    var body: some View {
        ZStack {
            // Background and gift share full-screen coordinates, so the hotspot tracks the crop.
            GeometryReader { screen in
                let alignment: Alignment = screen.size.width > screen.size.height ? .bottom : .center
                ZStack {
                    BackgroundArt(name: .bgMenu, alignment: alignment)
                    giftHotspot(in: screen.size, alignment: alignment)
                }
            }
            .ignoresSafeArea()

            DesignCanvas { metrics in
                if metrics.isLandscape {
                    landscapeLayout(metrics)
                } else {
                    portraitLayout(metrics)
                }
            }
        }
    }

    // MARK: Layouts

    @ViewBuilder
    private func portraitLayout(_ m: CanvasMetrics) -> some View {
        header(m, plate: .figma(220, 191, 639, 140), settings: CGRect(x: 12, y: 67, width: 40, height: 40), store: CGRect(x: 308, y: 67, width: 40, height: 40))

        FloatingGem().place(.figma(656.08, 630, 227.9, 227.9), m)

        gameTile(.egypt, emblem: .figma(55, 481, 541.95, 541.95), play: .figma(169, 920, 314, 103.27), m)
        gameTile(.fruit, emblem: .figma(483, 852, 541.95, 541.95), play: .figma(597, 1291, 314, 103.27), m)
        gameTile(.wheel, emblem: .figma(55, 1223, 541.95, 541.95), play: .figma(169, 1662, 314, 103.27), m)
    }

    @ViewBuilder
    private func landscapeLayout(_ m: CanvasMetrics) -> some View {
        header(m, plate: CGRect(x: 293.5, y: 12, width: 213, height: 46.7), settings: CGRect(x: 14, y: 15, width: 40, height: 40), store: CGRect(x: 746, y: 15, width: 40, height: 40))

        ForEach(Array(GameKind.allCases.enumerated()), id: \.element) { index, game in
            let x = 400 + CGFloat(index - 1) * 215
            gameTile(game,
                     emblem: CGRect(x: x - 76, y: 78, width: 152, height: 152),
                     play: CGRect(x: x - 52.35, y: 210, width: 104.7, height: 34.4), m)
        }
    }

    @ViewBuilder
    private func header(_ m: CanvasMetrics, plate: CGRect, settings settingsRect: CGRect, store storeRect: CGRect) -> some View {
        BalancePlate(balance: model.displayedBalance, refillDue: model.refillDue, refillAmount: model.rules.refillAmount, now: model.now)
            .place(plate, m)

        IconButton(systemName: "gearshape.fill", label: "Settings") {
            model.feedback.tap()
            model.modal = .settings
        }
        .place(settingsRect, m)

        if settings.storeVisible {
            IconButton(systemName: "bag.fill", label: "Store") { model.openStore() }
                .place(storeRect, m)
        }
    }

    private func gameTile(_ game: GameKind, emblem: CGRect, play: CGRect, _ m: CanvasMetrics) -> some View {
        let open = {
            model.feedback.tap()
            withAnimation(.easeInOut(duration: 0.3)) { model.route = .game(game) }
        }
        return Group {
            Button(action: open) {
                ArtImage(game.menuEmblem) { EmblemFallback(game: game) }
            }
            .buttonStyle(PressScale())
            .place(emblem, m)
            .accessibilityLabel(game.title)

            Button(action: open) {
                ArtImage(.buttonPlay) {
                    ZStack {
                        GoldRimCapsule(fill: [Color(red: 1, green: 0.3, blue: 0.3), Palette.spinRed])
                        OutlinedText(text: "PLAY", size: 15)
                    }
                }
            }
            .buttonStyle(PressScale())
            .place(play, m)
            .accessibilityLabel("Play \(game.title)")
        }
    }

    // MARK: Daily bonus gift

    private func giftHotspot(in size: CGSize, alignment: Alignment) -> some View {
        let rect = BackgroundArt.screenRect(ofBackgroundRect: Self.giftInBackground, in: size, alignment: alignment)
        let available = model.dailyBonusAmount > 0
        return ZStack {
            Button {
                if available {
                    model.claimDailyBonus()
                } else {
                    model.feedback.tap()
                    model.toast = model.nextDailyBonus.map { "Next free coins in \(Countdown.format($0.timeIntervalSince(model.now)))" }
                }
            } label: {
                Color.white.opacity(0.001)
            }
            .buttonStyle(.plain)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .accessibilityLabel(available ? "Daily bonus, \(Coins.format(model.dailyBonusAmount)) coins" : "Daily bonus")
            .accessibilityHint(available ? "Collect your free coins" : "Shows when the next bonus unlocks")

            GiftBadge(available: available, amount: model.dailyBonusAmount, next: model.nextDailyBonus, now: model.now)
                .position(x: rect.midX, y: rect.minY + min(rect.height * 0.12, 20))
                .allowsHitTesting(false)
        }
    }
}

private struct GiftBadge: View {
    let available: Bool
    let amount: Int
    let next: Date?
    let now: Date
    @State private var pulse = false

    var body: some View {
        Group {
            if available {
                Text("DAILY BONUS  +\(Coins.short(amount))")
                    .font(.game(13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.spinRed).overlay(Capsule().stroke(Palette.goldLight, lineWidth: 1.5)))
                    .scaleEffect(pulse ? 1.08 : 0.96)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
                    }
            } else if let next {
                Text("Next bonus \(Countdown.format(next.timeIntervalSince(now)))")
                    .font(.game(12, .bold))
                    .foregroundColor(Palette.goldLight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct FloatingGem: View {
    @State private var up = false

    var body: some View {
        ArtImage(.menuGem) { Color.clear }
            .offset(y: up ? -4 : 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { up = true }
            }
            .accessibilityHidden(true)
    }
}

struct EmblemFallback: View {
    let game: GameKind

    var body: some View {
        ZStack {
            GoldRimCircle(fill: [game.accent.opacity(0.9), game.accent.opacity(0.5)])
            Image(systemName: game == .egypt ? "crown.fill" : game == .fruit ? "leaf.fill" : "circle.grid.cross.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Palette.goldGradient)
                .padding(40)
        }
    }
}
