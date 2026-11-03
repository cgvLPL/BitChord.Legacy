import SwiftUI

@main
struct BitChordApp: App {
    @StateObject private var playback = PlaybackManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(playback)
                .preferredColorScheme(.dark)
        }
    }
}
