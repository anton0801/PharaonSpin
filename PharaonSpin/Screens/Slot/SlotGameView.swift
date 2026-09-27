import SlotCore
import SwiftUI

/// Figma "Game 1" (4670:810 / 6008:260) and "Game 2" (4999:217 / 6008:265).
struct SlotGameView: View {
    let theme: SlotTheme
    @EnvironmentObject private var model: AppModel

    var body: some View {
        SlotGameContent(model: model, theme: theme)
    }
}

private struct SlotLayout {
    var balance: CGRect
    var back: CGRect
    var info: CGRect
    var emblem: CGRect
    var glow: CGRect
    var frame: CGRect
    /// Rectangle of the 5×3 symbol slots (each slot = symbol + half the gap around it).
    var slots: CGRect
    var spin: CGRect
    var bets: BetPanelLayout
    var banner: CGPoint

    static let portrait = SlotLayout(
        balance: .figma(220, 183, 639, 140.03),
        back: CGRect(x: 12, y: 64.3, width: 40, height: 40),
        info: CGRect(x: 308, y: 64.3, width: 40, height: 40),
        emblem: .figma(135, 366, 847, 847),
        glow: .figma(-835, 61, 2749, 2749),
        frame: .figma(-56, 1021, 1192, 837),
        slots: .figma(168.45, 1248.55, 743.5, 446.1),
        spin: .figma(661, 1967, 318, 316),
        bets: .portrait,
        banner: CGPoint(x: 180, y: 636)
    )

    static let landscape = SlotLayout(
        balance: CGRect(x: 292.3, y: 292.7, width: 213, height: 46.7),
        back: CGRect(x: 16, y: 16, width: 40, height: 40),
        info: CGRect(x: 64, y: 16, width: 40, height: 40),
        emblem: CGRect(x: 577.5, y: 15.9, width: 205, height: 205),
        glow: CGRect(x: 400 - 579.6, y: 177 - 579.6, width: 1159.3, height: 1159.3),
        frame: CGRect(x: 152.4, y: 2.8, width: 497.6, height: 349.6),
        slots: CGRect(x: 240.8, y: 86.4, width: 323.2, height: 201.6),
        spin: CGRect(x: 648.6, y: 229.35, width: 106, height: 105.3),
        bets: .landscape,
        banner: CGPoint(x: 95, y: 222)
    )
}

private struct SlotGameContent: View {
    @ObservedObject var model: AppModel
    let theme: SlotTheme
    @StateObject private var vm: SlotViewModel

    init(model: AppModel, theme: SlotTheme) {
        self.model = model
        self.theme = theme
        _vm = StateObject(wrappedValue: SlotViewModel(theme: theme, app: model))
    }

    private var freeSpins: FreeSpinSession? { model.slotGame(theme).freeSpins }

    var body: some View {
        ZStack {
            BackgroundArt(name: theme.game.background, colors: theme.game.backgroundColors)

            DesignCanvas { m in
                let layout = m.isLandscape ? SlotLayout.landscape : SlotLayout.portrait
                gameLayer(layout, m)
            }

            if let big = vm.bigWin {
                BigWinOverlay(win: big) { vm.bigWin = nil }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .zIndex(5)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.bigWin)
        .onDisappear { vm.leave() }
        #if DEBUG
        .task {
            guard DebugLaunch.autoSpin else { return }
            try? await Task.sleep(nanoseconds: 800_000_000)
            vm.spin()
        }
        #endif
    }

    @ViewBuilder
    private func gameLayer(_ layout: SlotLayout, _ m: CanvasMetrics) -> some View {
        // Ellipse 1320: a soft shadow under the reels (the export includes its blur halo, hence the large rect).
        ArtImage(theme.reelGlow) { Color.clear }
        .place(layout.glow, m)
        .allowsHitTesting(false)

        ArtImage(theme.emblem) { EmblemFallback(game: theme.game) }
            .place(layout.emblem, m)
            .accessibilityHidden(true)

        ArtImage(theme.reelFrame) { ReelFrameFallback(theme: theme) }
            .place(layout.frame, m)
            .accessibilityHidden(true)

        ReelsView(vm: vm, theme: theme)
            .place(layout.slots, m)

        BalancePlate(balance: model.displayedBalance, refillDue: model.refillDue, refillAmount: model.rules.refillAmount, now: model.now)
            .place(layout.balance, m)

        let bet = freeSpins?.bet ?? model.bet(for: theme.game)
        let locked = vm.isSpinning || freeSpins != nil
        BetPanel(
            metrics: m,
            layout: layout.bets,
            bet: bet,
            betCaption: freeSpins != nil ? "Free Spins Bet" : "Total Bet",
            win: vm.lastWin,
            canDecrease: !locked && model.canDecreaseBet(theme.game),
            canIncrease: !locked && model.canIncreaseBet(theme.game),
            decrease: { model.decreaseBet(theme.game) },
            increase: { model.increaseBet(theme.game) }
        )

        SpinButton(
            enabled: !vm.isSpinning && model.canSpinSlot(theme),
            badge: freeSpins.map { "FREE \($0.remaining)" }
        ) {
            vm.spin()
        }
        .place(layout.spin, m)

        if let text = vm.highlight?.caption ?? vm.banner {
            Text(text)
                .font(.game(m(11)))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, m(10))
                .padding(.vertical, m(4))
                .background(Capsule().fill(Color.black.opacity(0.72)).overlay(Capsule().stroke(Palette.gold, lineWidth: 1)))
                .frame(maxWidth: m(m.isLandscape ? 170 : 300))
                .position(x: m(layout.banner.x), y: m(layout.banner.y))
                .allowsHitTesting(false)
                .transition(.opacity)
        }

        IconButton(systemName: "chevron.backward", label: "Back to menu") {
            model.feedback.tap()
            vm.leave()
            withAnimation(.easeInOut(duration: 0.3)) { model.route = .menu }
        }
        .place(layout.back, m)

        IconButton(systemName: "info", label: "Paytable and rules") {
            model.feedback.tap()
            model.modal = .slotInfo(theme)
        }
        .place(layout.info, m)
    }
}

