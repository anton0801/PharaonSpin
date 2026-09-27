/// Slot symbols ordered by value: `s1` is the lowest paying symbol, `s9` the highest.
/// Both themes (Egypt and Fruit) share this ranking; only the artwork differs.
public enum SlotSymbol: Int, CaseIterable, Codable, Sendable {
    case s1 = 1, s2, s3, s4, s5, s6, s7, s8, s9
    /// Substitutes for every symbol except `scatter`. Has no pay of its own.
    case wild
    /// Pays anywhere on screen and triggers free spins.
    case scatter

    public static let paying: [SlotSymbol] = [.s1, .s2, .s3, .s4, .s5, .s6, .s7, .s8, .s9]

    public var isPaying: Bool { rawValue <= SlotSymbol.s9.rawValue }
}
