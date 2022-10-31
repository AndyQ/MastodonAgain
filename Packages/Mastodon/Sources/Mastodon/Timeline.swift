import Foundation

public struct Timeline {
    public enum TimelineType: Equatable {
        case `public`
        case hashtag(String)
        case home
        case list(String) // List.ID

        public var path: URLPath {
            switch self {
            case .public:
                return "/api/v1/timelines/public"
            case .hashtag(let hashtag):
                return "/api/v1/timelines/tag/\(hashtag)"
            case .home:
                return "/api/v1/timelines/home"
            case .list(let list):
                return "/api/v1/timelines/list/\(list)"
            }
        }
    }

    public struct Page: Identifiable {
        public let id: AnyHashable
        public let url: URL
        public var statuses: [Status]
        public let previous: URL?
        public let next: URL?

        init(url: URL, statuses: [Status] = [], previous: URL? = nil, next: URL? = nil) {
            assert(statuses.first!.id >= statuses.last!.id)
            self.id = "\(url) | \(statuses.count)\(statuses.first!.id) -> \(statuses.last!.id)"
            self.url = url
            self.statuses = statuses
            self.previous = previous
            self.next = next
        }
    }

    public enum Direction {
        case previous
        case next
    }

    public let timelineType: TimelineType
    public let url: URL
    public var pages: [Page]

    public init(host: String, timelineType: Timeline.TimelineType, pages: [Page] = []) {
        self.url = URL(string: "https://\(host)\(timelineType.path)")!
        self.timelineType = timelineType
        self.pages = pages
    }
}

extension Timeline: CustomStringConvertible {
    public var description: String {
        String("Timeline(timelineType: \(timelineType), pages: \(pages.count)")
    }
}

public extension Timeline {
    var previousURL: URL? {
        guard let first = pages.first else {
            return nil
        }

        if let url = first.previous {
            return url
        }
        else {
            return url.appending(queryItems: [
                .init(name: "since_id", value: first.statuses.first!.id.rawValue)
            ])
        }
    }

    var nextURL: URL? {
        pages.last?.next
    }
}

