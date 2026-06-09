import StoreKit
import SwiftUI

@MainActor
final class TipStore: ObservableObject {
    // Must match the product ID you create in App Store Connect
    static let productID = "bec.support"

    @Published var product: Product?
    @Published var isPurchasing = false
    @Published var purchased = false

    init() {
        Task { await load() }
    }

    func load() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        guard let result = try? await product.purchase() else { return }
        if case .success = result {
            withAnimation { purchased = true }
        }
    }
}
