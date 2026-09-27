/// Pay multipliers. Line pays multiply the line bet (total bet ÷ number of lines);
/// scatter pays multiply the total bet.
public struct Paytable: Sendable, Equatable {
    /// `line[symbol.rawValue][count]` — multiplier for `count` of a kind (0 when it does not pay).
    private let line: [[Int]]
    /// `scatter[count]` — multiplier of the total bet for `count` scatters anywhere.
    private let scatter: [Int]

    /// - Parameter line: multipliers for three, four and five of a kind, per symbol.
    public init(line: [SlotSymbol: [Int]], scatter: [Int: Int]) {
        var table = Array(repeating: Array(repeating: 0, count: 6), count: SlotSymbol.scatter.rawValue + 1)
        for (symbol, pays) in line {
            precondition(pays.count == 3, "expected pays for 3, 4 and 5 of a kind")
            table[symbol.rawValue][3] = pays[0]
            table[symbol.rawValue][4] = pays[1]
            table[symbol.rawValue][5] = pays[2]
        }
        self.line = table
        let maxCount = scatter.keys.max() ?? 0
        self.scatter = (0...max(maxCount, 5)).map { scatter[$0] ?? 0 }
    }

    public func lineMultiplier(_ symbol: SlotSymbol, count: Int) -> Int {
        guard count >= 3 else { return 0 }
        return line[symbol.rawValue][min(count, 5)]
    }

    public func scatterMultiplier(count: Int) -> Int {
        guard count >= 0 else { return 0 }
        return scatter[min(count, scatter.count - 1)]
    }

    public static let standard: Paytable = {
        let line: [SlotSymbol: [Int]] = [
            .s1: [5, 15, 40],
            .s2: [5, 15, 40],
            .s3: [8, 20, 60],
            .s4: [10, 30, 80],
            .s5: [12, 40, 100],
            .s6: [15, 50, 150],
            .s7: [25, 80, 250],
            .s8: [40, 150, 500],
            .s9: [60, 250, 1000],
        ]
        let scatter: [Int: Int] = [3: 2, 4: 10, 5: 50]
        return Paytable(line: line, scatter: scatter)
    }()
}

public struct FreeSpinRules: Sendable, Equatable {
    /// Scatters needed anywhere on screen to award free spins.
    public let triggerCount: Int
    /// Spins awarded when triggered from the base game.
    public let initialSpins: Int
    /// Spins added when triggered again during free spins.
    public let retriggerSpins: Int
    /// Every win during free spins is multiplied by this.
    public let winMultiplier: Int

    public init(triggerCount: Int, initialSpins: Int, retriggerSpins: Int, winMultiplier: Int) {
        self.triggerCount = triggerCount
        self.initialSpins = initialSpins
        self.retriggerSpins = retriggerSpins
        self.winMultiplier = winMultiplier
    }

    public static let standard = FreeSpinRules(triggerCount: 3, initialSpins: 10, retriggerSpins: 5, winMultiplier: 2)
}

/// Twenty fixed paylines. Each entry is the row (0 top, 1 middle, 2 bottom) on reels 1…5.
///
/// The spec lists `0 1 1 1 0` twice (L10 and L13); L10 is replaced with the unused
/// `1 0 1 0 1` so all twenty lines are distinct. Every line has the same symbol
/// distribution, so this does not change the RTP.
public enum Paylines {
    public static let standard: [[Int]] = [
        [1, 1, 1, 1, 1], // L1
        [0, 0, 0, 0, 0], // L2
        [2, 2, 2, 2, 2], // L3
        [0, 1, 2, 1, 0], // L4
        [2, 1, 0, 1, 2], // L5
        [0, 0, 1, 2, 2], // L6
        [2, 2, 1, 0, 0], // L7
        [1, 0, 0, 0, 1], // L8
        [1, 2, 2, 2, 1], // L9
        [1, 0, 1, 0, 1], // L10
        [1, 0, 1, 2, 1], // L11
        [1, 2, 1, 0, 1], // L12
        [0, 1, 1, 1, 0], // L13
        [2, 1, 1, 1, 2], // L14
        [0, 1, 0, 1, 0], // L15
        [2, 1, 2, 1, 2], // L16
        [1, 1, 0, 1, 1], // L17
        [1, 1, 2, 1, 1], // L18
        [0, 0, 2, 0, 0], // L19
        [2, 2, 0, 2, 2], // L20
    ]
}

