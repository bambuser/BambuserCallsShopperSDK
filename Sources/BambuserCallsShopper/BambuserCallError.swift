//
//  BambuserCallError.swift
//  BambuserCallsShopper
//

import Foundation

/// Errors surfaced via `BambuserCallDelegate.bambuserCall(_:didEncounter:)`.
public enum BambuserCallError: Error {

    /// A native → JS `evaluateJavaScript` call failed.
    case javaScriptEvaluationFailed(operation: String, underlying: Error)

    /// An incoming event from the embed couldn't be parsed. Event is dropped.
    case invalidEventPayload(eventName: String, reason: String)
}
