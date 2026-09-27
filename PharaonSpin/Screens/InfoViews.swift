import SlotCore
import SwiftUI

/// Slot Info: paytable, lines, free-spin rules and the RTP computed from the strips.
struct SlotInfoView: View {
    let theme: SlotTheme
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ModalPanel(title: "Paytable", width: (320, 640), dismiss: { model.modal = nil }) { m in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: m(14)) {
                    let bet = model.slotGame(theme).freeSpins?.bet ?? model.bet(for: theme.game)
                    let lineBet = bet / model.slotMachine.paylines.count
                    InfoCaption(text: "Line bet = Total Bet ÷ 20 = \(Coins.format(lineBet)) coins", m: m)

                    let columns = Array(repeating: GridItem(.flexible(), spacing: m(8)), count: m.isLandscape ? 3 : 1)
                    LazyVGrid(columns: columns, alignment: .leading, spacing: m(6)) {
                        ForEach(SlotSymbol.paying.reversed(), id: \.self) { symbol in
                            payRow(symbol, lineBet: lineBet, m)
                        }
                    }

                    specialRow(.wild, text: "Substitutes for every symbol except SCATTER. Lands on reels 2, 3 and 4.", m)
                    specialRow(.scatter, text: "Pays anywhere on screen from the total bet: 3 → ×2, 4 → ×10, 5 → ×50. Three or more award 10 free spins.", m)

                    InfoSection(title: "Free spins", m: m) {
                        InfoCaption(text: "10 free spins at the bet that triggered them. Every win during free spins is doubled. Three or more scatters during free spins add 5 more.", m: m)
                    }

                    InfoSection(title: "20 lines", m: m) {
                        InfoCaption(text: "Wins pay left to right from reel 1. Only the highest win on each line pays; wins on different lines add up.", m: m)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: m(6)), count: m.isLandscape ? 10 : 5), spacing: m(8)) {
                            ForEach(Array(model.slotMachine.paylines.enumerated()), id: \.offset) { index, line in
                                PaylineDiagram(index: index, rows: line)
                                    .frame(height: m(34))
                            }
                        }
                    }

                    InfoSection(title: "Return to player", m: m) {
                        Text(String(format: "%.2f%%", model.slotReturn.total * 100))
                            .font(.game(m(22)))
                            .foregroundColor(Palette.amber)
                        InfoCaption(text: "The theoretical long-run return, calculated from the reel strips each time the app starts. Every spin is independent: the result is drawn by a random number generator before the reels move and never depends on your balance, the time, purchases or earlier spins.", m: m)
                    }

                    InfoCaption(text: "This game is for entertainment only. No real money can be won. Coins have no cash value.", m: m)
                        .foregroundColor(Palette.goldLight)
                }
            }
            .frame(maxHeight: m(m.isLandscape ? 250 : 560))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func payRow(_ symbol: SlotSymbol, lineBet: Int, _ m: CanvasMetrics) -> some View {
        HStack(spacing: m(10)) {
            SymbolView(theme: theme, symbol: symbol)
                .frame(width: m(40), height: m(40))
            VStack(alignment: .leading, spacing: m(1)) {
                ForEach([5, 4, 3], id: \.self) { count in
                    let multiplier = model.slotMachine.paytable.lineMultiplier(symbol, count: count)
                    HStack(spacing: m(6)) {
                        Text("\(count)×")
                            .font(.game(m(11), .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: m(20), alignment: .leading)
                        Text("×\(multiplier)")
                            .font(.game(m(11)))
                            .foregroundColor(Palette.amber)
                            .frame(width: m(42), alignment: .leading)
                        Text(Coins.format(multiplier * lineBet))
                            .font(.game(m(10), .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(theme.name(of: symbol)): five pay \(model.slotMachine.paytable.lineMultiplier(symbol, count: 5)) times the line bet, four \(model.slotMachine.paytable.lineMultiplier(symbol, count: 4)), three \(model.slotMachine.paytable.lineMultiplier(symbol, count: 3))")
    }

    private func specialRow(_ symbol: SlotSymbol, text: String, _ m: CanvasMetrics) -> some View {
        HStack(alignment: .center, spacing: m(10)) {
            SymbolView(theme: theme, symbol: symbol)
                .frame(width: m(44), height: m(44))
            InfoCaption(text: text, m: m)
        }
    }
}

private struct InfoSection<Content: View>: View {
    let title: String
    let m: CanvasMetrics
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: m(6)) {
            Text(title.uppercased())
                .font(.game(m(13)))
                .foregroundStyle(Palette.goldGradient)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

private struct InfoCaption: View {
    let text: String
    let m: CanvasMetrics

    var body: some View {
        Text(text)
            .font(.game(m(11), .medium))
            .foregroundColor(.white.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PaylineDiagram: View {
    let index: Int
    let rows: [Int]

    var body: some View {
        GeometryReader { geometry in
            let cellW = geometry.size.width / 5
            let cellH = (geometry.size.height - 10) / 3
            VStack(spacing: 1) {
                ZStack(alignment: .topLeading) {
                    ForEach(0..<15, id: \.self) { cell in
                        let reel = cell / 3
                        let row = cell % 3
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(rows[reel] == row ? Palette.gold : Color.white.opacity(0.15))
                            .frame(width: cellW - 1.5, height: cellH - 1.5)
                            .offset(x: CGFloat(reel) * cellW, y: CGFloat(row) * cellH)
                    }
                }
                .frame(width: geometry.size.width, height: cellH * 3, alignment: .topLeading)
                Text("\(index + 1)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Line \(index + 1): rows \(rows.map { ["top", "middle", "bottom"][$0] }.joined(separator: ", "))")
    }
}

/// Odds panel: the required disclosure of every sector's probability, plus the exact RTP.
struct WheelOddsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ModalPanel(title: "Odds", width: (320, 620), dismiss: { model.modal = nil }) { m in
            ScrollView(showsIndicators: false) {
                VStack(spacing: m(10)) {
                    let columns = m.isLandscape ? 2 : 1
                    let sectors = model.wheel.sectors
                    let perColumn = (sectors.count + columns - 1) / columns
                    HStack(alignment: .top, spacing: m(16)) {
                        ForEach(0..<columns, id: \.self) { column in
                            VStack(spacing: m(3)) {
                                headerRow(m)
                                ForEach(sectors[(column * perColumn)..<min(sectors.count, (column + 1) * perColumn)]) { sector in
                                    oddsRow(sector, m)
                                }
                            }
                        }
                    }

                    HStack {
                        Text("Return to player")
                            .font(.game(m(13), .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.2f%%", model.wheel.exactRTP * 100))
                            .font(.game(m(18)))
                            .foregroundColor(Palette.amber)
                    }
                    .padding(.top, m(4))

                    Text("Exact, not simulated: Σ(weight × multiplier) ÷ total weight, with free spins (which can win more free spins) included. The sector is drawn by weight before the wheel starts turning. One free spin every 4 hours plays at a \(Coins.format(model.rules.wheelBonusStake))-coin stake. Coins have no cash value.")
                        .font(.game(m(10), .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxHeight: m(m.isLandscape ? 250 : 560))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func headerRow(_ m: CanvasMetrics) -> some View {
        HStack {
            Text("Sector").frame(maxWidth: .infinity, alignment: .leading)
            Text("Result").frame(maxWidth: .infinity, alignment: .leading)
            Text("Chance").frame(width: m(56), alignment: .trailing)
        }
        .font(.game(m(10), .bold))
        .foregroundStyle(Palette.goldGradient)
        .accessibilityHidden(true)
    }

    private func oddsRow(_ sector: WheelSector, _ m: CanvasMetrics) -> some View {
        let probability = model.wheel.probability(ofSector: sector.id) * 100
        return HStack {
            Text("\(sector.id + 1). \(Self.name(of: sector.artwork))")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Self.result(of: sector.prize))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(Palette.amber)
            Text(String(format: probability < 1 ? "%.3f%%" : "%.2f%%", probability))
                .frame(width: m(56), alignment: .trailing)
        }
        .font(.game(m(11), .semibold))
        .foregroundColor(.white)
        .padding(.vertical, m(3))
        .padding(.horizontal, m(6))
        .background(RoundedRectangle(cornerRadius: m(6)).fill(Color.white.opacity(sector.id.isMultiple(of: 2) ? 0.06 : 0.02)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sector \(sector.id + 1), \(Self.name(of: sector.artwork)): \(Self.result(of: sector.prize)), \(String(format: "%.2f", probability)) percent")
    }

    static func name(of artwork: WheelArtwork) -> String {
        switch artwork {
        case .gift: return "Gift"
        case .plus100: return "+100"
        case .vip: return "VIP"
        case .bell: return "Bell"
        case .freeSpins: return "FS"
        case .plus50: return "+50"
        case .medal: return "Medal"
        }
    }

    static func result(of prize: WheelPrize) -> String {
        switch prize {
        case .freeSpins(let count): return "\(count) free spins"
        case .multiplier:
            let value = prize.multiplier ?? 0
            let text = value == value.rounded() ? String(Int(value)) : String(value)
            return value == 1 ? "×1 (bet back)" : "×\(text)"
        }
    }
}
