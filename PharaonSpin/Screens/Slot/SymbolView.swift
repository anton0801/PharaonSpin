import SlotCore
import SwiftUI

/// One reel symbol. WILD and SCATTER have no Figma art yet: they are drawn in code until
/// `egypt_wild`, `egypt_scatter`, `fruit_wild` and `fruit_scatter` image sets are added.
/// Their labels are always added in code, as the brief asks.
struct SymbolView: View {
    let theme: SlotTheme
    let symbol: SlotSymbol

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                ArtImage(theme.art(for: symbol)) {
                    switch symbol {
                    case .wild: WildArt(theme: theme)
                    case .scatter: ScatterArt(theme: theme)
                    default: PlainSymbolFallback(theme: theme, symbol: symbol)
                    }
                }
                if symbol == .wild || symbol == .scatter {
                    SymbolLabel(text: symbol == .wild ? "WILD" : "SCATTER", side: side)
                        .offset(y: side * 0.36)
                }
            }
            .frame(width: side, height: side)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityLabel(theme.name(of: symbol))
    }
}

private struct SymbolLabel: View {
    let text: String
    let side: CGFloat

    var body: some View {
        Text(text)
            .font(.game(side * (text.count > 4 ? 0.17 : 0.22)))
            .foregroundStyle(Palette.goldGradient)
            .shadow(color: .black, radius: 0, x: 0, y: 1.5)
            .shadow(color: .black.opacity(0.9), radius: 1.5)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: side * 1.05)
    }
}

/// Egypt: golden scarab in a turquoise gem frame. Fruit: golden star with a rainbow rim.
private struct WildArt: View {
    let theme: SlotTheme

    var body: some View {
        GeometryReader { geometry in
            let s = geometry.size.width
            ZStack {
                if theme == .egypt {
                    RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                        .fill(Palette.goldGradient)
                        .rotationEffect(.degrees(45))
                        .padding(s * 0.12)
                    RoundedRectangle(cornerRadius: s * 0.14, style: .continuous)
                        .fill(RadialGradient(colors: [Color(red: 0.4, green: 1, blue: 0.95), Color(red: 0, green: 0.55, blue: 0.6)],
                                             center: .topLeading, startRadius: 2, endRadius: s * 0.7))
                        .rotationEffect(.degrees(45))
                        .padding(s * 0.19)
                    Image(systemName: "ladybug.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Palette.goldGradient)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        .padding(s * 0.3)
                } else {
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center))
                        .padding(s * 0.04)
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Palette.goldGradient)
                        .padding(s * 0.13)
                    Image(systemName: "sparkle")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                        .frame(width: s * 0.2)
                        .offset(x: -s * 0.12, y: -s * 0.1)
                }
            }
            .shadow(color: (theme == .egypt ? Color.cyan : Color.yellow).opacity(0.6), radius: s * 0.08)
        }
    }
}

/// Egypt: golden pyramid with the eye of Horus and rays. Fruit: glowing bell with cherries.
private struct ScatterArt: View {
    let theme: SlotTheme

    var body: some View {
        GeometryReader { geometry in
            let s = geometry.size.width
            ZStack {
                ForEach(0..<12, id: \.self) { ray in
                    Capsule()
                        .fill(Palette.goldLight.opacity(0.55))
                        .frame(width: s * 0.04, height: s * 0.48)
                        .offset(y: -s * 0.24)
                        .rotationEffect(.degrees(Double(ray) * 30))
                }
                if theme == .egypt {
                    Triangle()
                        .fill(Palette.goldGradient)
                        .overlay(Triangle().stroke(Palette.goldDark, lineWidth: s * 0.025))
                        .frame(width: s * 0.78, height: s * 0.66)
                        .offset(y: s * 0.02)
                    Image(systemName: "eye.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.7))
                        .frame(width: s * 0.3)
                        .offset(y: s * 0.1)
                } else {
                    Image(systemName: "bell.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Palette.goldGradient)
                        .padding(s * 0.16)
                    HStack(spacing: s * 0.02) {
                        Circle().fill(RadialGradient(colors: [Color(red: 1, green: 0.4, blue: 0.4), Color(red: 0.7, green: 0, blue: 0.05)], center: .topLeading, startRadius: 1, endRadius: s * 0.15))
                        Circle().fill(RadialGradient(colors: [Color(red: 1, green: 0.4, blue: 0.4), Color(red: 0.7, green: 0, blue: 0.05)], center: .topLeading, startRadius: 1, endRadius: s * 0.15))
                    }
                    .frame(width: s * 0.38, height: s * 0.18)
                    .offset(x: s * 0.18, y: s * 0.22)
                }
            }
            .shadow(color: Palette.gold.opacity(0.7), radius: s * 0.08)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// Stand-in for a Figma symbol that has not been exported yet.
private struct PlainSymbolFallback: View {
    let theme: SlotTheme
    let symbol: SlotSymbol

    private var systemName: String {
        let egypt = ["leaf.fill", "key.fill", "eye.fill", "scroll.fill", "cylinder.fill", "triangle.fill", "ladybug.fill", "pawprint.fill", "crown.fill"]
        let fruit = ["circle.fill", "oval.fill", "circle.circle.fill", "heart.fill", "circle.grid.3x3.fill", "drop.fill", "bell.fill", "rectangle.fill", "7.circle.fill"]
        return (theme == .egypt ? egypt : fruit)[symbol.rawValue - 1]
    }

    var body: some View {
        GeometryReader { geometry in
            let s = geometry.size.width
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(symbol.rawValue >= 7 ? AnyShapeStyle(Palette.goldGradient)
                                 : AnyShapeStyle(LinearGradient(colors: [.white, Color(hue: Double(symbol.rawValue) / 9, saturation: 0.7, brightness: 1)], startPoint: .top, endPoint: .bottom)))
                .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
                .padding(s * 0.14)
        }
    }
}
