import Foundation

/// One tick of a playing match: the current minute, an optional event that
/// just fired, and whether the match has reached full time.
struct MatchTick: Sendable {
    let minute: Int
    let event: ScriptedEvent?
    let isFullTime: Bool
}

/// Plays a single fixed-duration match: a clock that runs 0 → full time
/// over a real wall-clock duration, emitting scripted events as it passes
/// their minute, then a final full-time tick.
protocol LiveMatchService: Sendable {
    func play(_ fixture: Fixture, realDuration: Duration) -> AsyncStream<MatchTick>
}

struct MockLiveMatchService: LiveMatchService {
    func play(_ fixture: Fixture, realDuration: Duration) -> AsyncStream<MatchTick> {
        let events = fixture.scriptedEvents.sorted { $0.minute < $1.minute }
        let fullTime = LiveRules.fullTimeMinute
        let stepDelay = realDuration / fullTime
        return AsyncStream { continuation in
            let task = Task {
                var ei = 0
                for minute in 1...fullTime {
                    try? await Task.sleep(for: stepDelay)
                    if Task.isCancelled { break }
                    var fired = false
                    while ei < events.count && events[ei].minute <= minute {
                        continuation.yield(MatchTick(minute: events[ei].minute, event: events[ei], isFullTime: false))
                        ei += 1
                        fired = true
                    }
                    if !fired && minute % 5 == 0 {
                        continuation.yield(MatchTick(minute: minute, event: nil, isFullTime: false))
                    }
                }
                continuation.yield(MatchTick(minute: fullTime, event: nil, isFullTime: true))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
