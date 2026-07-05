import Foundation

/// Parses JSON data structures used by the SDK.
enum JsonParser {

    /// Parse a custom answer key from raw JSON data.
    static func parseAnswerKey(from data: Data) throws -> AnswerKey {
        return try JSONDecoder().decode(AnswerKey.self, from: data)
    }

    /// Parse a player list from raw JSON data (the all_{sport}_players.json format).
    ///
    /// Individual malformed records (null seasons, missing names) are skipped
    /// instead of failing the whole list — one bad row in a 20k+ player file
    /// must not disable autocomplete for the entire sport.
    static func parsePlayerList(from data: Data) throws -> [PlayerInfo] {
        let decoded = try JSONDecoder().decode([FailableDecodable<PlayerData>].self, from: data)
        var skipped = 0
        let players: [PlayerInfo] = decoded.compactMap { wrapper in
            guard let pd = wrapper.value else {
                skipped += 1
                return nil
            }
            let playerId = pd.player_id.trimmingCharacters(in: .whitespacesAndNewlines)
            let playerName = pd.playerName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\u{00c2}", with: "")
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "?", with: "")
            guard !playerId.isEmpty, !playerName.isEmpty else {
                skipped += 1
                return nil
            }
            let seasons = [pd.first_season, pd.last_season].filter { !$0.isEmpty }
            return PlayerInfo(
                playerId: playerId,
                playerName: playerName,
                yearsPlayed: seasons.joined(separator: "-").replacingOccurrences(of: ".0", with: "")
            )
        }
        if skipped > 0 {
            SporTriviaLogger.warning("Skipped \(skipped) unparseable player records (kept \(players.count))")
        }
        return deduplicate(players)
    }

    /// Remove duplicate players by playerId.
    static func deduplicate(_ players: [PlayerInfo]) -> [PlayerInfo] {
        var seen: [String: PlayerInfo] = [:]
        for player in players {
            seen[player.playerId] = player
        }
        return Array(seen.values)
    }

    /// Format game results as JSON for S3 upload — schema v2.
    ///
    /// The schema is a cross-platform contract with partners: the iOS and
    /// Android SDKs (and the first-party apps) emit the SAME keys in the
    /// SAME order, documented in PARTNER_SETUP.md. Serialized with
    /// OrderedJsonWriter because JSONSerialization cannot guarantee order.
    static func formatGameResults(
        userInfo: SporTriviaUserInfo,
        gameId: String,
        correctPlayers: [PlayerInfo],
        location: LocationResult = .unavailable
    ) throws -> Data {
        let fullName = [userInfo.firstName, userInfo.lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let answersFound = correctPlayers.map { player -> String in
            player.yearsPlayed.isEmpty ? player.playerName : "\(player.playerName) \(player.yearsPlayed)"
        }

        // Alphabetical key order keeps custom answers deterministic across
        // platforms (the source dictionaries are unordered on both).
        let customFieldAnswers: [(String, JsonValue)] = userInfo.customFieldAnswers
            .sorted { $0.key < $1.key }
            .map { ($0.key, .string($0.value)) }

        let correctAnswers: [JsonValue] = correctPlayers.map { player in
            .object([
                ("player_id", .string(player.playerId)),
                ("player_name", .string(player.playerName)),
                ("years_played", .string(player.yearsPlayed)),
            ])
        }

        let locationValue: JsonValue
        if let fix = location.fix {
            locationValue = .object([
                ("latitude", .double(fix.latitude)),
                ("longitude", .double(fix.longitude)),
                ("accuracy_meters", .double(fix.accuracyMeters)),
                ("captured_at", .string(fix.capturedAt)),
            ])
        } else {
            locationValue = .null
        }

        let payload = JsonValue.object([
            ("schema_version", .int(2)),
            ("game_id", .string(gameId)),
            ("submitted_at", .string(utcTimestampFormatter.string(from: Date()))),
            ("platform", .string("ios")),
            ("source", .string("sdk")),
            ("sdk_version", .string(SporTriviaSDK.sdkVersion)),
            ("first_name", .string(userInfo.firstName)),
            ("last_name", .string(userInfo.lastName)),
            ("name", .string(fullName)),
            ("email", .string(userInfo.email)),
            ("phone", .string(userInfo.phoneNumber)),
            ("over_18", .bool(userInfo.over18)),
            ("custom_field_answers", .object(customFieldAnswers)),
            ("answers_found", .array(answersFound.map { .string($0) })),
            ("correct_answers", .array(correctAnswers)),
            ("location", locationValue),
            ("location_status", .string(location.status.rawValue)),
        ])
        return payload.serializedData()
    }

    /// UTC timestamp matching the Android SDK byte-for-byte
    /// (yyyy-MM-dd'T'HH:mm:ss'Z', no fractional seconds).
    static let utcTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

/// Decodes to nil instead of throwing, so one malformed element cannot fail
/// an entire array decode.
struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}
