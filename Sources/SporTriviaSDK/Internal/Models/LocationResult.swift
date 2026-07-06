import Foundation

/// A single captured device location.
struct LocationFix: Equatable {
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    /// UTC timestamp of the fix, formatted like `submitted_at`.
    let capturedAt: String
}

/// Outcome of a location capture attempt — mirrors the `location_status`
/// values in the upload schema.
enum LocationStatus: String {
    case granted
    case denied
    case unavailable
    case timeout
}

/// Result handed to the upload formatter. `fix` is non-nil iff `status`
/// is `.granted`.
struct LocationResult: Equatable {
    let status: LocationStatus
    let fix: LocationFix?

    static let unavailable = LocationResult(status: .unavailable, fix: nil)
    static let denied = LocationResult(status: .denied, fix: nil)
    static let timedOut = LocationResult(status: .timeout, fix: nil)

    static func granted(_ fix: LocationFix) -> LocationResult {
        LocationResult(status: .granted, fix: fix)
    }
}

/// Abstraction over location capture so game logic and the JSON formatter
/// stay CoreLocation-free (and unit-testable off-device).
protocol LocationProviding: AnyObject {
    /// Ask for when-in-use permission (if needed) and start acquiring a fix.
    /// Called when the player-info screen (or the game, when there is no
    /// info screen) appears, so a fix is usually ready by upload time.
    func requestPermissionAndWarmUp()

    /// Best-effort capture: returns immediately when a fix or a definite
    /// denial is known, otherwise waits up to `timeout` seconds. Never throws.
    func capture(timeout: TimeInterval) async -> LocationResult
}
