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
    /// Width in key units (one letter key = 1).
    var width: CGFloat = 1
    /// Flexible keys (the space bar) take up whatever room is left in the row.
    var isFlexible = false
    var alternates: [String] = []
    var label: String?

    var isCharacter: Bool {
        if case .character = action { return true }
        return false
    }
}

/// The key layout.
///
/// Each page is the standard iPhone keyboard cut into a left and a right half along the
/// same zig-zag the system split keyboard uses (T|Y, G|H, V|B). Each half is 5.5 units wide.
/// The left half is anchored to the left screen edge and the right half to the right edge.
///
/// When not split, the two halves are joined back together, which gives exactly the normal
/// iPhone layout.
enum KeyboardLayouts {
    struct Page {
        let left: [[KeySpec]]
        let right: [[KeySpec]]
    }

    static let halfWidthUnits: CGFloat = 5.5
    static let fullWidthUnits: CGFloat = 10

    static func page(_ page: KeyboardPage, showsGlobe: Bool) -> Page {
        switch page {
        case .letters:
            return Page(
                left: [
                    keys("qwert"),
                    [spacer(0.5)] + keys("asdfg"),
                    [KeySpec(action: .shift, width: 1.3), spacer(0.2)] + keys("zxcv"),
                    bottomLeft(switchTo: .numbers, label: "123", showsGlobe: showsGlobe),
                ],
                right: [
                    keys("yuiop"),
                    keys("hjkl") + [spacer(0.5)],
                    keys("bnm") + [spacer(0.2), backspace],
                    bottomRight,
                ]
            )
        case .numbers:
            return Page(
                left: [
                    keys("12345"),
                    keys("-/:;("),
                    [KeySpec(action: .page(.symbols), width: 1.3, label: "#+="), spacer(0.2)] + keys(".,?", width: 4.0 / 3.0),
                    bottomLeft(switchTo: .letters, label: "ABC", showsGlobe: showsGlobe),
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
                    bottomLeft(switchTo: .letters, label: "ABC", showsGlobe: showsGlobe),
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

    /// Joins a left and right half row back into one full-width row.
    static func join(_ left: [KeySpec], _ right: [KeySpec]) -> [KeySpec] {
        var right = right
        // The two halves of the space bar become a single space bar.
        if left.last?.action == .space, right.first?.action == .space {
            right.removeFirst()
        }
        return left + right
    }

    // MARK: - Helpers

    private static let backspace = KeySpec(action: .backspace, width: 1.3)

    private static let bottomRight: [KeySpec] = [
        KeySpec(action: .space, isFlexible: true),
        KeySpec(action: .returnKey, width: 2.5),
    ]

    private static func bottomLeft(switchTo page: KeyboardPage, label: String, showsGlobe: Bool) -> [KeySpec] {
        var row = [KeySpec(action: .page(page), width: 1.25, label: label)]
        if showsGlobe {
            row.append(KeySpec(action: .globe, width: 1.25))
        }
        row.append(KeySpec(action: .space, isFlexible: true))
        return row
    }

    private static func spacer(_ width: CGFloat) -> KeySpec {
        KeySpec(action: .spacer, width: width)
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
