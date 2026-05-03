import SwiftUI

/// Theme customization for the SDK's UI.
public struct SporTriviaTheme {
    public var primaryColor: Color
    public var backgroundColor: Color
    public var gradientColors: [Color]
    public var textColor: Color
    public var accentColor: Color
    public var correctColor: Color
    public var incorrectColor: Color

    public init(
        primaryColor: Color = .blue,
        backgroundColor: Color = Color(red: 0.1, green: 0.1, blue: 0.2),
        gradientColors: [Color] = [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.05, green: 0.05, blue: 0.15)],
        textColor: Color = .white,
        accentColor: Color = .yellow,
        correctColor: Color = .green,
        incorrectColor: Color = .red
    ) {
        self.primaryColor = primaryColor
        self.backgroundColor = backgroundColor
        self.gradientColors = gradientColors
        self.textColor = textColor
        self.accentColor = accentColor
        self.correctColor = correctColor
        self.incorrectColor = incorrectColor
    }
}
