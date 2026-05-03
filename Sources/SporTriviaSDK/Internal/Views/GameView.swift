import SwiftUI
import Combine

/// Main game screen — shows the question, player input, and score.
struct GameView: View {
    @ObservedObject var gameState: GameState
    @ObservedObject var gameEngine: GameEngine
    @ObservedObject var playerListManager: PlayerListManager
    let onGameEnd: () -> Void

    @State private var userInput: String = ""
    @State private var isCheckMark: Bool = false
    @State private var isX: Bool = false
    @State private var isPlayerAlreadyUsed: Bool = false
    @State private var isDropdownVisible: Bool = false

    private var theme: SporTriviaTheme { SporTriviaSDK.theme }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                // Question or team display
                questionSection

                // Score display
                scoreSection

                // Player input
                inputSection

                // Submit button
                submitButton

                // Give up button
                giveUpButton

                Spacer()
            }
            .padding()

            // Feedback overlays
            feedbackOverlay
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var questionSection: some View {
        if let question = gameState.customQuestion, !question.isEmpty {
            Text(question)
                .font(.title3.bold())
                .foregroundColor(theme.textColor)
                .multilineTextAlignment(.center)
                .padding()
        } else {
            HStack(spacing: 20) {
                if let image = gameState.team1Image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack {
                    Text(gameState.team1String)
                        .font(.headline)
                        .foregroundColor(theme.textColor)
                    if !gameState.team2String.isEmpty {
                        Text(gameState.team2String)
                            .font(.headline)
                            .foregroundColor(theme.textColor)
                    }
                }
                if let image = gameState.team2Image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
    }

    private var scoreSection: some View {
        HStack(spacing: 20) {
            Text("Correct: \(gameState.correct)")
                .foregroundColor(theme.correctColor)
            Text("Players Left: \(gameState.playersLeft)")
                .foregroundColor(theme.textColor)
        }
        .font(.subheadline.bold())
    }

    private var inputSection: some View {
        VStack(spacing: 4) {
            TextField("Enter player name", text: $userInput)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                .autocapitalization(.words)
                .disableAutocorrection(true)
                .onChange(of: userInput) { newValue in
                    playerListManager.userInput = newValue
                    playerListManager.updateFilteredPlayerInfoList()
                    isDropdownVisible = !playerListManager.filteredPlayerInfoList.isEmpty && !newValue.isEmpty
                }
                .onSubmit {
                    onSubmit()
                }

            if isDropdownVisible {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(playerListManager.filteredPlayerInfoList.prefix(10), id: \.playerId) { player in
                            Button(action: {
                                userInput = player.playerName
                                playerListManager.selectedPlayerInfo = player
                                isDropdownVisible = false
                            }) {
                                HStack {
                                    Text(player.playerName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(player.yearsPlayed)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 4)
            }
        }
    }

    private var submitButton: some View {
        Button(action: onSubmit) {
            Text("Submit")
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(userInput.isEmpty ? Color.gray : theme.primaryColor)
                .cornerRadius(8)
        }
        .disabled(userInput.isEmpty)
    }

    private var giveUpButton: some View {
        Button(action: onGameEnd) {
            Text("Give Up")
                .foregroundColor(theme.incorrectColor)
                .padding(8)
        }
    }

    @ViewBuilder
    private var feedbackOverlay: some View {
        if isCheckMark {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(theme.correctColor)
                .transition(.scale)
        }
        if isX {
            Image(systemName: "xmark.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(theme.incorrectColor)
                .transition(.scale)
        }
        if isPlayerAlreadyUsed {
            Text("Player Already Used!")
                .font(.headline)
                .foregroundColor(theme.accentColor)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
        }
    }

    // MARK: - Actions

    private func onSubmit() {
        guard !userInput.isEmpty else { return }

        let player: PlayerInfo
        if let selected = playerListManager.selectedPlayerInfo {
            player = selected
        } else {
            player = playerListManager.selectPlayerInfoFromInput()
        }

        // Check if already used
        if gameEngine.checkIfIdUsed(playerId: player.playerId) {
            withAnimation { isPlayerAlreadyUsed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { isPlayerAlreadyUsed = false }
            }
            clearInput()
            return
        }

        // Check answer
        let correct = gameEngine.checkAnswer(playerInfo: player)

        if correct {
            withAnimation { isCheckMark = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { isCheckMark = false }
            }
            if gameEngine.allAnswersFound {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    onGameEnd()
                }
            }
        } else {
            withAnimation { isX = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { isX = false }
            }
        }

        clearInput()
    }

    private func clearInput() {
        userInput = ""
        playerListManager.userInput = ""
        playerListManager.selectedPlayerInfo = nil
        playerListManager.filteredPlayerInfoList = []
        isDropdownVisible = false
    }
}
