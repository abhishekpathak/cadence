import Foundation
import Testing
@testable import CadenceCore

final class Harness {
    var t = Date(timeIntervalSince1970: 1_000_000)
    var finished: [Session] = []
    lazy var engine: CadenceEngine = {
        let e = CadenceEngine(now: { [unowned self] in self.t })
        e.onSessionFinished = { [unowned self] in self.finished.append($0) }
        return e
    }()
    func advance(_ minutes: Double) { t = t.addingTimeInterval(minutes * 60) }
}

@Suite struct CadenceEngineTests {
    @Test func fullCycleSucceeds() {
        let h = Harness(), e = h.engine
        e.startFocus(purpose: "x"); h.advance(25)
        e.startRecall(); h.advance(5)
        e.startRest(); h.advance(5)
        e.endCurrent()
        #expect(h.finished.count == 1)
        #expect(h.finished[0].completed)
    }

    @Test func anyDurationCountsIfAllPhasesRan() {
        let h = Harness(), e = h.engine
        e.startFocus(purpose: "x"); h.advance(1)
        e.startRecall(); h.advance(60)
        e.startRest(); h.advance(1)
        e.endCurrent()
        #expect(h.finished[0].completed)
    }

    @Test func pausedTimeDoesNotCount() {
        let h = Harness(), e = h.engine
        e.startFocus(purpose: "x"); h.advance(10)
        e.pause(); h.advance(100)
        #expect(e.isPaused)
        #expect(abs(e.remaining! - 15 * 60) < 0.001)
        e.resume(); h.advance(5)
        #expect(!e.isPaused)
        #expect(abs(e.remaining! - 10 * 60) < 0.001)
    }

    @Test func customDurationsApplyFromNextPhase() {
        let h = Harness(), e = h.engine
        e.minutes[.focus] = 50
        e.startFocus(purpose: "x")
        #expect(abs(e.remaining! - 50 * 60) < 0.001)
        e.minutes[.focus] = 10               // changing mid-phase must not affect the running one
        h.advance(5)
        #expect(abs(e.remaining! - 45 * 60) < 0.001)
        #expect(e.duration(of: .focus) == 10 * 60)
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
