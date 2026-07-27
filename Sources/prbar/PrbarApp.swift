import SwiftUI

@main
struct PrbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PanelView(model: model)
                .task { model.start() }
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsPane(model: model)
        }
    }
}

private struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.pull")
            if model.count(.direct) > 0 {
                Text("\(model.count(.direct))")
            }
        }
    }
}
