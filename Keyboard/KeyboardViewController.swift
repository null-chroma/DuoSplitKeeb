import UIKit

/// Root view. Adopting `UIInputViewAudioFeedback` enables the standard key click sound
/// (which follows Settings → Sounds & Haptics → Keyboard Feedback).
final class KeyboardRootView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

final class KeyboardViewController: UIInputViewController {
    private let keyboardView = KeyboardView(frame: .zero)
    private var heightConstraint: NSLayoutConstraint?
    private var settings = KeyboardSettings.load()
    private let predictor = TextPredictor()
    private lazy var haptic = UIImpactFeedbackGenerator(style: .light)

    private var page: KeyboardPage = .letters
    private var shift: ShiftState = .off
    private var lastShiftTap: CFTimeInterval = 0
    private var previousWasSpace = false
    private var lastAutocorrection: (original: String, replacement: String, separator: String)?

    // MARK: - Lifecycle

    override func loadView() {
        let root = KeyboardRootView(frame: .zero, inputViewStyle: .keyboard)
        root.allowsSelfSizing = true
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.delegate = self
        view.addSubview(keyboardView)
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let height = view.heightAnchor.constraint(equalToConstant: preferredHeight())
        height.priority = UILayoutPriority(999)
        height.isActive = true
        heightConstraint = height

        if let lang = primaryLanguage {
            predictor.language = lang.replacingOccurrences(of: "-", with: "_")
        }
        requestSupplementaryLexicon { [weak self] lexicon in
            self?.predictor.load(lexicon: lexicon)
        }

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (vc: KeyboardViewController, _: UITraitCollection) in
            vc.pushState()
        }
        observeSettingsChanges()
        applySettings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSettings()
        configureForCurrentField()
        refresh()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateHeight()
    }

    /// Key size follows the screen width (like the system split keyboard), so the keyboard
    /// height does too.
    private func preferredHeight() -> CGFloat {
        var width = view.bounds.width
        if width <= 0 {
            width = view.window?.windowScene?.screen.bounds.width ?? UIScreen.main.bounds.width
        }
        return keyboardView.computeMetrics(forWidth: width).height
    }

    private func updateHeight() {
        let h = preferredHeight()
        if let c = heightConstraint, abs(c.constant - h) > 0.5 {
            c.constant = h
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refresh()
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(KeyboardSettings.changedNotificationName as CFString),
            nil
        )
    }

    // MARK: - Settings

    private func observeSettingsChanges() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let vc = Unmanaged<KeyboardViewController>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { vc.reloadSettings() }
            },
            KeyboardSettings.changedNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func reloadSettings() {
        let new = KeyboardSettings.load()
        guard new != settings else { return }
        settings = new
        applySettings()
        refresh()
    }

    private func applySettings() {
        keyboardView.settings = settings
        updateHeight()
        keyboardView.setNeedsLayout()
    }

    // MARK: - State

    private var proxy: UITextDocumentProxy { textDocumentProxy }
    private var textBefore: String { proxy.documentContextBeforeInput ?? "" }

    private func configureForCurrentField() {
        switch proxy.keyboardType ?? .default {
        case .numberPad, .decimalPad, .phonePad, .numbersAndPunctuation, .asciiCapableNumberPad:
            page = .numbers
        default:
            page = .letters
        }
        shift = .off
        lastAutocorrection = nil
        previousWasSpace = false
    }

    private func refresh() {
        updateAutoShift()
        pushState()
        updateSuggestions()
    }

    private func afterEdit() {
        updateAutoShift()
        pushState()
        updateSuggestions()
    }

    private func pushState() {
        let (title, primary) = returnKeyAppearance()
        var returnEnabled = true
        if proxy.enablesReturnKeyAutomatically == true {
            let hasText = !(textBefore.isEmpty && (proxy.documentContextAfterInput ?? "").isEmpty)
            returnEnabled = hasText
        }

        let isDark: Bool
        switch proxy.keyboardAppearance ?? .default {
        case .dark: isDark = true
        case .light: isDark = false
        default: isDark = traitCollection.userInterfaceStyle == .dark
        }

        keyboardView.apply(KeyboardView.State(
            page: page,
            shift: shift,
            returnTitle: title,
            returnIsPrimary: primary,
            returnEnabled: returnEnabled,
            isDark: isDark
        ))
    }

    /// `nil` title = the plain return arrow.
    private func returnKeyAppearance() -> (String?, Bool) {
        switch proxy.returnKeyType ?? .default {
        case .go: return ("go", true)
        case .google: return ("search", true)
        case .join: return ("join", true)
        case .next: return ("next", false)
        case .route: return ("route", true)
        case .search: return ("search", true)
        case .send: return ("send", true)
        case .yahoo: return ("search", true)
        case .done: return ("done", true)
        case .emergencyCall: return ("emergency", true)
        case .continue: return ("continue", true)
        default: return (nil, false)
        }
    }

    private func updateAutoShift() {
        guard shift != .capsLock else { return }
        shift = shouldAutoCapitalize() ? .on : .off
    }

    private func shouldAutoCapitalize() -> Bool {
        guard settings.autoCapitalize else { return false }
        let before = textBefore
        switch proxy.autocapitalizationType ?? .sentences {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            guard let last = before.last else { return true }
            return last.isWhitespace
        default:
            guard let last = before.last else { return true }
            if last.isNewline { return true }
            guard last.isWhitespace else { return false }
            let trimmed = before.trimmingCharacters(in: .whitespaces)
            guard let end = trimmed.last else { return true }
            return end == "." || end == "!" || end == "?" || end.isNewline
        }
    }

    private func updateSuggestions() {
        guard proxy.autocorrectionType != .no, proxy.keyboardType != .URL else {
            keyboardView.suggestionBar.setSuggestions([])
            return
        }
        let word = predictor.currentWord(in: textBefore)
        keyboardView.suggestionBar.setSuggestions(
            predictor.suggestions(for: word, autocorrect: settings.autocorrect)
        )
    }

    // MARK: - Editing

    private var autocorrectAllowed: Bool {
        settings.autocorrect && proxy.autocorrectionType != .no && proxy.keyboardType != .URL
            && proxy.keyboardType != .emailAddress && proxy.keyboardType != .webSearch
    }

    /// Fix the word before the cursor (if needed) just before a separator is typed.
    private func applyAutocorrection(separator: String) {
        guard autocorrectAllowed else { return }
        let word = predictor.currentWord(in: textBefore)
        guard let fix = predictor.autocorrection(for: word), fix != word else { return }
        for _ in 0..<word.count { proxy.deleteBackward() }
        proxy.insertText(fix)
        lastAutocorrection = (word, fix, separator)
    }
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboardViewDidPressKey(_ view: KeyboardView) {
        UIDevice.current.playInputClick()
        if settings.haptics && hasFullAccess {
            haptic.impactOccurred()
        }
    }

    func keyboardView(_ view: KeyboardView, insert text: String) {
        lastAutocorrection = nil
        previousWasSpace = false
        if text.count == 1, ".,!?;:".contains(text) {
            applyAutocorrection(separator: text)
        }
        proxy.insertText(text)
        if shift == .on { shift = .off }
        if page != .letters && text == "'" { page = .letters }
        afterEdit()
    }

    func keyboardViewDeleteBackward(_ view: KeyboardView) {
        previousWasSpace = false
        if let ac = lastAutocorrection, textBefore.hasSuffix(ac.replacement + ac.separator) {
            // Backspace right after an autocorrection puts back what you typed.
            for _ in 0..<(ac.replacement.count + ac.separator.count) { proxy.deleteBackward() }
            proxy.insertText(ac.original)
            predictor.ignore(ac.original)
        } else {
            proxy.deleteBackward()
        }
        lastAutocorrection = nil
        afterEdit()
    }

    func keyboardViewShift(_ view: KeyboardView) {
        let now = CACurrentMediaTime()
        if shift == .capsLock {
            shift = .off
            lastShiftTap = 0
        } else if now - lastShiftTap < 0.35 {
            shift = .capsLock
            lastShiftTap = 0
        } else {
            shift = shift == .off ? .on : .off
            lastShiftTap = now
        }
        pushState()
    }

    func keyboardViewSpace(_ view: KeyboardView) {
        let before = textBefore
        lastAutocorrection = nil
        if settings.doubleSpacePeriod, previousWasSpace, before.hasSuffix(" "),
           let prev = before.dropLast().last,
           prev.isLetter || prev.isNumber || prev == ")" || prev == "\"" || prev == "'" {
            proxy.deleteBackward()
            proxy.insertText(". ")
            previousWasSpace = false
        } else {
            applyAutocorrection(separator: " ")
            proxy.insertText(" ")
            previousWasSpace = true
        }
        if page != .letters { page = .letters }
        afterEdit()
    }

    func keyboardViewReturn(_ view: KeyboardView) {
        lastAutocorrection = nil
        previousWasSpace = false
        applyAutocorrection(separator: "\n")
        proxy.insertText("\n")
        afterEdit()
    }

    func keyboardView(_ view: KeyboardView, switchTo page: KeyboardPage) {
        previousWasSpace = false
        self.page = page
        updateAutoShift()
        pushState()
    }

    func keyboardView(_ view: KeyboardView, moveCursorBy offset: Int) {
        previousWasSpace = false
        lastAutocorrection = nil
        proxy.adjustTextPosition(byCharacterOffset: offset)
        afterEdit()
    }

    func keyboardView(_ view: KeyboardView, globeTouchFrom source: UIView, event: UIEvent) {
        handleInputModeList(from: source, with: event)
    }

    func keyboardView(_ view: KeyboardView, didSelect suggestion: Suggestion) {
        let word = predictor.currentWord(in: textBefore)
        lastAutocorrection = nil
        switch suggestion.kind {
        case .verbatim:
            predictor.learn(word)
            proxy.insertText(" ")
        case .correction, .completion:
            for _ in 0..<word.count { proxy.deleteBackward() }
            proxy.insertText(suggestion.text + " ")
        }
        previousWasSpace = true
        afterEdit()
    }
}
