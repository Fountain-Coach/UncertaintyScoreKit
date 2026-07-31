import Foundation

/// The minimum stable identity of one uncertainty mark.
///
/// Note IDs are local to their producer lane. A consumer must carry both parts when it selects, persists,
/// exposes, or routes a note; wording is presentation and is never identity.
public struct UncertaintyAddress: Codable, Hashable, Sendable, Identifiable, CustomStringConvertible {
    public let laneID: String
    public let noteID: String

    public init(laneID: String, noteID: String) {
        self.laneID = laneID
        self.noteID = noteID
    }

    public var id: String { Self.id(laneID: laneID, noteID: noteID) }

    /// Stable, human-readable machine identity. The components are length-prefixed so delimiter characters in
    /// producer IDs cannot make two addresses collide.
    public static func id(laneID: String, noteID: String) -> String {
        "uncertainty-address-\(laneID.utf8.count)-\(laneID)-\(noteID.utf8.count)-\(noteID)"
    }

    public var description: String { "\(laneID)::\(noteID)" }
}

public extension UncertaintyScore {
    func address(for note: UncertaintyNote, in lane: UncertaintyLane) -> UncertaintyAddress {
        UncertaintyAddress(laneID: lane.id, noteID: note.id)
    }

    func note(for address: UncertaintyAddress) -> UncertaintyNote? {
        lane(id: address.laneID)?.notes.first { $0.id == address.noteID }
    }

    func lane(for address: UncertaintyAddress) -> UncertaintyLane? {
        lane(id: address.laneID)
    }

    var addresses: [UncertaintyAddress] {
        lanes.flatMap { lane in lane.notes.map { UncertaintyAddress(laneID: lane.id, noteID: $0.id) } }
    }
}
