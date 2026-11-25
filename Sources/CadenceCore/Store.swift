import Foundation

public final class Store {
    public let url: URL

    public init(url: URL? = nil) {
        if let url {
            self.url = url
            return
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.url = support.appendingPathComponent("Cadence/sessions.json")
        // One-time carry-over from the app's former name (Pomo).
        let old = support.appendingPathComponent("Pomo/sessions.json")
        if !FileManager.default.fileExists(atPath: self.url.path), FileManager.default.fileExists(atPath: old.path) {
            try? FileManager.default.createDirectory(at: self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: old, to: self.url)
        }
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
