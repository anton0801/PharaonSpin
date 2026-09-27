import Foundation
import SlotCore

/// xoshiro256++ seeded through splitmix64. Tests only — production always uses `SystemRandomSource`.
final class SeededRandomSource: RandomSource {
    private var s0: UInt64
    private var s1: UInt64
    private var s2: UInt64
    private var s3: UInt64

    init(seed: UInt64) {
        var x = seed
        func splitmix() -> UInt64 {
            x &+= 0x9E37_79B9_7F4A_7C15
            var z = x
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        s0 = splitmix()
        s1 = splitmix()
        s2 = splitmix()
        s3 = splitmix()
    }

    func next() -> UInt64 {
        let result = rotl(s0 &+ s3, 23) &+ s0
        let t = s1 << 17
        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3
        s2 ^= t
        s3 = rotl(s3, 45)
        return result
    }

    private func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 {
        (x << k) | (x >> (64 - k))
    }
}

/// Replays values chosen so that `uniform(n)` returns the queued integers in order.
final class ScriptedRandomSource: RandomSource {
    private var queue: [(value: Int, bound: Int)]

    /// Each pair is the integer `uniform(bound)` must return next.
    init(_ values: [(Int, Int)]) {
        queue = values.map { (value: $0.0, bound: $0.1) }
    }

    func next() -> UInt64 {
        precondition(!queue.isEmpty, "scripted source exhausted")
        let (value, bound) = queue.removeFirst()
        // uniform() takes the high 64 bits of next() × bound; aim at the middle of the bucket.
        let bucket = (Double(value) + 0.5) / Double(bound)
        return UInt64(bucket * 18_446_744_073_709_551_615.0)
    }
}

enum Statistics {
    /// Upper tail of the chi-square distribution: P(X ≥ x) for `degrees` degrees of freedom.
    static func chiSquarePValue(_ x: Double, degrees: Int) -> Double {
        regularizedGammaQ(Double(degrees) / 2, x / 2)
    }

    /// Two-sample chi-square test of homogeneity; returns (statistic, degrees of freedom).
    static func chiSquareHomogeneity(_ a: [Int], _ b: [Int]) -> (Double, Int) {
        precondition(a.count == b.count)
        let totalA = Double(a.reduce(0, +))
        let totalB = Double(b.reduce(0, +))
        let total = totalA + totalB
        var statistic = 0.0
        var used = 0
        for i in a.indices {
            let column = Double(a[i] + b[i])
            guard column > 0 else { continue }
            used += 1
            let expectedA = column * totalA / total
            let expectedB = column * totalB / total
            statistic += pow(Double(a[i]) - expectedA, 2) / expectedA
            statistic += pow(Double(b[i]) - expectedB, 2) / expectedB
        }
        return (statistic, used - 1)
    }

    private static func regularizedGammaQ(_ a: Double, _ x: Double) -> Double {
        if x <= 0 { return 1 }
        if x < a + 1 {
            // Series for P(a, x).
            var sum = 1 / a
            var term = sum
            var n = a
            for _ in 0..<1000 {
                n += 1
                term *= x / n
                sum += term
                if abs(term) < abs(sum) * 1e-15 { break }
            }
            let p = sum * exp(-x + a * log(x) - lgamma(a))
            return 1 - p
        }
        // Continued fraction for Q(a, x) (Lentz).
        let tiny = 1e-300
        var b = x + 1 - a
        var c = 1 / tiny
        var d = 1 / b
        var h = d
        for i in 1..<1000 {
            let an = -Double(i) * (Double(i) - a)
            b += 2
            d = an * d + b
            if abs(d) < tiny { d = tiny }
            c = b + an / c
            if abs(c) < tiny { c = tiny }
            d = 1 / d
            let delta = d * c
            h *= delta
            if abs(delta - 1) < 1e-15 { break }
        }
        return exp(-x + a * log(x) - lgamma(a)) * h
    }
}
