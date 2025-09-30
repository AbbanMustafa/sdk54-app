import UIKit

public protocol ViewConfigurable {
    func configure()
    func setupConstraints()
    func applyStyles()
}

public class BaseView: UIView, ViewConfigurable {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        setupConstraints()
        applyStyles()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
        setupConstraints()
        applyStyles()
    }

    public func configure() {}
    public func setupConstraints() {}
    public func applyStyles() {}
}

public class CustomButton: BaseView {
    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private var action: (() -> Void)?

    public enum ButtonStyle {
        case primary
        case secondary
        case outline
        case text

        var backgroundColor: UIColor {
            switch self {
            case .primary: return .systemBlue
            case .secondary: return .systemGray
            case .outline: return .clear
            case .text: return .clear
            }
        }

        var textColor: UIColor {
            switch self {
            case .primary, .secondary: return .white
            case .outline, .text: return .systemBlue
            }
        }
    }

    private var style: ButtonStyle = .primary

    public override func configure() {
        addSubview(titleLabel)
        addSubview(iconView)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    public override func setupConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    public override func applyStyles() {
        backgroundColor = style.backgroundColor
        titleLabel.textColor = style.textColor
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }

    @objc private func handleTap() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
        action?()
    }

    public func setTitle(_ title: String) {
        titleLabel.text = title
    }

    public func setAction(_ action: @escaping () -> Void) {
        self.action = action
    }

    public func setStyle(_ style: ButtonStyle) {
        self.style = style
        applyStyles()
    }
}

public class CardView: BaseView {
    private let contentStackView = UIStackView()
    private let headerLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let footerView = UIView()

    public override func configure() {
        addSubview(contentStackView)
        contentStackView.axis = .vertical
        contentStackView.spacing = 12
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill

        contentStackView.addArrangedSubview(headerLabel)
        contentStackView.addArrangedSubview(subtitleLabel)
        contentStackView.addArrangedSubview(bodyLabel)
        contentStackView.addArrangedSubview(footerView)
    }

    public override func setupConstraints() {
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    public override func applyStyles() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8

        headerLabel.font = .systemFont(ofSize: 20, weight: .bold)
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel

        bodyLabel.font = .systemFont(ofSize: 16, weight: .regular)
        bodyLabel.numberOfLines = 0
    }

    public func setHeader(_ text: String) {
        headerLabel.text = text
    }

    public func setSubtitle(_ text: String) {
        subtitleLabel.text = text
    }

    public func setBody(_ text: String) {
        bodyLabel.text = text
    }
}

public class GradientView: BaseView {
    private let gradientLayer = CAGradientLayer()

    public enum GradientDirection {
        case horizontal
        case vertical
        case diagonal

        var startPoint: CGPoint {
            switch self {
            case .horizontal: return CGPoint(x: 0, y: 0.5)
            case .vertical: return CGPoint(x: 0.5, y: 0)
            case .diagonal: return CGPoint(x: 0, y: 0)
            }
        }

        var endPoint: CGPoint {
            switch self {
            case .horizontal: return CGPoint(x: 1, y: 0.5)
            case .vertical: return CGPoint(x: 0.5, y: 1)
            case .diagonal: return CGPoint(x: 1, y: 1)
            }
        }
    }

    public override func configure() {
        layer.insertSublayer(gradientLayer, at: 0)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    public func setColors(_ colors: [UIColor]) {
        gradientLayer.colors = colors.map { $0.cgColor }
    }

    public func setDirection(_ direction: GradientDirection) {
        gradientLayer.startPoint = direction.startPoint
        gradientLayer.endPoint = direction.endPoint
    }
}

public class AnimationController {
    public enum AnimationType {
        case fadeIn
        case fadeOut
        case slideIn(direction: Direction)
        case slideOut(direction: Direction)
        case scale(from: CGFloat, to: CGFloat)
        case rotate(angle: CGFloat)

        public enum Direction {
            case left, right, top, bottom
        }
    }

    public static func animate(_ view: UIView, type: AnimationType, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        switch type {
        case .fadeIn:
            view.alpha = 0
            UIView.animate(withDuration: duration, animations: {
                view.alpha = 1
            }, completion: { _ in completion?() })

        case .fadeOut:
            UIView.animate(withDuration: duration, animations: {
                view.alpha = 0
            }, completion: { _ in completion?() })

        case .slideIn(let direction):
            let translation = getTranslation(for: direction, view: view)
            view.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
            UIView.animate(withDuration: duration, animations: {
                view.transform = .identity
            }, completion: { _ in completion?() })

        case .slideOut(let direction):
            let translation = getTranslation(for: direction, view: view)
            UIView.animate(withDuration: duration, animations: {
                view.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
            }, completion: { _ in completion?() })

        case .scale(let from, let to):
            view.transform = CGAffineTransform(scaleX: from, y: from)
            UIView.animate(withDuration: duration, animations: {
                view.transform = CGAffineTransform(scaleX: to, y: to)
            }, completion: { _ in completion?() })

        case .rotate(let angle):
            UIView.animate(withDuration: duration, animations: {
                view.transform = CGAffineTransform(rotationAngle: angle)
            }, completion: { _ in completion?() })
        }
    }

    private static func getTranslation(for direction: AnimationType.Direction, view: UIView) -> CGPoint {
        switch direction {
        case .left: return CGPoint(x: -view.bounds.width, y: 0)
        case .right: return CGPoint(x: view.bounds.width, y: 0)
        case .top: return CGPoint(x: 0, y: -view.bounds.height)
        case .bottom: return CGPoint(x: 0, y: view.bounds.height)
        }
    }
}
