//
//  BambuserEnvironment.swift
//  BambuserCallsShopper
//
//  Which Bambuser embed the SDK talks to. Hosts pick a region on the
//  configuration; the SDK holds the URL.
//

import Foundation

/// A Bambuser region. The embed URL for each region is hard-coded in
/// the SDK so hosts pick a value (`.us` or `.eu`), not a URL.
///
/// `.custom(URL)` exists for local development against a self-hosted
/// or forked embed. It is a struct static so extensions can add more
/// (e.g. an internal `.stageUS` provided by a build-local overlay
/// file that isn't committed to git).
public struct BambuserEnvironment: Sendable, Equatable {

    public let embedURL: URL

    public init(embedURL: URL) {
        self.embedURL = embedURL
    }

    /// Global / US production servers. Use this if your BamHub is on
    /// `https://lcx.bambuser.com/`.
    public static let us = BambuserEnvironment(
        embedURL: URL(string: "https://one-to-one.bambuser.com/embed.js")!
    )

    /// EU production servers. Use this if your BamHub is on
    /// `https://lcx-eu.bambuser.com/`.
    public static let eu = BambuserEnvironment(
        embedURL: URL(string: "https://one-to-one.bambuser.com/eu/embed.js")!
    )

    #if DEBUG
    /// Bambuser-internal staging on the US region. **Debug-only** —
    /// wrapped in `#if DEBUG` so the URL is stripped from release
    /// builds and never ships in a published binary.
    ///
    /// Not for merchant use.
    public static let stageUS = BambuserEnvironment(
        embedURL: URL(string: "https://lvs-121-dev.web.app/embed.js")!
    )
    #endif
}
