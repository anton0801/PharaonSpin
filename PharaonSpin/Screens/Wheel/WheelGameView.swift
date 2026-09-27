import SlotCore
import SwiftUI

/// Figma "Game 3" (4999:218 / 6008:269).
struct WheelGameView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        WheelGameContent(model: model)
    }
}

private struct WheelLayout {
    var balance: CGRect
    var back: CGRect
    var odds: CGRect
    var decoration: CGRect
    var glow: CGRect
    var wheel: CGRect
    var spin: CGRect
    var bets: BetPanelLayout
    var banner: CGPoint

    static let portrait = WheelLayout(
        balance: .figma(220, 183, 639, 140.03),
        back: CGRect(x: 12, y: 64.3, width: 40, height: 40),
        odds: CGRect(x: 302, y: 596, width: 40, height: 40),
        decoration: .figma(134, 366, 848, 847),
        glow: .figma(-835, 61, 2749, 2749),
        wheel: .figma(67, 1002, 945, 945),
        spin: .figma(661, 1967, 318, 316),
        bets: .portrait,
        banner: CGPoint(x: 180, y: 300)
    )

    static let landscape = WheelLayout(
        balance: CGRect(x: 26.7, y: 38.65, width: 213, height: 46.7),
        back: CGRect(x: 16, y: 104, width: 40, height: 40),
        odds: CGRect(x: 566, y: 294, width: 40, height: 40),
        decoration: CGRect(x: 557, y: 6.6, width: 222, height: 222),
        glow: CGRect(x: 400.8 - 579.6, y: 178 - 579.6, width: 1159.3, height: 1159.3),
        wheel: CGRect(x: 243.3, y: 20.5, width: 315, height: 315),
        spin: CGRect(x: 648.6, y: 229.35, width: 106, height: 105.3),
        bets: .landscape,
        banner: CGPoint(x: 133, y: 222)
    )
}

private struct WheelGameContent: View {
    @ObservedObject var model: AppModel
    @StateObject private var vm: WheelViewModel

    init(model: AppModel) {
        self.model = model
        _vm = StateObject(wrappedValue: WheelViewModel(app: model))
    }

    private var freeSpinsLeft: Int { model.state.wheelGame.freeSpinsRemaining }

    var body: some View {
        ZStack {
            BackgroundArt(name: .bgWheel, colors: GameKind.wheel.backgroundColors)
            DesignCanvas { m in
                content(m.isLandscape ? .landscape : .portrait, m)
            }
        }
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
    private func content(_ layout: WheelLayout, _ m: CanvasMetrics) -> some View {
        // Ellipse 1320: a soft shadow under the wheel (the export includes its blur halo).
        ArtImage(.wheelGlow) { Color.clear }
        .place(layout.glow, m)
        .allowsHitTesting(false)

        // Decorative only: turns slowly, never affects the result.
        TimelineView(.animation) { context in
            let angle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60) * 6
            ArtImage(.emblemWheel) { EmblemFallback(game: .wheel) }
                .rotationEffect(.degrees(angle))
        }
        .place(layout.decoration, m)
        .accessibilityHidden(true)

        WheelView(animator: vm.animator, wheel: model.wheel, highlighted: vm.isSpinning ? nil : vm.landedSector)
            .place(layout.wheel, m)

        BalancePlate(balance: model.displayedBalance, refillDue: model.refillDue, refillAmount: model.rules.refillAmount, now: model.now)
            .place(layout.balance, m)

        let freePending = freeSpinsLeft > 0
        let bonus = !freePending && model.wheelBonusAvailable
        let stake = freePending ? model.state.wheelGame.freeSpinStake : bonus ? model.rules.wheelBonusStake : model.bet(for: .wheel)
        BetPanel(
            metrics: m,
            layout: layout.bets,
            bet: stake,
            betCaption: freePending ? "Free Spin Bet" : bonus ? "Free Spin" : "Total Bet",
            win: vm.lastWin,
            canDecrease: !vm.isSpinning && !freePending && !bonus && model.canDecreaseBet(.wheel),
            canIncrease: !vm.isSpinning && !freePending && !bonus && model.canIncreaseBet(.wheel),
            decrease: { model.decreaseBet(.wheel) },
            increase: { model.increaseBet(.wheel) }
        )

        SpinButton(
            enabled: !vm.isSpinning && model.canSpinWheel(),
            badge: freePending ? "FREE \(freeSpinsLeft)" : bonus ? "FREE" : nil
        ) {
            vm.spin()
        }
        .place(layout.spin, m)

        if !bonus && !freePending, let next = model.nextWheelBonus, next > model.now {
            Text("Free spin in \(Countdown.format(next.timeIntervalSince(model.now)))")
                .font(.game(m(9.5), .bold))
                .foregroundColor(Palette.goldLight)
                .padding(.horizontal, m(8))
                .padding(.vertical, m(3))
                .background(Capsule().fill(Color.black.opacity(0.65)))
                .position(x: m(layout.spin.midX), y: m(layout.spin.minY - 7))
                .allowsHitTesting(false)
        }

        if let banner = vm.banner {
            Text(banner)
                .font(.game(m(12)))
                .foregroundColor(.white)
                .padding(.horizontal, m(12))
                .padding(.vertical, m(5))
                .background(Capsule().fill(Color.black.opacity(0.72)).overlay(Capsule().stroke(Palette.gold, lineWidth: 1)))
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

        IconButton(systemName: "info", label: "Odds and return to player") {
            model.feedback.tap()
            model.modal = .wheelOdds
        }
        .place(layout.odds, m)
    }
}

/// Figma "Game 3" wheel = Component 37 (sector disc, turns) under Component 38 (lights ring and
/// hub, static), with the pointer fixed at the top.
private struct WheelView: View {
    @ObservedObject var animator: WheelAnimator
    let wheel: FortuneWheel
    let highlighted: Int?

