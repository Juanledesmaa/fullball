import Testing
@testable import Fullball

struct FutsalMatchSupportTests {
    private func mp(_ id: String, _ pos: Position, _ s: Stats) -> (id: String, position: Position, stats: Stats) { (id, pos, s) }

    @Test func assemblyBuildsFiveWithCaptainAndTactics() {
        let inputs = [
            mp("gk", .gk,  Stats(pace: 40, shooting: 10, passing: 40, defending: 80)),
            mp("d",  .def, Stats(pace: 50, shooting: 20, passing: 50, defending: 70)),
            mp("m",  .mid, Stats(pace: 60, shooting: 50, passing: 90, defending: 50)),
            mp("f1", .fwd, Stats(pace: 70, shooting: 95, passing: 50, defending: 30)),
            mp("f2", .fwd, Stats(pace: 80, shooting: 70, passing: 40, defending: 30)),
        ]
        let side = MatchSideAssembly.build(players: inputs, tactics: Tactics(intensity: .aggressive), captainID: "f1")
        #expect(side.players.count == 5)
        #expect(side.captainID == "f1")
        #expect(side.tactics.intensity == .aggressive)
        #expect(side.goalkeeper?.id == "gk")
    }

    @Test func rewardScalesWithPointsAndCaptainDoubles() {
        let contribs = [
            PlayerContribution(playerID: "f1", goals: 1, assists: 0, saves: 0, points: 100),
            PlayerContribution(playerID: "m",  goals: 0, assists: 1, saves: 0, points: 40),
        ]
        let r = FutsalReward.from(contributions: contribs, captainID: "f1")
        #expect(r.points == 240)            // 100*2 + 40
        #expect(r.cash == AgentRules.commission(forPoints: 240))
        #expect(r.rep == 3)                 // f1 goals*2=2 + m assists=1
        #expect(r.wonBonus == (240 >= LiveRules.winBonusTarget))
    }

    @Test func rewardIsZeroForEmptyContributions() {
        let r = FutsalReward.from(contributions: [], captainID: nil)
        #expect(r.points == 0)
        #expect(r.cash == 0)
        #expect(r.wonBonus == false)
    }
}
