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
    /// Distance in points between the outermost keys and the side edges of the screen.
    var edgeMargin: Double = 4
    /// Extra inward shift for the bottom row only, so the 123 and return keys clear the
    /// screen's rounded bottom corners.
    var bottomCornerInset: Double = 16
    /// Key size relative to the system split keyboard (1 = same size).
    var keyScale: Double = 1
    /// Key height relative to the system keyboard (1 = same height).
    var keyHeightScale: Double = 1
    var showSuggestionBar = true
    /// Pop-up balloons on key press while split (the system split keyboard just highlights).
    var keyPopups = false
    var autocorrect = true
    var autoCapitalize = true
    var doubleSpacePeriod = true
    var haptics = false

    static let edgeMarginRange: ClosedRange<Double> = 0...80
    static let bottomCornerInsetRange: ClosedRange<Double> = 0...60
    static let keyScaleRange: ClosedRange<Double> = 0.75...1.3
    static let keyHeightScaleRange: ClosedRange<Double> = 0.8...1.3

    /// Darwin notification posted by the app whenever a setting changes so a visible
    /// keyboard can update immediately.
    static let changedNotificationName = "dev.duosplitkeeb.settings-changed"

    private enum Key {
        static let splitMode = "splitMode"
        static let edgeMargin = "edgeMargin.v2"
        static let bottomCornerInset = "bottomCornerInset"
        static let keyScale = "keyScale"
        static let keyHeightScale = "keyHeightScale"
        static let showSuggestionBar = "showSuggestionBar"
        static let keyPopups = "keyPopups"
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
        if let v = d.object(forKey: Key.bottomCornerInset) as? Double { s.bottomCornerInset = v.clamped(to: bottomCornerInsetRange) }
        if let v = d.object(forKey: Key.keyScale) as? Double { s.keyScale = v.clamped(to: keyScaleRange) }
        if let v = d.object(forKey: Key.keyHeightScale) as? Double { s.keyHeightScale = v.clamped(to: keyHeightScaleRange) }
        if let v = d.object(forKey: Key.showSuggestionBar) as? Bool { s.showSuggestionBar = v }
        if let v = d.object(forKey: Key.keyPopups) as? Bool { s.keyPopups = v }
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
        d.set(bottomCornerInset, forKey: Key.bottomCornerInset)
        d.set(keyScale, forKey: Key.keyScale)
        d.set(keyHeightScale, forKey: Key.keyHeightScale)
        d.set(showSuggestionBar, forKey: Key.showSuggestionBar)
        d.set(keyPopups, forKey: Key.keyPopups)
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
