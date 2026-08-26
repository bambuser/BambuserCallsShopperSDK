//
//  ProductsListViewController.swift
//  BambuserCallsShopperUIKitDemo
//
//  Two-column grid of the demo catalogue. Compositional layout,
//  diffable data source; product tap fires `onProductSelected`
//  which RootTabBarController wires to a push.
//

import UIKit
import BambuserCallsShopper

final class ProductsListViewController: UIViewController {

    private let cart: CartStore
    private let bambuserCall: BambuserCallController

    var onProductSelected: ((DemoProduct) -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!

    init(cart: CartStore, bambuserCall: BambuserCallController) {
        self.cart = cart
        self.bambuserCall = bambuserCall
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCollectionView()
        applySnapshot()
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.5),
                    heightDimension: .fractionalHeight(1.0)
                )
            )
            item.contentInsets = .init(top: 6, leading: 6, bottom: 6, trailing: 6)

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(260)
                ),
                subitems: [item]
            )

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = .init(top: 8, leading: 8, bottom: 8, trailing: 8)
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let cellReg = UICollectionView.CellRegistration<ProductCardCell, String> { cell, _, sku in
            guard let product = ProductCatalog.product(for: sku) else { return }
            cell.configure(with: product)
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) {
            collectionView, indexPath, sku in
            collectionView.dequeueConfiguredReusableCell(
                using: cellReg, for: indexPath, item: sku
            )
        }
    }

    private func applySnapshot() {
        var snap = NSDiffableDataSourceSnapshot<Int, String>()
        snap.appendSections([0])
        snap.appendItems(ProductCatalog.all.map(\.id))
        dataSource.apply(snap, animatingDifferences: false)
    }
}

extension ProductsListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let sku = dataSource.itemIdentifier(for: indexPath),
              let product = ProductCatalog.product(for: sku) else { return }
        onProductSelected?(product)
    }
}

// MARK: - Product card cell

private final class ProductCardCell: UICollectionViewCell {

    private let imageView   = UIImageView()
    private let brandLabel  = UILabel()
    private let nameLabel   = UILabel()
    private let priceLabel  = UILabel()

    private var imageTask: URLSessionDataTask?

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .secondarySystemBackground

        brandLabel.font = .preferredFont(forTextStyle: .caption2)
        brandLabel.textColor = .secondaryLabel

        nameLabel.font = .preferredFont(forTextStyle: .subheadline)
        nameLabel.numberOfLines = 2

        priceLabel.font = .preferredFont(forTextStyle: .footnote)

        let stack = UIStackView(arrangedSubviews: [imageView, brandLabel, nameLabel, priceLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.setCustomSpacing(6, after: imageView)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        imageView.image = nil
    }

    func configure(with product: DemoProduct) {
        brandLabel.text = product.brand.uppercased()
        nameLabel.text  = product.name
        priceLabel.text = String(format: "$%.2f", product.price)
        loadImage(product.imageURL)
    }

    private func loadImage(_ url: URL) {
        imageTask?.cancel()
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { self?.imageView.image = image }
        }
        imageTask?.resume()
    }
}
