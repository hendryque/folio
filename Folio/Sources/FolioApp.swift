import SwiftUI
import SwiftData

@main
struct FolioApp: App {
    let modelContainer: ModelContainer

    init() {
        self.modelContainer = makeFolioModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
