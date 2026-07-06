import SwiftUI

/// Theme customization for the SDK's UI.
///
/// Defaults match the SporTrivia website/portal design: a dark navy
/// gradient background with teal primary actions and mint/cyan accents.
public struct SporTriviaTheme {
    public var primaryColor: Color
    public var backgroundColor: Color
    public var gradientColors: [Color]
    public var textColor: Color
    public var accentColor: Color
    public var correctColor: Color
    public var incorrectColor: Color

    public init(
        primaryColor: Color = Color(red: 20 / 255, green: 184 / 255, blue: 166 / 255),        // teal #14B8A6
        backgroundColor: Color = Color(red: 13 / 255, green: 27 / 255, blue: 42 / 255),       // navy #0D1B2A
        gradientColors: [Color] = [
            Color(red: 7 / 255, green: 17 / 255, blue: 31 / 255),                             // #07111F
            Color(red: 13 / 255, green: 27 / 255, blue: 42 / 255),                            // #0D1B2A
            Color(red: 18 / 255, green: 38 / 255, blue: 58 / 255)                             // #12263A
        ],
        textColor: Color = Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255),          // #F8FAFC
        accentColor: Color = Color(red: 103 / 255, green: 232 / 255, blue: 249 / 255),        // cyan #67E8F9
        correctColor: Color = Color(red: 167 / 255, green: 243 / 255, blue: 208 / 255),       // mint #A7F3D0
        incorrectColor: Color = Color(red: 252 / 255, green: 165 / 255, blue: 165 / 255)      // soft red #FCA5A5
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
