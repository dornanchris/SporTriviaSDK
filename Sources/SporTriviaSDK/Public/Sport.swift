import Foundation

/// Supported sports/leagues in SporTrivia.
public enum Sport: String, Codable, CaseIterable, Sendable {
    case mlb
    case nba
    case nfl
    case nhl
    case ahl
    case echl

    /// Human-readable display name for the sport.
    public var displayName: String {
        switch self {
        case .mlb: return "Baseball"
        case .nba: return "Basketball"
        case .nfl: return "Football"
        case .nhl: return "Hockey"
        case .ahl: return "AHL Hockey"
        case .echl: return "ECHL Hockey"
        }
    }

    /// The league identifier used in S3 paths (uppercase).
    var leagueKey: String {
        rawValue.uppercased()
    }

    /// The sport category used in S3 image paths.
    var sportCategory: String {
        switch self {
        case .mlb: return "baseball"
        case .nba: return "basketball"
        case .nfl: return "football"
        case .nhl, .ahl, .echl: return "hockey"
        }
    }
}
