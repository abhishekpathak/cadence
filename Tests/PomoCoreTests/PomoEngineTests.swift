import Foundation
import Testing
@testable import PomoCore

final class Harness {
    var t = Date(timeIntervalSince1970: 1_000_000)
    var finished: [Session] = []
    lazy var engine: PomoEngine = {
        let e = PomoEngine(now: { [unowned self] in self.t })
        e.onSessionFinished = { [unowned self] in self.finished.append($0) }
        return e
    }()
    func advance(_ minutes: Double) { t = t.addingTimeInterval(minutes * 60) }
}

@Suite struct PomoEngineTests {
    @Test func fullCycleSucceeds() {
        let h = Harness(), e = h.engine
        e.startFocus(purpose: "x"); h.advance(25)
        e.startRecall(); h.advance(5)
        e.startRest(); h.advance(5)
        e.endCurrent()
        #expect(h.finished.count == 1)
        #expect(h.finished[0].completed)
    }

    @Test func overflowWithinLimitSucceeds() {
        let h = Harness(), e = h.engine
        e.startFocus(purpose: "x"); h.advance(30)
        e.startRecall(); h.advance(10)
        e.startRest(); h.advance(10)
        e.endCurrent()
        #expect(h.finished[0].completed)
    }

    @Test func overflowBeyondLimitFails() {
        let h = Harness(), e = h.engine
        e.startFocus(purpose: "x"); h.advance(41)
        e.startRecall(); h.advance(5)
        e.startRest(); h.advance(5)
        e.endCurrent()
        #expect(!h.finished[0].completed)
    }

    @Test func endingPhaseEarlyFails() {
        let h = Harness(), e = h.engine
        e.startFocus(purpose: "x"); h.advance(10)
        e.startRecall(); h.advance(5)
        e.startRest(); h.advance(5)
        e.endCurrent()
        #expect(!h.finished[0].completed)
    }

    @Test func abandonedAfterFocusFails() {
        let h = Harness(), e = h.engine
        e.startFocus(purpose: "x"); h.advance(25)
        e.startBreak()
        #expect(h.finished.count == 1)
        #expect(!h.finished[0].completed)
        #expect(e.active?.phase == .rest_break)
    }

    @Test func standaloneRecallIsNotRecorded() {
        let h = Harness(), e = h.engine
        e.startRecall(); h.advance(5)
        e.endCurrent()
        #expect(h.finished.isEmpty)
    }

    @Test func remainingGoesNegativeInOverflow() {
        let h = Harness(), e = h.engine
        e.startFocus(purpose: "x"); h.advance(26)
        #expect(abs(e.remaining! - (-60)) < 0.001)
    }
}