    /// Radii as fractions of the wheel radius, measured on the Figma art: the hub of the static ring
    /// covers up to `hubRadius`; the coloured sectors end at `sectorRadius`.
    static let hubRadius: CGFloat = 0.3
    static let innerRadius: CGFloat = 0.325
    static let outerRadius: CGFloat = 0.855

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                // The disc's own printed SPIN hub is masked out so nothing lettered turns under the static hub.
                ArtImage(.wheelDisc) { WheelDiscFallback(wheel: wheel) }
                    .rotationEffect(.degrees(animator.rotation))
                    .mask(Annulus(inner: Self.hubRadius, outer: 1.01).fill(style: FillStyle(eoFill: true)))

                if let highlighted {
                    SectorGlow(sectorWidth: WheelViewModel.geometry.sectorWidth)
                        .fill(Palette.goldLight.opacity(0.28))
                        .rotationEffect(.degrees(WheelViewModel.geometry.center(ofSector: highlighted) + animator.rotation))
                        .mask(Annulus(inner: Self.innerRadius, outer: Self.outerRadius).fill(style: FillStyle(eoFill: true)))
                        .transition(.opacity)
                        .id(highlighted)
                }

                ArtImage(.wheelRing) {
                    WheelRingFallback()
                    WheelHubFallback().frame(width: side * Self.innerRadius * 2, height: side * Self.innerRadius * 2)
                }

                ArtImage(.wheelPointer) { PointerFallback() }
                    .rotationEffect(.degrees(90))
                    .frame(width: side * 0.19, height: side * 0.19)
                    .rotationEffect(.degrees(animator.pointerTilt), anchor: .top)
                    .position(x: side / 2, y: side * 0.06)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
            }
            .frame(width: side, height: side)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fortune wheel")
        .accessibilityValue(highlighted.map { "Landed on sector \($0 + 1)" } ?? "")
    }
}

private struct Annulus: Shape {
    let inner: CGFloat
    let outer: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - radius * outer, y: center.y - radius * outer, width: radius * outer * 2, height: radius * outer * 2))
        path.addEllipse(in: CGRect(x: center.x - radius * inner, y: center.y - radius * inner, width: radius * inner * 2, height: radius * inner * 2))
        return path
    }
}

/// The wedge under the pointer, lit once the wheel stops.
private struct SectorGlow: Shape {
    let sectorWidth: Double

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: .degrees(-90 - sectorWidth / 2), endAngle: .degrees(-90 + sectorWidth / 2), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Fallback art (only while the Figma wheel layers are missing)

private struct WheelDiscFallback: View {
    let wheel: FortuneWheel

    private static let colors: [Color] = [
        Color(red: 1, green: 0.8, blue: 0.1), Color(red: 0.75, green: 0.85, blue: 0.1), Color(red: 0.2, green: 0.7, blue: 0.1),
        Color(red: 0.1, green: 0.75, blue: 0.75), Color(red: 0.1, green: 0.65, blue: 1), Color(red: 0.15, green: 0.3, blue: 0.95),
        Color(red: 0.45, green: 0.2, blue: 0.85), Color(red: 0.7, green: 0.15, blue: 0.85), Color(red: 0.95, green: 0.15, blue: 0.7),
        Color(red: 1, green: 0.2, blue: 0.4), Color(red: 0.95, green: 0.1, blue: 0.1), Color(red: 1, green: 0.45, blue: 0.05),
    ]

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let geometryModel = WheelViewModel.geometry
            ZStack {
                ForEach(wheel.sectors) { sector in
                    let center = geometryModel.center(ofSector: sector.id)
                    SectorWedge(start: center - geometryModel.sectorWidth / 2, end: center + geometryModel.sectorWidth / 2)
                        .fill(Self.colors[sector.id % Self.colors.count])
                    Text(label(for: sector))
                        .font(.game(side * 0.055))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                        .offset(y: -side * 0.3)
                        .rotationEffect(.degrees(center))
                }
            }
            .frame(width: side, height: side)
        }
    }

    private func label(for sector: WheelSector) -> String {
        switch sector.prize {
        case .freeSpins: return "FS"
        case .multiplier:
            let value = sector.prize.multiplier ?? 0
            return "×" + (value == value.rounded() ? String(Int(value)) : String(value))
        }
    }
}

private struct SectorWedge: Shape {
    let start: Double
    let end: Double

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: .degrees(start - 90), endAngle: .degrees(end - 90), clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct WheelRingFallback: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().strokeBorder(Palette.goldGradient, lineWidth: side * 0.06)
                ForEach(0..<24, id: \.self) { index in
                    Circle()
                        .fill(Color(red: 1, green: 0.97, blue: 0.8))
                        .frame(width: side * 0.03, height: side * 0.03)
                        .shadow(color: .yellow, radius: 3)
                        .offset(y: -side * 0.47)
                        .rotationEffect(.degrees(Double(index) * 15))
                }
            }
        }
    }
}

private struct WheelHubFallback: View {
    var body: some View {
        GoldRimCircle(fill: [Color(red: 1, green: 0.35, blue: 0.35), Palette.spinRed])
    }
}

private struct PointerFallback: View {
    var body: some View {
        PointerShape()
            .fill(LinearGradient(colors: [Color(red: 1, green: 0.4, blue: 0.4), Palette.spinRed], startPoint: .top, endPoint: .bottom))
            .overlay(PointerShape().stroke(Palette.goldLight, lineWidth: 2))
            .padding(6)
    }
}

/// Triangle pointing right, like the Figma pointer before it is turned to face down.
private struct PointerShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.12))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.maxY - rect.height * 0.12))
            path.closeSubpath()
        }
    }
}
