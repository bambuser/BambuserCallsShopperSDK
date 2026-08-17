# BambuserCallsShopper — Integration Guide

Comprehensive reference for hosting the Bambuser one-to-one calls
widget inside a Swift / SwiftUI app.

- [Architecture](#architecture)
- [Setup](#setup)
- [Configuration](#configuration)
- [Handlers — data sources](#handlers)
- [Delegate — event stream](#delegate)
- [Outbound API](#outbound-api)
- [Payload types](#payload-types)
- [Factory-spec bridge](#factory-spec-bridge)
- [Environments](#environments)
- [Concurrency & threading](#concurrency)
- [Forward-compat contract](#forward-compat-contract)
- [Troubleshooting](#troubleshooting)

## Architecture

The SDK is three types that fit together:

- **`BambuserCallController`** — `@MainActor` `ObservableObject`. Owns
  the WebView, the JS bridge, and the observable state (`isVisible`,
  `callState`, `isPiP`, `pipPresentation`). Held as `@StateObject` by
  the host.
- **`BambuserCallHandlers`** — struct with four optional closures.
  Data-source contracts: the SDK invokes one, receives a value, and
  replies to the embed. Nil handlers mean "the SDK won't install the
  underlying JS listener at all", so the widget doesn't wait for a
  reply that will never come.
- **`BambuserCallDelegate`** — protocol with two methods. All
  fire-and-forget events flow through one `didEmit(event:)` with a
  `BambuserCallEvent` enum; the second method (`didEncounter(error:)`)
  has a default no-op.

Presentation is a single `BambuserCallOverlay(controller:)` in your
view tree.

```
Host app ─────────────────────────────────────────
  │
  ├── BambuserCallController ──── configuration
  │       │                        └─ environment (.us / .eu)
  │       ├── handlers ──────────── 4 data-source closures
  │       ├── delegate (weak) ─── BambuserCallDelegate
  │       └── @Published state (isVisible, callState, isPiP)
  │
  └── BambuserCallOverlay(controller: …)
          │
          └── WKWebView + JS bridge (SDK-internal)
```

## Setup

### 1. Add the package

```swift
.package(url: "https://github.com/bambuser/BambuserCallsShopperSDK", from: "0.1.0")
```

### 2. Info.plist keys

```xml
<key>NSCameraUsageDescription</key>
<string>Talk to a Bambuser sales agent over video.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Talk to a Bambuser sales agent over video.</string>
```

### 3. Create the controller

```swift
@StateObject private var call = BambuserCallController(
    configuration: BambuserCallConfiguration(
        orgId: "YOUR_ORG_ID",
        environment: .us
    )
)
```

### 4. Mount the overlay

```swift
ZStack {
    MyContent()
    BambuserCallOverlay(controller: call)
}
```

The overlay renders nothing until `call.show(...)` is called.

### 5. Wire the bridge

`.onAppear` on the root view (once per session):

```swift
call.delegate = self.bridge          // weak reference
call.handlers = makeHandlers()       // struct value
```

Handlers must be set **before** `show()`. The subscription set is
frozen at `show()` time — changes after show are logged as warnings
and take effect on the next `show()`.

### 6. Open a call

```swift
call.show(connectId: "abc", queue: "premium")
```

## Configuration

`BambuserCallConfiguration` is initialised once and passed into the
controller. All fields either have a sensible default or are optional
(nil-forwards to the embed's own default — the SDK doesn't second
guess).

### Required

| Field           | Type                       | Notes                                             |
| --------------- | -------------------------- | ------------------------------------------------- |
| `orgId`         | `String`                   | Bambuser workspace org id                         |

### Region

| Field           | Type                       | Default | Notes                                    |
| --------------- | -------------------------- | ------- | ---------------------------------------- |
| `environment`   | `BambuserEnvironment`      | `.us`   | `.us` or `.eu`                           |

### Presentation (SDK-owned)

| Field                  | Type      | Default    | Notes                              |
| ---------------------- | --------- | ---------- | ---------------------------------- |
| `floatingPipSize`      | `CGSize`  | 180×260    | Mini-player size when connected    |
| `isInspectable`        | `Bool`    | `true` in DEBUG | Enables Safari Web Inspector  |
| `autoExpandOnConnect`  | `Bool`    | `true`     | Restore full-screen on connect     |
| `dismissOnCallEnd`     | `Bool`    | `true`     | Auto-close overlay when call ends  |

### Embed constructor forwards

All of the following are pushed through to
`new BambuserOneToOneEmbed({...})`. Optional (`Bool?`, `String?`,
`[String]?`) fields are only emitted when the host sets them —
otherwise the embed's built-in defaults apply.

| Field                       | Type      | Notes                                                          |
| --------------------------- | --------- | -------------------------------------------------------------- |
| `locale`                    | `String?` | e.g. `"sv-SE"`, `"en-GB"`                                      |
| `initialCustomerData`       | `BambuserJSONValue?` | See "customer data" below                           |
| `initialTrackingTags`       | `[BambuserTrackingTag]` | Max 20; last key wins                            |
| `initialQueue`              | `String?` | Overrides workspace default queue                              |
| `dropInEnabled`             | `Bool?`   | Show/hide drop-in card. Default: embed's default (`true`)     |
| `bookingsEnabled`           | `Bool?`   | Show/hide booking card. Default: BamHub setting               |
| `openBookingPage`           | `Bool`    | Open directly on booking page. Default `false`                |
| `bookingServiceIds`         | `[String]?` | Restrict visible services                                    |
| `bookingResourceId`         | `String?` | Pin to a booking resource                                      |
| `bookingIframeUrl`          | `String?` | Custom booking iframe URL                                      |
| `enableScanning`            | `Bool`    | Barcode/QR in agent app. Default `false`                      |
| `merchantBaseUrl`           | `String?` | Base URL for co-browsing mode                                 |
| `disableCoBrowsing`         | `Bool`    | Default `false`                                                |
| `themeId`                   | `String?` | Override active BamHub theme                                   |
| `allowFirstPartyCookies`    | `Bool?`   | Default: embed's default (`true`)                             |
| `forwardUnknownEmbedEvents` | `Bool`    | Install the JS catch-all emitter. Default `false`             |

### Customer data

Passed as raw `BambuserJSONValue` — shape it however you want. Built-in
fields the embed recognises: `externalId`, `firstName`, `lastName`,
`email`, `phone`. Any other flat key/value pairs are shown as extra
rows to the agent.

```swift
initialCustomerData: .object([
    "externalId": .string(user.id),
    "firstName": .string(user.firstName),
    "email": .string(user.email),
    "loyaltyTier": .string("gold"),   // custom
])
```

Refresh later with `controller.updateData(_:)`.

## Handlers

Data-source closures on `BambuserCallHandlers`. The SDK invokes one
per matching embed event, receives your value, and dispatches back to
the widget. **Only the closures you set trigger a JS subscription** —
missing handlers mean the widget won't ask.

```swift
public struct BambuserCallHandlers {
    var provideProductData: (@MainActor (BambuserProductRef) async -> BambuserFactorySpec?)?
    var provideSearchData:  (@MainActor (BambuserSearchRequest) async -> BambuserFactorySpec?)?
    var shouldAddToCart:    (@MainActor (BambuserCartIntent) async -> BambuserCartResult)?
    var shouldUpdateCart:   (@MainActor (BambuserCartIntent) async -> BambuserCartResult)?
}
```

### `provideProductData`

Fires when the agent adds a product by SKU, URL, or barcode. Called
once per ref in the payload — you don't fan out.

```swift
handlers.provideProductData = { ref in
    guard let sku = resolveSKU(from: ref) else { return nil }
    guard let product = catalog.product(for: sku) else { return nil }
    return product.toBambuserFactorySpec()
}
```

`BambuserProductRef` fields:

| Field         | Type              | Notes                                                       |
| ------------- | ----------------- | ----------------------------------------------------------- |
| `ref`         | `String`          | SKU, URL, or barcode                                        |
| `kind`        | `Kind`            | `.productReference` / `.url` / `.scannedCode` / `.unknown(String)` |
| `bambuserId`  | `String`          | Echo back on the reply — SDK-owned                          |
| `raw`         | `BambuserJSONValue` | Full raw JSON for the ref, including any new fields       |

Returning `nil` = "product not found" — the agent tool shows the
empty-state card after its own timeout.

### `provideSearchData`

Fires when the agent types in the tool's search field.

```swift
handlers.provideSearchData = { request in
    let results = try? await searchAPI.search(request.term, page: request.page)
    return results?.toBambuserFactorySpec()
}
```

`BambuserSearchRequest` fields: `term`, `page`, `callbackKey`, `raw`.

Return `nil` for empty results.

### `shouldAddToCart` / `shouldUpdateCart`

Fires when the agent adds or updates a cart line in their tool.

```swift
handlers.shouldAddToCart = { intent in
    do {
        try await cart.add(sku: intent.sku, quantity: intent.quantity)
        return .success
    } catch let e as OutOfStockError {
        return .failure(reason: "out-of-stock")
    } catch {
        return .failure()
    }
}
```

`BambuserCartIntent` fields: `sku`, `quantity`, `previousQuantity`,
`raw`.

`BambuserCartResult`:

- `.success` → `true`
- `.failure(reason: String?)` → `false` or `{success: false, reason: '...'}`
- `.raw(BambuserJSONValue)` → any custom reply shape verbatim

### Async handler semantics

- All handlers run on `@MainActor`. `await` inside them yields the
  main-actor to other work, then resumes when the actor is free.
- One `Task` is spawned per event. Product refs with distinct
  `bambuserId`s never race; search / cart requests carry unique
  `callbackKey`s.
- If the WebView is torn down mid-await, the eventual reply no-ops
  silently (guarded on `webView != nil`).

## Delegate

Fire-and-forget events. One protocol, two methods. Every event comes
through `didEmit(event:)` as a `BambuserCallEvent` case.

```swift
@MainActor
public protocol BambuserCallDelegate: AnyObject {
    func bambuserCall(_ controller: BambuserCallController, didEmit event: BambuserCallEvent)
    func bambuserCall(_ controller: BambuserCallController, didEncounter error: BambuserCallError)
}
```

`didEncounter` has a default no-op — implement only when you want to
log errors.

### `BambuserCallEvent` cases

| Case                              | Payload                                                | When                                                    |
| --------------------------------- | ------------------------------------------------------ | ------------------------------------------------------- |
| `.close`                          | —                                                      | Widget closed (user or `destroy()`)                     |
| `.callStateChanged(CallState)`    | `.idle / .connecting / .connected / .ended`            | Any state transition                                    |
| `.presentationChanged(isPiP:presentation:)` | `Bool`, `PipPresentation`                    | PiP/fullscreen flip                                     |
| `.checkout(cart: BambuserJSONValue)` | Raw cart payload                                     | Shopper tapped checkout                                 |
| `.chatRequested`                  | —                                                      | Shopper picked "I prefer to chat"                       |
| `.navigateTo(url: URL)`           | Absolute URL                                           | Agent asked to route the shopper (checkout uses this too) |
| `.queueOpened(BambuserQueueOpenState)` | `isOpen`, `nextCloseTime?`, `raw`                | Queue opened / was open on init                         |
| `.queueClosed(BambuserQueueOpenState)` | `isOpen`, `nextOpenTime?`, `raw`                 | Queue closed / was closed on init                       |
| `.agentsOnlineChanged(BambuserAgentsOnline)` | `numberOfAgentsOnline`, `queueId?`, `raw`  | Online count changed                                    |
| `.waitingTimeChanged(BambuserQueueWaitingTime)` | `estimatedWaitingTime`, `agents`, `place`, `queueId?`, `raw` | Queue wait updated             |
| `.trackingEvent(BambuserTrackingEvent)` | Bambuser + GA4-shaped analytics                   | Every embed tracking-event                              |
| `.other(name:payload:)`           | `String`, `BambuserJSONValue`                          | Firehose — only when `forwardUnknownEmbedEvents = true` |

Handle a subset with a switch:

```swift
func bambuserCall(_ c: BambuserCallController, didEmit event: BambuserCallEvent) {
    switch event {
    case .checkout:                       navigation.push(.checkout)
    case .navigateTo(let url):            router.push(url)
    case .agentsOnlineChanged(let a):     available = a.numberOfAgentsOnline > 0
    default:                              break
    }
}
```

For forward-compat, use `@unknown default:` — a future SDK case
becomes a warning instead of an error.

## Outbound API

Methods on `BambuserCallController`.

### Lifecycle

- `show(orgId:connectId:queue:)` — mount overlay, start session. All
  three are optional overrides (defaults come from the configuration).
- `close()` — dismiss overlay + reset state. Any in-flight async
  invokes get cancelled with an error.
- `destroy()` — call the embed's `destroy()` then `close()`.

### Presentation

- `enterPiP(presentation: .floating | .minimized)`
- `expand()` — leave PiP back to full-screen
- `floatAbove(url: String?)` — mini-player, optionally navigating to a
  URL (co-browsing)

### Product / cart / search replies

Convenience wrappers over the generic `invoke(...)` primitives. Use
these from your handlers' reply path or call them directly.

- `provideProductData(bambuserId:factorySpec:)` — reply to
  `provide-product-data`
- `provideSearchData(callbackKey:factorySpec:)` — reply to
  `provide-search-data`
- `notify(callbackKey:info:)` — raw JS reply (used internally for cart
  callbacks; exposed for anything else that stashes a callback on
  `window`)
- `notifyProductNavigation(externalId:)` — echo a host-side PDP open
  back to the widget (agent's carousel follows)

### Customer data / tracking

- `updateData(_ data: BambuserJSONValue?)` — refresh customer info.
  `nil` re-invokes the data function you configured at init.
- `setTrackingTags(_ tags: [BambuserTrackingTag])`
- `notifyCustomerEvent(_ eventKey: String, payload: BambuserJSONValue)` —
  report a shopper-driven event to the widget without going through
  the dataLayer interceptor. `eventKey` is the constant name on
  `BambuserOneToOneEmbed.CUSTOMER_EVENTS` (`"ADDED_TO_CART"`,
  `"REMOVED_FROM_CART"`, `"PRODUCT_VIEWED"`). The JS helper resolves
  the constant at call time — new keys work with no SDK release.

### Queue queries

Async — return the embed's live promise value.

- `areQueuesOpen() async throws -> BambuserQueueOpenState`
- `getNumberOfOnlineAgents(queue: String?) async throws -> BambuserAgentsOnline`
- `getEstimatedWaitingTime(queue: String?) async throws -> BambuserQueueWaitingTime`
- `setQueue(_ term: String)` — switch active queue

Wait until after `show()` — the queries need the WebView to be mounted.
If cancelled by `close()` mid-query, the awaiting `Task` gets a
`BambuserCallError.javaScriptEvaluationFailed`.

### Custom elements

- `updateElement(_ element: BambuserElement, state: BambuserElementState?)`
  — override the drop-in card or booking card content on the start
  screen. Pass `nil` to reset to default.

```swift
call.updateElement(.dropInCard, state: BambuserElementState(
    disableCTA: true,
    subtitle: "No agents available right now",
    buttonText: "Try again later"
))
```

### Generic invoke primitives

Escape hatches — call any embed method, present or future.

```swift
// Fire-and-forget, optionally with a factory-callback last arg:
call.invoke(
    embedMethod: "updateProduct",
    primaryArgs: [.string(bambuserId)],
    factorySpec: product.factorySpec
)

// Reply to a callback the embed handed us (searchResponse, cart, …):
call.invoke(
    callback: request.callbackKey,
    factorySpec: response.factorySpec
)

// Promise-returning method — awaits the JS resolution:
let value = try await call.invoke(async: "areQueuesOpen")
```

The typed convenience methods (`provideProductData`, `updateData`,
`areQueuesOpen`, etc.) are all thin wrappers over these three.

## Payload types

Every SDK-owned payload struct exposes both typed fields and a
`raw: BambuserJSONValue` with the full unmodified web JSON — so if
Bambuser adds a new field, you access it via `.raw` without waiting
for an SDK release.

- `BambuserProductRef` — provide-product-data entry
- `BambuserSearchRequest` — provide-search-data payload
- `BambuserCartIntent` — cart intent (with `.raw` inner payload)
- `BambuserQueueOpenState`, `BambuserAgentsOnline`,
  `BambuserQueueWaitingTime` — queue event / query payloads
- `BambuserTrackingEvent` — tracking-event with Bambuser + GA4 fields
- `BambuserCallError` — `javaScriptEvaluationFailed` / `invalidEventPayload`

## Factory-spec bridge

The embed's product / search reply APIs are **chained JavaScript
builder callbacks**, not JSON:

```js
oneToOneEmbed.updateProduct(id, factory =>
    factory.currency("USD").locale("en-US").product(pf =>
        pf.name(...).sku(...).variations(vf => arr.map(v => vf().name(...)))
    )
);
```

`BambuserFactorySpec` describes such a chain **as data**, so the
native side never touches JS strings. A single JS reducer
(`__bambuserApplyFactorySpec`) walks the spec against whatever
factory the embed hands out.

```swift
let spec = BambuserFactorySpec([
    .method("currency", args: [.string("USD")]),
    .method("locale",   args: [.string("en-US")]),
    .method("product", factory: BambuserFactorySpec([
        .method("name",     args: [.string("Cap")]),
        .method("sku",      args: [.string("CAP-1")]),
        .method("variations", items: [
            BambuserFactoryItem(spec: BambuserFactorySpec([
                .method("name",     args: [.string("Cap - Red")]),
                .method("sku",      args: [.string("CAP-1-RED")]),
                .method("imageUrls", args: [.array([.string("https://.../red.png")])]),
                .method("price", factory: BambuserFactorySpec([
                    .method("current", args: [.double(19.99)]),
                ])),
            ])),
        ]),
    ])),
])
```

Three call shapes:

- **Plain call** — `.method(name, args:)` → `factory.name(arg1, arg2)`
- **Nested factory** — `.method(name, args:, factory:)` →
  `factory.name(args..., f => applySpec(f, subspec))`
- **Items builder** — `.method(name, items: [...])` →
  `factory.name(args..., iFactory => items.map(i => applySpec(iFactory(...i.factoryArgs), i.spec)))`

New embed builder methods work automatically; no SDK change.

### Reference model in the demo

The demo target ships `BambuserProduct`, `BambuserSearchResponse`,
`BambuserCustomerData` as reference model types. Each has a
`.factorySpec` extension. **These live in the demo, not the SDK** —
copy them if useful, or replace them with your own product model
entirely.

## Environments

`BambuserEnvironment` is a struct with hardcoded static factories:

```swift
public struct BambuserEnvironment: Sendable, Equatable {
    public let embedURL: URL
    public init(embedURL: URL)

    public static let us = BambuserEnvironment(
        embedURL: URL(string: "https://one-to-one.bambuser.com/embed.js")!
    )
    public static let eu = BambuserEnvironment(
        embedURL: URL(string: "https://one-to-one.bambuser.com/eu/embed.js")!
    )
}
```

Pick to match your BamHub cluster. Set via
`BambuserCallConfiguration(orgId:, environment: .us)`.

## Concurrency

- **All public API is `@MainActor`.** Serial by construction — no
  locks needed inside your handlers.
- **Handler snapshot is frozen at `show()`.** Reassigning
  `controller.handlers` mid-session logs a warning; changes take
  effect on the next `show()`.
- **Delegate is `weak`.** Hold a strong reference elsewhere or it
  gets released.
- **Async invoke continuations are cancelled on `close()`.** Any
  awaiting `Task` throws a `BambuserCallError` instead of leaking.
- **Store-then-eval ordering** for async invokes: the continuation is
  registered *before* the JS eval, so a fast `__async-response` can't
  arrive before the map has the entry.

## Forward-compat contract

The SDK is designed so **field-level embed changes never require an
SDK release**. What that gets you concretely:

**New incoming field on an event.** Accessible via `event.<payload>.raw`
in the handler / delegate case. Typed fields on payload structs are
convenience — the full JSON is always in `raw`.

**New reply shape the widget expects on cart.** Use
`BambuserCartResult.raw(BambuserJSONValue)` for arbitrary reply
payloads.

**New embed builder method.** Add it to your `BambuserFactorySpec`
chain — the JS reducer walks it verbatim.

**New embed constructor option.** File an issue; new top-level fields
in the config object need one line in `EmbedHTMLBuilder` to be
emitted.

**New method on `oneToOneEmbed`.** Use
`controller.invoke(embedMethod:...)` (fire-and-forget) or
`controller.invoke(async:...)` (promise-returning). Both call any
method name.

**New CUSTOMER_EVENTS key.** Use
`controller.notifyCustomerEvent("NEW_KEY", payload: ...)` — the JS
helper looks the constant up on the live embed class.

**Truly new event.** Set
`configuration.forwardUnknownEmbedEvents = true` and handle in
`.other(name:payload:)` on `BambuserCallEvent`.

## Troubleshooting

### Handlers don't fire

- Check `bridge = BambuserCallBridge.configure(...)` ran before
  `show()`. Add a `print` inside `.onAppear` to confirm the ordering.
- Check the console for `▶︎ provideProductData` / `▶︎ provideSearchData`
  log lines when the agent enters a SKU. Missing = no JS subscription;
  present = the handler ran (any nil returns are visible in the log
  too).
- Handlers frozen at `show()` — reassigning after only takes effect
  on the next `show()`.

### `feedCount=0` but you're using a live catalog

Preload before `show()`. Handlers read data live so a late fetch will
be seen by the next event, but a call already in-flight will time
out.

### "Could not create a sandbox extension for '.app'"

WebKit noise, benign. Emitted when WKWebView's Networking process
preemptively requests a bundle-path extension. Doesn't affect the
WebView. See [README's launch-log breakdown](./README.md#).

### GPU / WebContent / Networking process took N seconds

WKWebView spawns three XPC helpers on first use. Cold-launch cost.
To warm-start, instantiate a hidden `WKWebView` at app launch and
`loadHTMLString("", baseURL: nil)`.

### Call stalls at "Connecting" / `-105 DNS` errors

WebRTC DNS failure resolving `*.livekit.cloud`. Real-device issues:

1. Turn off *Settings → Network → Private DNS* (or set to Automatic)
2. Update the Bambuser system WebView / iOS system components
3. Try mobile data if on restrictive Wi-Fi

Verified working: `curl https://bambuser-calls.turn.livekit.cloud`
resolves.

### Widget UI never appears despite call showing as connected

Check the diagnostic backgrounds in `BambuserCallOverlay.swift` — set
`DEBUG_BACKGROUNDS = true` to tint the overlay red, the WebView frame
blue, and the WebView yellow. If you see red only, the SwiftUI frame
didn't size. If red + blue, the WebView is mounted but content isn't
loading. If yellow, the WebView loaded HTML but the embed didn't render
(check for `JS[E]` errors in the log).

### "callState never advances past connecting"

Watch the log for `JS[I]` and `JS[E]` messages — the embed logs its
own state transitions there. Common causes: bad `orgId`, wrong region
(`.us` vs `.eu`), no agents online.

---

For the SDK-side wire protocol details (how each JS `.on(...)` maps
to a native event, and how the emitter override works), see comments
in `Sources/BambuserCallsShopper/Internal/EmbedHTMLBuilder.swift`.
