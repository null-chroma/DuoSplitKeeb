import UIKit

/// Colors approximating the system keyboard. Tweak here if anything looks off on device.
struct KeyboardTheme {
    let isDark: Bool
    let characterKey: UIColor
    let functionKey: UIColor
    let pressedCharacterKey: UIColor
    let pressedFunctionKey: UIColor
    let primaryKey: UIColor
    let pressedPrimaryKey: UIColor
    let text: UIColor
    let primaryText: UIColor
    let pressedPrimaryText: UIColor
    let shadow: UIColor
    let shadowOpacity: Float
    let separator: UIColor
    let popupFill: UIColor
    let selectionFill: UIColor
    let selectionText: UIColor

    static let light = KeyboardTheme(
        isDark: false,
        characterKey: .white,
        functionKey: UIColor(red: 0.671, green: 0.694, blue: 0.733, alpha: 1),
        pressedCharacterKey: UIColor(red: 0.671, green: 0.694, blue: 0.733, alpha: 1),
        pressedFunctionKey: .white,
        primaryKey: UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1),
        pressedPrimaryKey: .white,
        text: .black,
        primaryText: .white,
        pressedPrimaryText: .black,
        shadow: UIColor(red: 0.533, green: 0.541, blue: 0.557, alpha: 1),
        shadowOpacity: 1,
        separator: UIColor(white: 0, alpha: 0.16),
        popupFill: .white,
        selectionFill: UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1),
        selectionText: .white
    )

    static let dark = KeyboardTheme(
        isDark: true,
        characterKey: UIColor(white: 0.42, alpha: 1),
        functionKey: UIColor(white: 0.27, alpha: 1),
        pressedCharacterKey: UIColor(white: 0.27, alpha: 1),
        pressedFunctionKey: UIColor(white: 0.42, alpha: 1),
        primaryKey: UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1),
        pressedPrimaryKey: UIColor(white: 0.42, alpha: 1),
        text: .white,
        primaryText: .white,
        pressedPrimaryText: .white,
        shadow: .black,
        shadowOpacity: 0.4,
        separator: UIColor(white: 1, alpha: 0.2),
        popupFill: UIColor(white: 0.42, alpha: 1),
        selectionFill: UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1),
        selectionText: .white
    )
}
