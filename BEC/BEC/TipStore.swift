import StoreKit
import SwiftUI

@MainActor
final class TipStore: ObservableObject {
    // Must match the product ID you create in App Store Connect
    static let productID = "bec.support"

    @Published var product: Product?
    @Published var isPurchasing = false
    @Published var purchased = false
    @Published var loadFailed = false
    @Published var purchaseError: String?

    init() {
        Task { await load() }
    }

    func load() async {
        loadFailed = false
        // StoreKit's connection to the App Store can take a moment to come up,
        // especially right after a fresh install — retry before giving up so the
        // row doesn't get stuck on "Loading…" and become permanently disabled.
        for attempt in 0..<4 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            }
            if let found = try? await Product.products(for: [Self.productID]).first {
                product = found
                return
            }
        }
        loadFailed = true
    }

    func purchase() async {
        if loadFailed {
            await load()
            return
        }
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                withAnimation { purchased = true }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Waiting for approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Something went wrong. Try again."
        }
    }
}
