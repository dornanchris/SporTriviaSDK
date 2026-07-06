import SwiftUI

/// Main entry point for the SporTrivia SDK.
///
/// Usage:
/// ```swift
/// // 1. Configure the SDK (typically in app startup)
/// SporTriviaSDK.configure(SporTriviaConfiguration(
///     credentialProvider: MyCredentialProvider()
/// ))
///
/// // 2. Present the custom game view
/// let gameView = SporTriviaSDK.customGameView(
///     gameId: "NYI_Top5A",
///     sport: .nhl,
///     delegate: self
/// )
/// ```
public final class SporTriviaSDK {
    /// SDK release version, reported as `sdk_version` in game-result uploads.
    /// Keep in step with the git tag when releasing.
    public static let sdkVersion = "1.1.0"

    static var configuration: SporTriviaConfiguration?

    /// Configure the SDK. Must be called before launching any game views.
    public static func configure(_ configuration: SporTriviaConfiguration) {
        self.configuration = configuration
    }

    /// Returns a SwiftUI View that hosts the entire custom game flow
    /// (User Info -> Game -> Game Over -> Answers).
    ///
    /// Present it with `.fullScreenCover` (recommended). Interactive
    /// swipe-to-dismiss is disabled so a sheet can't be accidentally
    /// swiped away mid-game; the player exits through the in-game close
    /// button, which asks for confirmation and calls
    /// ``SporTriviaDelegate/sporTriviaDidCancel()``.
    ///
    /// - Parameters:
    ///   - gameId: The custom game identifier (S3 file name, e.g. "NYI_Top5A").
    ///   - sport: The sport/league for this game.
    ///   - delegate: Optional delegate to receive game lifecycle events.
    /// - Returns: A SwiftUI view hosting the full custom game flow.
    public static func customGameView(
        gameId: String,
        sport: Sport,
        delegate: SporTriviaDelegate? = nil
    ) -> some View {
        guard let config = configuration else {
            fatalError("SporTriviaSDK.configure() must be called before creating game views.")
        }
        return CustomGameFlowView(
            gameId: gameId,
            sport: sport,
            configuration: config,
            delegate: delegate
        )
        .interactiveDismissDisabled()
    }

    /// The current theme, falling back to defaults if none configured.
    static var theme: SporTriviaTheme {
        configuration?.theme ?? SporTriviaTheme()
    }
}
