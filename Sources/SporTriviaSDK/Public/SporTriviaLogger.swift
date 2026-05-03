import Foundation

/// Log levels for SDK debug output.
public enum SporTriviaLogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case none = 4

    public static func < (lhs: SporTriviaLogLevel, rhs: SporTriviaLogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var prefix: String {
        switch self {
        case .debug:   return "\u{1f50d} [DEBUG]"
        case .info:    return "\u{2139}\u{fe0f} [INFO]"
        case .warning: return "\u{26a0}\u{fe0f} [WARN]"
        case .error:   return "\u{274c} [ERROR]"
        case .none:    return ""
        }
    }
}

/// Logging system for the SporTrivia SDK.
///
/// By default, logs go to `print()` at `.warning` level and above.
/// Host apps can customize both the log level and the output handler:
///
/// ```swift
/// // See everything the SDK does:
/// SporTriviaLogger.logLevel = .debug
///
/// // Route SDK logs to your own logging system:
/// SporTriviaLogger.logHandler = { level, message in
///     MyLogger.log("SporTriviaSDK [\(level)]: \(message)")
/// }
/// ```
public final class SporTriviaLogger {

    /// Minimum log level to emit. Set to `.debug` to see everything.
    /// Default is `.warning`.
    public static var logLevel: SporTriviaLogLevel = .warning

    /// Custom log handler. If nil, logs go to `print()`.
    /// Set this to route SDK logs into your own logging system.
    public static var logHandler: ((SporTriviaLogLevel, String) -> Void)?

    // MARK: - Internal logging methods

    static func debug(_ message: @autoclosure () -> String) {
        log(.debug, message())
    }

    static func info(_ message: @autoclosure () -> String) {
        log(.info, message())
    }

    static func warning(_ message: @autoclosure () -> String) {
        log(.warning, message())
    }

    static func error(_ message: @autoclosure () -> String) {
        log(.error, message())
    }

    private static func log(_ level: SporTriviaLogLevel, _ message: String) {
        guard level >= logLevel else { return }
        if let handler = logHandler {
            handler(level, message)
        } else {
            print("SporTriviaSDK \(level.prefix) \(message)")
        }
    }
}
