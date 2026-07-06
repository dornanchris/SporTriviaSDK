import Foundation
import CoreLocation

/// Captures the device location for game-result uploads.
///
/// Flow: `requestPermissionAndWarmUp()` fires the when-in-use permission
/// prompt on the player-info screen and starts acquiring a GPS fix, so by
/// the time the game ends `capture(timeout:)` usually returns instantly.
/// Location is strictly best-effort — a denial, a missing Info.plist usage
/// string in the host app, or a slow fix never blocks or fails the upload.
final class LocationService: NSObject, LocationProviding, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var latestFix: LocationFix?
    private var settledStatus: LocationStatus?
    private var waiters: [(LocationResult) -> Void] = []
    private var warmedUp = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - LocationProviding

    func requestPermissionAndWarmUp() {
        guard !warmedUp else { return }
        warmedUp = true

        // Without the usage string the OS silently ignores the permission
        // request — surface that to the integrating developer once.
        guard Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil else {
            SporTriviaLogger.warning(
                "NSLocationWhenInUseUsageDescription is missing from the app's Info.plist — "
                + "location will not be captured with game results (see PARTNER_SETUP.md)"
            )
            settle(.unavailable)
            return
        }

        // Note: we intentionally do NOT call CLLocationManager.locationServicesEnabled()
        // here — it does synchronous IPC that blocks the main thread (Apple warns
        // against it and it caused a visible hang). The authorization request and
        // the delegate's didFailWithError path handle services-off gracefully.
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            settle(.denied)
        @unknown default:
            settle(.unavailable)
        }
    }

    func capture(timeout: TimeInterval) async -> LocationResult {
        if let fix = latestFix {
            return .granted(fix)
        }
        if let status = settledStatus, status != .granted {
            return LocationResult(status: status, fix: nil)
        }

        // Permission granted (or prompt still showing) but no fix yet — wait
        // for the delegate or the timeout, whichever comes first.
        return await withCheckedContinuation { continuation in
            let box = ResumeOnce(continuation)
            DispatchQueue.main.async {
                self.waiters.append { result in box.resume(result) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                let hasPermission = self.manager.authorizationStatus == .authorizedWhenInUse
                    || self.manager.authorizationStatus == .authorizedAlways
                box.resume(hasPermission ? .timedOut : .unavailable)
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            settle(.denied)
        case .notDetermined:
            break
        @unknown default:
            settle(.unavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let fix = LocationFix(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracyMeters: location.horizontalAccuracy,
            capturedAt: LocationService.utcFormatter.string(from: location.timestamp)
        )
        latestFix = fix
        settledStatus = .granted
        let pending = waiters
        waiters = []
        pending.forEach { $0(.granted(fix)) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        SporTriviaLogger.warning("Location capture failed: \(error.localizedDescription) — uploading without location")
        // Keep any earlier fix; only settle as unavailable when we have nothing.
        if latestFix == nil && settledStatus == nil {
            settle(.unavailable)
        }
    }

    // MARK: - Helpers

    private func settle(_ status: LocationStatus) {
        settledStatus = status
        let pending = waiters
        waiters = []
        pending.forEach { $0(LocationResult(status: status, fix: nil)) }
    }

    static let utcFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

/// Guards a CheckedContinuation so competing resume paths (fix delivered vs
/// timeout) can both call it safely.
private final class ResumeOnce {
    private var continuation: CheckedContinuation<LocationResult, Never>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<LocationResult, Never>) {
        self.continuation = continuation
    }

    func resume(_ result: LocationResult) {
        lock.lock()
        let target = continuation
        continuation = nil
        lock.unlock()
        target?.resume(returning: result)
    }
}
