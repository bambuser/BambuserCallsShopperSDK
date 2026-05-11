//
//  ProductsListView.swift
//  BambuserCallsShopperDemo
//

import SwiftUI

struct ProductsListView: View {
    @EnvironmentObject private var navigation: NavigationCoordinator

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack(path: navigation.productsPathBinding) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(ProductCatalog.all) { product in
                        NavigationLink(value: product.id) {
                            ProductCard(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
            .navigationTitle("Products")
            .navigationDestination(for: String.self) { sku in
                if let product = ProductCatalog.product(for: sku) {
                    ProductDetailView(product: product)
                        .id(sku)
                } else {
                    Text("Unknown product")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ProductCard: View {
    let product: DemoProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: product.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .empty:
                    Color(.secondarySystemBackground)
                        .overlay(ProgressView())
                case .failure:
                    Color(.secondarySystemBackground)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.tertiary)
                        )
                @unknown default:
                    Color(.secondarySystemBackground)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(product.brand.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .kerning(1)
                Text(product.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(product.price, format: .currency(code: product.currency))
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
        }
    }
}
