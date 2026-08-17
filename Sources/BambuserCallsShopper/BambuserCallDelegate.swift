//
//  BambuserCallDelegate.swift
//  BambuserCallsShopper
//
//  Fire-and-forget notification bridge. Assign a delegate to
//  `controller.delegate` and switch on `BambuserCallEvent` for the
//  events you care about. `didEncounter` is the error channel; it has
//  a no-op default so hosts implement it only when they want to log
//  or surface errors.
//
//  For events where the SDK needs a value back (product hydration,
//  search results, cart resolution), use `BambuserCallHandlers`.
//

import Foundation

@MainActor
public protocol BambuserCallDelegate: AnyObject {

    /// Single stream. Every fire-and-forget event the SDK emits comes
    /// through here as a `BambuserCallEvent` case — switch on the
    /// case and handle what you care about.
    func bambuserCall(
        _ controller: BambuserCallController,
        didEmit event: BambuserCallEvent
    )

    /// Non-fatal SDK errors (JS eval failures, malformed payloads,
    /// etc.). Default: no-op.
    func bambuserCall(
        _ controller: BambuserCallController,
        didEncounter error: BambuserCallError
    )
}

public extension BambuserCallDelegate {
    func bambuserCall(
        _ controller: BambuserCallController,
        didEncounter error: BambuserCallError
    ) {}
}
