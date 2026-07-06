import SwiftUI

/// Game over screen — shows final score, share, and navigation options.
struct GameOverView: View {
    @ObservedObject var gameState: GameState
    let onSeeAnswers: () -> Void
    let onDone: () -> Void

    private var theme: SporTriviaTheme { SporTriviaSDK.theme }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                SponsorshipBannerView(gameState: gameState)

                Spacer()

                Text("GAME OVER!")
                    .font(.largeTitle.bold())
                    .foregroundColor(theme.incorrectColor)

                Text("Streak: \(gameState.currentStreak)")
                    .font(.title)
                    .foregroundColor(theme.textColor)

                HStack(spacing: 24) {
                    Text("Correct: \(gameState.correct)")
                        .foregroundColor(theme.correctColor)
                    Text("Incorrect: \(gameState.incorrect)")
                        .foregroundColor(theme.incorrectColor)
                }
                .font(.headline)

                HStack(spacing: 24) {
                    Text("Max Streak: \(gameState.maxStreak)")
                        .foregroundColor(theme.textColor)
                }
                .font(.subheadline)

                // Share button
                Button(action: shareScore) {
                    Label("Share Score", systemImage: "square.and.arrow.up")
                        .fontWeight(.bold)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
                                            theme.primaryColor
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
                }

                // See Answers button
                Button(action: onSeeAnswers) {
                    Text("See Answers")
                        .fontWeight(.bold)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.primaryColor)
                        )
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
                }

                // Done button
                Button(action: onDone) {
                    Label("Done", systemImage: "checkmark.circle")
                        .fontWeight(.bold)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.primaryColor)
                        )
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
                }

                Spacer()
            }
        }
    }

    private func shareScore() {
        let message = "I scored a Streak of \(gameState.currentStreak) in SporTrivia! Can you beat that?"
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
