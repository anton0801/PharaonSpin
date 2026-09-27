import SlotCore
import SwiftUI
import UIKit

/// One reel's visible column. `symbols` runs top to bottom; `offset` is the column's top edge
/// relative to the reel window, in cells (negative = scrolled up).
struct ReelColumn: Equatable {
    var symbols: [SlotSymbol]
    var offset: CGFloat
}

/// Something the win presentation cycles through: a paying line or the scatters.
struct WinHighlight: Equatable {
    var cells: Set<Int>
    var lineIndex: Int?
    var caption: String
}

enum BigWinLevel: Equatable {
    case big, mega

    var title: String { self == .big ? "BIG WIN" : "MEGA WIN" }
}

struct BigWin: Equatable {
    var level: BigWinLevel
    var amount: Int
}

@MainActor
final class SlotViewModel: ObservableObject {
    enum Phase { case idle, spinning }

    /// Every reel scrolls the same number of cells with the same curve whatever the result:
    /// no slow-down or anticipation on near misses.
    static let spinCells = [16, 21, 26, 31, 36]
    static let spinDurations: [Double] = [1.05, 1.3, 1.55, 1.8, 2.05]
    static let spinCurve = (x1: 0.3, y1: 0.0, x2: 0.2, y2: 1.0)

    let theme: SlotTheme
    @Published private(set) var reels: [ReelColumn]
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastWin = 0
    @Published private(set) var highlight: WinHighlight?
    @Published var bigWin: BigWin?
    @Published var banner: String?

    private weak var app: AppModel?
    private var stops: [Int]
    private var presentation: Task<Void, Never>?
    /// Win still held back from the balance display.
    private var unrevealed = 0

    init(theme: SlotTheme, app: AppModel) {
        self.theme = theme
        self.app = app
        let strips = app.slotMachine.strips
        let start = strips.map { Int.random(in: 0..<$0.count) }
        stops = start
        reels = zip(strips, start).map { strip, stop in
            ReelColumn(symbols: Self.window(strip, from: stop - 1, count: 5), offset: -1)
        }
    }

    var isSpinning: Bool { phase == .spinning }

    func spin() {
        guard let app, phase == .idle, app.canSpinSlot(theme) else { return }
        finishPresentation()

        // The outcome — and the coins — are settled here, before a single frame moves.
        guard let round = app.spinSlot(theme) else { return }
        let outcome = round.outcome
        unrevealed = outcome.totalWin
        lastWin = 0
        phase = .spinning
        app.feedback.tap()

        let strips = app.slotMachine.strips
        var prepared: [ReelColumn] = []
        for reel in 0..<SlotMachine.reelCount {
            let strip = strips[reel]
            let distance = Self.spinCells[reel]
            let target = outcome.stops[reel]
            let current = stops[reel]
            // Target window (with the symbol above it) then real strip continuation, then what is on screen now.
            let symbols = Self.window(strip, from: target - 1, count: distance + 1) + Self.window(strip, from: current, count: 4)
            prepared.append(ReelColumn(symbols: symbols, offset: -CGFloat(distance + 1)))
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { reels = prepared }
        stops = outcome.stops

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for reel in 0..<SlotMachine.reelCount {
                let curve = Self.spinCurve
                withAnimation(.timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: Self.spinDurations[reel])) {
                    self.reels[reel].offset = -1
                }
            }
        }

        presentation = Task { [weak self] in
            var elapsed = 0.0
            for reel in 0..<SlotMachine.reelCount {
                let wait = Self.spinDurations[reel] - elapsed
                elapsed = Self.spinDurations[reel]
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                self.settle(reel: reel)
                self.app?.feedback.reelStop()
            }
            guard let self, !Task.isCancelled else { return }
            self.phase = .idle
            await self.present(round)
        }
    }

    /// Replaces the long spin column with the short resting one (same pixels, so nothing jumps).
    private func settle(reel: Int) {
        guard let strip = app?.slotMachine.strips[reel] else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            reels[reel] = ReelColumn(symbols: Self.window(strip, from: stops[reel] - 1, count: 5), offset: -1)
        }
    }

    private func present(_ round: SlotRound) async {
        guard let app else { return }
        let outcome = round.outcome
        let total = outcome.totalWin

        if total > 0 {
            app.feedback.win(big: total >= outcome.totalBet * 20)
            // Count the win up and release it into the balance at the same pace.
            let steps = 24
            var shown = 0
            for step in 1...steps {
                let value = Int((Double(total) * Double(step) / Double(steps)).rounded())
                app.reveal(value - shown)
                unrevealed -= value - shown
                shown = value
                withAnimation(.linear(duration: 0.03)) { lastWin = value }
                try? await Task.sleep(nanoseconds: 33_000_000)
                if Task.isCancelled { return }
            }
            let multiple = Double(total) / Double(outcome.totalBet)
            if multiple >= 50 {
                bigWin = BigWin(level: .mega, amount: total)
            } else if multiple >= 20 {
                bigWin = BigWin(level: .big, amount: total)
            }
            announce("Win \(Coins.format(total)) coins")
        } else {
            announce("No win")
        }

        if round.triggeredFreeSpins {
            app.feedback.bonus()
            banner = "\(outcome.freeSpinsAwarded) FREE SPINS · WINS ×\(app.slotMachine.freeSpinRules.winMultiplier)"
        } else if outcome.isFreeSpin, outcome.freeSpinsAwarded > 0 {
            app.feedback.bonus()
            banner = "+\(outcome.freeSpinsAwarded) FREE SPINS"
        } else if let done = round.completedFreeSpins {
            banner = "FREE SPINS WIN \(Coins.format(done.totalWin))"
        }

        let items = highlights(for: outcome)
        guard !items.isEmpty else { return }
        while !Task.isCancelled {
            for item in items {
                withAnimation(.easeInOut(duration: 0.2)) { highlight = item }
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                if Task.isCancelled { return }
            }
            if items.count == 1 { return }
        }
    }

    private func highlights(for outcome: SpinOutcome) -> [WinHighlight] {
        var items = outcome.lineWins.map { win in
            WinHighlight(
                cells: Set(win.cells),
                lineIndex: win.lineIndex,
                caption: "LINE \(win.lineIndex + 1) · \(win.count)× \(theme.name(of: win.symbol).uppercased()) · \(Coins.format(win.payout))"
            )
        }
        if outcome.scatterWin > 0 || outcome.freeSpinsAwarded > 0 {
            items.append(WinHighlight(
                cells: Set(outcome.scatterCells),
                lineIndex: nil,
                caption: "\(outcome.scatterCount)× SCATTER" + (outcome.scatterWin > 0 ? " · \(Coins.format(outcome.scatterWin))" : "")
            ))
        }
        return items
    }

    /// Stops the win presentation and releases anything still held back.
    func finishPresentation() {
        presentation?.cancel()
        presentation = nil
        if unrevealed > 0 {
            app?.reveal(unrevealed)
            unrevealed = 0
        }
        highlight = nil
        banner = nil
    }

    /// Leaving mid-spin is fine: the result was booked already, so reveal it and settle the reels.
    func leave() {
        finishPresentation()
        if phase == .spinning {
            for reel in 0..<SlotMachine.reelCount { settle(reel: reel) }
            phase = .idle
        }
    }

    private func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    static func window(_ strip: [SlotSymbol], from start: Int, count: Int) -> [SlotSymbol] {
        (0..<count).map { strip[((start + $0) % strip.count + strip.count) % strip.count] }
    }
}
