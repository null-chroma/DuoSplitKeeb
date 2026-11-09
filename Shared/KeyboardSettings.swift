import Foundation

/// When the keyboard should use the split layout.
enum SplitMode: Int, CaseIterable, Identifiable {
    /// Split whenever the phone is unfolded (wide, roughly square screen). Normal keyboard when folded.
    case automatic = 0
    /// Always split, even on the folded (narrow) screen.
    case always = 1
    /// Never split.
    case never = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .automatic: return "When unfolded"
        case .always: return "Always"
        case .never: return "Never"
        }
    }
}

/// Settings shared between the containing app (where you change them) and the keyboard
/// extension (which reads them). They are stored in the shared App Group.
struct KeyboardSettings: Equatable {
    var splitMode: SplitMode = .automatic
    /// Distance in points between the outermost keys and the edge of the screen.
    var edgeMargin: Double = 3
    /// Width of one letter key "slot" (key + gap) in points, while split.
    var keyWidth: Double = 42
    /// Height of one key row (key + gap) in points.
    var rowHeight: Double = 54
    var autocorrect = true
    var autoCapitalize = true
    var doubleSpacePeriod = true
    var haptics = false

    static let edgeMarginRange: ClosedRange<Double> = 0...60
    static let keyWidthRange: ClosedRange<Double> = 30...64
    static let rowHeightRange: ClosedRange<Double> = 44...72

    /// Darwin notification posted by the app whenever a setting changes so a visible
    /// keyboard can update immediately.
    static let changedNotificationName = "dev.duosplitkeeb.settings-changed"

    private enum Key {
        static let splitMode = "splitMode"
        static let edgeMargin = "edgeMargin"
        static let keyWidth = "keyWidth"
        static let rowHeight = "rowHeight"
        static let autocorrect = "autocorrect"
        static let autoCapitalize = "autoCapitalize"
        static let doubleSpacePeriod = "doubleSpacePeriod"
        static let haptics = "haptics"
    }

    /// The App Group identifier, injected into each target's Info.plist from the
    /// `APP_GROUP_ID` build setting.
    static var appGroupID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String,
              !id.isEmpty, !id.contains("$(") else { return nil }
        return id
    }

    static var store: UserDefaults {
        if let id = appGroupID, let shared = UserDefaults(suiteName: id) {
            return shared
        }
        return .standard
    }

    static func load() -> KeyboardSettings {
        let d = store
        var s = KeyboardSettings()
        if let raw = d.object(forKey: Key.splitMode) as? Int, let mode = SplitMode(rawValue: raw) {
            s.splitMode = mode
        }
        if let v = d.object(forKey: Key.edgeMargin) as? Double { s.edgeMargin = v.clamped(to: edgeMarginRange) }
        if let v = d.object(forKey: Key.keyWidth) as? Double { s.keyWidth = v.clamped(to: keyWidthRange) }
        if let v = d.object(forKey: Key.rowHeight) as? Double { s.rowHeight = v.clamped(to: rowHeightRange) }
        if let v = d.object(forKey: Key.autocorrect) as? Bool { s.autocorrect = v }
        if let v = d.object(forKey: Key.autoCapitalize) as? Bool { s.autoCapitalize = v }
        if let v = d.object(forKey: Key.doubleSpacePeriod) as? Bool { s.doubleSpacePeriod = v }
        if let v = d.object(forKey: Key.haptics) as? Bool { s.haptics = v }
        return s
    }

    func save() {
        let d = KeyboardSettings.store
        d.set(splitMode.rawValue, forKey: Key.splitMode)
        d.set(edgeMargin, forKey: Key.edgeMargin)
        d.set(keyWidth, forKey: Key.keyWidth)
        d.set(rowHeight, forKey: Key.rowHeight)
        d.set(autocorrect, forKey: Key.autocorrect)
        d.set(autoCapitalize, forKey: Key.autoCapitalize)
        d.set(doubleSpacePeriod, forKey: Key.doubleSpacePeriod)
        d.set(haptics, forKey: Key.haptics)
    }

    static func postChanged() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(changedNotificationName as CFString),
            nil, nil, true
        )
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
