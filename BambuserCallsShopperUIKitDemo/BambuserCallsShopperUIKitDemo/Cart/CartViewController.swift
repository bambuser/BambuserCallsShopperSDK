//
//  CartViewController.swift
//  BambuserCallsShopperUIKitDemo
//
//  Table view of cart lines with per-row +/- steppers and a subtotal
//  footer. Observes CartStore via Combine so mutations from the SDK
//  (`shouldAddToCart` / `shouldUpdateCart`) reflect live.
//

import UIKit
import Combine

final class CartViewController: UIViewController {

    private let cart: CartStore

    private let tableView    = UITableView(frame: .zero, style: .plain)
    private let footerView   = UIView()
    private let subtotalLabel = UILabel()
    private let emptyLabel   = UILabel()

    private var lines: [(product: DemoProduct, quantity: Int)] = []
    private var cancellables = Set<AnyCancellable>()

    init(cart: CartStore) {
        self.cart = cart
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()

        cart.$lines
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Empty",
            style: .plain,
            target: self,
            action: #selector(emptyCart)
        )
        navigationItem.rightBarButtonItem?.tintColor = .systemRed
    }

    // MARK: - Setup

    private func setupUI() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.rowHeight = 76
        tableView.separatorInset = .init(top: 0, left: 84, bottom: 0, right: 0)
        tableView.register(CartRowCell.self, forCellReuseIdentifier: "row")
        view.addSubview(tableView)

        emptyLabel.text = "Your cart is empty.\nAdd items from Products or via an expert call."
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        // Subtotal footer.
        subtotalLabel.font = .preferredFont(forTextStyle: .headline)
        subtotalLabel.textAlignment = .right
        let subtotalTitle = UILabel()
        subtotalTitle.text = "Subtotal"
        subtotalTitle.font = .preferredFont(forTextStyle: .headline)

        let row = UIStackView(arrangedSubviews: [subtotalTitle, subtotalLabel])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false

        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.backgroundColor = .secondarySystemBackground
        footerView.addSubview(row)
        view.addSubview(footerView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: footerView.topAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 56),

            row.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
        ])
    }

    // MARK: - Data

    private func reload() {
        lines = cart.orderedLines
        tableView.reloadData()
        emptyLabel.isHidden = !lines.isEmpty
        tableView.isHidden  = lines.isEmpty
        footerView.isHidden = lines.isEmpty
        subtotalLabel.text = String(format: "$%.2f", cart.subtotal)
        navigationItem.rightBarButtonItem?.isEnabled = !lines.isEmpty
    }

    @objc private func emptyCart() {
        cart.clear()
    }
}

// MARK: - Data source

extension CartViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        lines.count
    }

    func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let (product, qty) = lines[indexPath.row]
        let cell = tv.dequeueReusableCell(withIdentifier: "row", for: indexPath) as! CartRowCell
        cell.configure(with: product, quantity: qty) { [weak self] delta in
            self?.cart.setQuantity(qty + delta, for: product.id)
        }
        return cell
    }
}

// MARK: - Row cell

private final class CartRowCell: UITableViewCell {

    private let img       = UIImageView()
    private let title     = UILabel()
    private let price     = UILabel()
    private let qtyLabel  = UILabel()
    private let minusBtn  = UIButton(configuration: .plain())
    private let plusBtn   = UIButton(configuration: .plain())

    private var onQuantityChange: ((Int) -> Void)?
    private var imageTask: URLSessionDataTask?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        img.contentMode = .scaleAspectFill
        img.clipsToBounds = true
        img.layer.cornerRadius = 8
        img.backgroundColor = .secondarySystemBackground

        title.font = .preferredFont(forTextStyle: .subheadline)
        title.numberOfLines = 2
        price.font = .preferredFont(forTextStyle: .caption1)
        price.textColor = .secondaryLabel

        qtyLabel.font = .preferredFont(forTextStyle: .body)
        qtyLabel.textAlignment = .center
        qtyLabel.setContentHuggingPriority(.required, for: .horizontal)

        minusBtn.setImage(UIImage(systemName: "minus"), for: .normal)
        plusBtn.setImage(UIImage(systemName: "plus"), for: .normal)
        minusBtn.addTarget(self, action: #selector(dec), for: .touchUpInside)
        plusBtn.addTarget(self, action: #selector(inc), for: .touchUpInside)

        let text = UIStackView(arrangedSubviews: [title, price])
        text.axis = .vertical
        text.spacing = 2

        let stepper = UIStackView(arrangedSubviews: [minusBtn, qtyLabel, plusBtn])
        stepper.axis = .horizontal
        stepper.spacing = 4

        let row = UIStackView(arrangedSubviews: [img, text, stepper])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            img.widthAnchor.constraint(equalToConstant: 56),
            img.heightAnchor.constraint(equalToConstant: 56),
            qtyLabel.widthAnchor.constraint(equalToConstant: 24),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        img.image = nil
    }

    func configure(with product: DemoProduct, quantity: Int, onQuantityChange: @escaping (Int) -> Void) {
        title.text = product.name
        price.text = String(format: "$%.2f", product.price)
        qtyLabel.text = "\(quantity)"
        self.onQuantityChange = onQuantityChange

        imageTask?.cancel()
        imageTask = URLSession.shared.dataTask(with: product.imageURL) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { self?.img.image = image }
        }
        imageTask?.resume()
    }

    @objc private func inc() { onQuantityChange?(+1) }
    @objc private func dec() { onQuantityChange?(-1) }
}
