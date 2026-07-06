import SwiftUI

/// Tappable sponsorship banner, shown only when the question has a
/// sponsorship configured in the SporTrivia portal.
struct SponsorshipBannerView: View {
    @ObservedObject var gameState: GameState
    @Environment(\.openURL) private var openURL

    private var theme: SporTriviaTheme { SporTriviaSDK.theme }

    var body: some View {
        if let image = gameState.sponsorshipImage {
            VStack(spacing: 4) {
                Button {
                    if let url = URL(string: gameState.sponsorshipURL) {
                        openURL(url)
                    }
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                if !gameState.sponsorshipBrand.isEmpty {
                    Text("Sponsored by: \(gameState.sponsorshipBrand)")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textColor.opacity(0.8))
                }
            }
        }
    }
}
