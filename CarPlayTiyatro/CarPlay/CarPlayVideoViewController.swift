import UIKit

/// CarPlay penceresinin kök görünümü. Web görüntüsü `videoContainer` içine taşınır.
final class CarPlayVideoViewController: UIViewController {
    let videoContainer = UIView()

    private let placeholderLabel = UILabel()
    private let lockOverlay = UIView()
    private let lockLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        placeholderLabel.text = "Telefondan bir video açın ve \"Araç\" ekranını seçin."
        configure(label: placeholderLabel, in: view)

        videoContainer.backgroundColor = .clear
        videoContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoContainer)
        NSLayoutConstraint.activate([
            videoContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoContainer.topAnchor.constraint(equalTo: view.topAnchor),
            videoContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        lockOverlay.backgroundColor = .black
        lockOverlay.isHidden = true
        lockOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lockOverlay)
        NSLayoutConstraint.activate([
            lockOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lockOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            lockOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            lockOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        lockLabel.text = "Sürüş sırasında video gösterilmez.\nAraç durduğunda video geri gelir."
        configure(label: lockLabel, in: lockOverlay)
    }

    func setDrivingLocked(_ locked: Bool) {
        loadViewIfNeeded()
        lockOverlay.isHidden = !locked
    }

    private func configure(label: UILabel, in parent: UIView) {
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .title3)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: parent.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: parent.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: parent.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: parent.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ])
    }
}
