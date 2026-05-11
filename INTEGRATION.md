# BambuserCalls-shopper — Integration guide

A practical walkthrough of every public function the package exposes and what a host app needs to do to actually wire each one up. Read alongside [`README.md`](README.md), which has the quick-start summary.

---

## Contents

1. [What the package does](#what-the-package-does)
2. [Add the package](#add-the-package)
3. [Required Info.plist entries](#required-infoplist-entries)
4. [Bootstrapping at app launch](#bootstrapping-at-app-launch)
5. [Public API reference](#public-api-reference)
   - [`BambuserCallConfiguration`](#bambusercallconfiguration)
   - [`BambuserCallController`](#bambusercallcontroller)
   - [`BambuserCallOverlay`](#bambusercalloverlay)
   - [`BambuserCallDelegate`](#bambusercalldelegate)
   - [Enums](#enums)
   - [Product-hydration models](#product-hydration-models)
6. [Implementation checklist](#implementation-checklist)
7. [Product hydration in detail](#product-hydration-in-detail)
8. [Cart integration in detail](#cart-integration-in-detail)
9. [PiP customization](#pip-customization)
10. [Common pitfalls](#common-pitfalls)

---

## What the package does

It hides three things behind a small SwiftUI surface:

- A `WKWebView` that loads the Bambuser one-to-one embed script and grants camera/mic permissions automatically.
- A draggable picture-in-picture overlay that resizes itself between a slim ringing strip and a full mini-player as the SDK reports viewport-mode changes.
- A two-way JS bridge that converts SDK events into Swift delegate callbacks and lets you push product/cart updates back into the embed.

You implement a delegate to bridge the bridge to your app's navigation stack, catalog, and cart.

---

## Add the package

In Xcode: **File → Add Package Dependencies → Add Local…** and point at `Example/Packages/BambuserCalls-shopper/`. Add the **BambuserCalls-shopper** library to the app target. In code, write `import BambuserCallsShopper` (Swift module names can't contain hyphens, so the camelCase form is used in code).

Two legacy library aliases — `BambuserCall` and `BambuserExpertChat` — point at the same target. They exist so existing project references keep linking; remove them from `Package.swift` after migrating fully.

---

## Required Info.plist entries

Video calls won't start without these permission strings:

| Key | Value (suggestion) |
|---|---|
| `NSCameraUsageDescription` | "We need access to your camera so the expert can see you during the call." |
| `NSMicrophoneUsageDescription` | "We need microphone access so the expert can hear you during the call." |

The framework auto-grants `WKWebView`'s media-capture prompt once iOS has approved them at the system level.

---

## Bootstrapping at app launch

Construct one controller, hold a delegate strongly, drop one overlay into your view tree.

```swift
import SwiftUI
import BambuserCallsShopper

@main
struct MyApp: App {
    @StateObject var navigationManager = NavigationManager()

    @StateObject var bambuserCall = BambuserCallController(
        configuration: BambuserCallConfiguration(orgId: "your-org-id")
    )

    @State private var bridge: AppBambuserCallDelegate?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bambuserCall)
                .environmentObject(navigationManager)
                .overlay(BambuserCallOverlay(controller: bambuserCall))
                .onAppear {
                    if bridge == nil {
                        let b = AppBambuserCallDelegate(navigationManager: navigationManager)
                        bridge = b
                        bambuserCall.delegate = b
                    }
                }
        }
    }
}
```

Two things to note:

- `BambuserCallController.delegate` is `weak`. The app must keep a strong reference (a `@State` property is the simplest place).
- `BambuserCallOverlay` belongs in a ZStack/overlay above your main UI so the floating PiP sits on top of everything else.

To start a session from anywhere:

```swift
@EnvironmentObject var bambuserCall: BambuserCallController
…
Button("Talk to expert") {
    bambuserCall.show()
}
```

---

## Public API reference

### `BambuserCallConfiguration`

Frozen at init. Only `orgId` is required. The public surface is intentionally
small — six knobs that hosts realistically flip — and everything else (embed
triggers, navigation/fill modes, ringing-strip size, animation curves, custom
user agent, getUserMedia polyfill) lives as internal-only defaults.

```swift
public struct BambuserCallConfiguration {
    public var orgId: String
    public var embedUrl: URL              // default https://one-to-one.bambuser.com/embed.js
    public var floatingPipSize: CGSize    // default 180×260
    public var isInspectable: Bool        // default true in DEBUG, false in release
    public var autoExpandOnConnect: Bool  // default true
    public var dismissOnCallEnd: Bool     // default true

    public init(
        orgId: String,
        embedUrl: URL = .defaultEmbedUrl,
        floatingPipSize: CGSize = .defaultFloatingPipSize,
        isInspectable: Bool = .defaultIsInspectable,
        autoExpandOnConnect: Bool = true,
        dismissOnCallEnd: Bool = true
    )
}
```

What each one does:

- **`orgId`** — Bambuser organization id, hardcoded into the JS embed call.
- **`embedUrl`** — embed script URL. Override for staging / labs / branch builds.
- **`floatingPipSize`** — frame for the connected mini-player (full video tile + controls). The package handles the smaller ringing-strip size internally.
- **`isInspectable`** — whether `WKWebView.isInspectable` is true. Default leaves Safari Web Inspector on in DEBUG and off in release so production builds aren't debuggable.
- **`autoExpandOnConnect`** — if the user minimized to PiP during the connecting phase, the framework restores full-screen the moment the call goes live.
- **`dismissOnCallEnd`** — when set, the overlay closes itself the moment the SDK reports `call-ended` (and friends).

If you genuinely need to override one of the internal knobs (e.g. a different
trigger set, custom user agent, no-tab-bar layout), file an issue — it usually
means we should promote it to the public API rather than have you reach in.

### `BambuserCallController`

`@MainActor public final class BambuserCallController: ObservableObject`

#### Init

```swift
public init(configuration: BambuserCallConfiguration)
```

Hold the controller as `@StateObject` at app root and inject via `.environmentObject(...)`.

#### Published state — observe with SwiftUI

```swift
@Published public private(set) var isVisible: Bool
@Published public private(set) var isPiP: Bool
@Published public private(set) var pipPresentation: PipPresentation
@Published public private(set) var orgId: String?
@Published public private(set) var callState: CallState
@Published public var embedUrl: URL                      // mutable, hot-swappable
public weak var delegate: (any BambuserCallDelegate)?    // assign at startup
public var isCallActive: Bool { get }                    // .connecting OR .connected
```

#### Lifecycle methods — call from your UI

```swift
public func show(orgId: String? = nil, embedUrl: URL? = nil)
public func close()
public func expand()
public func enterPiP(presentation: PipPresentation = .floating)
```

- **`show()`** — opens the overlay full-screen. Uses `configuration.orgId` unless you pass an override (multi-tenant apps).
- **`close()`** — fully tears down the embed and resets all state to idle. Called automatically at call-end if `dismissOnCallEnd` is true.
- **`expand()` / `enterPiP()`** — manual presentation control. The SDK itself flips between full and floating based on user actions, but exposing these lets you script overlays from buttons elsewhere in the app.

#### Outbound bridge — push state into the embed

```swift
public func notifyProductNavigation(externalId: String)
public func hydrateProduct(bambuserId: String, payload: BambuserHydratedProduct)
```

- **`notifyProductNavigation`** — call this whenever the user navigates to a product *outside* the embed (taps a card on a different tab, follows a deep link, etc.). The embed's product carousel mirrors the new selection. Gated on `isCallActive` so it's safe to fire-and-forget.
- **`hydrateProduct`** — manual hydration entry point. Hosts normally don't call this directly; the framework calls it on your behalf with whatever your delegate returns from `bambuserCall(_:provideProductData:completion:)`.

### `BambuserCallOverlay`

`public struct BambuserCallOverlay: View`

```swift
public init(controller: BambuserCallController)
```

Place exactly one in your view tree, either via `.overlay(...)` on the root or as a sibling in a `ZStack`. Renders nothing while the controller is hidden, so it has no ambient cost when you're not in a call.

### `BambuserCallDelegate`

`@MainActor public protocol BambuserCallDelegate: AnyObject`

Almost every method has a default implementation. The minimum a host has to implement is the navigation request:

```swift
func bambuserCall(
    _ controller: BambuserCallController,
    didRequestNavigationTo externalId: String
)
```

Optional methods (with default empty/false implementations):

```swift
// Lifecycle
func bambuserCallDidRequestClose(_ controller: BambuserCallController)
func bambuserCallDidRequestCheckout(_ controller: BambuserCallController)
func bambuserCall(_ controller: BambuserCallController, didChangeCallState state: CallState)
func bambuserCall(_ controller: BambuserCallController, didChangePresentation isPiP: Bool, presentation: PipPresentation)

// Cart (default returns false for both)
func bambuserCall(_ controller: BambuserCallController,
                  shouldAddToCart sku: String,
                  quantity: Int,
                  completion: @escaping (Bool) -> Void)
func bambuserCall(_ controller: BambuserCallController,
                  shouldUpdateCartItem sku: String,
                  quantity: Int,
                  completion: @escaping (Bool) -> Void)

// Hydration (default returns empty dict)
func bambuserCall(_ controller: BambuserCallController,
                  provideProductData references: [BambuserCallProductReference],
                  completion: @escaping ([String: BambuserHydratedProduct]) -> Void)

// Catch-all observer
func bambuserCall(_ controller: BambuserCallController,
                  didReceiveEvent name: String,
                  payload: Any?)
```

### Enums

```swift
public enum CallState: Equatable, Sendable {
    case idle, connecting, connected, ended
}

public enum PipPresentation: Equatable, Sendable {
    case minimized   // 60pt ringing strip (floatingLeftMinimized / RightMinimized)
    case floating    // 260pt mini-player (floating)
}
```

### Product-hydration models

Mirror the shape of the [Bambuser fluent product builder](https://bambuser.com/docs/video-consultation/provide-product-data/). All `Encodable + Sendable`.

```swift
public struct BambuserCallProductReference: Equatable, Sendable {
    public let bambuserId: String              // pass back to updateProduct
    public let ref: String                     // map to YOUR catalog
    public let referenceType: ReferenceType    // url / productReference / scannedCode / unknown
}

public struct BambuserHydratedProduct: Encodable, Sendable {
    public var currency: String                // "USD"
    public var locale: String                  // "en-US"
    public var product: BambuserProductDetails
}

public struct BambuserProductDetails: Encodable, Sendable {
    public var name: String?
    public var subtitle: String?
    public var description: String?
    public var url: String?
    public var sku: String?
    public var attributes: [BambuserAttribute]?
    public var variations: [BambuserVariation]?
    public var defaultVariationIndex: Int?
    public var rating: BambuserRating?
}

public struct BambuserAttribute: Encodable, Sendable {
    public var id: String                      // "color", "size", …
    public var displayName: String?
    public var options: [Option]
    public struct Option: Encodable, Sendable {
        public var id: String                  // "red", "small", …
        public var displayName: String?
    }
}

public struct BambuserVariation: Encodable, Sendable {
    public var name: String
    public var sku: String
    public var imageUrls: [String]
    public var subtitle: String?
    public var url: String?
    public var inStock: Bool?
    public var price: BambuserPrice?
    public var attributes: [String: String]?   // attributeId → optionId
}

public struct BambuserPrice: Encodable, Sendable {
    public var current: Double
    public var original: Double?
}

public struct BambuserRating: Encodable, Sendable {
    public var rating: Double
    public var maxValue: Double                // default 5
    public var numberOfRatings: Int?
}
```

---

## Implementation checklist

For each entry: what already exists in the package, and what you have to write in your host app.

### 1. Show / dismiss the overlay

**In package:** `controller.show()`, `controller.close()`, `BambuserCallOverlay` view.

**You need to:** Pick where to call `show()` (a "Talk to expert" button on a product page is typical) and place the overlay in your view tree.

### 2. Receive product clicks from the embed

**In package:** Parses `navigate-to` forwarded events, unwraps `externalId` from the three shapes (string, `{id, feedId}` dict, URL slug fallback), calls `delegate.bambuserCall(_:didRequestNavigationTo:)`.

**You need to:** Implement `didRequestNavigationTo`, map the externalId to your product schema, push your detail screen. Optionally call `controller.notifyProductNavigation(externalId:)` to confirm you navigated.

### 3. Send product clicks to the embed

**In package:** `controller.notifyProductNavigation(externalId:)` (gated on `isCallActive`).

**You need to:** Wire this into your existing product detail screen's `onAppear` / size-selection change handlers so the embed's carousel stays in sync.

### 4. Hydrate products on demand

**In package:** Listens for `provide-product-data`, parses the references, calls `delegate.bambuserCall(_:provideProductData:completion:)`. After your completion fires, the framework JSON-encodes each entry and applies it to the embed's fluent product builder via JS.

**You need to:** Implement the hydration delegate method, look up your catalog, return a `[bambuserId: BambuserHydratedProduct]` dictionary. See [Product hydration in detail](#product-hydration-in-detail) for the mapping recipe.

### 5. Cart add / update

**In package:** Listens for `should-add-item-to-cart` / `should-update-item-in-cart`, extracts SKU + quantity from common payload shapes, hands them to your delegate with a completion handler. Resolves the embed-side promise via `controller.resolveCart(...)` once your completion fires.

**You need to:** Implement the two cart delegate methods, do the actual cart mutation, call the completion with `true` on success or `false` on failure (e.g. out of stock).

### 6. Checkout

**In package:** Listens for `goto-checkout`, calls `delegate.bambuserCallDidRequestCheckout(_)`.

**You need to:** Implement the method to switch to your cart screen / present checkout.

### 7. Call lifecycle observation

**In package:** Maps the embed's various call-* event names onto a unified `CallState`. Auto-expands from PiP on first connect if `autoExpandOnConnect` is true. Auto-closes the overlay on `call-ended` if `dismissOnCallEnd` is true.

**You need to:** Optionally implement `didChangeCallState` for analytics, custom UI feedback, etc.

### 8. PiP placement / drag

**In package:** Drag-to-move with cumulative offset, auto-resize between `minimizedPipSize` (ringing) and `floatingPipSize` (connected), bottom-right resting position with safe-area + tab-bar insets.

**You need to:** Just configure the sizes. If your app's bottom chrome differs from the standard 49pt tab bar, set `bottomReserve`.

### 9. Catch-all observer

**In package:** All embed events that aren't routed to specific delegate methods (and a few that are) are also delivered via `bambuserCall(_:didReceiveEvent:payload:)`.

**You need to:** Use this for analytics piggybacks, debugging, or future events the framework hasn't explicitly modelled yet. Default impl is a no-op.

---

## Product hydration in detail

When the embed asks for product data (the agent typed a SKU / URL / scanned a barcode), the flow is:

1. JS emits `provide-product-data` with one or more references.
2. Framework parses them into `[BambuserCallProductReference]` and calls your delegate.
3. Your delegate fetches data (sync or async — the completion is held open) and calls `completion(dict)`.
4. Framework iterates the dict and runs `controller.hydrateProduct(bambuserId:payload:)` for each entry.
5. JS bridge applies the JSON onto the SDK's fluent product builder via `oneToOneEmbed.updateProduct(...)`.

### Minimum viable hydration

For a single-variation product:

```swift
func bambuserCall(
    _ controller: BambuserCallController,
    provideProductData references: [BambuserCallProductReference],
    completion: @escaping ([String: BambuserHydratedProduct]) -> Void
) {
    var hydrated: [String: BambuserHydratedProduct] = [:]
    for ref in references {
        guard let product = catalog.lookup(ref.ref) else { continue }
        hydrated[ref.bambuserId] = BambuserHydratedProduct(
            currency: "USD",
            locale: "en-US",
            product: BambuserProductDetails(
                name: product.name,
                description: product.description,
                sku: product.sku,
                variations: [
                    BambuserVariation(
                        name: product.name,
                        sku: product.sku,
                        imageUrls: product.imageUrls.map { $0.absoluteString },
                        inStock: product.inStock,
                        price: BambuserPrice(current: product.price)
                    )
                ]
            )
        )
    }
    completion(hydrated)
}
```

### Multi-variation with attributes

If your product has color and size dimensions, declare them at the parent level and reference them from each variation:

```swift
let attributes: [BambuserAttribute] = [
    BambuserAttribute(id: "color", displayName: "Color", options: [
        .init(id: "red",   displayName: "Red"),
        .init(id: "blue",  displayName: "Blue")
    ]),
    BambuserAttribute(id: "size", displayName: "Size", options: [
        .init(id: "s", displayName: "S"),
        .init(id: "m", displayName: "M"),
        .init(id: "l", displayName: "L")
    ])
]

let variations: [BambuserVariation] = [
    BambuserVariation(
        name: "Red, Small",
        sku: "shirt-red-s",
        imageUrls: ["https://…/red.jpg"],
        inStock: true,
        price: BambuserPrice(current: 49.99),
        attributes: ["color": "red", "size": "s"]
    ),
    // … one per concrete combination
]

let hydrated = BambuserHydratedProduct(
    currency: "USD",
    locale: "en-US",
    product: BambuserProductDetails(
        name: "Linen shirt",
        description: "100% premium linen.",
        sku: "shirt",
        attributes: attributes,
        variations: variations
    )
)
```

### Async hydration

The completion can fire later — e.g. from a network call:

```swift
Task {
    var hydrated: [String: BambuserHydratedProduct] = [:]
    for ref in references {
        if let product = await api.fetchProduct(ref: ref.ref) {
            hydrated[ref.bambuserId] = product.toBambuserHydrated()
        }
    }
    completion(hydrated)
}
```

The embed will hold the agent's product slot in a loading state until you reply.

---

## Cart integration in detail

Both cart events deliver a SKU + quantity + a completion handler. Your job is to mutate your real cart and reply.

```swift
func bambuserCall(
    _ controller: BambuserCallController,
    shouldAddToCart sku: String,
    quantity: Int,
    completion: @escaping (Bool) -> Void
) {
    Task {
        do {
            try await cartService.add(sku: sku, quantity: quantity)
            completion(true)
        } catch {
            completion(false)   // embed shows "couldn't add" UI to the agent
        }
    }
}

func bambuserCall(
    _ controller: BambuserCallController,
    shouldUpdateCartItem sku: String,
    quantity: Int,
    completion: @escaping (Bool) -> Void
) {
    Task {
        let success = await cartService.update(sku: sku, quantity: quantity)
        completion(success)
    }
}
```

Replying with `false` tells the agent the action failed (out of stock, validation error, etc.). The embed surfaces a generic failure message; if you need a custom reason string, plumb it through your own catch-all delegate implementation and log/handle it there.

---

## PiP customization

Override the connected mini-player frame:

```swift
BambuserCallConfiguration(
    orgId: "your-org-id",
    floatingPipSize: CGSize(width: 200, height: 280)
)
```

That's the only PiP knob exposed publicly. The framework picks the right
size for the dial-up ringing strip internally and parks the floater bottom-
right with safe-area + tab-bar margins. Users can drag it anywhere from there;
drag offset resets each time PiP is re-entered so every session starts at the
resting position.

To programmatically open in PiP:

```swift
bambuserCall.show()              // opens full-screen
bambuserCall.enterPiP(.floating) // immediately goes to PiP
```

---

## Common pitfalls

**Delegate stays nil because nothing keeps it alive.**
`BambuserCallController.delegate` is `weak`. Hold it strongly somewhere — typically a `@State` property at app root. The bootstrap example above shows the pattern.

**`isCallActive` is false when you expected it to be true.**
The framework only flips `callState` when the embed emits one of the recognized lifecycle event names. If your SDK build emits something else (a custom rename), implement `didReceiveEvent` and call `controller.setCallState(.connecting/.connected)` manually — but file a bug first; we should expand the recognized list.

**Embed lists won't scroll inside the PiP.**
Drag-to-move only intercepts touches when `controller.isPiP` is true. If you experience the issue in *full-screen* mode, double-check you didn't disable hit-testing on the overlay or wrap it in a gesture-stealing container.

**`provide-product-data` completion never fires.**
The framework holds the JS-side promise until your `completion` closure runs. Make sure every code path in your delegate calls `completion(dict)` — even for the empty case (`completion([:])`).

**Calling `notifyProductNavigation` from a screen the user reached without an active call does nothing.**
This is intentional — `isCallActive` gates the JS bridge so we don't spam the embed when no expert is watching. Call it freely; it's a no-op when not in a call.

**Hydration "succeeds" but the embed still shows a broken product.**
The fluent JS builder requires either zero `attributes` *and* zero `variations`, OR a fully consistent attributes-and-variations setup where every `variation.attributes[attrId] = optionId` references something declared in the parent `attributes`. Mismatches silently produce broken output.

---

## What's *not* in the public API (yet)

These are intentionally internal:

- `EmbedWebView` — the `UIViewRepresentable` wrapping `WKWebView`.
- `EmbedHTMLBuilder` — generates the host page + JS bridge.
- `EmbedEventRouter` — parses native-bridge messages.

If you need WebView customization (custom `WKUIDelegate`, additional user scripts), open an issue and we can expose a focused customization protocol rather than leaking `WKWebView` directly.
