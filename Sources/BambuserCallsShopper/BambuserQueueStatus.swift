//
//  BambuserQueueStatus.swift
//  BambuserCallsShopper
//
//  Strongly-typed *convenience* payloads for the queue-status events
//  and async queue-query methods. Each struct also carries a `raw`
//  field so hosts can read fields the SDK doesn't surface as typed
//  properties — including anything Bambuser adds later.
//
//  See https://bambuser.com/docs/video-consultation/queue-status/
//

import Foundation

/// Queue open/closed snapshot delivered by `queue-is-open` and
/// `queue-is-closed`, and returned by `areQueuesOpen()`.
public struct BambuserQueueOpenState: Equatable, Sendable {

    public let isOpen: Bool

    /// ISO-8601 timestamp of the next scheduled open. `nil` when queues
    /// are always open or the schedule isn't known.
    public let nextOpenTime: Date?

    /// ISO-8601 timestamp of the next scheduled close.
    public let nextCloseTime: Date?

    /// The full unmodified JSON payload from the embed. Read this for
    /// any field the SDK doesn't surface as a typed property.
    public let raw: BambuserJSONValue

    public init(
        isOpen: Bool,
        nextOpenTime: Date? = nil,
        nextCloseTime: Date? = nil,
        raw: BambuserJSONValue = .null
    ) {
        self.isOpen = isOpen
        self.nextOpenTime = nextOpenTime
        self.nextCloseTime = nextCloseTime
        self.raw = raw
    }
}

/// Payload of `agents-online` and the `getNumberOfOnlineAgents()`
/// reply.
public struct BambuserAgentsOnline: Equatable, Sendable {

    public let numberOfAgentsOnline: Int
    public let queueId: String?

    /// Full unmodified JSON payload from the embed.
    public let raw: BambuserJSONValue

    public init(
        numberOfAgentsOnline: Int,
        queueId: String? = nil,
        raw: BambuserJSONValue = .null
    ) {
        self.numberOfAgentsOnline = numberOfAgentsOnline
        self.queueId = queueId
        self.raw = raw
    }
}

/// Payload of `queue-estimated-waiting-time` and
/// `getEstimatedWaitingTime()`.
public struct BambuserQueueWaitingTime: Equatable, Sendable {

    /// Estimated seconds a new shopper would wait before being connected.
    public let estimatedWaitingTime: Int

    /// Total online agents currently serving the queue.
    public let agents: Int

    /// Place this shopper would take after joining the queue
    /// (`current line length + 1`).
    public let place: Int

    public let queueId: String?

    /// Full unmodified JSON payload from the embed.
    public let raw: BambuserJSONValue

    public init(
        estimatedWaitingTime: Int,
        agents: Int,
        place: Int,
        queueId: String? = nil,
        raw: BambuserJSONValue = .null
    ) {
        self.estimatedWaitingTime = estimatedWaitingTime
        self.agents = agents
        self.place = place
        self.queueId = queueId
        self.raw = raw
    }
}
