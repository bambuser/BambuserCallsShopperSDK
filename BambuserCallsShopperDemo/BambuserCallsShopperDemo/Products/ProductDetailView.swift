//
//  ProductDetailView.swift
//  BambuserCallsShopperDemo
//

import SwiftUI
import BambuserCallsShopper

struct ProductDetailView: View {
    let product: DemoProduct

    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var bambuserCall: BambuserCallController

    @State private var addedToCart = false
    @State private var showSetupAlert = false

    private var images: [URL] {
        [product.imageURL] + product.additionalImages
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                imageStrip

                VStack(alignment: .leading, spacing: 6) {
                    Text(product.brand.uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .kerning(1)
                    Text(product.name)
                        .font(.title2.weight(.semibold))
                    Text(product.price, format: .currency(code: product.currency))
                        .font(.title3.weight(.medium))
                        .monospacedDigit()
                }

                Text(product.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                actions
            }
            .padding()
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: cart.quantity(for: product.id)) { newValue in
            // Reset the "Added to cart" confirmation if the cart line gets
            // cleared elsewhere (e.g. user removed it from the cart tab).
            if newValue == 0 { addedToCart = false }
        }
        .onAppear {
            // If a cart event already added this product, reflect that in
            // the button state on revisit.
            addedToCart = cart.quantity(for: product.id) > 0
            // Tell the embed (if a call is active) that the user is now
            // looking at this product.
            bambuserCall.notifyProductNavigation(externalId: product.id)
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var imageStrip: some View {
        if images.count == 1 {
            heroImage(url: images[0])
        } else {
            TabView {
                ForEach(images, id: \.self) { url in
                    heroImage(url: url)
                }
            }
            .tabViewStyle(.page)
            .frame(height: 320)
        }
    }

    private func heroImage(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .empty:
                Color(.secondarySystemBackground).overlay(ProgressView())
            case .failure:
                Color(.secondarySystemBackground).overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                )
            @unknown default:
                Color(.secondarySystemBackground)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                cart.add(sku: product.id, quantity: 1)
                addedToCart = true
            } label: {
                Label(
                    addedToCart ? "Added to Cart" : "Add to Cart",
                    systemImage: addedToCart ? "checkmark" : "cart.badge.plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                if isBambuserConfigured {
                    bambuserCall.show()
                } else {
                    showSetupAlert = true
                }
            } label: {
                Label("Talk to expert", systemImage: "person.wave.2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .alert("Bambuser credentials missing", isPresented: $showSetupAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Set demoOrgId at the top of BambuserCallsShopperDemoApp.swift before starting an expert call.")
            }
        }
        .padding(.top, 4)
    }
}
