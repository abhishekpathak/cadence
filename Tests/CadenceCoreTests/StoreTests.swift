import Foundation
import Testing
@testable import CadenceCore

@Suite struct StoreTests {
    func tempDir() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func session(_ purpose: String, completed: Bool = true) -> Session {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        return Session(purpose: purpose, phases: [PhaseRecord(phase: .focus, start: t, end: t.addingTimeInterval(60))], completed: completed)
    }

    @Test func roundTrip() throws {
        let store = Store(url: tempDir().appendingPathComponent("sessions.jsonl"))
        try store.append(session("a")); try store.append(session("b", completed: false))
        let loaded = store.load()
        #expect(loaded.sessions.map(\.purpose) == ["a", "b"])
        #expect(loaded.sessions.map(\.completed) == [true, false])
        #expect(loaded.skipped == 0)
    }

    @Test func purposeWithNewlineStaysOneLine() throws {
        let url = tempDir().appendingPathComponent("sessions.jsonl")
        let store = Store(url: url)
        try store.append(session("line1\nline2"))
        #expect(store.load().sessions.first?.purpose == "line1\nline2")
        #expect(try String(contentsOf: url).split(separator: "\n").count == 1)
    }

    @Test func corruptLineIsSkippedAndPreserved() throws {
        let url = tempDir().appendingPathComponent("sessions.jsonl")
        let store = Store(url: url)
        try store.append(session("a"))
        let h = try FileHandle(forWritingTo: url); try h.seekToEnd()
        try h.write(contentsOf: Data("{not json}\n".utf8)); try h.close()
        try store.append(session("b"))
        let loaded = store.load()
        #expect(loaded.sessions.map(\.purpose) == ["a", "b"])
        #expect(loaded.skipped == 1)
        #expect(try String(contentsOf: url).contains("{not json}")) // never rewritten
    }

    @Test func partialLastLineDoesNotSwallowNextAppend() throws {
        let url = tempDir().appendingPathComponent("sessions.jsonl")
        let store = Store(url: url)
        try store.append(session("a"))
        let h = try FileHandle(forWritingTo: url); try h.seekToEnd()
        try h.write(contentsOf: Data("{\"purpose\":\"trunc".utf8)); try h.close() // crash mid-write
        try store.append(session("b"))
        let loaded = store.load()
        #expect(loaded.sessions.map(\.purpose) == ["a", "b"])
        #expect(loaded.skipped == 1)
    }

    @Test func migratesLegacyArrayAndKeepsBackup() throws {
        let dir = tempDir()
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        let legacy = dir.appendingPathComponent("sessions.json")
        try e.encode([session("old1"), session("old2")]).write(to: legacy)
        let store = Store(url: dir.appendingPathComponent("sessions.jsonl"))
        #expect(store.load().sessions.map(\.purpose) == ["old1", "old2"])
        #expect(FileManager.default.fileExists(atPath: legacy.path))
        try store.append(session("new"))
        #expect(store.load().sessions.count == 3)
    }

    @Test func unparsableLegacyFileIsNeverTouchedOrOverwritten() throws {
        let dir = tempDir()
        let legacy = dir.appendingPathComponent("sessions.json")
        try Data("garbage".utf8).write(to: legacy)
        let store = Store(url: dir.appendingPathComponent("sessions.jsonl"))
        try store.append(session("new"))
        #expect(store.load().sessions.map(\.purpose) == ["new"])
        #expect(try String(contentsOf: legacy) == "garbage")
    }
}
