import Foundation

public final class Store {
    public let url: URL

    public init(url: URL? = nil) {
        self.url = url ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pomo/sessions.json")
    }

    public func load() -> [Session] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return (try? d.decode([Session].self, from: data)) ?? []
    }

    public func append(_ session: Session) {
        var all = load()
        all.append(session)
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? e.encode(all).write(to: url, options: .atomic)
    }
}
