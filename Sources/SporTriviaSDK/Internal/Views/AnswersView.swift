import SwiftUI

/// Answers screen — displays the remaining correct answers after the game.
struct AnswersView: View {
    @ObservedObject var gameState: GameState
    let onBack: () -> Void
    let onDone: () -> Void

    private var theme: SporTriviaTheme { SporTriviaSDK.theme }

    var body: some View {
        VStack {
            Text("Trivia Answers")
                .font(.title.bold())
                .foregroundColor(theme.textColor)
                .padding(.top, 20)

            // Team header
            VStack {
                HStack {
                    Text(gameState.team1String)
                        .bold()
                    if let image = gameState.team1Image {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 50, height: 50)
                    }
                    Spacer()
                    if !gameState.team2String.isEmpty {
                        Text(gameState.team2String)
                            .bold()
                        if let image = gameState.team2Image {
                            Image(uiImage: image)
                                .resizable()
                                .frame(width: 50, height: 50)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white)

                // Player list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(gameState.correctPlayerInfo, id: \.self) { playerInfo in
                            VStack {
                                Divider()
                                Text(playerInfo.playerName)
                                    .font(.headline)
                                    .padding()
                            }
                        }
                    }
                }
                .background(Color.white)
            }
            .padding()

            // Navigation
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .padding()
                        .background(theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Spacer()

                Button(action: onDone) {
                    Label("Done", systemImage: "checkmark.circle")
                        .padding()
                        .background(theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .background(Color(red: 40/255, green: 45/255, blue: 47/255))
    }
}
