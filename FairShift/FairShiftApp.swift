import SwiftUI

@main
struct FairShiftApp: App {
    @State private var environment: AppEnvironment

    init() {
        let environment = AppEnvironment.live()
        // `-seedSampleData` fills an empty store with demo shifts, for demos and UI checks
        if CommandLine.arguments.contains("-seedSampleData"),
           (try? environment.workplaces.allWorkplaces().isEmpty) == true {
            try? SampleData.load(into: environment)
        }
        _environment = State(initialValue: environment)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(environment: environment)
        }
    }
}
