import Foundation

/// Parses JSON data structures used by the SDK.
enum JsonParser {

    /// Parse a custom answer key from raw JSON data.
    static func parseAnswerKey(from data: Data) throws -> AnswerKey {
        return try JSONDecoder().decode(AnswerKey.self, from: data)
    }

    /// Parse a player list from raw JSON data (the all_{sport}_players.json format).
    ///
    /// Uses `JSONSerialization` + dictionary access so it matches the Android
    /// SDK's parser field-for-field (`JsonParser.parsePlayerList`): tolerant of
    /// String-or-number `player_id`/seasons, accepts the name under either
    /// `Player` (older files) or `name` (the live MLB/NBA/NFL files), and skips
    /// only the individual record that lacks an id or name — never the whole
    /// list. A previous strict-`Codable` version was the one iOS/Android
    /// divergence that could leave autocomplete empty.
    static func parsePlayerList(from data: Data) throws -> [PlayerInfo] {
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            SporTriviaLogger.warning("Player list JSON was not an array of objects — autocomplete suggestions will be empty")
            return []
        }
        var seen: [String: PlayerInfo] = [:]
        var skipped = 0
        for object in array {
            let playerId = stringValue(object["player_id"]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Prefer the legacy "Player" key, fall back to "name".
            let rawName = stringValue(object["Player"]).isEmpty ? stringValue(object["name"]) : stringValue(object["Player"])
            let playerName = rawName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\u{00c2}", with: "")
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "?", with: "")
            guard !playerId.isEmpty, !playerName.isEmpty else {
                skipped += 1
                continue
            }
            let firstSeason = stringValue(object["first_season"]).replacingOccurrences(of: ".0", with: "")
            let lastSeason = stringValue(object["last_season"]).replacingOccurrences(of: ".0", with: "")
            let yearsPlayed = [firstSeason, lastSeason].filter { !$0.isEmpty }.joined(separator: "-")
            // Dedup by id (last one wins), matching Android's HashMap.
            seen[playerId] = PlayerInfo(playerId: playerId, playerName: playerName, yearsPlayed: yearsPlayed)
        }
        if skipped > 0 {
            SporTriviaLogger.warning("Skipped \(skipped) player records with no id/name")
        }
        SporTriviaLogger.info("Parsed \(seen.count) players from list")
        return Array(seen.values)
    }

    /// String coercion mirroring Android's `String.valueOf(obj.get(...))`:
    /// strings pass through; whole numbers render without a decimal; null/
    /// missing/other becomes "".
    private static func stringValue(_ value: Any?) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            // Distinguish real doubles from ints so 1926 → "1926", not "1926.0".
            if CFNumberIsFloatType(number), number.doubleValue != number.doubleValue.rounded() {
                return number.stringValue
            }
            return String(number.int64Value)
        default:
            return ""
        }
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
        // Pretty-printed (one field per line) for human-readable exports; key
        // order and content match the Android SDK byte-for-content.
        return payload.serializedData(pretty: true)
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
