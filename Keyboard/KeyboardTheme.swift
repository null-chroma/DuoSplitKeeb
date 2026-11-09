import UIKit

/// Colors matching the current system keyboard: flat keys with no shadow, and the letter and
/// function keys in the same color. Tweak here if anything looks off on the device.
struct KeyboardTheme {
    let isDark: Bool
    let key: UIColor
    let pressedKey: UIColor
    let primaryKey: UIColor
    let pressedPrimaryKey: UIColor
    let text: UIColor
    let primaryText: UIColor
    let separator: UIColor
    let popupFill: UIColor
    let selectionFill: UIColor
    let selectionText: UIColor

    static let light = KeyboardTheme(
        isDark: false,
        key: .white,
        pressedKey: UIColor(white: 0.80, alpha: 1),
        primaryKey: UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1),
        pressedPrimaryKey: UIColor(red: 0.0, green: 0.36, blue: 0.80, alpha: 1),
        text: .black,
        primaryText: .white,
        separator: UIColor(white: 0, alpha: 0.16),
        popupFill: .white,
        selectionFill: UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1),
        selectionText: .white
    )

    /// Measured from the screenshot: keys ≈ #4A4A4A on a ≈ #262626 keyboard background.
    static let dark = KeyboardTheme(
        isDark: true,
        key: UIColor(white: 0.29, alpha: 1),
        pressedKey: UIColor(white: 0.45, alpha: 1),
        primaryKey: UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1),
        pressedPrimaryKey: UIColor(red: 0.03, green: 0.40, blue: 0.80, alpha: 1),
        text: .white,
        primaryText: .white,
        separator: UIColor(white: 1, alpha: 0.2),
        popupFill: UIColor(white: 0.36, alpha: 1),
        selectionFill: UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1),
        selectionText: .white
    )
}
