import Foundation

/// Handles all S3 data operations via the credential provider (no AWS SDK dependency).
class S3DataService {
    private let credentialProvider: SporTriviaCredentialProvider
    private let bucketName: String

    init(credentialProvider: SporTriviaCredentialProvider, bucketName: String) {
        self.credentialProvider = credentialProvider
        self.bucketName = bucketName
    }

    /// Download data from S3 using a presigned GET URL.
    func download(key: String) async throws -> Data {
        SporTriviaLogger.debug("Requesting presigned GET URL for: \(key)")
        let url: URL
        do {
            url = try await credentialProvider.presignedGetURL(forKey: key)
            SporTriviaLogger.debug("Got presigned URL: \(url.absoluteString.prefix(80))...")
        } catch {
            SporTriviaLogger.error("Credential provider failed for GET '\(key)': \(error)")
            throw error
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            SporTriviaLogger.error("No HTTP response for: \(key)")
            throw S3DataServiceError.downloadFailed(key: key)
        }

        guard httpResponse.statusCode == 200 else {
            SporTriviaLogger.error("Download failed for '\(key)': HTTP \(httpResponse.statusCode), body: \(String(data: data.prefix(200), encoding: .utf8) ?? "n/a")")
            throw S3DataServiceError.downloadFailed(key: key, statusCode: httpResponse.statusCode)
        }

        SporTriviaLogger.info("Downloaded '\(key)' (\(data.count) bytes)")
        return data
    }

    /// Upload data to S3 using a presigned PUT URL.
    func upload(key: String, data: Data) async throws {
        SporTriviaLogger.debug("Requesting presigned PUT URL for: \(key)")
        let url = try await credentialProvider.presignedPutURL(forKey: key)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            SporTriviaLogger.error("Upload failed for '\(key)': HTTP \(code)")
            throw S3DataServiceError.uploadFailed(key: key)
        }
        SporTriviaLogger.info("Uploaded '\(key)' (\(data.count) bytes)")
    }

    /// Download a custom answer key JSON from S3.
    func downloadAnswerKey(customFileName: String) async throws -> AnswerKey {
        let key = "answer_keys/custom/\(customFileName).json"
        SporTriviaLogger.info("Loading answer key: \(key)")
        let data = try await download(key: key)
        do {
            let answerKey = try JSONDecoder().decode(AnswerKey.self, from: data)
            SporTriviaLogger.info("Answer key parsed: combo=\(answerKey.combo), \(answerKey.player_id.count) player IDs, question=\(answerKey.question ?? "none")")
            return answerKey
        } catch {
            SporTriviaLogger.error("Failed to parse answer key JSON: \(error). Raw data: \(String(data: data.prefix(300), encoding: .utf8) ?? "n/a")")
            throw error
        }
    }

    /// Download the player list for a given sport. Parsing is lenient —
    /// malformed records are skipped, never the whole list (see
    /// JsonParser.parsePlayerList).
    func downloadPlayerList(sport: Sport) async throws -> [PlayerInfo] {
        let key = "answer_keys/\(sport.rawValue)/all_\(sport.rawValue)_players.json"
        SporTriviaLogger.info("Loading player list: \(key)")
        let data = try await download(key: key)
        return try JsonParser.parsePlayerList(from: data)
    }

    /// Download a team image from S3.
    func downloadTeamImage(sport: Sport, teamAbbr: String) async throws -> Data {
        let key = "team_images/\(sport.sportCategory)/\(sport.leagueKey)/\(teamAbbr).png"
        return try await download(key: key)
    }

    /// Upload custom game results to the response path embedded in the answer key.
    func uploadGameResults(responsePath: String, resultData: Data) async throws {
        var folderPath = responsePath
        while folderPath.hasSuffix("/") {
            folderPath = String(folderPath.dropLast())
        }
        let key = "\(folderPath)/\(UUID().uuidString).json"
        try await upload(key: key, data: resultData)
    }

    /// Upload custom game results to S3 (legacy path derivation, used when the
    /// answer key predates the embedded response_path).
    func uploadGameResults(sport: Sport, teamName: String, suffix: String, resultData: Data) async throws {
        let folderPath = "custom/\(sport.leagueKey)/\(teamName)/\(suffix)"
        let fileName = UUID().uuidString + ".json"
        let key = "\(folderPath)/\(fileName)"
        try await upload(key: key, data: resultData)
    }
}

enum S3DataServiceError: LocalizedError {
    case downloadFailed(key: String, statusCode: Int = -1)
    case uploadFailed(key: String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let key, let code):
            if code > 0 {
                return "Failed to download '\(key)' (HTTP \(code)). Check that your credential provider returns valid presigned URLs."
            }
            return "Failed to download '\(key)'. Check your credential provider and network connection."
        case .uploadFailed(let key):
            return "Failed to upload to '\(key)'. Check your credential provider's presignedPutURL."
        }
    }
}
