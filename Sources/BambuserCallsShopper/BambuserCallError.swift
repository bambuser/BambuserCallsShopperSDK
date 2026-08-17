//
//  BambuserCallError.swift
//  BambuserCallsShopper
//

import Foundation

/// Errors the framework surfaces via
/// `BambuserCallDelegate.bambuserCall(_:didEncounter:)`. Hosts can log
/// or surface them; otherwise the framework continues to no-op
/// internally.
public enum BambuserCallError: Error {

    /// A native → JS `evaluateJavaScript` call failed. `operation` is a
    /// short tag identifying which outbound call (e.g.
    /// `"notifyProductNavigation('1234')"`).
    case javaScriptEvaluationFailed(operation: String, underlying: Error)

    /// An incoming event from the embed couldn't be parsed into the
    /// expected payload shape. The event is dropped rather than emitted
    /// in a malformed form.
    case invalidEventPayload(eventName: String, reason: String)
}
