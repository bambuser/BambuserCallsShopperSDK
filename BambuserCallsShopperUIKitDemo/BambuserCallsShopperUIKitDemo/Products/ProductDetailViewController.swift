//
//  ProductDetailViewController.swift
//  BambuserCallsShopperUIKitDemo
//
//  PDP with hero image, name/price/description, "Add to cart" and
//  "Talk to expert" buttons. Echoes the navigation back to the embed
//  via `notifyProductNavigation` on viewDidAppear so the widget stays
//  in sync when the shopper reaches a product page from any tap.
//

import UIKit
import BambuserCallsShopper

final class ProductDetailViewController: UIViewController {

    let product: DemoProduct
    private let cart: CartStore
    private let bambuserCall: BambuserCallController
    private let bambuserSDK: BambuserShopperSDK

    private let scrollView   = UIScrollView()
    private let container    = UIStackView()
    private let imageView    = UIImageView()
    private let addToCartBtn = UIButton(configuration: .filled())
    private let expertBtn    = UIButton(configuration: .bordered())

    init(
        product: DemoProduct,
        cart: CartStore,
        bambuserCall: BambuserCallController,
        bambuserSDK: BambuserShopperSDK
    ) {
        self.product = product
        self.cart = cart
        self.bambuserCall = bambuserCall
        self.bambuserSDK = bambuserSDK
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = product.name
        setupUI()
        refreshAddToCartButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Keep the embed in lock-step with the app's product page.
        bambuserCall.notifyProductNavigation(externalId: product.id)
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        container.axis = .vertical
        container.spacing = 16
        container.isLayoutMarginsRelativeArrangement = true
        container.directionalLayoutMargins = .init(top: 16, leading: 16, bottom: 24, trailing: 16)
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            container.topAnchor.constraint(equalTo: scrollView.topAnchor),
            container.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // Hero.
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 14
        imageView.backgroundColor = .secondarySystemBackground
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 1 / 1.1),
        ])
        loadImage(product.imageURL)

        // Text block.
        let brand = UILabel()
        brand.text = product.brand.uppercased()
        brand.font = .preferredFont(forTextStyle: .caption1)
        brand.textColor = .secondaryLabel

        let name = UILabel()
        name.text = product.name
        name.font = .preferredFont(forTextStyle: .title2)
        name.numberOfLines = 0

        let price = UILabel()
        price.text = String(format: "$%.2f", product.price)
        price.font = .preferredFont(forTextStyle: .headline)

        let desc = UILabel()
        desc.text = product.description
        desc.font = .preferredFont(forTextStyle: .body)
        desc.textColor = .secondaryLabel
        desc.numberOfLines = 0

        [brand, name, price, desc].forEach { container.addArrangedSubview($0) }

        // Buttons.
        addToCartBtn.addTarget(self, action: #selector(addToCart), for: .touchUpInside)
        expertBtn.setTitle("Talk to expert", for: .normal)
        expertBtn.setImage(UIImage(systemName: "person.crop.circle.badge"), for: .normal)
        expertBtn.addTarget(self, action: #selector(talkToExpert), for: .touchUpInside)

        [addToCartBtn, expertBtn].forEach { container.addArrangedSubview($0) }
    }

    private func loadImage(_ url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { self?.imageView.image = image }
        }.resume()
    }

    private func refreshAddToCartButton() {
        let inCart = cart.quantity(for: product.id) > 0
        addToCartBtn.setTitle(inCart ? "  Added to Cart" : "  Add to Cart", for: .normal)
        addToCartBtn.setImage(
            UIImage(systemName: inCart ? "checkmark" : "cart"),
            for: .normal
        )
    }

    @objc private func addToCart() {
        cart.add(sku: product.id, quantity: 1)
        refreshAddToCartButton()

        // Fire-and-forget shopper tracking. `track(...)` no-ops silently
        // when no valid LCTE region exists, so it's safe to call even
        // outside an active call flow.
        let sdk = bambuserSDK
        let product = product
        Task {
            try? await sdk.track(
                event: "add-to-cart",
                with: [
                    "products": [[
                        "id": product.id,
                        "name": product.name,
                        "price": product.price,
                        "currency": product.currency,
                        "quantity": 1,
                    ]]
                ]
            )
        }
    }

    @objc private func talkToExpert() {
        guard DemoConfiguration.isConfigured else {
            let alert = UIAlertController(
                title: "Bambuser credentials missing",
                message: "Set DemoConfiguration.orgId before starting an expert call.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
            return
        }
        bambuserCall.show()
    }
}
