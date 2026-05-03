import UIKit

/// Caches team images downloaded from S3 to disk and memory.
class ImageCache {
    private let s3Service: S3DataService
    private var memoryCache: [String: UIImage] = [:]
    private let cacheDirectory: URL

    init(s3Service: S3DataService) {
        self.s3Service = s3Service

        // Use a dedicated SDK subdirectory to avoid conflicts with the host app
        let cacheBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cacheBase.appendingPathComponent("SporTriviaSDK/TeamImages")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Get a team image, loading from memory cache, disk cache, or S3.
    func teamImage(sport: Sport, teamAbbr: String) async -> UIImage? {
        let cacheKey = "\(sport.leagueKey)/\(teamAbbr)"

        // Check memory cache
        if let cached = memoryCache[cacheKey] {
            return cached
        }

        // Check disk cache
        let diskPath = cacheDirectory
            .appendingPathComponent(sport.leagueKey, isDirectory: true)
            .appendingPathComponent("\(teamAbbr).png")

        if let data = try? Data(contentsOf: diskPath), let image = UIImage(data: data) {
            memoryCache[cacheKey] = image
            return image
        }

        // Download from S3
        do {
            let data = try await s3Service.downloadTeamImage(sport: sport, teamAbbr: teamAbbr)
            if let image = UIImage(data: data) {
                memoryCache[cacheKey] = image

                // Save to disk
                let leagueDir = cacheDirectory.appendingPathComponent(sport.leagueKey, isDirectory: true)
                try? FileManager.default.createDirectory(at: leagueDir, withIntermediateDirectories: true)
                try? data.write(to: diskPath)

                return image
            }
        } catch {
            print("SporTriviaSDK: Failed to download team image for \(teamAbbr): \(error)")
        }

        return nil
    }
}
