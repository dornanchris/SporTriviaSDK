import Foundation

/// Represents a player with their ID, name, and years active.
public class PlayerInfo: Codable, Hashable, Identifiable {
    public var playerId: String
    public var playerName: String
    public var yearsPlayed: String

    /// Search key computed once at construction — autocomplete compares
    /// against this instead of re-normalizing 20k+ names per keystroke.
    let normalizedName: String

    public var id: String { playerId }

    public init(playerId: String, playerName: String, yearsPlayed: String) {
        self.playerId = playerId
        self.playerName = playerName
        self.yearsPlayed = yearsPlayed
        self.normalizedName = PlayerInfo.normalize(playerName)
    }

    /// Lowercased, diacritic-insensitive, alphanumerics only
    /// ("José Peña" → "josepena").
    static func normalize(_ string: String) -> String {
        return string
            .folding(options: .diacriticInsensitive, locale: nil)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    // MARK: - Codable (normalizedName is derived, not part of the coded shape)

    enum CodingKeys: String, CodingKey {
        case playerId
        case playerName
        case yearsPlayed
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try container.decode(String.self, forKey: .playerId)
        playerName = try container.decode(String.self, forKey: .playerName)
        yearsPlayed = try container.decode(String.self, forKey: .yearsPlayed)
        normalizedName = PlayerInfo.normalize(playerName)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(playerId, forKey: .playerId)
        try container.encode(playerName, forKey: .playerName)
        try container.encode(yearsPlayed, forKey: .yearsPlayed)
    }

    public static func == (lhs: PlayerInfo, rhs: PlayerInfo) -> Bool {
        return lhs.playerId == rhs.playerId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(playerId)
    }
}
