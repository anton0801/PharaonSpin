import QuartzCore
import SlotCore
import SwiftUI
import UIKit

/// Frame-driven wheel motion, so the pointer can react to every divider it passes.
@MainActor
final class WheelAnimator: ObservableObject {
    @Published private(set) var rotation: Double = 0
    @Published private(set) var pointerTilt: Double = 0

    private let geometry: WheelGeometry
    private var link: CADisplayLink?
    private var start: Double = 0
    private var target: Double = 0
    private var startTime: CFTimeInterval = 0
    private var duration: CFTimeInterval = 4.5
    private var lastDivider = 0
    private var lastTick: CFTimeInterval = 0
    private var completion: (() -> Void)?
    var onDivider: (() -> Void)?

    init(geometry: WheelGeometry) {
        self.geometry = geometry
    }

    func spin(to target: Double, duration: CFTimeInterval, completion: @escaping () -> Void) {
        stop()
        start = rotation
        self.target = target
        self.duration = duration
        self.completion = completion
        startTime = CACurrentMediaTime()
        lastDivider = dividerIndex(at: rotation)
        let link = CADisplayLink(target: DisplayLinkProxy(self), selector: #selector(DisplayLinkProxy.step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    /// Ease-out cubic: fast start, long even glide into the stop — the same curve for every result.
    private func eased(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }

    fileprivate func step() {
        let now = CACurrentMediaTime()
        let t = min(1, (now - startTime) / duration)
        let value = start + (target - start) * eased(t)
        let speed = (target - start) * 3 * pow(1 - t, 2) / duration // degrees per second
        rotation = value

        let divider = dividerIndex(at: value)
        if divider != lastDivider {
            lastDivider = divider
            if now - lastTick > 0.045 {
                lastTick = now
                onDivider?()
            }
        }
        // Phase past the last divider, in degrees: the pointer flicks back and settles.
        let phase = (value + geometry.firstSectorCenter + geometry.sectorWidth / 2)
            .truncatingRemainder(dividingBy: geometry.sectorWidth)
        let kick = max(0, 1 - phase / 12)
        pointerTilt = -(4 + 14 * kick) * min(1, speed / 160)

        if t >= 1 {
            stop()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pointerTilt = 0 }
            let done = completion
            completion = nil
            done?()
        }
    }

    private func dividerIndex(at rotation: Double) -> Int {
        Int(floor((rotation + geometry.firstSectorCenter + geometry.sectorWidth / 2) / geometry.sectorWidth))
    }
}

/// Breaks the CADisplayLink → target retain cycle. The link fires on the main run loop.
@MainActor
private final class DisplayLinkProxy {
    weak var owner: WheelAnimator?

    init(_ owner: WheelAnimator) {
        self.owner = owner
    }

    @objc func step() {
        owner?.step()
    }
}

@MainActor
final class WheelViewModel: ObservableObject {
    /// Sector 1 (the gift) is centred 15° left of the top in the Figma wheel art.
    static let geometry = WheelGeometry(sectorCount: 12, firstSectorCenter: -15)
    static let spinDuration: CFTimeInterval = 4.5

    @Published private(set) var isSpinning = false
    @Published private(set) var lastWin = 0
    @Published private(set) var landedSector: Int?
    @Published var banner: String?

    let animator = WheelAnimator(geometry: geometry)
    private weak var app: AppModel?
    private var presentation: Task<Void, Never>?
    private var unrevealed = 0

    init(app: AppModel) {
        self.app = app
        animator.onDivider = { [weak app] in app?.feedback.tick() }
    }

    func spin() {
        guard let app, !isSpinning, app.canSpinWheel() else { return }
        finishPresentation()

        // The sector is drawn by weight before the wheel moves; the animation only shows it.
        guard let round = app.spinWheel() else { return }
        unrevealed = round.payout
        lastWin = 0
        landedSector = nil
        isSpinning = true
        app.feedback.tap()

        // Presentation-only randomness: how many turns and where inside the sector the pointer lands.
        let turns = Int.random(in: 5...7)
        let offset = Double.random(in: -0.4...0.4)
        let target = Self.geometry.targetRotation(from: animator.rotation, sector: round.sector, turns: turns, offset: offset)
        animator.spin(to: target, duration: Self.spinDuration) { [weak self] in
            self?.isSpinning = false
            self?.landedSector = round.sector
            self?.present(round)
        }
    }

    private func present(_ round: WheelRound) {
        guard let app else { return }
        presentation = Task { [weak self] in
            guard let self else { return }
            if round.payout > 0 {
                app.feedback.win(big: round.payout >= round.stake * 5)
                let steps = 20
                var shown = 0
                for step in 1...steps {
                    let value = round.payout * step / steps
                    app.reveal(value - shown)
                    self.unrevealed -= value - shown
                    shown = value
                    withAnimation(.linear(duration: 0.03)) { self.lastWin = value }
                    try? await Task.sleep(nanoseconds: 33_000_000)
                    if Task.isCancelled { return }
                }
            }
            let prize = app.wheel.sectors[round.sector].prize
            switch prize {
            case .freeSpins(let count):
                app.feedback.bonus()
                self.banner = "+\(count) FREE SPINS"
            case .multiplier:
                let multiplier = prize.multiplier ?? 0
                let label = multiplier == multiplier.rounded() ? String(Int(multiplier)) : String(multiplier)
                self.banner = "×\(label) · " + (round.payout > 0 ? "WIN \(Coins.format(round.payout))" : "NO WIN")
            }
            UIAccessibility.post(notification: .announcement, argument: self.banner ?? "")
        }
    }

    func finishPresentation() {
        presentation?.cancel()
        presentation = nil
        if unrevealed > 0 {
            app?.reveal(unrevealed)
            unrevealed = 0
        }
        banner = nil
    }

    func leave() {
        if isSpinning {
            animator.stop()
            isSpinning = false
        }
        finishPresentation()
    }
}
