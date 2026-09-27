import StoreKit
import SwiftUI

/// Coin store. Opened only from the Store button — never automatically, never after a loss.
/// Offline, the Figma "No Internet" screen replaces the shelf; the games themselves work offline.
struct StoreView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var network: NetworkMonitor

    @State private var message: String?

    var body: some View {
        Group {
            if !network.isOnline {
                OfflineStoreView(close: close)
            } else {
                shelf
            }
        }
        .task(id: network.isOnline) {
            if network.isOnline, store.loadState != .loaded { await store.loadProducts() }
        }
    }

    private var shelf: some View {
        ModalPanel(title: "Store", width: (310, 600), dismiss: close) { m in
            VStack(spacing: m(10)) {
                BalancePlate(balance: model.displayedBalance, now: model.now)
                    .frame(width: m(180), height: m(39.5))

                switch store.loadState {
                case .loaded:
                    let columns = m.isLandscape ? [GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: m(8)) {
                        ForEach(AppConfig.coinPacks) { pack in
                            packRow(pack, m)
                        }
                    }
                case .failed:
                    PanelText(text: "The store is unavailable right now.", size: m(14))
                    BarButton(title: "Try Again", style: .blue, height: m(38)) {
                        Task { await store.loadProducts() }
                    }
                    .frame(width: m(170))
                default:
                    ProgressView()
                        .tint(Palette.gold)
                        .frame(height: m(120))
                }

                if let message {
                    PanelText(text: message, size: m(12), color: Palette.goldLight)
                }

                PanelText(text: "Coins are for entertainment only and have no cash value.", size: m(10), weight: .medium, color: .white.opacity(0.7))
                    .padding(.top, m(2))
            }
        }
    }

    private func packRow(_ pack: CoinPack, _ m: CanvasMetrics) -> some View {
        HStack(spacing: m(8)) {
            VStack(alignment: .leading, spacing: m(1)) {
                Text(pack.name.uppercased())
                    .font(.game(m(11), .bold))
                    .foregroundColor(.white.opacity(0.85))
                Text(Coins.format(pack.coins))
                    .font(.game(m(17)))
                    .foregroundColor(Palette.amber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("coins")
                    .font(.game(m(9), .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer(minLength: m(4))
            let product = store.products[pack.id]
            BarButton(title: store.purchasingID == pack.id ? "…" : product?.displayPrice ?? "—", style: .green, height: m(36)) {
                buy(pack)
            }
            .frame(width: m(96))
            .disabled(product == nil || store.purchasingID != nil)
            .accessibilityLabel("Buy \(Coins.format(pack.coins)) coins for \(product?.displayPrice ?? "")")
        }
        .padding(.horizontal, m(14))
        .padding(.vertical, m(7))
        .background(ArtImage(.plateBet, capInsets: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)) { DarkPlate() })
    }

    private func buy(_ pack: CoinPack) {
        model.feedback.tap()
        Task {
            switch await store.purchase(pack) {
            case .success(let coins):
                model.feedback.bonus()
                message = "+\(Coins.format(coins)) coins added."
            case .pending:
                message = "Purchase pending approval."
            case .cancelled:
                message = nil
            case .failed:
                message = "The purchase did not complete."
            }
        }
    }

    private func close() {
        model.feedback.tap()
        model.modal = nil
    }
}

/// Figma "No Internet" (4989:232) — shown in place of the store shelf only.
private struct OfflineStoreView: View {
    let close: () -> Void

    var body: some View {
        ZStack {
            BackgroundArt(name: .bgOffline)
            DesignCanvas { m in
                VStack(spacing: m(18)) {
                    PanelText(text: "Please check your internet connection.\nThe store needs to be online —\nevery game works offline.", size: m(15), weight: .medium)
                        .padding(m(26))
                        .frame(width: m(204), height: m(204))
                        .background(PanelBackground())
                    BarButton(title: "Back", style: .blue, height: m(40), action: close)
                        .frame(width: m(150))
                }
                .frame(width: m(m.designSize.width), height: m(m.designSize.height))
            }
        }
    }
}
