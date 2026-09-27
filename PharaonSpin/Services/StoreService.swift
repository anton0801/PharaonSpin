import Combine
import Foundation
import Network
import StoreKit

/// Watches connectivity. The game itself is fully offline; only the store needs a network.
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "network.monitor"))
    }

    deinit {
        monitor.cancel()
    }
}

/// StoreKit 2 consumable coin packs with on-device verification.
@MainActor
final class StoreService: ObservableObject {
    enum LoadState: Equatable {
        case idle, loading, loaded, failed
    }

    enum PurchaseResult {
        case success(coins: Int), cancelled, pending, failed
    }

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var purchasingID: String?

    /// Called with (transaction id, coins) for every verified coin transaction; returns true once credited.
    var credit: ((UInt64, Int) -> Bool)?

    private var updatesTask: Task<Void, Never>?

    func start() {
        guard AppConfig.storeEnabled, updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await processUnfinished() }
    }

    func loadProducts() async {
        guard AppConfig.storeEnabled, loadState != .loading else { return }
        loadState = .loading
        do {
            let loaded = try await Product.products(for: AppConfig.coinPacks.map(\.id))
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            loadState = loaded.isEmpty ? .failed : .loaded
        } catch {
            loadState = .failed
        }
    }

    func purchase(_ pack: CoinPack) async -> PurchaseResult {
        guard let product = products[pack.id] else { return .failed }
        purchasingID = pack.id
        defer { purchasingID = nil }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return .failed }
                let coins = coinsFor(productID: transaction.productID)
                _ = credit?(transaction.id, coins)
                await transaction.finish()
                return .success(coins: coins)
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Re-syncs with the App Store. Only offered when non-consumables exist.
    func restore() async {
        try? await AppStore.sync()
    }

    private func processUnfinished() async {
        for await result in Transaction.unfinished {
            await handle(result)
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        // Unverified transactions are never credited.
        guard case .verified(let transaction) = result else { return }
        if transaction.revocationDate == nil {
            _ = credit?(transaction.id, coinsFor(productID: transaction.productID))
        }
        await transaction.finish()
    }

    private func coinsFor(productID: String) -> Int {
        AppConfig.coinPacks.first { $0.id == productID }?.coins ?? 0
    }
}
