# BambuserCalls-shopper

A focused Swift package that wraps Bambuser's one-to-one (video consultation / expert call) web embed in a native iOS surface. Provides:

- A SwiftUI overlay that hosts the embed inside a `WKWebView` with auto-granted camera/mic permissions.
- A draggable PiP / floating mini-player that sizes itself to match the embed's viewport (slim ringing strip during connect, full mini-player after).
- A delegate-based bridge so the host app can react to navigation, cart, and product-hydration events.
- A small Codable model for product hydration matching the Bambuser fluent JS builder shape.

> **Names**
> - **Package / library**: `BambuserCalls-shopper` (the SwiftPM-facing name; this is what you write in `dependencies`).
> - **Module / `import` name**: `BambuserCallsShopper` (Swift module names can't contain hyphens, so the camelCase form is used in code).
> - **Folder on disk**: still `Packages/BambuserExpertChat/Sources/BambuserExpertChat` from earlier iterations. Rename in Finder when convenient and update `Package.swift`'s `path:` to match — purely cosmetic.

## Add the package

In Xcode: **File → Add Package Dependencies → Add Local…** and select this folder. Then add the `BambuserCalls-shopper` library to your app target.

For backwards compatibility, the package also exposes legacy `BambuserCall` and `BambuserExpertChat` library aliases that point at the same module. If your Xcode project still links one of those, the build will continue to work — but updates to the latest module name (`BambuserCallsShopper`) are encouraged.

## Quick start

```swift
import BambuserCallsShopper

@main
struct MyApp: App {
    @StateObject private var bambuserCall = BambuserCallController(
        configuration: BambuserCallConfiguration(orgId: "your-org-id")
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bambuserCall)
                .overlay(BambuserCallOverlay(controller: bambuserCall))
        }
    }
}
```

Open a session from anywhere:

```swift
@EnvironmentObject var bambuserCall: BambuserCallController
…
Button("Talk to expert") {
    bambuserCall.show()
}
```

## Configure

```swift
let config = BambuserCallConfiguration(
    orgId: "your-org-id",
    embedUrl: URL(string: "https://one-to-one.bambuser.com/embed.js")!,
    floatingPipSize: CGSize(width: 200, height: 280),
    minimizedPipSize: CGSize(width: 200, height: 64),
    pipMargin: 20,
    bottomReserve: 49,                              // tab bar
    transitionAnimation: .easeInOut(duration: 0.22),
    customUserAgent: nil,                           // nil = use Safari iOS UA
    isInspectable: true,                            // DEBUG default
    dismissOnCallEnd: true,
    autoExpandOnConnect: true
)
```

Every parameter is optional except `orgId`. Defaults match Bambuser's standard configuration.

## Bridge to the host app

Implement `BambuserCallDelegate`:

```swift
final class CallBridge: BambuserCallDelegate {

    // Required: route product clicks to the host's product screen.
    func bambuserCall(
        _ controller: BambuserCallController,
        didRequestNavigationTo externalId: String
    ) {
        navigationManager.push(.productDetail(externalId), in: .products)
        controller.notifyProductNavigation(externalId: externalId)
    }

    // Optional: hydrate products on demand.
    func bambuserCall(
        _ controller: BambuserCallController,
        provideProductData references: [BambuserCallProductReference],
        completion: @escaping ([String: BambuserHydratedProduct]) -> Void
    ) {
        Task {
            var hydrated: [String: BambuserHydratedProduct] = [:]
            for ref in references {
                if let product = await catalog.lookup(ref.ref) {
                    hydrated[ref.bambuserId] = product.toBambuserHydrated()
                }
            }
            completion(hydrated)
        }
    }
}
```

All other delegate methods have empty defaults — implement only what you need.

## Calling into the embed

`BambuserCallController` exposes outbound JS for the two common operations:

```swift
// Tell the embed the user navigated to a product (gated on isCallActive).
bambuserCall.notifyProductNavigation(externalId: "1232")

// Hydrate a product manually (normally done via the delegate callback).
bambuserCall.hydrateProduct(bambuserId: "abc", payload: ...)
```

## Product hydration

When the embed fires `provide-product-data`, the framework collects the requested references and calls `bambuserCall(_:provideProductData:completion:)`. The host returns a `[bambuserId: BambuserHydratedProduct]` dictionary. The framework converts each entry to JSON and applies it to the embed's fluent product builder via JS.

`BambuserHydratedProduct` mirrors the [Bambuser product builder schema](https://bambuser.com/docs/video-consultation/provide-product-data/) — `currency`, `locale`, `product` with `name` / `description` / `attributes` / `variations`. Each variation carries `name`, `sku`, `imageUrls`, optional `price`, `inStock`, and an `attributes` dictionary mapping back to the parent `attributes` definitions.

## Public API at a glance

| Type | Purpose |
|---|---|
| `BambuserCallController` | `@MainActor ObservableObject`. State, lifecycle, JS bridge. |
| `BambuserCallOverlay` | `View`. Renders the embed at the right frame for the current state. |
| `BambuserCallConfiguration` | Frozen value type holding all configurable knobs. |
| `BambuserCallDelegate` | Protocol the host implements to receive events. |
| `CallState` | `idle / connecting / connected / ended`. |
| `PipPresentation` | `minimized / floating`. |
| `BambuserCallProductReference` | Identifier passed during `provide-product-data`. |
| `BambuserHydratedProduct` & friends | Codable models for the product builder. |

## Internals (not public API)

- `EmbedWebView` — `UIViewRepresentable` wrapping `WKWebView`.
- `EmbedHTMLBuilder` — generates the host page + JS bridge.
- `EmbedEventRouter` — parses `nativeBridge` messages and dispatches.

These are intentionally internal; if you need WebView customization (custom `WKUIDelegate`, additional user scripts, etc.), open an issue and we can expose a focused customization protocol.
