import SwiftUI

struct CollectionView: View {
    let container: AppContainer
    @State private var vm: CollectionViewModel

    init(container: AppContainer) {
        self.container = container
        _vm = State(initialValue: CollectionViewModel(container: container))
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenHeader(kicker: "Your agency", title: "Roster") {
                    HStack(spacing: 10) {
                        Menu {
                            ForEach(RosterSort.allCases, id: \.self) { s in
                                Button {
                                    vm.sort = s
                                } label: {
                                    HStack {
                                        Text(s.rawValue)
                                        if vm.sort == s { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 12))
                                Text(vm.sort.rawValue)
                                    .font(WC.display(11))
                            }
                            .foregroundStyle(WC.coral)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .overlay(Capsule().strokeBorder(WC.coral, lineWidth: 1.5))
                        }
                        VStack(spacing: -2) {
                            Text("\(vm.squadRating)").font(WC.display(22)).foregroundStyle(WC.coral)
                            Text("SQUAD").font(WC.display(8)).tracking(1).foregroundStyle(WC.sub)
                        }
                    }
                }
                completionStrip
                filters
                if vm.sortedItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(vm.sortedItems) { owned in
                                NavigationLink(value: owned.id) {
                                    CardTile(owned: owned, energy: vm.energy(owned.id))
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(ScreenBackground())
            .navigationDestination(for: String.self) { cardID in
                CardDetailView(container: container, cardID: cardID)
            }
        }
        .onAppear { vm.reload() }
    }

    private var completionStrip: some View {
        VStack(spacing: 5) {
            HStack {
                Text("DEX \(vm.totalCount) / \(vm.catalogTotal)")
                    .font(WC.display(10)).tracking(0.5).foregroundStyle(WC.sub)
                Spacer()
                Text("\(Int(vm.completion * 100))% COMPLETE")
                    .font(WC.display(10)).tracking(0.5).foregroundStyle(WC.coral)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WC.fill)
                    // multicolor WC26 spectrum fill
                    LinearGradient(colors: WC.spectrum, startPoint: .leading, endPoint: .trailing)
                        .mask(Capsule())
                        .frame(width: max(4, geo.size.width * vm.completion))
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private var filters: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Rarity.allCases.reversed(), id: \.self) { r in
                        Button { vm.toggleRarity(r) } label: {
                            Chip(label: r.displayName, active: vm.rarityFilter == r, accent: true)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Position.allCases, id: \.self) { p in
                        Button { vm.togglePosition(p) } label: {
                            Chip(label: p.rawValue, active: vm.positionFilter == p)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus").font(.system(size: 42))
                .foregroundStyle(WC.faint)
            Text(vm.totalCount == 0 ? "No clients yet" : "No clients match")
                .font(WC.display(18)).foregroundStyle(WC.inkText)
            Text(vm.totalCount == 0
                 ? "Scout players or sign a marquee client on the Market. Your clients earn you Cash when they perform in live matches."
                 : "Try a different filter.")
                .font(WC.ui(13)).foregroundStyle(WC.sub)
                .multilineTextAlignment(.center).lineSpacing(2)
                .padding(.horizontal, 36)
            if vm.totalCount == 0 {
                Button { container.navigator.go(.packs) } label: {
                    Text("GO SCOUT").font(WC.display(13)).tracking(0.5).foregroundStyle(.white)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Capsule().fill(WC.coral))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CollectionView(container: .preview())
}
