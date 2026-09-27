import SwiftUI

// MARK: - Fallback shapes (used only while a Figma image set is missing)

struct GoldRimCircle: View {
    var fill: [Color]

    var body: some View {
        ZStack {
            Circle().fill(Palette.goldGradient)
            Circle()
                .fill(LinearGradient(colors: fill, startPoint: .top, endPoint: .bottom))
                .padding(4)
            Circle()
                .trim(from: 0.55, to: 0.95)
                .stroke(Color.white.opacity(0.35), lineWidth: 2)
                .rotationEffect(.degrees(-10))
                .padding(8)
        }
    }
}

struct GoldRimCapsule: View {
    var fill: [Color]

    var body: some View {
        ZStack {
            Capsule().fill(Palette.goldGradient)
            Capsule().fill(LinearGradient(colors: fill, startPoint: .top, endPoint: .bottom)).padding(3)
        }
    }
}

struct DarkPlate: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Palette.plate.opacity(0.9))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Balance plate

/// Coin + blue bar from Figma, with the live balance and the refill countdown when one is running.
struct BalancePlate: View {
    let balance: Int
    var refillDue: Date?
    var refillAmount = 0
    var now: Date

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            ZStack(alignment: .leading) {
                ArtImage(.plateBalance, contentMode: .fit) {
                    HStack(spacing: 0) {
                        GoldRimCircle(fill: [Palette.goldLight, Palette.amber])
                            .frame(width: height)
                            .zIndex(1)
                        GoldRimCapsule(fill: [Palette.skyBlue, Palette.royalBlue])
                            .padding(.vertical, height * 0.1)
                            .padding(.leading, -height * 0.35)
                    }
                }
                OutlinedText(text: Coins.format(balance), size: height * 0.36)
                    .frame(width: geometry.size.width * 0.66)
                    .position(x: geometry.size.width * 0.573, y: height * 0.5)
                    .contentTransition(.numericText())
                if let refillDue, refillDue > now {
                    Text("+\(Coins.short(refillAmount)) in \(Countdown.format(refillDue.timeIntervalSince(now)))")
                        .font(.game(height * 0.22, .bold))
                        .foregroundColor(Palette.goldLight)
                        .padding(.horizontal, height * 0.18)
                        .padding(.vertical, height * 0.05)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                        .position(x: geometry.size.width * 0.573, y: height * 1.12)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Balance \(Coins.format(balance)) coins")
        .accessibilityValue(refillDue.map { "Free refill in \(Countdown.format($0.timeIntervalSince(now)))" } ?? "")
    }
}

// MARK: - Round icon button (Back, Info, Settings, Store)

/// Blue glossy button with a gold rim, matching the balance plate. Drawn in code: the Figma file has no such icon.
struct IconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                ZStack {
                    GoldRimCircle(fill: [Palette.skyBlue, Palette.royalBlue])
                    Image(systemName: systemName)
                        .font(.system(size: geometry.size.width * 0.42, weight: .heavy))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                }
            }
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(label)
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - SPIN

struct SpinButton: View {
    var enabled: Bool
    /// "FREE" for the periodic free spin, or the number of free spins left.
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                let side = geometry.size.width
                ZStack {
                    if enabled {
                        ArtImage(.buttonSpin) { spinFallback(active: true) }
                    } else {
                        ArtImage(.buttonSpinDisabled) { spinFallback(active: false) }
                    }
                    if let badge {
                        Text(badge)
                            .font(.game(side * 0.13))
                            .foregroundColor(.white)
                            .padding(.horizontal, side * 0.08)
                            .padding(.vertical, side * 0.025)
                            .background(Capsule().fill(Palette.green).overlay(Capsule().stroke(Palette.goldLight, lineWidth: 2)))
                            .position(x: side * 0.5, y: side * 0.1)
                    }
                }
            }
        }
        .buttonStyle(PressScale())
        .disabled(!enabled)
        .accessibilityLabel(badge.map { "Spin, \($0)" } ?? "Spin")
    }

    private func spinFallback(active: Bool) -> some View {
        ZStack {
            GoldRimCircle(fill: active ? [Color(red: 1, green: 0.35, blue: 0.35), Palette.spinRed] : [.gray, Color(white: 0.3)])
            OutlinedText(text: "SPIN", size: 22)
        }
    }
}

// MARK: - Total Bet / Win / − +

struct BetPanelLayout {
    var totalBet: CGRect
    var win: CGRect
    var minus: CGRect
    var plus: CGRect

    /// Figma portrait positions (Game 1, group 874252675).
    static let portrait = BetPanelLayout(
        totalBet: .figma(145, 1980, 360, 123),
        win: .figma(105, 2120, 440, 150.33),
        minus: .figma(81, 2128, 134.85, 134),
        plus: .figma(435, 2128, 134.85, 134)
    )

    /// Measured from the landscape frames (Game 4–6).
    static let landscape: BetPanelLayout = {
        let win = CGRect(x: 99.2 - 73.3, y: 314.4 - 25, width: 146.7, height: 50.1)
        return BetPanelLayout(
            totalBet: CGRect(x: 95.2 - 60, y: 262.8 - 20.5, width: 120, height: 41),
            win: win,
            minus: CGRect(x: win.midX - 59 - 22.5, y: win.midY - 22.3, width: 45, height: 44.7),
            plus: CGRect(x: win.midX + 59 - 22.5, y: win.midY - 22.3, width: 45, height: 44.7)
        )
    }()
}

