import Combine
import SlotCore
import SwiftUI
import UserNotifications

enum Route: Equatable {
    case loading
    case disclosure
    case menu
    case game(GameKind)
}

enum Modal: Equatable {
    case settings
    case store
    case slotInfo(SlotTheme)
    case wheelOdds
    case responsiblePlay
    case sessionReminder
    case notificationPrompt
    case dailyBonus(amount: Int)
}

@MainActor
final class AppModel: ObservableObject {
    let rules = EconomyRules.standard
    let ladder = BetLadder.standard
    let slotMachine = SlotMachine.standard
    let wheel = FortuneWheel.standard
    /// Computed from the strips at launch, never stored as a constant.
    let slotReturn: SlotReturn

    let settings: SettingsStore
    let feedback: Feedback
    let storeService: StoreService
    let network: NetworkMonitor
    let notifications = NotificationService()

    @Published private(set) var state: PlayerState {
        didSet { playerStore.save(state) }
    }
    @Published var route: Route = .loading
    @Published var modal: Modal?
    @Published private(set) var now = Date()
    @Published private(set) var loadProgress: Double = 0
    /// Coins already credited by a decided spin but not yet revealed by its animation.
    @Published private(set) var heldWin = 0
    @Published var toast: String?

    private let playerStore = PlayerStore()
    private let random: RandomSource = SystemRandomSource()
    private var ticker: AnyCancellable?
    private var settingsObserver: AnyCancellable?
    private var sessionStart = Date()
    private var backgroundedAt: Date?

