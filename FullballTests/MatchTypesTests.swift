import Testing
@testable import Fullball

struct MatchTypesTests {
    private func player(_ id: String, _ pos: Position, _ s: Stats) -> MatchPlayer {
        MatchPlayer(id: id, position: pos, stats: s)
    }

    @Test func matchPlayerStyleDerivesFromStats() {
        let p = player("a", .fwd, Stats(pace: 90, shooting: 10, passing: 10, defending: 10))
        #expect(p.style == .pace)
    }

    @Test func matchSideExposesGoalkeeperAndOutfield() {
        let players = [
            player("gk", .gk,  Stats(pace: 40, shooting: 10, passing: 40, defending: 80)),
            player("d",  .def, Stats(pace: 50, shooting: 20, passing: 50, defending: 70)),
            player("m",  .mid, Stats(pace: 60, shooting: 50, passing: 80, defending: 50)),
            player("f1", .fwd, Stats(pace: 70, shooting: 80, passing: 50, defending: 30)),
            player("f2", .fwd, Stats(pace: 80, shooting: 70, passing: 40, defending: 30)),
        ]
        let side = MatchSide(players: players, tactics: Tactics(),
                             teamStyle: .technical, dangerManID: "f1", captainID: "f1")
        #expect(side.goalkeeper?.id == "gk")
        #expect(side.outfield.map(\.id) == ["d", "m", "f1", "f2"])
    }
}
