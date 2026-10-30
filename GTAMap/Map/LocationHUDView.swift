import UIKit

/// GTA-style location text in the corner: street name above, district in bold italics.
final class LocationHUDView: UIView {
    private let streetLabel = UILabel()
    private let areaLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        streetLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        streetLabel.textColor = UIColor(white: 0.85, alpha: 1)

        let italicBold = UIFont.systemFont(ofSize: 22, weight: .heavy).fontDescriptor
            .withSymbolicTraits([.traitItalic, .traitBold]) ?? UIFont.systemFont(ofSize: 22).fontDescriptor
        areaLabel.font = UIFont(descriptor: italicBold, size: 22)
        areaLabel.textColor = .white

        for label in [streetLabel, areaLabel] {
            label.textAlignment = .right
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
            label.layer.shadowColor = UIColor.black.cgColor
            label.layer.shadowOpacity = 1
            label.layer.shadowRadius = 2
            label.layer.shadowOffset = CGSize(width: 1, height: 1)
        }

        let stack = UIStackView(arrangedSubviews: [streetLabel, areaLabel])
        stack.axis = .vertical
        stack.alignment = .trailing
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(area: String, street: String) {
        guard area != areaLabel.text || street != streetLabel.text else { return }
        UIView.transition(with: self, duration: 0.35, options: .transitionCrossDissolve) {
            self.areaLabel.text = area
            self.streetLabel.text = street.uppercased()
            self.streetLabel.isHidden = street.isEmpty
        }
    }
}
