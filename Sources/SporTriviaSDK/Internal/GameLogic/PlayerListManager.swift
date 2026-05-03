import Foundation

/// Manages the player list for autocomplete and player selection.
/// Instance-scoped replacement for the singleton PlayerListViewModel.
class PlayerListManager: ObservableObject {
    @Published var userInput: String = ""
    @Published var filteredPlayerInfoList: [PlayerInfo] = []
    @Published var playerInfoList: [PlayerInfo] = []
    @Published var selectedPlayerInfo: PlayerInfo?

    var isSearching: Bool {
        !userInput.isEmpty
    }

    /// Update the filtered player list based on current user input.
    func updateFilteredPlayerInfoList() {
        let normalizedInput = normalizeString(userInput)
        guard !normalizedInput.isEmpty else {
            filteredPlayerInfoList = []
            return
        }
        filteredPlayerInfoList = playerInfoList.filter { playerInfo in
            let normalizedName = normalizeString(playerInfo.playerName)
            return normalizedName.contains(normalizedInput)
        }
    }

    /// Try to select a player from the current input text.
    /// Returns the matched PlayerInfo, or a dummy if no match found.
    func selectPlayerInfoFromInput() -> PlayerInfo {
        let normalizedInput = normalizeString(userInput)

        for playerInfo in playerInfoList {
            let normalizedName = normalizeString(playerInfo.playerName)
            if normalizedName == normalizedInput {
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

    private func normalizeString(_ str: String) -> String {
        return str
            .folding(options: .diacriticInsensitive, locale: nil)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}
