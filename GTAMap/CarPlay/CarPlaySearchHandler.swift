import CarPlay
import MapKit

/// Destination search for CarPlay using Apple's on-device, free MKLocalSearchCompleter.
final class CarPlaySearchHandler: NSObject, CPSearchTemplateDelegate, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private let onSelect: (MKMapItem) async -> Void
    private var pendingResults: (([CPListItem]) -> Void)?

    init(region: MKCoordinateRegion?, onSelect: @escaping (MKMapItem) async -> Void) {
        self.onSelect = onSelect
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        if let region { completer.region = region }
    }

    // MARK: CPSearchTemplateDelegate

    func searchTemplate(_ searchTemplate: CPSearchTemplate,
                        updatedSearchText searchText: String,
                        completionHandler: @escaping ([CPListItem]) -> Void) {
        pendingResults?([])
        guard !searchText.isEmpty else {
            pendingResults = nil
            completionHandler([])
            return
        }
        pendingResults = completionHandler
        completer.queryFragment = searchText
    }

    func searchTemplate(_ searchTemplate: CPSearchTemplate,
                        selectedResult item: CPListItem,
                        completionHandler: @escaping () -> Void) {
        guard let completion = item.userInfo as? MKLocalSearchCompletion else {
            completionHandler()
            return
        }
        Task { @MainActor in
            defer { completionHandler() }
            let response = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
            if let mapItem = response?.mapItems.first {
                await onSelect(mapItem)
            }
        }
    }

    // MARK: MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let items = completer.results.prefix(12).map { result -> CPListItem in
            let item = CPListItem(text: result.title, detailText: result.subtitle)
            item.userInfo = result
            return item
        }
        pendingResults?(Array(items))
        pendingResults = nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        pendingResults?([])
        pendingResults = nil
    }
}
