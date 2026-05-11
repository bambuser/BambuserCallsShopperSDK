//
//  BambuserCallDelegate.swift
//  BambuserCallsShopper
//

import Foundation

/// Host-side bridge for a `BambuserCallController`. Two methods:
///
///  • `bambuserCall(_:didEmit:)` — the event stream. Required.
///  • `bambuserCall(_:didEncounterError:)` — the error channel. Optional
///    (has a no-op default).
@MainActor
public protocol BambuserCallDelegate: AnyObject {

    /// Every event the framework recognizes is delivered here. See
    /// `BambuserCallEvent` for the case list.
    func bambuserCall(
        _ controller: BambuserCallController,
        didEmit event: BambuserCallEvent
    )

    /// Errors the framework couldn't quietly absorb. Hosts can log these
    /// for debugging or surface them in UI.
    func bambuserCall(
        _ controller: BambuserCallController,
        didEncounterError error: BambuserCallError
    )
}

public extension BambuserCallDelegate {
    func bambuserCall(
        _ controller: BambuserCallController,
        didEncounterError error: BambuserCallError
    ) {}
}
