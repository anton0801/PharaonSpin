/// A source of uniformly distributed random bits.
///
/// Every outcome in SlotCore is drawn through this protocol and nothing else: no clock,
/// balance, spin counter or purchase history is ever passed to the code that picks a result.
public protocol RandomSource: AnyObject {
    func next() -> UInt64
}

extension RandomSource {
    /// Uniform integer in `0..<upperBound`, without modulo bias (Lemire's nearly-divisionless method).
    public func uniform(_ upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive")
        let bound = UInt64(upperBound)
        var product = next().multipliedFullWidth(by: bound)
        if product.low < bound {
            let threshold = (0 &- bound) % bound
            while product.low < threshold {
                product = next().multipliedFullWidth(by: bound)
            }
        }
        return Int(product.high)
    }

    /// Uniform `Double` in `[0, 1)` with 53 bits of precision.
    public func unitInterval() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }
}

/// Production source backed by the operating system's cryptographically secure generator.
public final class SystemRandomSource: RandomSource {
    private var generator = SystemRandomNumberGenerator()

    public init() {}

    public func next() -> UInt64 {
        generator.next()
    }
}
