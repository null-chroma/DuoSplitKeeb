import UIKit

protocol KeyboardViewDelegate: AnyObject {
    func keyboardViewDidPressKey(_ view: KeyboardView)
    func keyboardView(_ view: KeyboardView, insert text: String)
    func keyboardViewDeleteBackward(_ view: KeyboardView)
    func keyboardViewShift(_ view: KeyboardView)
    func keyboardViewSpace(_ view: KeyboardView)
    func keyboardViewReturn(_ view: KeyboardView)
    func keyboardView(_ view: KeyboardView, switchTo page: KeyboardPage)
    func keyboardView(_ view: KeyboardView, moveCursorBy offset: Int)
    func keyboardView(_ view: KeyboardView, globeTouchFrom source: UIView, event: UIEvent)
    func keyboardView(_ view: KeyboardView, didSelect suggestion: Suggestion)
}

/// Draws the suggestion bar and all keys, lays them out (split or joined), and handles touches.
final class KeyboardView: UIView {
    struct State: Equatable {
        var page: KeyboardPage = .letters
        var shift: ShiftState = .off
        var showsGlobe = true
        var returnTitle = "return"
        var returnIsPrimary = false
        var returnEnabled = true
        var isDark = false
    }

    static let suggestionBarHeight: CGFloat = 44
    static let topPadding: CGFloat = 2
    static let bottomPadding: CGFloat = 2
    static let rowCount = 4
    /// Horizontal gap between neighboring keys (same as the system keyboard).
    static let keyGap: CGFloat = 6

    static func preferredHeight(for settings: KeyboardSettings) -> CGFloat {
        suggestionBarHeight + topPadding + CGFloat(rowCount) * CGFloat(settings.rowHeight) + bottomPadding
    }

    weak var delegate: KeyboardViewDelegate?

    var settings = KeyboardSettings() {
        didSet {
            guard settings != oldValue else { return }
            setNeedsLayout()
        }
    }

    private(set) var state = State()
    let suggestionBar = SuggestionBar()

    // MARK: - Private state

    private enum Side { case left, right, joined }

    private struct Segment {
        var row: Int
        var side: Side
        var specs: [KeySpec]
        var views: [KeyView?]
    }

    private struct BuildSignature: Equatable {
        var page: KeyboardPage
        var showsGlobe: Bool
        var split: Bool
    }

    private final class TrackedTouch {
        enum Mode { case normal, alternates, trackpad }
        var key: KeyView
        var mode: Mode = .normal
        var timer: Timer?
        var location: CGPoint
        var trackpadRemainder: CGFloat = 0

        init(key: KeyView, location: CGPoint) {
            self.key = key
            self.location = location
        }

        func stopTimer() {
            timer?.invalidate()
            timer = nil
        }
    }

    private var segments: [Segment] = []
    private var keyViews: [KeyView] = []
    private var builtSignature: BuildSignature?
    private var theme = KeyboardTheme.light
    private var keyUnit: CGFloat = 40
    private let preview = KeyPreviewView()
    private var alternatesView: AlternatesView?
    private var tracked: [UITouch: TrackedTouch] = [:]

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        addSubview(suggestionBar)
        suggestionBar.onSelect = { [weak self] suggestion in
            guard let self else { return }
            self.delegate?.keyboardView(self, didSelect: suggestion)
        }
        preview.hide()
        addSubview(preview)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - State

    func apply(_ newState: State) {
        let old = state
        state = newState
        theme = newState.isDark ? .dark : .light
        overrideUserInterfaceStyle = newState.isDark ? .dark : .light
        suggestionBar.theme = theme
        if old.page != newState.page || old.showsGlobe != newState.showsGlobe {
            setNeedsLayout()
            layoutIfNeeded()
        }
        refreshKeys()
    }

    private func displayText(_ character: String) -> String {
        guard state.shift != .off else { return character }
        let upper = character.uppercased()
        return upper.count == character.count ? upper : character
    }

