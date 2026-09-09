//
//  CartView.swift
//  BambuserCallsShopperDemo
//

import SwiftUI

struct CartView: View {
    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var bambuserSDKHolder: BambuserSDKHolder

    @State private var isCheckingOut = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if cart.orderedLines.isEmpty {
                    emptyState
                } else {
                    contentList
                }
            }
            .navigationTitle("Cart")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Thanks for your order!", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your purchase was tracked.")
            }
            .alert(
                "Purchase tracking failed",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("Your cart is empty.")
                .font(.headline)
            Text("Add items from the Products tab or via the expert call.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentList: some View {
        List {
            Section {
                ForEach(cart.orderedLines, id: \.product.id) { line in
                    CartLineRow(product: line.product, quantity: line.quantity)
                        .environmentObject(cart)
                }
                .onDelete { offsets in
                    let skus = offsets.map { cart.orderedLines[$0].product.id }
                    skus.forEach { cart.remove(sku: $0) }
                }
            }

            Section {
                HStack {
                    Text("Subtotal")
                        .font(.headline)
                    Spacer()
                    Text(cart.subtotal, format: .currency(code: cart.currency))
                        .font(.headline)
                        .monospacedDigit()
                }

                Button {
                    completePurchase()
                } label: {
                    HStack {
                        if isCheckingOut {
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("Completing purchase…")
                        } else {
                            Label("Complete purchase", systemImage: "creditcard")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCheckingOut || cart.orderedLines.isEmpty)

                Button {
                    cart.clear()
                } label: {
                    Label("Empty cart", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .disabled(isCheckingOut)
            }
        }
    }

    private func completePurchase() {
        let lines = cart.orderedLines
        guard !lines.isEmpty else { return }

        let subtotal = lines.reduce(0.0) { $0 + $1.product.price * Double($1.quantity) }
        let currency = lines.first?.product.currency ?? "USD"
        let transaction: [String: Sendable] = [
            "id": UUID().uuidString,
            "currency": currency,
            "subtotal": subtotal,
            "total": subtotal,
            "tax": 0.0,
            "shippingCost": 0.0,
        ]
        let products: [[String: Sendable]] = lines.map { line in
            var entry: [String: Sendable] = [
                "id": line.product.id,
                "name": line.product.name,
                "price": line.product.price,
                "currency": line.product.currency,
                "quantity": line.quantity,
            ]
            if !line.product.brand.isEmpty {
                entry["brand"] = line.product.brand
            }
            if !line.product.category.isEmpty {
                entry["category"] = line.product.category
            }
            return entry
        }

        isCheckingOut = true
        let sdk = bambuserSDKHolder.sdk
        Task {
            do {
                _ = try await sdk.track(
                    event: "purchase",
                    with: [
                        "transaction": transaction,
                        "products": products,
                    ]
                )
                isCheckingOut = false
                cart.clear()
                showSuccess = true
            } catch {
                isCheckingOut = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct CartLineRow: View {
    let product: DemoProduct
    let quantity: Int
    @EnvironmentObject private var cart: CartStore

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: product.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(product.price, format: .currency(code: product.currency))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Stepper(
                value: Binding(
                    get: { quantity },
                    set: { cart.setQuantity($0, for: product.id) }
                ),
                in: 0...99
            ) {
                Text("\(quantity)")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .frame(minWidth: 24, alignment: .trailing)
            }
            .labelsHidden()
            .fixedSize()
        }
        .padding(.vertical, 4)
    }
}
