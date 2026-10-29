import Foundation

enum StreamingService: String, CaseIterable, Identifiable {
    case youtube
    case netflix

    var id: String { rawValue }

    var title: String {
        switch self {
        case .youtube: return "YouTube"
        case .netflix: return "Netflix"
        }
    }

    var symbolName: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .netflix: return "film.fill"
        }
    }

    var homeURL: URL {
        switch self {
        case .youtube: return URL(string: "https://m.youtube.com")!
        case .netflix: return URL(string: "https://www.netflix.com/browse")!
        }
    }

    /// Netflix mobil tarayıcıda oynatmaya izin vermediği için masaüstü Safari gibi görünürüz.
    var userAgent: String? {
        switch self {
        case .youtube:
            return nil
        case .netflix:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        }
    }
}
