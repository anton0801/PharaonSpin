import SwiftUI

/// Figma "Settings" (4999:219): Sound and Vibro as drawn, plus the switches and links the brief adds.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.openURL) private var openURL

    @State private var confirmDelete = false
    @State private var parentalGate = false
    @State private var gateAnswer = ""
    @State private var gateQuestion = ParentalQuestion.random()

    var body: some View {
        ZStack {
            BackgroundArt(name: .bgMenu)
            Color.black.opacity(0.55).ignoresSafeArea()

            DesignCanvas { m in
                VStack(spacing: m(m.isLandscape ? 4 : 10)) {
                    ArtImage(.settingsTitle) { GoldTitle(text: "Settings", size: m(40)) }
                        .frame(height: m(m.isLandscape ? 46 : 82))
                        .accessibilityLabel("Settings")
                        .accessibilityAddTraits(.isHeader)

                    ScrollView(showsIndicators: false) {
                        if m.isLandscape {
                            HStack(alignment: .top, spacing: m(24)) {
                                VStack(spacing: m(10)) { toggles(m) }
                                VStack(spacing: m(8)) { links(m) }
                            }
                        } else {
                            VStack(spacing: m(12)) {
                                toggles(m)
                                Divider().background(Color.white.opacity(0.2)).padding(.vertical, m(2))
                                links(m)
                            }
                        }
                    }
                    .padding(.horizontal, m(26))
                    .padding(.vertical, m(24))
                    .frame(width: m(m.isLandscape ? 560 : 300))
                    .frame(maxHeight: m(m.isLandscape ? 290 : 560))
                    .fixedSize(horizontal: false, vertical: true)
                    .background(PanelBackground())
                }
                .frame(width: m(m.designSize.width), height: m(m.designSize.height))

                IconButton(systemName: "chevron.backward", label: "Back") {
                    model.feedback.tap()
                    model.modal = nil
                }
                .place(CGRect(x: 12, y: m.isLandscape ? 12 : 64, width: 40, height: 40), m)
            }
        }
        .alert("Delete all data?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { model.deleteAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your coins, progress and settings will be reset to a fresh start.")
        }
        .alert("Ask a grown-up", isPresented: $parentalGate) {
            TextField("Answer", text: $gateAnswer)
                .keyboardType(.numberPad)
            Button("Turn On") {
                if Int(gateAnswer) == gateQuestion.answer { settings.storeOn = true }
                gateAnswer = ""
            }
            Button("Cancel", role: .cancel) { gateAnswer = "" }
        } message: {
            Text("To turn purchases back on, answer: \(gateQuestion.text)")
        }
    }

    @ViewBuilder
    private func toggles(_ m: CanvasMetrics) -> some View {
        toggleRow("Sound", isOn: $settings.soundOn, m)
        toggleRow("Vibro", isOn: $settings.vibrationOn, m)
        if AppConfig.storeEnabled {
            toggleRow("Store", caption: "Purchases on/off", isOn: Binding(
                get: { settings.storeOn },
                set: { newValue in
                    if newValue {
                        gateQuestion = .random()
                        parentalGate = true
                    } else {
                        settings.storeOn = false
                    }
                }
            ), m)
        }
        toggleRow("Session Reminder", caption: "Every 60 minutes", isOn: $settings.sessionReminderOn, m)
    }

    @ViewBuilder
    private func links(_ m: CanvasMetrics) -> some View {
        linkButton("Responsible Play", m) { model.modal = .responsiblePlay }
        linkButton("Privacy Policy", m) { openURL(AppConfig.privacyPolicyURL) }
        linkButton("Terms of Use", m) { openURL(AppConfig.termsURL) }
        if AppConfig.hasNonConsumables && settings.storeVisible {
            linkButton("Restore Purchases", m) { Task { await model.storeService.restore() } }
        }
        BarButton(title: "Delete Data", style: .red, height: m(38)) {
            model.feedback.tap()
            confirmDelete = true
        }
        .frame(width: m(200))
        .padding(.top, m(4))
    }

    private func toggleRow(_ title: String, caption: String? = nil, isOn: Binding<Bool>, _ m: CanvasMetrics) -> some View {
        HStack(spacing: m(10)) {
            VStack(alignment: .leading, spacing: m(1)) {
                Text(title)
                    .font(.game(m(15), .bold))
                    .foregroundColor(.white)
                if let caption {
                    Text(caption)
                        .font(.game(m(10), .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Spacer(minLength: m(8))
            ArtToggle(title: title, isOn: isOn, height: m(32)) { model.feedback.tap() }
        }
        .frame(width: m(240))
    }

    private func linkButton(_ title: String, _ m: CanvasMetrics, action: @escaping () -> Void) -> some View {
        Button {
            model.feedback.tap()
            action()
        } label: {
            HStack {
                Text(title)
                    .font(.game(m(14), .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: m(12), weight: .bold))
                    .foregroundColor(Palette.gold)
            }
            .padding(.horizontal, m(14))
            .frame(width: m(240), height: m(36))
            .background(RoundedRectangle(cornerRadius: m(10), style: .continuous).fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: m(10), style: .continuous).stroke(Palette.gold.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(PressScale())
    }
}

/// A sum a young child cannot guess, as a light parental gate before purchases are re-enabled.
struct ParentalQuestion {
    let text: String
    let answer: Int

    static func random() -> ParentalQuestion {
        let a = Int.random(in: 6...9)
        let b = Int.random(in: 6...9)
        return ParentalQuestion(text: "\(a) × \(b) = ?", answer: a * b)
    }
}