struct BetPanel: View {
    let metrics: CanvasMetrics
    let layout: BetPanelLayout
    let bet: Int
    var betCaption = "Total Bet"
    let win: Int
    let canDecrease: Bool
    let canIncrease: Bool
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        Group {
            plate(.plateBet, rect: layout.totalBet, title: betCaption, value: bet, titleSize: 9.3, valueSize: 16.5, valueColor: Palette.amber)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(betCaption) \(Coins.format(bet)) coins")
            plate(.plateWin, rect: layout.win, title: "WIN", value: win, titleSize: 10.5, valueSize: 20, valueColor: .white)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Win \(Coins.format(win)) coins")
            stepButton(.buttonMinus, symbol: "minus", enabled: canDecrease, action: decrease)
                .place(layout.minus, metrics)
                .accessibilityLabel("Decrease Bet")
            stepButton(.buttonPlus, symbol: "plus", enabled: canIncrease, action: increase)
                .place(layout.plus, metrics)
                .accessibilityLabel("Increase Bet")
        }
    }

    private func plate(_ art: ArtName, rect: CGRect, title: String, value: Int, titleSize: CGFloat, valueSize: CGFloat, valueColor: Color) -> some View {
        ZStack {
            ArtImage(art, contentMode: .fit) { DarkPlate() }
            VStack(spacing: metrics(0.5)) {
                Text(title)
                    .font(.game(metrics(titleSize), .bold))
                    .foregroundColor(.white)
                Text(Coins.format(value))
                    .font(.game(metrics(valueSize)))
                    .foregroundColor(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, metrics(22))
            .offset(y: metrics(1))
        }
        .place(rect, metrics)
    }

    private func stepButton(_ art: ArtName, symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ArtImage(art) {
                ZStack {
                    GoldRimCircle(fill: [Palette.skyBlue, Palette.royalBlue])
                    Image(systemName: symbol).font(.system(size: metrics(18), weight: .black)).foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PressScale())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}

// MARK: - Panels and bar buttons

/// The Settings panel (black glass in a gold frame), stretchable to any size via cap insets.
struct PanelBackground: View {
    var body: some View {
        ArtImage(.settingsPanel, capInsets: EdgeInsets(top: 40, leading: 40, bottom: 40, trailing: 40)) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.goldGradient)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.18), Color(white: 0.04)], startPoint: .top, endPoint: .bottom))
                    .padding(7)
            }
        }
    }
}

enum BarStyle {
    case red, blue, green

    var art: ArtName {
        switch self {
        case .red: return .buttonRedBar
        case .blue: return .buttonBlueBar
        case .green: return .buttonGreenBar
        }
    }

    var colors: [Color] {
        switch self {
        case .red: return [Color(red: 1, green: 0.3, blue: 0.3), Palette.spinRed]
        case .blue: return [Palette.skyBlue, Palette.royalBlue]
        case .green: return [Color(red: 0.4, green: 0.9, blue: 0.3), Palette.green]
        }
    }
}

struct BarButton: View {
    let title: String
    var style: BarStyle = .green
    var height: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                ArtImage(style.art, capInsets: EdgeInsets(top: 22, leading: 30, bottom: 22, trailing: 30)) {
                    GoldRimCapsule(fill: style.colors)
                }
                OutlinedText(text: title, size: height * 0.38)
                    .padding(.horizontal, height * 0.5)
            }
            .frame(height: height)
        }
        .buttonStyle(PressScale())
    }
}

/// On/Off toggle using the Figma switch artwork.
struct ArtToggle: View {
    let title: String
    @Binding var isOn: Bool
    var height: CGFloat = 34
    var onChange: (() -> Void)?

    var body: some View {
        Button {
            isOn.toggle()
            onChange?()
        } label: {
            ZStack {
                if isOn {
                    ArtImage(.toggleOn) { fallback(on: true) }
                } else {
                    ArtImage(.toggleOff) { fallback(on: false) }
                }
            }
            .frame(width: height * 363 / 158, height: height)
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }

    private func fallback(on: Bool) -> some View {
        ZStack(alignment: on ? .trailing : .leading) {
            GoldRimCapsule(fill: on ? [Color(red: 0.4, green: 0.9, blue: 0.3), Palette.green] : [Color(white: 0.35), Color(white: 0.15)])
            Circle().fill(Palette.goldGradient).padding(3)
            Text(on ? "On" : "Off")
                .font(.game(height * 0.45))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: on ? .leading : .trailing)
                .padding(.horizontal, height * 0.35)
        }
    }
}

/// Gold title text, standing in for the raster "SETTINGS"-style titles on screens Figma has no art for.
struct GoldTitle: View {
    let text: String
    var size: CGFloat

    var body: some View {
        OutlinedText(text: text.uppercased(), size: size, gradient: Palette.goldGradient)
            .shadow(color: Palette.amber.opacity(0.6), radius: size * 0.2)
    }
}