    private func refreshKeys() {
        let letterFont = UIFont.systemFont(ofSize: min(25, max(18, (keyUnit * 0.58).rounded())), weight: .regular)
        let functionFont = UIFont.systemFont(ofSize: 16, weight: .regular)
        for key in keyViews {
            key.theme = theme
            switch key.spec.action {
            case .character(let c):
                key.configure(text: displayText(c), symbol: nil, style: .character, font: letterFont)
            case .shift:
                let symbol: String
                switch state.shift {
                case .off: symbol = "shift"
                case .on: symbol = "shift.fill"
                case .capsLock: symbol = "capslock.fill"
                }
                key.configure(text: nil, symbol: symbol, style: state.shift == .off ? .function : .character, font: functionFont)
            case .backspace:
                key.configure(text: nil, symbol: key.isPressed ? "delete.left.fill" : "delete.left", style: .function, font: functionFont)
            case .page:
                key.configure(text: key.spec.label, symbol: nil, style: .function, font: functionFont)
            case .globe:
                key.configure(text: nil, symbol: "globe", style: .function, font: functionFont)
            case .space:
                key.configure(text: "space", symbol: nil, style: .character, font: functionFont)
            case .returnKey:
                key.configure(text: state.returnTitle, symbol: nil,
                              style: state.returnIsPrimary ? .primary : .function, font: functionFont)
                key.isEnabled = state.returnEnabled
            case .spacer:
                break
            }
        }
    }

    // MARK: - Layout

    private func shouldSplit() -> Bool {
        switch settings.splitMode {
        case .always: return true
        case .never: return false
        case .automatic:
            // Unfolded = wide and close to square. Folded phone in landscape is wide but
            // long and skinny, so it gets the normal keyboard.
            guard bounds.width >= 600 else { return false }
            let screen = window?.windowScene?.screen.bounds.size ?? UIScreen.main.bounds.size
            let long = max(screen.width, screen.height)
            let short = max(1, min(screen.width, screen.height))
            return long / short < 1.6
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        suggestionBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: Self.suggestionBarHeight)
        preview.frame = bounds
        alternatesView?.frame = bounds
        guard bounds.width > 0 else { return }

        let split = shouldSplit()
        let signature = BuildSignature(page: state.page, showsGlobe: state.showsGlobe, split: split)
        if signature != builtSignature {
            rebuild(signature)
        }
        layoutKeys(split: split)
        refreshKeys()
        bringSubviewToFront(preview)
        if let alternatesView { bringSubviewToFront(alternatesView) }
    }

    private func rebuild(_ signature: BuildSignature) {
        cancelAllTouches()
        keyViews.forEach { $0.removeFromSuperview() }
        keyViews = []
        segments = []

        let page = KeyboardLayouts.page(signature.page, showsGlobe: signature.showsGlobe)
        for row in 0..<page.left.count {
            if signature.split {
                segments.append(makeSegment(row: row, side: .left, specs: page.left[row]))
                segments.append(makeSegment(row: row, side: .right, specs: page.right[row]))
            } else {
                segments.append(makeSegment(row: row, side: .joined,
                                            specs: KeyboardLayouts.join(page.left[row], page.right[row])))
            }
        }
        builtSignature = signature
    }

    private func makeSegment(row: Int, side: Side, specs: [KeySpec]) -> Segment {
        let views: [KeyView?] = specs.map { spec in
            guard spec.action != .spacer else { return nil }
            let v = KeyView(spec: spec)
            insertSubview(v, belowSubview: preview)
            keyViews.append(v)
            return v
        }
        return Segment(row: row, side: side, specs: specs, views: views)
    }

    private func layoutKeys(split: Bool) {
        let rowHeight = CGFloat(settings.rowHeight)
        let vGap = max(8, (rowHeight * 0.22).rounded())
        let hGap = Self.keyGap
        let top = Self.suggestionBarHeight + Self.topPadding
        let width = bounds.width

        var leftX: CGFloat = 0, rightX: CGFloat = 0, halfWidth: CGFloat = 0
        if split {
            // `edgeMargin` is the visible distance from the screen edge to the first key.
            let outer = max(0, CGFloat(settings.edgeMargin) - hGap / 2)
            let maxUnit = max(20, (width - 2 * outer - 40) / (2 * KeyboardLayouts.halfWidthUnits))
            keyUnit = min(CGFloat(settings.keyWidth), maxUnit)
            halfWidth = keyUnit * KeyboardLayouts.halfWidthUnits
            leftX = outer
            rightX = width - outer - halfWidth
        } else {
            keyUnit = width / KeyboardLayouts.fullWidthUnits
        }

        for segment in segments {
            let y = top + CGFloat(segment.row) * rowHeight
            switch segment.side {
            case .left:
                place(segment, x: leftX, width: halfWidth, alignment: .leading, y: y, rowHeight: rowHeight, hGap: hGap, vGap: vGap)
            case .right:
                place(segment, x: rightX, width: halfWidth, alignment: .trailing, y: y, rowHeight: rowHeight, hGap: hGap, vGap: vGap)
            case .joined:
                place(segment, x: 0, width: width, alignment: .center, y: y, rowHeight: rowHeight, hGap: hGap, vGap: vGap)
            }
        }
    }

