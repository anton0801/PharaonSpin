import SwiftUI

/// Opening animation for the daily gift. The coins are credited on tap; this only shows them.
struct DailyBonusView: View {
    let amount: Int
    @EnvironmentObject private var model: AppModel
    @State private var opened = false

    var body: some View {
        ModalPanel(title: "Daily Bonus", width: (280, 360)) { m in
            VStack(spacing: m(12)) {
                Image(systemName: opened ? "gift.fill" : "gift")
                    .font(.system(size: m(58), weight: .bold))
                    .foregroundStyle(Palette.goldGradient)
                    .scaleEffect(opened ? 1 : 0.4)
                    .rotationEffect(.degrees(opened ? 0 : -18))
                    .shadow(color: Palette.gold.opacity(0.8), radius: opened ? m(16) : 0)
                    .accessibilityHidden(true)
                OutlinedText(text: "+\(Coins.format(amount))", size: m(34), gradient: Palette.goldGradient)
                    .opacity(opened ? 1 : 0)
                    .accessibilityLabel("\(Coins.format(amount)) free coins")
                let days = amount / max(1, model.rules.dailyBonus)
                PanelText(text: days > 1 ? "\(days) days of free coins saved up." : "Come back tomorrow for more free coins.", size: m(13))
                BarButton(title: "Collect", style: .green, height: m(44)) {
                    model.feedback.tap()
                    model.dailyBonusDismissed()
                }
                .frame(width: m(170))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) { opened = true }
        }
    }
}

/// Figma "Notifications" (4989:257) with the corrected, non-casino copy. Shown after the first
/// claimed daily bonus; the system permission prompt appears only after YES.
struct NotificationPromptView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GeometryReader { screen in
            let landscape = screen.size.width > screen.size.height
            // BGforNotifications already paints the fruit emblem for the portrait frame; landscape
            // (no matching art exported) uses the loading hall plus the emblem on its own.
            let paintedEmblem = !landscape && ArtLibrary.shared.image(.bgNotifications) != nil
            ZStack {
                BackgroundArt(name: landscape ? .bgLoading : .bgNotifications)
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                DesignCanvas { m in
                    if m.isLandscape {
                        ArtImage(.menuEmblemFruit) { EmblemFallback(game: .fruit) }
                            .place(CGRect(x: 60, y: 40, width: 280, height: 280), m)
                        VStack(spacing: m(12)) { copy(m) }
                            .frame(width: m(380))
                            .position(x: m(580), y: m(180))
                    } else {
                        if !paintedEmblem {
                            ArtImage(.menuEmblemFruit) { EmblemFallback(game: .fruit) }
                                .place(CGRect(x: 24, y: 150, width: 312, height: 312), m)
                        }
                        VStack(spacing: m(12)) { copy(m) }
                            .frame(width: m(300))
                            .position(x: m(180), y: m(640))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private func copy(_ m: CanvasMetrics) -> some View {
        Text("ALLOW NOTIFICATIONS ABOUT FREE COINS")
            .font(.game(m(18)))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
        Text("Get notified about daily free coins and new games.")
            .font(.system(size: m(15), weight: .regular, design: .rounded).italic())
            .foregroundColor(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        BarButton(title: "YES, NOTIFY ME", style: .red, height: m(46)) {
            model.feedback.tap()
            model.acceptNotifications()
        }
        .padding(.top, m(6))
        Button {
            model.feedback.tap()
            model.skipNotifications()
        } label: {
            Text("SKIP")
                .font(.game(m(15)))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: m(34))
                .background(Capsule().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(PressScale())
    }
}

/// After 60 minutes of continuous play.
struct SessionReminderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ModalPanel(title: "Time Check", width: (290, 380)) { m in
            VStack(spacing: m(14)) {
                Image(systemName: "clock.fill")
                    .font(.system(size: m(40), weight: .bold))
                    .foregroundStyle(Palette.goldGradient)
                    .accessibilityHidden(true)
                PanelText(text: "You've been playing for an hour.", size: m(17), weight: .bold)
                PanelText(text: "A short break is a good idea. You can turn this reminder off in Settings.", size: m(12), weight: .medium, color: .white.opacity(0.75))
                HStack(spacing: m(10)) {
                    BarButton(title: "Take a Break", style: .blue, height: m(42)) {
                        model.feedback.tap()
                        model.takeBreak()
                    }
                    BarButton(title: "Keep Playing", style: .green, height: m(42)) {
                        model.feedback.tap()
                        model.keepPlaying()
                    }
                }
            }
        }
    }
}

struct ResponsiblePlayView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ModalPanel(title: "Responsible Play", width: (310, 560), dismiss: { model.modal = .settings }) { m in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: m(10)) {
                    point("Pharaoh Spin is a game for entertainment. No real money can be won or lost, and coins have no cash value.", m)
                    point("Decide how long you want to play before you start, and take regular breaks. The session reminder can nudge you every hour.", m)
                    point("If you are playing to escape, or it stops being fun, stop and talk to someone.", m)
                    point("If gambling is affecting you or someone close to you, free and confidential help is available.", m)
                    BarButton(title: "Get Help", style: .blue, height: m(42)) {
                        openURL(AppConfig.responsiblePlayURL)
                    }
                    .frame(width: m(200))
                    .frame(maxWidth: .infinity)
                    .padding(.top, m(4))
                    .accessibilityHint("Opens the National Council on Problem Gambling website")
                }
            }
            .frame(maxHeight: m(m.isLandscape ? 240 : 480))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func point(_ text: String, _ m: CanvasMetrics) -> some View {
        HStack(alignment: .top, spacing: m(8)) {
            Circle().fill(Palette.gold).frame(width: m(6), height: m(6)).padding(.top, m(5))
            Text(text)
                .font(.game(m(13), .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
