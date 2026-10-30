import Combine
import MapKit
import UIKit

/// Phone UI: the same GTA map with a search field. Routes chosen here also appear in CarPlay.
final class PhoneViewController: UIViewController, UITextFieldDelegate {
    private let model = NavigationModel.shared
    private let mapViewController = MapViewController()
    private let searchField = UITextField()
    private let actionButton = UIButton(type: .system)
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark

        addChild(mapViewController)
        mapViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapViewController.view)
        mapViewController.didMove(toParent: self)

        searchField.placeholder = "Set waypoint…"
        searchField.borderStyle = .roundedRect
        searchField.backgroundColor = UIColor(white: 0.08, alpha: 0.9)
        searchField.textColor = .white
        searchField.returnKeyType = .search
        searchField.clearButtonMode = .whileEditing
        searchField.delegate = self

        actionButton.tintColor = UIColor(red: 0.76, green: 0.48, blue: 1, alpha: 1)
        actionButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        let recenter = UIButton(type: .system)
        recenter.setImage(UIImage(systemName: "location.north.line.fill"), for: .normal)
        recenter.tintColor = .white
        recenter.addAction(UIAction { [weak self] _ in self?.mapViewController.recenter() }, for: .touchUpInside)

        let bar = UIStackView(arrangedSubviews: [searchField, actionButton, recenter])
        bar.spacing = 10
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        NSLayoutConstraint.activate([
            mapViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            mapViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            bar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 40),
        ])

        Publishers.CombineLatest(model.$route, model.$isNavigating)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] route, navigating in
                let title = navigating ? "End" : (route != nil ? "Drive" : "")
                self?.actionButton.setTitle(title, for: .normal)
                self?.actionButton.isHidden = title.isEmpty
            }
            .store(in: &cancellables)

        model.start()
    }

    @objc private func actionTapped() {
        if model.isNavigating {
            model.endNavigation()
        } else {
            model.startNavigation()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        guard let query = textField.text, !query.isEmpty else { return true }
        Task { await search(query) }
        return true
    }

    @MainActor
    private func search(_ query: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let location = model.location {
            request.region = MKCoordinateRegion(center: location.coordinate,
                                                latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        }
        guard let items = try? await MKLocalSearch(request: request).start().mapItems, !items.isEmpty else {
            showMessage("Nothing found for “\(query)”")
            return
        }
        let sheet = UIAlertController(title: "Set waypoint", message: nil, preferredStyle: .actionSheet)
        for item in items.prefix(6) {
            sheet.addAction(UIAlertAction(title: item.name ?? "Unnamed", style: .default) { [weak self] _ in
                Task { await self?.route(to: item) }
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = searchField
        present(sheet, animated: true)
    }

    @MainActor
    private func route(to item: MKMapItem) async {
        do {
            let route = try await model.calculateRoute(to: item)
            model.preview(route, to: item)
        } catch {
            showMessage("No route found")
        }
    }

    private func showMessage(_ text: String) {
        let alert = UIAlertController(title: text, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
