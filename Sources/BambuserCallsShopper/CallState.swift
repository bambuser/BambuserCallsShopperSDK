//
//  CallState.swift
//  BambuserCallsShopper
//

import Foundation

/// Lifecycle of a one-to-one call. `connecting` and `connected` are both
/// "active" (an expert is or will be on the other end); `idle` and `ended`
/// are not.
public enum CallState: Equatable, Sendable {
    case idle
    case connecting
    case connected
    case ended
}
