//
//  BambuserCallDelegate.swift
//  BambuserCallsShopper
//

import Foundation

/// Receives fire-and-forget events from the call widget. For events
/// where the SDK needs a value back (product hydration, search results,
/// cart resolution), use `BambuserCallHandlers`.
@MainActor
public protocol BambuserCallDelegate: AnyObject {

    /// Fires for every `BambuserCallEvent` the SDK emits.
    func bambuserCall(
        _ controller: BambuserCallController,
        didEmit event: BambuserCallEvent
    )

    /// Non-fatal SDK errors. Default: no-op.
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
