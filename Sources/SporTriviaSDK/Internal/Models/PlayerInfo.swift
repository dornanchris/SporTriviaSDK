import Foundation

/// Represents a player with their ID, name, and years active.
public class PlayerInfo: Codable, Hashable, Identifiable {
    public var playerId: String
    public var playerName: String
    public var yearsPlayed: String

    public var id: String { playerId }

    public init(playerId: String, playerName: String, yearsPlayed: String) {
        self.playerId = playerId
        self.playerName = playerName
        self.yearsPlayed = yearsPlayed
    }

    public static func == (lhs: PlayerInfo, rhs: PlayerInfo) -> Bool {
        return lhs.playerId == rhs.playerId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(playerId)
    }
}
