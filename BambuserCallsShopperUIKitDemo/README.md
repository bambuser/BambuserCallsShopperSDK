# BambuserCallsShopperUIKitDemo

UIKit twin of `BambuserCallsShopperDemo`. Same product catalogue, cart, and expert-call flow, but built on `UIViewController`s and demonstrating the SDK's UIKit adapter (`BambuserCallWindowPresenter`) instead of dropping `BambuserCallOverlay` into a SwiftUI `ZStack`.

## Configure

Open `BambuserCallsShopperUIKitDemo/App/DemoConfiguration.swift` and set `orgId`:

```swift
static let orgId: String = "YOUR_BAMBUSER_ORG_ID"
```

## Generate the Xcode project

```bash
brew install xcodegen        # one-time
cd BambuserCallsShopperUIKitDemo
xcodegen
open BambuserCallsShopperUIKitDemo.xcodeproj
```

The `project.yml` wires the local Swift package (`../Package.swift`) as a `BambuserCalls-shopper` dependency, so no manual "Add Package…" step is needed.

## Run

Select a real iPhone (recommended — the camera/mic behave properly), press ▶︎.

- Products tab → tap a product → **Talk to expert** starts the widget.
- When the widget flips to PiP, taps around the mini-player fall through to the underlying UIKit navigation — that's the passthrough hit-testing in `BambuserCallWindowPresenter` doing its job.

## How the overlay is presented

`SceneDelegate.scene(_:willConnectTo:options:)` does three things:

1. Builds the main `UIWindow` with `RootTabBarController` as root.
2. Configures `BambuserCallBridge` (delegate + data-source handlers) on the shared `BambuserCallController`.
3. Calls `BambuserCallWindowPresenter.attach(to: windowScene)` — this creates a second `PassthroughWindow` above the app, hosting `BambuserCallOverlay`. Empty regions pass through to the main window, so the tab bar and PDPs stay tappable while the widget is in PiP.

If you prefer to keep the overlay inline on a single screen (rather than a global window), swap the presenter for `BambuserCallHostView` — see the SDK-level UIKit adapter docs.

## Manual Xcode setup (fallback if xcodegen isn't available)

1. Xcode → **File → New → Project… → iOS App**. Language Swift, Interface Storyboard, Life Cycle UIKit App Delegate. Name it `BambuserCallsShopperUIKitDemo`.
2. Delete the generated `Main.storyboard`, `ViewController.swift`, `AppDelegate.swift`, `SceneDelegate.swift`. Remove the `Main storyboard file base name` entry from Info.plist.
3. Drag the `BambuserCallsShopperUIKitDemo/` folder from Finder into the project (Copy items if needed **off**, Create groups).
4. **File → Add Package Dependency…** → **Add Local…** → pick the SDK root folder → add `BambuserCalls-shopper` to the app target.
5. Add camera + mic usage descriptions to Info.plist (already set in the tracked one).
6. Set the target deployment to iOS 16, build & run.
