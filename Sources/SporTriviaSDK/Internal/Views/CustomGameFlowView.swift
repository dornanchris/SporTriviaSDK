import SwiftUI

/// Top-level coordinator view that manages the custom game flow.
/// Replaces ContentViewState navigation from the main app.
struct CustomGameFlowView: View {
    let gameId: String
    let sport: Sport
    let configuration: SporTriviaConfiguration
    weak var delegate: SporTriviaDelegate?

    @StateObject private var gameState = GameState()
    @StateObject private var playerListManager = PlayerListManager()
    @State private var flowStep: FlowStep = .userInfo
    @State private var isLoading: Bool = false
    @State private var loadError: String?

    private var s3Service: S3DataService {
        S3DataService(
            credentialProvider: configuration.credentialProvider,
            bucketName: configuration.s3BucketName
        )
    }

    private var imageCache: ImageCache {
        ImageCache(s3Service: s3Service)
    }

    @StateObject private var gameEngine: GameEngine = GameEngine(
        gameState: GameState(),
        playerListManager: PlayerListManager(),
        s3Service: S3DataService(credentialProvider: PlaceholderCredentialProvider(), bucketName: ""),
        imageCache: ImageCache(s3Service: S3DataService(credentialProvider: PlaceholderCredentialProvider(), bucketName: ""))
    )

    @State private var realEngine: GameEngine?

    var body: some View {
        Group {
            switch flowStep {
            case .userInfo:
                UserInfoView(
                    gameState: gameState,
                    onSubmit: { startLoading() },
                    onCancel: { delegate?.sporTriviaDidCancel() }
                )

            case .loading:
                loadingView

            case .game:
                if let engine = realEngine {
                    GameView(
                        gameState: gameState,
                        gameEngine: engine,
                        playerListManager: playerListManager,
                        onGameEnd: { endGame() }
                    )
                }

            case .gameOver:
                GameOverView(
                    gameState: gameState,
                    onSeeAnswers: { flowStep = .answers },
                    onDone: { finishFlow() }
                )

            case .answers:
                AnswersView(
                    gameState: gameState,
                    onBack: { flowStep = .gameOver },
                    onDone: { finishFlow() }
                )
            }
        }
    }

    // MARK: - Flow Control

    private func startLoading() {
        flowStep = .loading
        isLoading = true
        loadError = nil

        Task {
            do {
                let s3 = S3DataService(
                    credentialProvider: configuration.credentialProvider,
                    bucketName: configuration.s3BucketName
                )
                let cache = ImageCache(s3Service: s3)
                let engine = GameEngine(
                    gameState: gameState,
                    playerListManager: playerListManager,
                    s3Service: s3,
                    imageCache: cache
                )

                try await engine.loadGame(gameId: gameId, sport: sport)

                await MainActor.run {
                    self.realEngine = engine
                    engine.startGame()
                    SporTriviaLogger.info("Game started — transitioning to game view")
                    flowStep = .game
                    isLoading = false
                }
            } catch {
                SporTriviaLogger.error("Failed to load game '\(gameId)' (\(sport.rawValue)): \(error)")
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                    delegate?.sporTriviaDidFail(error: error)
                }
            }
        }
    }

    private func endGame() {
        gameState.gameInProgress = false
        flowStep = .gameOver

        // Upload results in background
        if let engine = realEngine {
            Task { await engine.uploadResults() }
        }
    }

    private func finishFlow() {
        if let engine = realEngine {
            let result = engine.buildResult()
            delegate?.sporTriviaDidComplete(result: result)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        let theme = SporTriviaSDK.theme
        return ZStack {
            LinearGradient(
                colors: theme.gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                if let error = loadError {
                    Text("Failed to load game")
                        .font(.headline)
                        .foregroundColor(theme.incorrectColor)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(theme.textColor.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Button("Retry") { startLoading() }
                        .foregroundColor(theme.primaryColor)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: theme.textColor))
                        .scaleEffect(1.5)
                    Text("Loading game...")
                        .foregroundColor(theme.textColor)
                }
            }
        }
    }
}

// MARK: - Flow Step Enum

private enum FlowStep {
    case userInfo
    case loading
    case game
    case gameOver
    case answers
}

// MARK: - Placeholder (used only for @StateObject initialization; replaced at runtime)

private struct PlaceholderCredentialProvider: SporTriviaCredentialProvider {
    func presignedGetURL(forKey key: String) async throws -> URL {
        throw S3DataServiceError.downloadFailed(key: key)
    }
    func presignedPutURL(forKey key: String) async throws -> URL {
        throw S3DataServiceError.uploadFailed(key: key)
    }
}
