import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch model.route {
            case .loading:
                LoadingView()
                    .transition(.opacity)
            case .disclosure:
                DisclosureView()
                    .transition(.opacity)
            case .menu:
                MenuView()
                    .transition(.opacity)
            case .game(let game):
                Group {
                    if let theme = game.slotTheme {
                        SlotGameView(theme: theme)
                    } else {
                        WheelGameView()
                    }
                }
                .id(game)
                .transition(.opacity)
            }

            ModalLayer()

            if let toast = model.toast {
                ToastView(text: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 2_400_000_000)
                        withAnimation { model.toast = nil }
                    }
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.toast)
    }
}

/// Every modal panel, drawn over the current screen. The store is only ever opened by the player.
struct ModalLayer: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            switch model.modal {
            case .none:
                EmptyView()
            case .settings:
                SettingsView().transition(.opacity)
            case .store:
                StoreView().transition(.opacity)
            case .slotInfo(let theme):
                SlotInfoView(theme: theme).transition(.opacity)
            case .wheelOdds:
                WheelOddsView().transition(.opacity)
            case .responsiblePlay:
                ResponsiblePlayView().transition(.opacity)
            case .sessionReminder:
                SessionReminderView().transition(.opacity)
            case .notificationPrompt:
                EmptyView() // NotificationPromptView().transition(.opacity)
            case .dailyBonus(let amount):
                DailyBonusView(amount: amount).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.modal)
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        VStack {
            Text(text)
                .font(.game(17))
                .foregroundColor(Palette.goldLight)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.black.opacity(0.8)).overlay(Capsule().stroke(Palette.gold, lineWidth: 1.5)))
                .padding(.top, 12)
            Spacer()
        }
        .allowsHitTesting(false)
        .accessibilityAddTraits(.isStaticText)
    }
}
