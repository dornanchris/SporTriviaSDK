import Foundation

/// Manages the player list for autocomplete and player selection.
/// Instance-scoped replacement for the singleton PlayerListViewModel.
class PlayerListManager: ObservableObject {
    @Published var userInput: String = ""
    @Published var filteredPlayerInfoList: [PlayerInfo] = []
    @Published var playerInfoList: [PlayerInfo] = []
    @Published var selectedPlayerInfo: PlayerInfo?

    /// Matches the dropdown display cap in GameView (`.prefix(10)`) — once
    /// this many matches are found there is no point scanning further.
    static let maxSuggestions = 10

    var isSearching: Bool {
        !userInput.isEmpty
    }

    /// Update the filtered player list based on current user input.
    /// Compares against each player's precomputed `normalizedName` and stops
    /// at `maxSuggestions` matches, so a keystroke never scans more of the
    /// 20k+ list than needed.
    func updateFilteredPlayerInfoList() {
        let normalizedInput = PlayerInfo.normalize(userInput)
        guard !normalizedInput.isEmpty else {
            filteredPlayerInfoList = []
            return
        }
        var matches: [PlayerInfo] = []
        for playerInfo in playerInfoList {
            if playerInfo.normalizedName.contains(normalizedInput) {
                matches.append(playerInfo)
                if matches.count >= PlayerListManager.maxSuggestions {
                    break
                }
            }
        }
        filteredPlayerInfoList = matches
        SporTriviaLogger.info("Autocomplete filter: input='\(userInput)' normalized='\(normalizedInput)' pool=\(playerInfoList.count) → \(matches.count) matches")
    }

    /// Try to select a player from the current input text.
    /// Returns the matched PlayerInfo, or a dummy if no match found.
    func selectPlayerInfoFromInput() -> PlayerInfo {
        let normalizedInput = PlayerInfo.normalize(userInput)

        for playerInfo in playerInfoList {
            if playerInfo.normalizedName == normalizedInput {
                selectedPlayerInfo = playerInfo
                return playerInfo
            }
        }

        // No match found — create a dummy entry (will be marked incorrect)
        let dummy = PlayerInfo(
            playerId: "unknown_\(UUID().uuidString)",
            playerName: userInput,
            yearsPlayed: ""
        )
        selectedPlayerInfo = dummy
        return dummy
    }
}
