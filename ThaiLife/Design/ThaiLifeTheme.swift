import SwiftUI

/// Forest-green + warm-white color system for Thai Life.
/// No orange, no Manao-like colors.
enum ThaiLifeTheme {
    // MARK: - Primary Colors
    static let deepGreen = Color(red: 0.13, green: 0.35, blue: 0.22)     // #215A38
    static let paleGreen = Color(red: 0.55, green: 0.80, blue: 0.65)     // #8CCCA6
    static let warmWhite = Color(red: 0.98, green: 0.97, blue: 0.94)     // #FAF8F0
    static let cardWhite = Color.white

    // MARK: - Rating Colors (4-level feedback)
    static let ratingAgain = Color(red: 0.85, green: 0.25, blue: 0.25)   // Red
    static let ratingHard = Color(red: 0.90, green: 0.65, blue: 0.20)    // Amber
    static let ratingGood = Color(red: 0.20, green: 0.60, blue: 0.35)    // Green
    static let ratingEasy = Color(red: 0.25, green: 0.50, blue: 0.80)    // Blue

    // MARK: - Text Colors
    static let textPrimary = Color(red: 0.15, green: 0.15, blue: 0.15)
    static let textSecondary = Color(red: 0.45, green: 0.45, blue: 0.45)
    static let textTertiary = Color(red: 0.65, green: 0.65, blue: 0.65)

    // MARK: - Semantic
    static let success = Color(red: 0.20, green: 0.60, blue: 0.35)
    static let warning = Color(red: 0.90, green: 0.65, blue: 0.20)
    static let error = Color(red: 0.85, green: 0.25, blue: 0.25)
}
