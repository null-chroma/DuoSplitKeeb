import UIKit

/// The magnified "balloon" shown above a letter key while it is pressed.
final class KeyPreviewView: UIView {
    private let shape = CAShapeLayer()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.addSublayer(shape)
        shape.shadowOffset = CGSize(width: 0, height: 1)
        shape.shadowRadius = 2
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// - Parameters:
    ///   - key: the visible frame of the key, in this view's coordinates.
    func show(text: String, key: CGRect, theme: KeyboardTheme) {
        let neck: CGFloat = 10
        let extra = max(6, (key.width * 0.3).rounded())
        let height = max(24, min(key.height * 1.1, key.minY - neck - 1))
        var top = CGRect(x: key.minX - extra, y: key.minY - neck - height,
                         width: key.width + 2 * extra, height: height)

        // Keys hugging the screen edge: slide the balloon inward so it stays on screen.
        if top.minX < 1 {
            top.origin.x += min(1 - top.minX, extra)
        } else if top.maxX > bounds.width - 1 {
            top.origin.x -= min(top.maxX - (bounds.width - 1), extra)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let path = Self.balloonPath(top: top, key: key, neck: neck)
        shape.path = path.cgPath
        shape.shadowPath = path.cgPath
        shape.fillColor = theme.popupFill.cgColor
        shape.shadowColor = UIColor.black.cgColor
        shape.shadowOpacity = theme.isDark ? 0.5 : 0.3
        CATransaction.commit()

        label.text = text
        label.textColor = theme.text
        label.font = .systemFont(ofSize: min(36, height * 0.8), weight: .regular)
        label.frame = top.insetBy(dx: 2, dy: 0)
        isHidden = false
    }

    func hide() {
        isHidden = true
    }

    private static func balloonPath(top t: CGRect, key k: CGRect, neck n: CGFloat) -> UIBezierPath {
        let r: CGFloat = 8
        let kr = KeyView.cornerRadius
        let p = UIBezierPath()
        p.move(to: CGPoint(x: t.minX + r, y: t.minY))
        p.addLine(to: CGPoint(x: t.maxX - r, y: t.minY))
        p.addArc(withCenter: CGPoint(x: t.maxX - r, y: t.minY + r), radius: r,
                 startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        p.addLine(to: CGPoint(x: t.maxX, y: t.maxY))
        p.addCurve(to: CGPoint(x: k.maxX, y: k.minY),
                   controlPoint1: CGPoint(x: t.maxX, y: t.maxY + n * 0.5),
                   controlPoint2: CGPoint(x: k.maxX, y: k.minY - n * 0.5))
        p.addLine(to: CGPoint(x: k.maxX, y: k.maxY - kr))
        p.addArc(withCenter: CGPoint(x: k.maxX - kr, y: k.maxY - kr), radius: kr,
                 startAngle: 0, endAngle: .pi / 2, clockwise: true)
        p.addLine(to: CGPoint(x: k.minX + kr, y: k.maxY))
        p.addArc(withCenter: CGPoint(x: k.minX + kr, y: k.maxY - kr), radius: kr,
                 startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        p.addLine(to: CGPoint(x: k.minX, y: k.minY))
        p.addCurve(to: CGPoint(x: t.minX, y: t.maxY),
                   controlPoint1: CGPoint(x: k.minX, y: k.minY - n * 0.5),
                   controlPoint2: CGPoint(x: t.minX, y: t.maxY + n * 0.5))
        p.addLine(to: CGPoint(x: t.minX, y: t.minY + r))
        p.addArc(withCenter: CGPoint(x: t.minX + r, y: t.minY + r), radius: r,
                 startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        p.close()
        return p
    }
}

/// The row of accented characters shown when a key is held down.
final class AlternatesView: UIView {
    private let panel = UIView()
    private let highlight = UIView()
    private var labels: [UILabel] = []
    private let options: [String]
    private let theme: KeyboardTheme
    private let cellWidth: CGFloat
    private static let padding: CGFloat = 4
    private var padding: CGFloat { Self.padding }
    private(set) var selectedIndex: Int = 0

    var selectedOption: String? {
        options.indices.contains(selectedIndex) ? options[selectedIndex] : nil
    }

    /// - Parameters:
    ///   - key: the visible key frame, in `container` coordinates.
    init(options: [String], key: CGRect, container: CGRect, theme: KeyboardTheme, touchX: CGFloat) {
        self.theme = theme
        self.cellWidth = max(key.width, 28)
        let cellHeight = key.height
        let padding = Self.padding
        let total = max(key.width, 28) * CGFloat(options.count) + 2 * padding

        // Grow to the right of the key, or to the left (in reverse order, so the first
        // option is still right above the finger) if there isn't room on the right.
        var x = key.minX - padding
        var ordered = options
        if x + total > container.maxX - 2 {
            x = key.maxX + padding - total
            ordered.reverse()
        }
        x = min(max(x, container.minX + 2), container.maxX - 2 - total)
        let y = max(2, key.minY - cellHeight - 2 * padding - 6)
        self.options = ordered

        super.init(frame: container)
        isUserInteractionEnabled = false

        panel.frame = CGRect(x: x, y: y, width: total, height: cellHeight + 2 * padding)
        panel.backgroundColor = theme.popupFill
        panel.layer.cornerRadius = 9
        panel.layer.cornerCurve = .continuous
        panel.layer.shadowColor = UIColor.black.cgColor
        panel.layer.shadowOpacity = theme.isDark ? 0.5 : 0.3
        panel.layer.shadowRadius = 3
        panel.layer.shadowOffset = CGSize(width: 0, height: 1)
        addSubview(panel)

        highlight.backgroundColor = theme.selectionFill
        highlight.layer.cornerRadius = KeyView.cornerRadius
        highlight.layer.cornerCurve = .continuous
        panel.addSubview(highlight)

        for (i, option) in ordered.enumerated() {
            let l = UILabel(frame: CGRect(x: padding + CGFloat(i) * cellWidth, y: padding,
                                          width: cellWidth, height: cellHeight))
            l.text = option
            l.textAlignment = .center
            l.font = .systemFont(ofSize: min(26, cellHeight * 0.6))
            panel.addSubview(l)
            labels.append(l)
        }
        select(atX: touchX)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func select(atX x: CGFloat) {
        let local = x - panel.frame.minX - padding
        let index = Int(floor(local / cellWidth))
        selectedIndex = min(max(index, 0), options.count - 1)
        highlight.frame = labels[selectedIndex].frame
        for (i, l) in labels.enumerated() {
            l.textColor = i == selectedIndex ? theme.selectionText : theme.text
        }
    }
}