    private enum Alignment { case leading, trailing, center }

    private func place(_ segment: Segment, x: CGFloat, width: CGFloat, alignment: Alignment,
                       y: CGFloat, rowHeight: CGFloat, hGap: CGFloat, vGap: CGFloat) {
        let unit = keyUnit
        let fixed = segment.specs.filter { !$0.isFlexible }.reduce(0) { $0 + $1.width } * unit
        let flexCount = CGFloat(segment.specs.filter { $0.isFlexible }.count)
        var flexWidth: CGFloat = 0
        var total = fixed
        if flexCount > 0 {
            flexWidth = max(unit, (width - fixed) / flexCount)
            total = fixed + flexWidth * flexCount
        }
        let scale: CGFloat = total > width ? width / total : 1
        total *= scale

        var cursor: CGFloat
        switch alignment {
        case .leading: cursor = x
        case .trailing: cursor = x + width - total
        case .center: cursor = x + (width - total) / 2
        }

        let isTopRow = segment.row == 0
        let isBottomRow = segment.row == Self.rowCount - 1
        for (spec, view) in zip(segment.specs, segment.views) {
            let w = (spec.isFlexible ? flexWidth : spec.width * unit) * scale
            if let view {
                let cell = CGRect(x: cursor, y: y, width: w, height: rowHeight)
                view.frame = cell.insetBy(dx: hGap / 2, dy: vGap / 2).integral
                var hit = cell
                if isTopRow { hit.origin.y -= Self.topPadding; hit.size.height += Self.topPadding }
                if isBottomRow { hit.size.height += Self.bottomPadding + 20 }
                view.hitFrame = hit
            }
            cursor += w
        }
    }

    // MARK: - Hit testing

    private func key(at point: CGPoint) -> KeyView? {
        guard point.y >= Self.suggestionBarHeight else { return nil }
        var best: KeyView?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for key in keyViews {
            let f = key.hitFrame
            if f.contains(point) { return key }
            let dx = max(f.minX - point.x, 0, point.x - f.maxX)
            let dy = max(f.minY - point.y, 0, point.y - f.maxY)
            let d = hypot(dx, dy)
            if d < bestDistance {
                bestDistance = d
                best = key
            }
        }
        // Snap to a nearby key (e.g. a tap in the strip between a key and the screen edge),
        // but ignore taps in the empty middle of the split keyboard.
        return bestDistance <= keyUnit * 0.75 ? best : nil
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)

            // Fast typing: a new finger landing commits a letter that is still held down.
            for (other, t) in tracked where t.mode == .normal && t.key.spec.isCharacter {
                tracked[other] = nil
                finish(t, commit: true)
            }

            guard let key = key(at: point) else { continue }
            let t = TrackedTouch(key: key, location: point)
            tracked[touch] = t
            press(t, event: event)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let t = tracked[touch] else { continue }
            let point = touch.location(in: self)
            let dx = point.x - t.location.x
            t.location = point

