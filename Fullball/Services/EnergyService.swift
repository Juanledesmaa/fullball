import Foundation
import SwiftData

/// Per-player energy: regenerates over real time, drains after active matches,
/// refillable for Gems. Reads/writes `CardInstance.energy` directly.
@MainActor
protocol EnergyService: AnyObject {
    func current(_ instance: CardInstance) -> Int
    func drainAfterMatch(fieldedIDs: [String], captainID: String?)
    func refillCost(_ instance: CardInstance) -> Int
    @discardableResult func refill(_ instance: CardInstance) -> Bool
}

@MainActor
final class DefaultEnergyService: EnergyService {
    private let context: ModelContext
    private let wallet: any WalletService
    private let collection: any CollectionService

    init(context: ModelContext, wallet: any WalletService, collection: any CollectionService) {
        self.context = context
        self.wallet = wallet
        self.collection = collection
    }

    func current(_ instance: CardInstance) -> Int {
        let minutes = Date().timeIntervalSince(instance.lastEnergyUpdate) / 60.0
        let regened = EnergyRules.regen(from: instance.energy, minutesElapsed: minutes)
        if regened != instance.energy {
            instance.energy = regened
            instance.lastEnergyUpdate = Date()
            try? context.save()
        }
        return instance.energy
    }

    func drainAfterMatch(fieldedIDs: [String], captainID: String?) {
        for id in fieldedIDs {
            guard let inst = collection.instance(forCardID: id) else { continue }
            _ = current(inst)
            inst.energy = EnergyRules.afterMatch(energy: inst.energy, isCaptain: id == captainID)
            inst.lastEnergyUpdate = Date()
        }
        try? context.save()
    }

    func refillCost(_ instance: CardInstance) -> Int {
        EnergyRules.refillCost(currentEnergy: current(instance))
    }

    @discardableResult
    func refill(_ instance: CardInstance) -> Bool {
        let cost = refillCost(instance)
        guard cost > 0, wallet.debit(.gems, cost) else { return false }
        instance.energy = EnergyRules.maxEnergy
        instance.lastEnergyUpdate = Date()
        try? context.save()
        wallet.save()
        return true
    }
}
