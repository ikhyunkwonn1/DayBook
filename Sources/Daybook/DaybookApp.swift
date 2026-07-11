import SwiftUI

@main
struct DaybookApp: App {
    @StateObject private var viewModel = DaybookViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .frame(minWidth: 1120, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
