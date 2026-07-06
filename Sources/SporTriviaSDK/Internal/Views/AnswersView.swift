import SwiftUI

/// Answers screen — displays the remaining correct answers after the game.
struct AnswersView: View {
    @ObservedObject var gameState: GameState
    let onBack: () -> Void
    let onDone: () -> Void

    private var theme: SporTriviaTheme { SporTriviaSDK.theme }

    private var cardFill: Color { Color(red: 15 / 255, green: 32 / 255, blue: 56 / 255) }
    private var cardBorder: Color { Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255).opacity(0.22) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Text("Trivia Answers")
                    .font(.title.bold())
                    .foregroundColor(theme.textColor)
                    .padding(.top, 20)

                // Team header
                VStack(spacing: 12) {
                    HStack {
                        Text(gameState.team1String)
                            .bold()
                            .foregroundColor(theme.textColor)
                        if let image = gameState.team1Image {
                            Image(uiImage: image)
                                .resizable()
                                .frame(width: 50, height: 50)
                        }
                        Spacer()
                        if !gameState.team2String.isEmpty {
                            Text(gameState.team2String)
                                .bold()
                                .foregroundColor(theme.textColor)
                            if let image = gameState.team2Image {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: 50, height: 50)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(cardFill.opacity(0.82))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(cardBorder, lineWidth: 1)
                    )

                    // Player list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(gameState.correctPlayerInfo, id: \.self) { playerInfo in
                                VStack {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                    Text(playerInfo.playerName)
                                        .font(.headline)
                                        .foregroundColor(theme.correctColor)
                                        .padding()
                                }
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(cardFill.opacity(0.62))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(cardBorder, lineWidth: 1)
                    )
                }
                .padding()

                // Navigation
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(theme.primaryColor)
                            )
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(action: onDone) {
                        Label("Done", systemImage: "checkmark.circle")
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(theme.primaryColor)
                            )
                            .foregroundColor(.white)
                    }
                }
                .padding()
            }
        }
    }
}