            switch t.mode {
            case .alternates:
                alternatesView?.select(atX: point.x)
            case .trackpad:
                t.trackpadRemainder += dx
                let step: CGFloat = 9
                let moves = Int(t.trackpadRemainder / step)
                if moves != 0 {
                    t.trackpadRemainder -= CGFloat(moves) * step
                    delegate?.keyboardView(self, moveCursorBy: moves)
                }
            case .normal:
                if t.key.spec.action == .globe, let event {
                    delegate?.keyboardView(self, globeTouchFrom: self, event: event)
                }
                // Sliding a finger from one letter to another changes the pressed letter.
                if t.key.spec.isCharacter, let newKey = key(at: point), newKey !== t.key, newKey.spec.isCharacter {
                    t.stopTimer()
                    t.key.isPressed = false
                    t.key = newKey
                    newKey.isPressed = true
                    showPreview(for: newKey)
                    scheduleAlternates(for: t)
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let t = tracked.removeValue(forKey: touch) else { continue }
            if t.key.spec.action == .globe, let event {
                delegate?.keyboardView(self, globeTouchFrom: self, event: event)
            }
            finish(t, commit: true)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let t = tracked.removeValue(forKey: touch) else { continue }
            if t.key.spec.action == .globe, let event {
                delegate?.keyboardView(self, globeTouchFrom: self, event: event)
            }
            finish(t, commit: false)
        }
    }

    private func cancelAllTouches() {
        let all = tracked.values
        tracked = [:]
        all.forEach { finish($0, commit: false) }
    }

    private func press(_ t: TrackedTouch, event: UIEvent?) {
        let key = t.key
        key.isPressed = true
        delegate?.keyboardViewDidPressKey(self)

        switch key.spec.action {
        case .character:
            showPreview(for: key)
            scheduleAlternates(for: t)
        case .backspace:
            refreshKeys()
            delegate?.keyboardViewDeleteBackward(self)
            t.timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self, weak t] _ in
                guard let self, let t else { return }
                t.timer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    self.delegate?.keyboardViewDidPressKey(self)
                    self.delegate?.keyboardViewDeleteBackward(self)
                }
            }
        case .shift:
            delegate?.keyboardViewShift(self)
        case .space:
            // Hold the space bar to move the cursor, like the system keyboard.
            t.timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self, weak t] _ in
                guard let self, let t, self.tracked.values.contains(where: { $0 === t }) else { return }
                t.mode = .trackpad
                self.setTrackpadMode(true)
            }
        case .globe:
            if let event { delegate?.keyboardView(self, globeTouchFrom: self, event: event) }
        case .page, .returnKey, .spacer:
            break
        }
    }

    private func finish(_ t: TrackedTouch, commit: Bool) {
        t.stopTimer()
        t.key.isPressed = false

        switch t.mode {
        case .alternates:
            if commit, let option = alternatesView?.selectedOption {
                delegate?.keyboardView(self, insert: option)
            }
            alternatesView?.removeFromSuperview()
            alternatesView = nil
        case .trackpad:
            setTrackpadMode(false)
        case .normal:
            if commit { performAction(t.key.spec.action) }
        }

        if t.key.spec.isCharacter { preview.hide() }
        if t.key.spec.action == .backspace { refreshKeys() }
    }

    private func performAction(_ action: KeyAction) {
        switch action {
        case .character(let c): delegate?.keyboardView(self, insert: displayText(c))
        case .space: delegate?.keyboardViewSpace(self)
        case .returnKey: if state.returnEnabled { delegate?.keyboardViewReturn(self) }
        case .page(let p): delegate?.keyboardView(self, switchTo: p)
        case .shift, .backspace, .globe, .spacer: break
        }
    }

    private func showPreview(for key: KeyView) {
        guard case .character(let c) = key.spec.action else { return }
        preview.frame = bounds
        preview.show(text: displayText(c), key: key.frame, theme: theme)
        bringSubviewToFront(preview)
    }

    private func scheduleAlternates(for t: TrackedTouch) {
        guard !t.key.spec.alternates.isEmpty else { return }
        t.timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self, weak t] _ in
            guard let self, let t, t.mode == .normal,
                  self.tracked.values.contains(where: { $0 === t }) else { return }
            self.preview.hide()
            self.alternatesView?.removeFromSuperview()
            let options = t.key.spec.alternates.map { self.displayText($0) }
            let v = AlternatesView(options: options, key: t.key.frame, container: self.bounds,
                                   theme: self.theme, touchX: t.location.x)
            self.addSubview(v)
            self.alternatesView = v
            t.mode = .alternates
        }
    }

    private func setTrackpadMode(_ on: Bool) {
        keyViews.forEach { $0.isContentHidden = on }
        suggestionBar.alpha = on ? 0.3 : 1
    }
}
