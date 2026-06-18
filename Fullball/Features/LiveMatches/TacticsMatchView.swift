import SwiftUI

struct TacticsMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: TacticsMatchViewModel

    init(fixture: Fixture, container: AppContainer, slateID: String) {
        _vm = State(initialValue: TacticsMatchViewModel(fixture: fixture, container: container, slateID: slateID))
    }

    var body: some View {
        ZStack {
            WC.screenBG.ignoresSafeArea()
            switch vm.phase {
            case .setup: setup
            case .playing, .fullTime: FutsalPitchView(vm: vm, onClose: { dismiss() })
            }
        }
    }

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("MATCH SETUP").font(WC.display(20)).foregroundStyle(WC.inkText)
                    Spacer()
                    Button("Close") { dismiss() }.foregroundStyle(WC.sub)
                }
                scouting
                picker("INTENSITY", Intensity.allCases, vm.tactics.intensity, \.displayName) { vm.tactics.intensity = $0 }
                picker("FOCUS", Focus.allCases, vm.tactics.focus, \.displayName) { vm.tactics.focus = $0 }
                kickOff
            }
            .padding(20)
        }
    }

    private var scouting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SCOUTING").font(WC.ui(12)).foregroundStyle(WC.sub)
            Text(vm.opponentName).font(WC.display(22)).foregroundStyle(WC.inkText)
            Text("Intensity: \(vm.opponent.tactics.intensity.displayName)").font(WC.ui(13)).foregroundStyle(WC.sub)
            Text("Focus: \(vm.opponent.tactics.focus.displayName)").font(WC.ui(13)).foregroundStyle(WC.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(WC.cardBG).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var kickOff: some View {
        VStack(spacing: 8) {
            if vm.alreadyFinished { Text("Already played this block.").font(WC.ui(13)).foregroundStyle(WC.sub) }
            else if vm.yourFieldedCount == 0 { Text("Field at least one client first.").font(WC.ui(13)).foregroundStyle(WC.coral) }
            else if !vm.canAfford { Text("Need \(vm.entryFee) Cash to play.").font(WC.ui(13)).foregroundStyle(WC.coral) }
            Button { vm.kickOff() } label: {
                Text("KICK OFF · \(vm.entryFee)").font(WC.ui(16))
                    .frame(maxWidth: .infinity).padding()
                    .background(WC.coral).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(vm.alreadyFinished || vm.yourFieldedCount == 0 || !vm.canAfford)
            .opacity((vm.alreadyFinished || vm.yourFieldedCount == 0 || !vm.canAfford) ? 0.5 : 1)
        }
    }

    private func picker<T: Hashable>(_ title: String, _ all: [T], _ sel: T,
                                     _ label: KeyPath<T, String>, _ set: @escaping (T) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(WC.ui(12)).foregroundStyle(WC.sub)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(all, id: \.self) { v in chip(v[keyPath: label], v == sel) { set(v) } } }
            }
        }
    }

    private func chip(_ text: String, _ on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(text).font(WC.ui(13)).padding(.horizontal, 12).padding(.vertical, 8)
                .background(on ? WC.coral : WC.fill).foregroundStyle(on ? .white : WC.inkText)
                .clipShape(Capsule())
        }
    }
}
