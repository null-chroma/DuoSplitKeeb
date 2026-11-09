import UIKit

enum KeyboardPage: Equatable {
    case letters, numbers, symbols
}

enum ShiftState: Equatable {
    case off, on, capsLock
}

enum KeyAction: Equatable {
    case character(String)
    case shift
    case backspace
    case page(KeyboardPage)
    case globe
    case space
    case returnKey
    /// Empty space used for alignment. Never drawn.
    case spacer
}

struct KeySpec {
    var action: KeyAction
    /// Width in key units (one letter key plus its gap = 1).
    var width: CGFloat = 1
    /// Flexible keys (the space bar) take up whatever room is left in the row.
    var isFlexible = false
    var alternates: [String] = []
    var label: String?
    /// Keys that the split keyboard shows on both halves (G and V). Dropped when joined.
    var isSplitDuplicate = false

    var isCharacter: Bool {
        if case .character = action { return true }
        return false
    }
}

/// The key layout, measured from the system split keyboard on the unfolded iPhone Duo.
///
/// Each half is 5.5 key units wide. The left half is anchored to the left screen edge and the
/// right half to the right edge. Like the system split keyboard, the right half repeats G and V
/// at the start of its middle and bottom rows.
///
/// When not split (phone folded), the halves are joined back into the normal iPhone layout.
enum KeyboardLayouts {
    struct Page {
        let left: [[KeySpec]]
        let right: [[KeySpec]]
    }

    static let halfWidthUnits: CGFloat = 5.5
    static let fullWidthUnits: CGFloat = 10

    static func page(_ page: KeyboardPage) -> Page {
        switch page {
        case .letters:
            return Page(
                left: [
                    keys("qwert"),
                    [spacer(0.5)] + keys("asdfg"),
                    [KeySpec(action: .shift, width: 1.3), spacer(0.2)] + keys("zxcv"),
                    bottomLeft(switchTo: .numbers, label: "123"),
                ],
                right: [
                    keys("yuiop"),
                    duplicate(keys("g")) + keys("hjkl") + [spacer(0.5)],
                    duplicate(keys("v")) + keys("bnm") + [spacer(0.2), backspace],
                    bottomRight,
                ]
            )
        case .numbers:
            return Page(
                left: [
                    keys("12345"),
                    keys("-/:;("),
                    [KeySpec(action: .page(.symbols), width: 1.3, label: "#+="), spacer(0.2)] + keys(".,?", width: 4.0 / 3.0),
                    bottomLeft(switchTo: .letters, label: "ABC"),
                ],
                right: [
                    keys("67890"),
                    keys(")$&@\""),
                    keys("!'", width: 4.0 / 3.0) + [spacer(0.2), backspace],
                    bottomRight,
                ]
            )
        case .symbols:
            return Page(
                left: [
                    keys("[]{}#"),
                    keys("_\\|~<"),
                    [KeySpec(action: .page(.numbers), width: 1.3, label: "123"), spacer(0.2)] + keys(".,?", width: 4.0 / 3.0),
                    bottomLeft(switchTo: .letters, label: "ABC"),
                ],
                right: [
                    keys("%^*+="),
                    keys(">€£¥•"),
                    keys("!'", width: 4.0 / 3.0) + [spacer(0.2), backspace],
                    bottomRight,
                ]
            )
        }
    }

    /// Joins a left and right half row back into one full-width (folded phone) row.
    static func join(_ left: [KeySpec], _ right: [KeySpec], isBottomRow: Bool) -> [KeySpec] {
        if isBottomRow, let pageKey = left.first {
            // Standard iPhone bottom row.
            var key = pageKey
            key.width = 1.25
            return [
                key,
                KeySpec(action: .globe, width: 1.25),
                KeySpec(action: .space, isFlexible: true),
                KeySpec(action: .returnKey, width: 2.5),
            ]
        }
        return left + right.filter { !$0.isSplitDuplicate }
    }

    // MARK: - Helpers

    private static let backspace = KeySpec(action: .backspace, width: 1.3)

    /// Measured: spacer, space bar (which also covers where the system dictation key sits —
    /// custom keyboards can't start dictation), return.
    private static let bottomRight: [KeySpec] = [
        spacer(0.45),
        KeySpec(action: .space, width: 3.6),
        KeySpec(action: .returnKey, width: 1.45),
    ]

    /// Measured: 123, globe, space bar (which also covers where the system emoji key sits —
    /// custom keyboards can't open the emoji keyboard directly), spacer.
    private static func bottomLeft(switchTo page: KeyboardPage, label: String) -> [KeySpec] {
        [
            KeySpec(action: .page(page), width: 0.967, label: label),
            KeySpec(action: .globe, width: 0.967),
            KeySpec(action: .space, width: 3.0),
            spacer(0.566),
        ]
    }

    private static func spacer(_ width: CGFloat) -> KeySpec {
        KeySpec(action: .spacer, width: width)
    }

    private static func duplicate(_ specs: [KeySpec]) -> [KeySpec] {
        specs.map { var s = $0; s.isSplitDuplicate = true; return s }
    }

    private static func keys(_ characters: String, width: CGFloat = 1) -> [KeySpec] {
        characters.map { c in
            let s = String(c)
            return KeySpec(action: .character(s), width: width, alternates: alternates[s] ?? [])
        }
    }

    /// Long-press accent / alternate characters, matching the system US English keyboard.
    static let alternates: [String: [String]] = [
        "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā"],
        "c": ["ç", "ć", "č"],
        "e": ["è", "é", "ê", "ë", "ē", "ė", "ę"],
        "i": ["î", "ï", "í", "ī", "į", "ì"],
        "l": ["ł"],
        "n": ["ñ", "ń"],
        "o": ["ô", "ö", "ò", "ó", "œ", "ø", "ō", "õ"],
        "s": ["ß", "ś", "š"],
        "u": ["û", "ü", "ù", "ú", "ū"],
        "y": ["ÿ"],
        "z": ["ž", "ź", "ż"],
        "0": ["°"],
        "-": ["–", "—", "•"],
        "/": ["\\"],
        "$": ["₽", "¥", "€", "¢", "£", "₩"],
        "&": ["§"],
        "\"": ["„", "“", "”", "«", "»"],
        ".": ["…"],
        "?": ["¿"],
        "!": ["¡"],
        "'": ["`", "‘", "’"],
        "%": ["‰"],
    ]
}
