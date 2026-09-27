#if DEBUG
import Foundation

/// Debug-only launch arguments for screenshots and manual QA, e.g.
/// `-resetState -screen wheel -autoSpin`. Compiled out of release builds.
enum DebugLaunch {
    private static let arguments = ProcessInfo.processInfo.arguments

    static var resetState: Bool { arguments.contains("-resetState") }
    static var autoSpin: Bool { arguments.contains("-autoSpin") }
    static var screen: String? { value(after: "-screen") }
    static var balance: Int? { value(after: "-balance").flatMap(Int.init) }

    private static func value(after key: String) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    @MainActor
    static func apply(to model: AppModel) {
        guard let screen else { return }
        if screen != "disclosure" { model.debugAcceptDisclosure() }
        switch screen {
        case "menu": model.route = .menu
        case "egypt": model.route = .game(.egypt)
        case "fruit": model.route = .game(.fruit)
        case "wheel": model.route = .game(.wheel)
        case "settings": model.route = .menu; model.modal = .settings
        case "store": model.route = .menu; model.modal = .store
        case "info": model.route = .game(.egypt); model.modal = .slotInfo(.egypt)
        case "odds": model.route = .game(.wheel); model.modal = .wheelOdds
        case "notifications": model.route = .menu; model.modal = .notificationPrompt
        case "reminder": model.route = .game(.egypt); model.modal = .sessionReminder
        case "bonus": model.route = .menu; model.claimDailyBonus()
        case "responsible": model.route = .menu; model.modal = .responsiblePlay
        default: model.route = .disclosure
        }
    }
}
#endif
