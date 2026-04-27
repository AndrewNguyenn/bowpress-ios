import SwiftUI

/// Generic stat-grid cell: eyebrow label / caller-supplied main view /
/// optional sub copy / optional tick row (mini bars).
struct BPStatGridCell<MainView: View, TickView: View>: View {
    let label: String
    let sub: String?
    let main: MainView
    let tick: TickView?

    init(
        label: String,
        sub: String? = nil,
        @ViewBuilder main: () -> MainView,
        @ViewBuilder tick: () -> TickView
    ) {
        self.label = label
        self.sub = sub
        self.main = main()
        self.tick = tick()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BPEyebrow(label)
            main
                .frame(maxWidth: .infinity, alignment: .leading)
            if let sub {
                Text(sub)
                    .font(.bpUI(14))
                    .foregroundStyle(Color.appInk3)
            }
            if let tick {
                tick
            }
        }
    }
}

extension BPStatGridCell where TickView == EmptyView {
    init(
        label: String,
        sub: String? = nil,
        @ViewBuilder main: () -> MainView
    ) {
        self.label = label
        self.sub = sub
        self.main = main()
        self.tick = nil
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        HStack(alignment: .top, spacing: 16) {
            BPStatGridCell(label: "Avg so far", sub: "15 arrows") {
                BPBigScore(value: "10.4", size: 56)
            } tick: {
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Rectangle().fill(Color.appPond).frame(width: 4, height: 10)
                    }
                }
            }
            BPStatGridCell(label: "Xs", sub: "40% rate") {
                BPBigScore(value: "6", size: 56, unit: "/15")
            }
        }
        .padding()
    }
}
