import SwiftUI

struct UnitToggle: View {
    @Binding var system: UnitSystem

    var body: some View {
        Picker("Units", selection: $system) {
            ForEach(UnitSystem.allCases) { s in
                Text(s.label).tag(s)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("unit_system_toggle")
    }
}

#Preview("Toggle — imperial") {
    @Previewable @State var system: UnitSystem = .imperial
    return Form {
        Section { UnitToggle(system: $system) }
    }
}

#Preview("Toggle — metric") {
    @Previewable @State var system: UnitSystem = .metric
    return Form {
        Section { UnitToggle(system: $system) }
    }
}