/// Reel strips, shuffled once during development and frozen here.
///
/// Composition per reel (count on the 40-stop strip):
///
/// | Symbol  | R1 | R2 | R3 | R4 | R5 |
/// |---------|----|----|----|----|----|
/// | S1      |  3 |  3 |  3 |  3 |  3 |
/// | S2      |  4 |  2 |  2 |  2 |  4 |
/// | S3      | 12 | 14 | 14 | 14 | 12 |
/// | S4      |  5 |  5 |  5 |  5 |  5 |
/// | S5      |  5 |  4 |  4 |  4 |  5 |
/// | S6      |  4 |  4 |  4 |  4 |  4 |
/// | S7      |  3 |  3 |  3 |  3 |  3 |
/// | S8      |  2 |  2 |  2 |  2 |  2 |
/// | S9      |  1 |  1 |  1 |  1 |  1 |
/// | WILD    |  0 |  1 |  1 |  1 |  0 |
/// | SCATTER |  1 |  1 |  1 |  1 |  1 |
///
/// S4–S9, WILD and SCATTER are exactly as specified. The specified S1–S3 counts (7/6/6)
/// gave an RTP of about 31.8%, so per the spec only S1–S3 were redistributed (the 19 stops
/// they share are unchanged) until the simulated RTP landed inside 93–96%.
/// No symbol appears more than twice in a row, including across the wrap-around.
public enum ReelStrips {
    public static let standard: [[SlotSymbol]] = [
        // Reel 1
        [.scatter, .s1, .s2, .s1, .s3, .s4, .s2, .s2, .s3, .s2,
         .s3, .s7, .s5, .s8, .s5, .s3, .s7, .s1, .s6, .s4,
         .s4, .s6, .s3, .s4, .s3, .s6, .s8, .s5, .s5, .s3,
         .s3, .s5, .s3, .s3, .s4, .s3, .s6, .s3, .s9, .s7],
        // Reel 2
        [.s4, .s6, .s3, .s6, .wild, .s7, .s4, .s3, .s3, .s8,
         .s3, .s3, .s8, .s4, .s5, .s5, .s1, .s3, .s3, .s5,
         .s2, .s3, .s3, .s4, .s5, .s3, .scatter, .s4, .s1, .s6,
         .s9, .s6, .s3, .s3, .s2, .s3, .s7, .s1, .s3, .s7],
        // Reel 3
        [.s1, .scatter, .s3, .s7, .s3, .s7, .s9, .s4, .s4, .s3,
         .s8, .s3, .wild, .s3, .s3, .s1, .s3, .s3, .s5, .s3,
         .s4, .s8, .s3, .s5, .s6, .s2, .s4, .s5, .s6, .s7,
         .s2, .s1, .s6, .s3, .s4, .s3, .s3, .s5, .s3, .s6],
        // Reel 4
        [.s3, .s5, .s5, .s8, .s3, .s7, .wild, .s4, .s7, .s6,
         .s3, .s3, .s6, .s3, .s3, .s7, .s3, .s9, .s4, .s1,
         .s1, .s3, .scatter, .s3, .s1, .s6, .s6, .s3, .s4, .s5,
         .s4, .s3, .s3, .s5, .s4, .s3, .s3, .s8, .s2, .s2],
        // Reel 5
        [.s5, .s1, .s3, .s3, .s8, .s3, .s7, .s8, .s6, .s1,
         .s3, .s6, .s5, .s2, .s2, .s3, .s2, .s7, .s4, .s5,
         .s3, .s1, .s3, .s4, .s2, .s5, .s7, .s9, .s3, .s4,
         .s3, .s3, .scatter, .s3, .s6, .s3, .s6, .s4, .s4, .s5],
    ]
}