    init() {
        let settings = SettingsStore()
        self.settings = settings
        self.feedback = Feedback(settings: settings)
        self.storeService = StoreService()
        self.network = NetworkMonitor()
        self.slotReturn = SlotMachine.standard.exactReturn()
        var initial = PlayerStore().load() ?? .fresh(rules: .standard)
        #if DEBUG
        if DebugLaunch.resetState { initial = .fresh(rules: .standard) }
        if let balance = DebugLaunch.balance { initial.wallet = Wallet(balance: balance) }
        #endif
        self.state = initial

        storeService.credit = { [weak self] id, coins in
            self?.creditPurchase(transactionID: id, coins: coins) ?? false
        }
        settingsObserver = settings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] date in
            self?.tick(date)
        }
    }

    // MARK: Loading

    func load() async {
        guard route == .loading else { return }
        let names = ArtName.allCases
        for (index, name) in names.enumerated() {
            await Task.detached(priority: .userInitiated) {
                ArtLibrary.shared.preload(name)
            }.value
            loadProgress = Double(index + 1) / Double(names.count)
        }
        storeService.start()
        try? await Task.sleep(nanoseconds: 300_000_000)
        withAnimation(.easeInOut(duration: 0.35)) {
            route = state.disclosureAccepted ? .menu : .disclosure
        }
        #if DEBUG
        DebugLaunch.apply(to: self)
        #endif
    }

    #if DEBUG
    func debugAcceptDisclosure() {
        state.disclosureAccepted = true
    }
    #endif

    func acceptDisclosure() {
        state.disclosureAccepted = true
        sessionStart = Date()
        withAnimation(.easeInOut(duration: 0.35)) { route = .menu }
    }

    // MARK: Balance and bets

    var balance: Int { state.wallet.balance }
    /// The balance shown on screen: a win appears only when its animation reveals it.
    var displayedBalance: Int { max(0, state.wallet.balance - heldWin) }

    func reveal(_ amount: Int) {
        heldWin = max(0, heldWin - amount)
    }

    func bet(for game: GameKind) -> Int {
        let stored = state.bets[game] ?? ladder.minimum
        return ladder.steps.contains(stored) ? stored : ladder.minimum
    }

    func canIncreaseBet(_ game: GameKind) -> Bool {
        ladder.increased(from: bet(for: game), balance: displayedBalance) != nil
    }

    func canDecreaseBet(_ game: GameKind) -> Bool {
        ladder.decreased(from: bet(for: game)) != nil
    }

    func increaseBet(_ game: GameKind) {
        guard let next = ladder.increased(from: bet(for: game), balance: displayedBalance) else { return }
        state.bets[game] = next
        feedback.tap()
    }

    func decreaseBet(_ game: GameKind) {
        guard let previous = ladder.decreased(from: bet(for: game)) else { return }
        state.bets[game] = previous
        feedback.tap()
    }

    // MARK: Slots

    func slotGame(_ theme: SlotTheme) -> SlotGame {
        state.slotGames[theme] ?? SlotGame()
    }

    func canSpinSlot(_ theme: SlotTheme) -> Bool {
        slotGame(theme).isInFreeSpins || state.wallet.canAfford(bet(for: theme.game))
    }

    /// Decides and books the spin before any animation starts.
    func spinSlot(_ theme: SlotTheme) -> SlotRound? {
        var wallet = state.wallet
        var game = slotGame(theme)
        guard let round = try? game.play(machine: slotMachine, bet: bet(for: theme.game), ladder: ladder,
                                         wallet: &wallet, using: random) else { return nil }
        heldWin += round.outcome.totalWin
        var next = state
        next.wallet = wallet
        next.slotGames[theme] = game
        state = next
        return round
    }

    // MARK: Wheel

    var wheelBonusAvailable: Bool {
        WheelBonus.isAvailable(lastSpin: state.lastWheelBonus, now: now, interval: rules.wheelBonusInterval)
    }

    var nextWheelBonus: Date? {
        WheelBonus.nextAvailable(lastSpin: state.lastWheelBonus, interval: rules.wheelBonusInterval)
    }

    func canSpinWheel() -> Bool {
        state.wheelGame.freeSpinsRemaining > 0 || wheelBonusAvailable || state.wallet.canAfford(bet(for: .wheel))
    }

    /// Pending free spins first, then the periodic free spin if available, otherwise a paid spin.
    func spinWheel() -> WheelRound? {
        var wallet = state.wallet
        var game = state.wheelGame
        let useBonus = game.freeSpinsRemaining == 0 && wheelBonusAvailable
        guard let round = try? game.play(wheel: wheel, bet: bet(for: .wheel), ladder: ladder,
                                         bonusStake: useBonus ? rules.wheelBonusStake : nil,
                                         wallet: &wallet, using: random) else { return nil }
        heldWin += round.payout
        var next = state
        next.wallet = wallet
        next.wheelGame = game
        if round.kind == .bonus { next.lastWheelBonus = now }
        state = next
        return round
    }

    // MARK: Daily bonus

    var claimableDailyDays: Int {
        DailyBonus.claimableDays(lastClaim: state.lastDailyClaim, now: now, calendar: .current, maxDays: rules.dailyBonusMaxDays)
    }

    var dailyBonusAmount: Int { claimableDailyDays * rules.dailyBonus }

    var nextDailyBonus: Date? {
        state.lastDailyClaim.map { DailyBonus.nextAvailable(after: $0, calendar: .current) }
    }

    func claimDailyBonus() {
        let amount = dailyBonusAmount
        guard amount > 0 else { return }
        var next = state
        try? next.wallet.credit(amount)
        next.lastDailyClaim = now
        next.hasClaimedDailyBonus = true
        state = next
        feedback.bonus()
        modal = .dailyBonus(amount: amount)
        if let date = nextDailyBonus {
            Task { await notifications.scheduleDailyBonusReminder(at: date) }
        }
    }

    /// Called when the daily bonus panel closes: the moment the value of notifications is obvious.
    func dailyBonusDismissed() {
        modal = nil
        Task { await offerNotificationsIfAppropriate() }
    }

    // MARK: Notifications pre-prompt

    private func offerNotificationsIfAppropriate() async {
        guard state.hasClaimedDailyBonus, !state.notificationsRequested else { return }
        if let snoozed = state.notificationPromptSnoozedUntil, Date() < snoozed { return }
        guard await notifications.authorizationStatus() == .notDetermined else { return }
        if modal == nil { modal = .notificationPrompt }
    }

    func acceptNotifications() {
        state.notificationsRequested = true
        modal = nil
        Task {
            let granted = await notifications.requestAuthorization()
            if granted, let date = nextDailyBonus {
                await notifications.scheduleDailyBonusReminder(at: date)
            }
        }
    }

    func skipNotifications() {
        state.notificationPromptSnoozedUntil = Date().addingTimeInterval(AppConfig.notificationPromptSnooze)
        modal = nil
    }

    // MARK: Refill

    var refillDue: Date? { state.refill.dueDate(delay: rules.refillDelay) }

    private var freeSpinsPending: Bool {
        state.slotGames.values.contains { $0.isInFreeSpins } || state.wheelGame.freeSpinsRemaining > 0
    }

    // MARK: Store

    func openStore() {
        guard settings.storeVisible else { return }
        feedback.tap()
        modal = .store
    }

    private func creditPurchase(transactionID: UInt64, coins: Int) -> Bool {
        guard coins > 0, !state.creditedTransactions.contains(transactionID) else { return false }
        var next = state
        next.creditedTransactions.insert(transactionID)
        try? next.wallet.credit(coins)
        state = next
        return true
    }

    // MARK: Session reminder

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if let backgroundedAt, Date().timeIntervalSince(backgroundedAt) > 5 * 60 {
                sessionStart = Date()
            }
            backgroundedAt = nil
            tick(Date())
        case .background:
            backgroundedAt = Date()
        default:
            break
        }
    }

    func keepPlaying() {
        sessionStart = Date()
        modal = nil
    }

    func takeBreak() {
        sessionStart = Date()
        modal = nil
        withAnimation(.easeInOut(duration: 0.3)) { route = .menu }
    }

    // MARK: Data

    func deleteAllData() {
        playerStore.erase()
        notifications.cancelAll()
        settings.reset()
        heldWin = 0
        state = .fresh(rules: rules)
        modal = nil
        withAnimation(.easeInOut(duration: 0.3)) { route = .disclosure }
    }

    // MARK: Clock

    private func tick(_ date: Date) {
        now = date
        guard route != .loading else { return }

        var refill = state.refill
        let amount = refill.update(balance: state.wallet.balance, minimumBet: ladder.minimum,
                                   freeSpinsPending: freeSpinsPending, now: date, rules: rules)
        if refill != state.refill || amount > 0 {
            var next = state
            next.refill = refill
            if amount > 0 { try? next.wallet.credit(amount) }
            state = next
            if amount > 0 {
                feedback.bonus()
                toast = "+\(Coins.format(amount)) free coins"
            }
        }

        if settings.sessionReminderOn, route != .disclosure, modal == nil,
           date.timeIntervalSince(sessionStart) >= AppConfig.sessionReminderInterval {
            modal = .sessionReminder
        }
    }
}
