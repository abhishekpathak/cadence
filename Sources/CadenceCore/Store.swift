import Foundation

/// Append-only session log: one JSON object per line in `sessions.jsonl`.
///
/// History is never rewritten. A failed read can't wipe it, a crash loses at most the
/// line being written, and unreadable lines are skipped but left in the file.
public final class Store {
    public struct Loaded {
        public var sessions: [Session]
        /// Lines that couldn't be decoded. They stay in the file untouched.
        public var skipped: Int
    }

    public let url: URL
    private var legacyURL: URL { url.deletingLastPathComponent().appendingPathComponent("sessions.json") }

    public init(url: URL? = nil) {
        let fm = FileManager.default
        if let url {
            self.url = url
        } else {
            let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.url = support.appendingPathComponent("Cadence/sessions.jsonl")
            // One-time carry-over from the app's former name (Pomo).
            let old = support.appendingPathComponent("Pomo/sessions.json")
            if !fm.fileExists(atPath: legacyURL.path), !fm.fileExists(atPath: self.url.path), fm.fileExists(atPath: old.path) {
                try? fm.createDirectory(at: legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.copyItem(at: old, to: legacyURL)
            }
        }
        migrateLegacyArray()
    }

    /// Converts the old single-array `sessions.json` once. The old file is left in place as a backup,
    /// and is never touched if it fails to parse.
    private func migrateLegacyArray() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path), fm.fileExists(atPath: legacyURL.path),
              let data = try? Data(contentsOf: legacyURL),
              let old = try? Self.decoder.decode([Session].self, from: data),
              let lines = try? old.map({ try Self.encoder.encode($0) }) else { return }
        var out = Data()
        for l in lines { out.append(l); out.append(0x0A) }
        try? out.write(to: url, options: .atomic)
    }

    public func load() -> Loaded {
        guard let data = try? Data(contentsOf: url) else { return Loaded(sessions: [], skipped: 0) }
        var result = Loaded(sessions: [], skipped: 0)
        for line in data.split(separator: 0x0A) where !line.allSatisfy({ $0 == 0x20 || $0 == 0x0D }) {
            if let s = try? Self.decoder.decode(Session.self, from: Data(line)) {
                result.sessions.append(s)
            } else {
                result.skipped += 1
            }
        }
        return result
    }

    /// Appends one line and flushes it to disk. Throws if the write fails, so callers can retry.
    public func append(_ session: Session) throws {
        let fm = FileManager.default
        var line = try Self.encoder.encode(session)
        line.append(0x0A)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil) }

        let fh = try FileHandle(forUpdating: url)
        defer { try? fh.close() }
        let end = try fh.seekToEnd()
        if end > 0 {
            // A crash mid-write can leave a partial last line; start on a fresh line so it can't merge with ours.
            try fh.seek(toOffset: end - 1)
            if try fh.read(upToCount: 1)?.first != 0x0A { try fh.seekToEnd(); try fh.write(contentsOf: Data([0x0A])) }
            else { try fh.seekToEnd() }
        }
        try fh.write(contentsOf: line)
        try fh.synchronize()
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys] // compact: no raw newlines, so one session is always one line
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
