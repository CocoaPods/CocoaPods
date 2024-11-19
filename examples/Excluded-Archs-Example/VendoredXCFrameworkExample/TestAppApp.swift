
import SwiftUI
import CoconutLib

@main
struct TestAppApp: App {
    var body: some Scene {
        WindowGroup {
            view
        }
    }

    var view: some View {
        Coconut().makeCoconuts()
        return ContentView()
    }
}
