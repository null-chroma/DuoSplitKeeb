import UIKit

/// A single drawn key. Touches are handled by `KeyboardView`, not by the key itself.
final class KeyView: UIView {
    enum Style {
        /// Every normal key (letters, shift, delete, 123, globe, space, plain return).
        case normal
        /// Blue action key ("go", "search", "send" …).
        case primary
    }

    let spec: KeySpec
    /// The touch area for this key, in `KeyboardView` coordinates. Includes the gaps around
    /// the key so there are no dead spots between keys.
    var hitFrame: CGRect = .zero

    var theme: KeyboardTheme = .light { didSet { applyColors() } }
    var isPressed = false { didSet { if isPressed != oldValue { applyColors() } } }
    var isEnabled = true { didSet { if isEnabled != oldValue { applyColors() } } }
    /// When false, the key keeps its color while pressed (a pop-up balloon covers it instead).
    var highlightsWhenPressed = true
    var cornerRadius: CGFloat = 8 {
        didSet { layer.cornerRadius = cornerRadius }
    }
    var isContentHidden = false {
        didSet {
            label.isHidden = isContentHidden
            icon.isHidden = isContentHidden
        }
    }

    private(set) var style: Style = .normal
    private let label = UILabel()
    private let icon = UIImageView()

    init(spec: KeySpec) {
        self.spec = spec
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous

        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.baselineAdjustment = .alignCenters
        addSubview(label)

        icon.contentMode = .center
        addSubview(icon)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String?, symbol: String?, symbolSize: CGFloat, style: Style, font: UIFont) {
        self.style = style
        if label.text != text { label.text = text }
        label.font = font
        if let symbol {
            let config = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .regular)
            icon.image = UIImage(systemName: symbol, withConfiguration: config)
        } else {
            icon.image = nil
        }
        applyColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 3, dy: 0)
        icon.frame = bounds
    }

    private func applyColors() {
        let showPressed = isPressed && (highlightsWhenPressed || !spec.isCharacter)
        let fill: UIColor
        var foreground: UIColor
        switch style {
        case .normal:
            fill = showPressed ? theme.pressedKey : theme.key
            foreground = theme.text
        case .primary:
            fill = showPressed ? theme.pressedPrimaryKey : theme.primaryKey
            foreground = theme.primaryText
        }
        if !isEnabled {
            foreground = foreground.withAlphaComponent(0.4)
        }
        backgroundColor = fill
        label.textColor = foreground
        icon.tintColor = foreground
    }
}
