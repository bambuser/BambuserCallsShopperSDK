//
//  BambuserQueueStatus.swift
//  BambuserCallsShopper
//

import Foundation

/// Queue open/closed snapshot delivered by `queue-is-open` /
/// `queue-is-closed` and returned by `areQueuesOpen()`.
public struct BambuserQueueOpenState: Equatable, Sendable {

    public let isOpen: Bool

    /// Next scheduled open. `nil` when queues are always open or
    /// the schedule isn't known.
    public let nextOpenTime: Date?

    /// Next scheduled close.
    public let nextCloseTime: Date?

    /// Full unmodified JSON payload — read any field the SDK doesn't
    /// surface as a typed property.
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

/// Payload of `agents-online` and `getNumberOfOnlineAgents()`.
public struct BambuserAgentsOnline: Equatable, Sendable {

    public let numberOfAgentsOnline: Int
    public let queueId: String?
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

    /// Estimated seconds until a new shopper is connected.
    public let estimatedWaitingTime: Int

    /// Total online agents serving the queue.
    public let agents: Int

    /// Place a new shopper would take after joining.
    public let place: Int

    public let queueId: String?
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
