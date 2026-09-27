import SwiftUI

enum Palette {
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.2)
    static let goldLight = Color(red: 1.0, green: 0.93, blue: 0.55)
    static let goldDark = Color(red: 0.72, green: 0.42, blue: 0.05)
    static let amber = Color(red: 1.0, green: 0.62, blue: 0.1)
    static let plate = Color(red: 0.09, green: 0.07, blue: 0.08)
    static let royalBlue = Color(red: 0.05, green: 0.36, blue: 0.9)
    static let skyBlue = Color(red: 0.25, green: 0.62, blue: 1.0)
    static let spinRed = Color(red: 0.9, green: 0.05, blue: 0.1)
    static let green = Color(red: 0.12, green: 0.72, blue: 0.2)

    static let goldGradient = LinearGradient(
        colors: [goldLight, gold, amber, goldDark],
        startPoint: .top, endPoint: .bottom
    )
}

extension Font {
    /// The chunky rounded face used for every number and label in the game UI.
    static func game(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

enum Coins {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func format(_ value: Int) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// 1,250,000 → "1.25M" for tight spots such as bet chips.
    static func short(_ value: Int) -> String {
        switch value {
        case 1_000_000...:
            let millions = Double(value) / 1_000_000
            return (millions == millions.rounded() ? String(Int(millions)) : String(format: "%.2g", millions)) + "M"
        case 1_000...:
            let thousands = Double(value) / 1_000
            return (thousands == thousands.rounded() ? String(Int(thousands)) : String(format: "%.3g", thousands)) + "K"
        default:
            return "\(value)"
        }
    }
}

enum Countdown {
    static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// White heavy text with a dark outline and drop shadow, as on the Figma plates.
struct OutlinedText: View {
    let text: String
    var size: CGFloat
    var color: Color = .white
    var gradient: LinearGradient?

    var body: some View {
        let label = Text(text).font(.game(size)).lineLimit(1).minimumScaleFactor(0.4)
        ZStack {
            label.foregroundColor(Color.black.opacity(0.55)).offset(y: size * 0.08)
            if let gradient {
                label.foregroundColor(.clear).overlay(gradient.mask(label))
            } else {
                label.foregroundColor(color)
            }
        }
    }
}
