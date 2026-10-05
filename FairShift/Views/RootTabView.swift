import SwiftUI

struct RootTabView: View {
    let environment: AppEnvironment

    var body: some View {
        TabView {
            NavigationStack { DashboardView(environment: environment) }
                .tabItem { Label("This Fortnight", systemImage: "gauge.with.dots.needle.50percent") }

            NavigationStack { RosterView(environment: environment) }
                .tabItem { Label("Roster", systemImage: "calendar") }

            NavigationStack { PayslipsView(environment: environment) }
                .tabItem { Label("Payslips", systemImage: "doc.text.magnifyingglass") }

            NavigationStack { WorkplacesView(environment: environment) }
                .tabItem { Label("Workplaces", systemImage: "building.2") }
        }
    }
}

#Preview {
    RootTabView(environment: .preview())
}
