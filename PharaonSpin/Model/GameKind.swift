import SlotCore
import SwiftUI

enum GameKind: String, Codable, CaseIterable, Identifiable {
    case egypt, fruit, wheel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .egypt: return "Pharaoh Reels"
        case .fruit: return "Fruit Fiesta"
        case .wheel: return "Fortune Wheel"
        }
    }

    var slotTheme: SlotTheme? {
        switch self {
        case .egypt: return .egypt
        case .fruit: return .fruit
        case .wheel: return nil
        }
    }

    var menuEmblem: ArtName {
        switch self {
        case .egypt: return .menuEmblemEgypt
        case .fruit: return .menuEmblemFruit
        case .wheel: return .menuEmblemWheel
        }
    }

    var background: ArtName {
        switch self {
        case .egypt: return .bgEgypt
        case .fruit: return .bgFruit
        case .wheel: return .bgWheel
        }
    }

    /// Fallback tint while the Figma art is missing.
    var accent: Color {
        switch self {
        case .egypt: return Palette.royalBlue
        case .fruit: return Color(red: 0.95, green: 0.45, blue: 0.05)
        case .wheel: return Palette.green
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .egypt: return [Color(red: 0.55, green: 0.4, blue: 0.1), Color(red: 0.25, green: 0.15, blue: 0.05)]
        case .fruit: return [Color(red: 0.4, green: 0.15, blue: 0.55), Color(red: 0.15, green: 0.05, blue: 0.3)]
        case .wheel: return [Color(red: 0.55, green: 0.1, blue: 0.08), Color(red: 0.25, green: 0.03, blue: 0.05)]
        }
    }
}

enum SlotTheme: String, Codable {
    case egypt, fruit

    var game: GameKind { self == .egypt ? .egypt : .fruit }
    var reelFrame: ArtName { self == .egypt ? .reelFrameEgypt : .reelFrameFruit }
    var reelGlow: ArtName { self == .egypt ? .reelGlowEgypt : .reelGlowFruit }
    var emblem: ArtName { self == .egypt ? .emblemEgypt : .emblemFruit }

    /// Reel window colour behind the symbols (teal for Egypt, green for Fruit), for the fallback frame.
    var windowColor: Color {
        self == .egypt ? Color(red: 0.0, green: 0.55, blue: 0.6) : Color(red: 0.05, green: 0.55, blue: 0.15)
    }

    func art(for symbol: SlotSymbol) -> ArtName {
        switch (self, symbol) {
        case (.egypt, .s1): return .egyptS1
        case (.egypt, .s2): return .egyptS2
        case (.egypt, .s3): return .egyptS3
        case (.egypt, .s4): return .egyptS4
        case (.egypt, .s5): return .egyptS5
        case (.egypt, .s6): return .egyptS6
        case (.egypt, .s7): return .egyptS7
        case (.egypt, .s8): return .egyptS8
        case (.egypt, .s9): return .egyptS9
        case (.egypt, .wild): return .egyptWild
        case (.egypt, .scatter): return .egyptScatter
        case (.fruit, .s1): return .fruitS1
        case (.fruit, .s2): return .fruitS2
        case (.fruit, .s3): return .fruitS3
        case (.fruit, .s4): return .fruitS4
        case (.fruit, .s5): return .fruitS5
        case (.fruit, .s6): return .fruitS6
        case (.fruit, .s7): return .fruitS7
        case (.fruit, .s8): return .fruitS8
        case (.fruit, .s9): return .fruitS9
        case (.fruit, .wild): return .fruitWild
        case (.fruit, .scatter): return .fruitScatter
        }
    }

    /// Accessibility name for each symbol.
    func name(of symbol: SlotSymbol) -> String {
        switch (self, symbol) {
        case (_, .wild): return "Wild"
        case (_, .scatter): return "Scatter"
        case (.egypt, _): return ["Lotus", "Ankh", "Eye of Horus", "Scroll", "Canopic Jar", "Pyramid", "Scarab", "Anubis", "Pharaoh Mask"][symbol.rawValue - 1]
        case (.fruit, _): return ["Cherry", "Lemon", "Orange", "Strawberry", "Grapes", "Watermelon", "Bell", "Gold Bar", "Seven"][symbol.rawValue - 1]
        }
    }
}
