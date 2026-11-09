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
        var returnTitle: String?
        var returnIsPrimary = false
        var returnEnabled = true
        var isDark = false
    }

    /// Sizes for one layout pass.
    struct Metrics: Equatable {
        var split: Bool
        /// Width of one key plus its gap.
        var unit: CGFloat
        /// Height of one key row plus its gap.
        var rowPitch: CGFloat
        var hGap: CGFloat
        var vGap: CGFloat
        var barHeight: CGFloat
        var topPadding: CGFloat
        var bottomPadding: CGFloat

        var keysTop: CGFloat { barHeight + topPadding }
        var height: CGFloat { keysTop + CGFloat(KeyboardView.rowCount) * rowPitch + bottomPadding }
        var keyHeight: CGFloat { rowPitch - vGap }
    }

    static let rowCount = 4

    // Measured from the system split keyboard on the unfolded screen: one key plus its gap is
    // 6% of the screen width, the gap is 19% of that, and rows are 96.7% as tall as keys are wide.
    static let splitUnitFraction: CGFloat = 0.06
    static let splitGapFraction: CGFloat = 0.19
    static let splitRowFraction: CGFloat = 0.967

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
    private var metrics = Metrics(split: false, unit: 40, rowPitch: 54, hGap: 6, vGap: 12,
                                  barHeight: 44, topPadding: 2, bottomPadding: 2)
    private let preview = KeyPreviewView()
    private var alternatesView: AlternatesView?
    private var tracked: [UITouch: TrackedTouch] = [:]

    private var showsPopups: Bool { !metrics.split || settings.keyPopups }

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
        backgroundColor = theme.background ?? .clear
        suggestionBar.theme = theme
        if old.page != newState.page {
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
        let keyHeight = metrics.keyHeight
        let letterFont = UIFont.systemFont(ofSize: min(30, max(17, (keyHeight * 0.5).rounded())), weight: .regular)
        let functionFont = UIFont.systemFont(ofSize: min(22, max(14, (keyHeight * 0.41).rounded())), weight: .regular)
        let symbolSize = min(24, max(16, (keyHeight * 0.42).rounded()))
        let popups = showsPopups

        for key in keyViews {
            key.theme = theme
            key.highlightsWhenPressed = !popups
            switch key.spec.action {
            case .character(let c):
                key.configure(text: displayText(c), symbol: nil, symbolSize: symbolSize, style: .normal, font: letterFont)
            case .shift:
                let symbol: String
                switch state.shift {
                case .off: symbol = "shift"
                case .on: symbol = "shift.fill"
                case .capsLock: symbol = "capslock.fill"
                }
                key.configure(text: nil, symbol: symbol, symbolSize: symbolSize, style: .normal, font: functionFont)
            case .backspace:
                key.configure(text: nil, symbol: key.isPressed ? "delete.left.fill" : "delete.left",
                              symbolSize: symbolSize, style: .normal, font: functionFont)
            case .page:
                key.configure(text: key.spec.label, symbol: nil, symbolSize: symbolSize, style: .normal, font: functionFont)
            case .globe:
                key.configure(text: nil, symbol: "globe", symbolSize: symbolSize, style: .normal, font: functionFont)
            case .space:
                // The system split keyboard's space bar has no label.
                key.configure(text: metrics.split ? nil : "space", symbol: nil, symbolSize: symbolSize,
                              style: .normal, font: functionFont)
            case .returnKey:
                if let title = state.returnTitle {
                    key.configure(text: title, symbol: nil, symbolSize: symbolSize,
                                  style: state.returnIsPrimary ? .primary : .normal, font: functionFont)
                } else {
                    key.configure(text: nil, symbol: "return.left", symbolSize: symbolSize,
                                  style: .normal, font: functionFont)
                }
                key.isEnabled = state.returnEnabled
            case .spacer:
                break
            }
        }
    }

    // MARK: - Layout

    private func shouldSplit(width: CGFloat) -> Bool {
        switch settings.splitMode {
        case .always: return true
        case .never: return false
        case .automatic:
            // Unfolded = wide and close to square. The folded phone in landscape is wide but
            // long and skinny, so it gets the normal keyboard.
            guard width >= 600 else { return false }
            let screen = window?.windowScene?.screen.bounds.size ?? UIScreen.main.bounds.size
            let long = max(screen.width, screen.height)
            let short = max(1, min(screen.width, screen.height))
            return long / short < 1.6
        }
    }

    func computeMetrics(forWidth width: CGFloat) -> Metrics {
        let heightScale = CGFloat(settings.keyHeightScale)
        if shouldSplit(width: width) {
            let outer = CGFloat(settings.edgeMargin)
            let maxUnit = max(20, (width - 2 * outer - 24) / (2 * KeyboardLayouts.halfWidthUnits))
            let unit = min(width * Self.splitUnitFraction * CGFloat(settings.keyScale), maxUnit)
            let rowPitch = unit * Self.splitRowFraction * heightScale
            let bar: CGFloat = settings.showSuggestionBar ? 40 : 0
            return Metrics(split: true, unit: unit, rowPitch: rowPitch,
                           hGap: (unit * Self.splitGapFraction).rounded(),
                           vGap: (rowPitch * 0.25).rounded(),
                           barHeight: bar,
                           topPadding: (unit * 0.1).rounded(),
                           bottomPadding: (unit * 0.25).rounded())
        } else {
            let rowPitch = 54 * heightScale
            return Metrics(split: false, unit: width / KeyboardLayouts.fullWidthUnits, rowPitch: rowPitch,
                           hGap: 6, vGap: (rowPitch * 0.22).rounded(),
                           barHeight: 44, topPadding: 2, bottomPadding: 2)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        preview.frame = bounds
        alternatesView?.frame = bounds
        guard bounds.width > 0 else { return }

        metrics = computeMetrics(forWidth: bounds.width)
        suggestionBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: metrics.barHeight)
        suggestionBar.isHidden = metrics.barHeight == 0

        let signature = BuildSignature(page: state.page, split: metrics.split)
        if signature != builtSignature {
            rebuild(signature)
        }
        layoutKeys()
        refreshKeys()
        bringSubviewToFront(preview)
        if let alternatesView { bringSubviewToFront(alternatesView) }
    }

    private func rebuild(_ signature: BuildSignature) {
        cancelAllTouches()
        keyViews.forEach { $0.removeFromSuperview() }
        keyViews = []
        segments = []

        let page = KeyboardLayouts.page(signature.page)
        for row in 0..<page.left.count {
            if signature.split {
                segments.append(makeSegment(row: row, side: .left, specs: page.left[row]))
                segments.append(makeSegment(row: row, side: .right, specs: page.right[row]))
            } else {
                let joined = KeyboardLayouts.join(page.left[row], page.right[row],
                                                  isBottomRow: row == Self.rowCount - 1)
                segments.append(makeSegment(row: row, side: .joined, specs: joined))
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

    private func layoutKeys() {
        let m = metrics
        let width = bounds.width
        let halfWidth = m.unit * KeyboardLayouts.halfWidthUnits
        // `edgeMargin` is the visible distance from the screen edge to the outermost key.
        let outer = max(0, CGFloat(settings.edgeMargin) - m.hGap / 2)
        let corner = CGFloat(settings.bottomCornerInset)

        for segment in segments {
            let y = m.keysTop + CGFloat(segment.row) * m.rowPitch
            let isBottomRow = segment.row == Self.rowCount - 1
            switch segment.side {
            case .left:
                let inset = isBottomRow ? corner : 0
                place(segment, x: outer + inset, width: halfWidth - inset, alignment: .leading, y: y)
            case .right:
                let inset = isBottomRow ? corner : 0
                place(segment, x: width - outer - halfWidth, width: halfWidth - inset, alignment: .trailing, y: y)
            case .joined:
                place(segment, x: 0, width: width, alignment: .center, y: y)
            }
        }
    }

    private enum Alignment { case leading, trailing, center }

    private func place(_ segment: Segment, x: CGFloat, width: CGFloat, alignment: Alignment, y: CGFloat) {
        let m = metrics
        let unit = m.unit
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
        let radius = (m.keyHeight * 0.24).rounded()
        for (spec, view) in zip(segment.specs, segment.views) {
            let w = (spec.isFlexible ? flexWidth : spec.width * unit) * scale
            if let view {
                let cell = CGRect(x: cursor, y: y, width: w, height: m.rowPitch)
                view.frame = cell.insetBy(dx: m.hGap / 2, dy: m.vGap / 2).integral
                view.cornerRadius = radius
                var hit = cell
                if isTopRow { hit.origin.y -= m.topPadding; hit.size.height += m.topPadding }
                if isBottomRow { hit.size.height += m.bottomPadding + 20 }
                view.hitFrame = hit
            }
            cursor += w
        }
    }

    // MARK: - Hit testing

    private func key(at point: CGPoint) -> KeyView? {
        guard point.y >= metrics.barHeight else { return nil }
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
        return bestDistance <= metrics.unit * 0.75 ? best : nil
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
        guard showsPopups, case .character(let c) = key.spec.action else { return }
        preview.frame = bounds
        preview.show(text: displayText(c), key: key.frame, cornerRadius: key.cornerRadius, theme: theme)
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
