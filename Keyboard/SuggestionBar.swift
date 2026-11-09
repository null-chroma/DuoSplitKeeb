import UIKit

struct Suggestion: Equatable {
    enum Kind {
        /// Exactly what was typed (shown in quotes). Tapping it keeps the word as-is.
        case verbatim
        /// A spelling correction.
        case correction
        /// A word completion.
        case completion
    }

    var text: String
    var kind: Kind
    /// Will be applied automatically when you type a space.
    var isAutocorrection = false
}

/// The three-slot predictive bar above the keys.
final class SuggestionBar: UIView {
    var onSelect: ((Suggestion) -> Void)?
    var theme: KeyboardTheme = .light { didSet { refresh() } }

    private var buttons: [UIButton] = []
    private var separators: [UIView] = []
    private var items: [Suggestion?] = [nil, nil, nil]

    override init(frame: CGRect) {
        super.init(frame: frame)
        for i in 0..<3 {
            let b = UIButton(type: .custom)
            b.tag = i
            b.titleLabel?.font = .systemFont(ofSize: 17)
            b.titleLabel?.adjustsFontSizeToFitWidth = true
            b.titleLabel?.minimumScaleFactor = 0.6
            b.titleLabel?.lineBreakMode = .byTruncatingMiddle
            b.layer.cornerRadius = 6
            b.layer.cornerCurve = .continuous
            b.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            addSubview(b)
            buttons.append(b)
        }
        for _ in 0..<2 {
            let s = UIView()
            addSubview(s)
            separators.append(s)
        }
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSuggestions(_ suggestions: [Suggestion]) {
        var slots: [Suggestion?] = [nil, nil, nil]
        switch suggestions.count {
        case 0: break
        case 1: slots[1] = suggestions[0]
        default:
            for (i, s) in suggestions.prefix(3).enumerated() { slots[i] = s }
        }
        guard slots != items else { return }
        items = slots
        refresh()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width / 3
        for (i, b) in buttons.enumerated() {
            b.frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: bounds.height).insetBy(dx: 4, dy: 5)
        }
        let px = 1 / max(1, traitCollection.displayScale)
        for (i, s) in separators.enumerated() {
            s.frame = CGRect(x: CGFloat(i + 1) * w - px / 2, y: bounds.height * 0.25,
                             width: px, height: bounds.height * 0.5)
        }
    }

    private func refresh() {
        for (i, b) in buttons.enumerated() {
            let item = items[i]
            var title = item?.text ?? ""
            if item?.kind == .verbatim { title = "\u{201C}\(title)\u{201D}" }
            b.setTitle(title, for: .normal)
            b.setTitleColor(theme.text, for: .normal)
            b.setTitleColor(theme.text.withAlphaComponent(0.4), for: .highlighted)
            b.isEnabled = item != nil
            b.backgroundColor = item?.isAutocorrection == true ? theme.key : .clear
        }
        for (i, s) in separators.enumerated() {
            s.backgroundColor = theme.separator
            // Hide a separator next to a highlighted pill or an empty slot, like the system bar.
            let a = items[i], b = items[i + 1]
            s.isHidden = a == nil || b == nil || a?.isAutocorrection == true || b?.isAutocorrection == true
        }
    }

    @objc private func tapped(_ sender: UIButton) {
        guard let item = items[sender.tag] else { return }
        onSelect?(item)
    }
}