/// The five reels, clipped to the reel window, plus the payline highlight.
private struct ReelsView: View {
    @ObservedObject var vm: SlotViewModel
    let theme: SlotTheme

    var body: some View {
        GeometryReader { geometry in
            let pitchX = geometry.size.width / CGFloat(SlotMachine.reelCount)
            let pitchY = geometry.size.height / CGFloat(SlotMachine.rowCount)
            let symbolSide = min(pitchX, pitchY) * 0.9

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(0..<SlotMachine.reelCount, id: \.self) { reel in
                        let column = vm.reels[reel]
                        VStack(spacing: 0) {
                            ForEach(Array(column.symbols.enumerated()), id: \.offset) { index, symbol in
                                let row = index - 1
                                let cell = reel * SlotMachine.rowCount + row
                                let dimmed = vm.highlight.map { !$0.cells.contains(cell) } ?? false
                                SymbolView(theme: theme, symbol: symbol)
                                    .frame(width: symbolSide, height: symbolSide)
                                    .frame(width: pitchX, height: pitchY)
                                    .opacity(vm.isSpinning ? 1 : (dimmed ? 0.4 : 1))
                                    .scaleEffect(!vm.isSpinning && vm.highlight?.cells.contains(cell) == true ? 1.08 : 1)
                            }
                        }
                        .frame(width: pitchX, height: pitchY, alignment: .top)
                        .offset(y: column.offset * pitchY)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                // A sliver of the neighbours shows at the window edge, as on a physical reel.
                .mask(Rectangle().padding(.vertical, -pitchY * 0.07))

                if let highlight = vm.highlight, !vm.isSpinning {
                    WinLineOverlay(highlight: highlight, pitch: CGSize(width: pitchX, height: pitchY), symbolSide: symbolSide)
                        .allowsHitTesting(false)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityGrid)
    }

    private var accessibilityGrid: String {
        (0..<SlotMachine.rowCount).map { row in
            (0..<SlotMachine.reelCount).map { reel in
                theme.name(of: vm.reels[reel].symbols[row + 1])
            }.joined(separator: ", ")
        }.joined(separator: ". ")
    }
}

private struct WinLineOverlay: View {
    let highlight: WinHighlight
    let pitch: CGSize
    let symbolSide: CGFloat

    private static let colors: [Color] = (0..<20).map { Color(hue: Double($0) * 0.37.truncatingRemainder(dividingBy: 1), saturation: 0.85, brightness: 1) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let line = highlight.lineIndex {
                let rows = Paylines.standard[line]
                let color = Self.colors[line % Self.colors.count]
                Path { path in
                    for (reel, row) in rows.enumerated() {
                        let point = CGPoint(x: (CGFloat(reel) + 0.5) * pitch.width, y: (CGFloat(row) + 0.5) * pitch.height)
                        if reel == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: max(2, pitch.height * 0.06), lineCap: .round, lineJoin: .round))
                .shadow(color: color, radius: 6)
            }
            ForEach(Array(highlight.cells), id: \.self) { cell in
                let reel = cell / SlotMachine.rowCount
                let row = cell % SlotMachine.rowCount
                RoundedRectangle(cornerRadius: symbolSide * 0.18, style: .continuous)
                    .stroke(Palette.goldLight, lineWidth: max(2, symbolSide * 0.05))
                    .shadow(color: Palette.gold, radius: 6)
                    .frame(width: symbolSide * 1.04, height: symbolSide * 1.04)
                    .position(x: (CGFloat(reel) + 0.5) * pitch.width, y: (CGFloat(row) + 0.5) * pitch.height)
            }
        }
    }
}

private struct ReelFrameFallback: View {
    let theme: SlotTheme

    var body: some View {
        GeometryReader { geometry in
            let inset = CGSize(width: geometry.size.width * 0.16, height: geometry.size.height * 0.2)
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.goldGradient)
                    .padding(.horizontal, inset.width * 0.55)
                    .padding(.vertical, inset.height * 0.6)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(RadialGradient(colors: [theme.windowColor.opacity(0.95), theme.windowColor.opacity(0.7)], center: .center, startRadius: 0, endRadius: geometry.size.width * 0.4))
                    .padding(.horizontal, inset.width * 0.72)
                    .padding(.vertical, inset.height * 0.8)
            }
        }
    }
}

struct BigWinOverlay: View {
    let win: BigWin
    let dismiss: () -> Void
    @State private var shown = 0
    @State private var glow = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 14) {
                GoldTitle(text: win.level.title, size: win.level == .mega ? 64 : 56)
                    .scaleEffect(glow ? 1.06 : 0.96)
                OutlinedText(text: Coins.format(shown), size: 40)
                    .contentTransition(.numericText())
                Text("Tap to continue")
                    .font(.game(14, .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .task {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { glow = true }
            let steps = 30
            for step in 1...steps {
                withAnimation(.linear(duration: 0.04)) { shown = win.amount * step / steps }
                try? await Task.sleep(nanoseconds: 45_000_000)
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            dismiss()
        }
    }
}
