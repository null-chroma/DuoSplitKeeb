import UIKit

/// A single drawn key. Touches are handled by `KeyboardView`, not by the key itself.
final class KeyView: UIView {
    enum Style {
        /// Letter / number / space keys (white in light mode).
        case character
        /// Shift, delete, 123, globe, return (gray in light mode).
        case function
        /// Blue action key ("go", "search", "send" …).
        case primary
    }

    static let cornerRadius: CGFloat = 5

    let spec: KeySpec
    /// The touch area for this key, in `KeyboardView` coordinates. Includes the gaps around
    /// the key so there are no dead spots between keys.
    var hitFrame: CGRect = .zero

    var theme: KeyboardTheme = .light { didSet { applyColors() } }
    var isPressed = false { didSet { if isPressed != oldValue { applyColors() } } }
    var isEnabled = true { didSet { if isEnabled != oldValue { applyColors() } } }
    var isContentHidden = false {
        didSet {
            label.isHidden = isContentHidden
            icon.isHidden = isContentHidden
        }
    }

    private(set) var style: Style = .character
    private let label = UILabel()
    private let icon = UIImageView()

    init(spec: KeySpec) {
        self.spec = spec
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        layer.cornerRadius = Self.cornerRadius
        layer.cornerCurve = .continuous
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0

        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.baselineAdjustment = .alignCenters
        addSubview(label)

        icon.contentMode = .center
        addSubview(icon)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String?, symbol: String?, style: Style, font: UIFont) {
        self.style = style
        if label.text != text { label.text = text }
        label.font = font
        if let symbol {
            let config = UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)
            icon.image = UIImage(systemName: symbol, withConfiguration: config)
        } else {
            icon.image = nil
        }
        applyColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Lowercase letters sit very slightly high on the system keyboard.
        let lift: CGFloat = spec.isCharacter ? 1 : 0
        label.frame = bounds.insetBy(dx: 3, dy: 0).offsetBy(dx: 0, dy: -lift)
        icon.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Self.cornerRadius).cgPath
    }

    private func applyColors() {
        let fill: UIColor
        var foreground: UIColor = theme.text
        switch style {
        case .character:
            // Letter keys show a popup instead of changing color; the space bar darkens.
            fill = (isPressed && spec.action == .space) ? theme.pressedCharacterKey : theme.characterKey
        case .function:
            fill = isPressed ? theme.pressedFunctionKey : theme.functionKey
        case .primary:
            fill = isPressed ? theme.pressedPrimaryKey : theme.primaryKey
            foreground = isPressed ? theme.pressedPrimaryText : theme.primaryText
        }
        if !isEnabled {
            foreground = foreground.withAlphaComponent(0.4)
        }
        backgroundColor = fill
        label.textColor = foreground
        icon.tintColor = foreground
        layer.shadowColor = theme.shadow.cgColor
        layer.shadowOpacity = theme.shadowOpacity
    }
}
