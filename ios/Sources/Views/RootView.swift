import SwiftUI

struct RootView: View {
    @EnvironmentObject private var playback: PlaybackManager
    @State private var selectedTab = 0
    @State private var showingPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.035, green: 0.035, blue: 0.045).ignoresSafeArea()

            TabView(selection: $selectedTab) {
                LibraryView(showingPlayer: $showingPlayer)
                    .tabItem { Label("Listen", systemImage: "music.note") }
                    .tag(0)
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(1)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                    .tag(2)
            }
            .tint(.white)

            if playback.currentTrack != nil {
                MiniPlayer(showingPlayer: $showingPlayer)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 52)
            }
        }
        .sheet(isPresented: $showingPlayer) {
            NowPlayingView()
                .environmentObject(playback)
        }
    }
}

private struct LibraryView: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Binding var showingPlayer: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Good evening")
                            .font(.largeTitle.bold())
                        Text("Your music, all in one place.")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Recently played")
                        .font(.title2.bold())

                    ForEach(Track.previews) { track in
                        Button {
                            playback.play(track)
                            showingPlayer = true
                        } label: {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(Color.white.opacity(0.09))
                                    .frame(width: 58, height: 58)
                                    .overlay(Image(systemName: "waveform").font(.title2))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title).font(.headline).foregroundColor(.white)
                                    Text(track.artist).font(.subheadline).foregroundColor(.white.opacity(0.55))
                                }
                                Spacer()
                                Image(systemName: "ellipsis").foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(20)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct SearchView: View {
    @State private var query = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Search")
                    .font(.largeTitle.bold())
                TextField("Songs, artists, albums", text: $query)
                    .padding(14)
                    .background(Color.white.opacity(0.09))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                Text("Connect a music catalogue provider to search.")
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            .padding(20)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Playback")) {
                    Label("Audio quality", systemImage: "waveform")
                    Label("Crossfade", systemImage: "arrow.left.arrow.right")
                    Label("Sleep timer", systemImage: "moon")
                }
                Section(header: Text("About")) {
                    Label("BitChord for iOS", systemImage: "music.note")
                    Text("iOS 15 compatibility foundation")
                }
            }
            .navigationTitle("Settings")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct MiniPlayer: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Binding var showingPlayer: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.12))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "music.note"))
            VStack(alignment: .leading, spacing: 3) {
                Text(playback.currentTrack?.title ?? "Not Playing")
                    .font(.subheadline.bold()).lineLimit(1)
                Text(playback.currentTrack?.artist ?? "")
                    .font(.caption).foregroundColor(.white.opacity(0.6)).lineLimit(1)
            }
            Spacer()
            Button(action: playback.togglePlayback) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(10)
        .background(Color(white: 0.13))
        .cornerRadius(14)
        .onTapGesture { showingPlayer = true }
    }
}

private struct NowPlayingView: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Button("Done") { presentationMode.wrappedValue.dismiss() }
                Spacer()
                Text("NOW PLAYING").font(.caption.bold()).tracking(2)
                Spacer()
                Image(systemName: "ellipsis").frame(width: 40)
            }
            .padding(.top, 24)

            Spacer()
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.08))
                .aspectRatio(1, contentMode: .fit)
                .overlay(Image(systemName: "waveform").font(.system(size: 64)).foregroundColor(.white.opacity(0.7)))
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                Text(playback.currentTrack?.title ?? "Not Playing").font(.title2.bold())
                Text(playback.currentTrack?.artist ?? "").foregroundColor(.white.opacity(0.6))
            }

            VStack(spacing: 8) {
                Slider(value: Binding(
                    get: { playback.currentTime },
                    set: { playback.seek(to: $0) }
                ), in: 0...max(playback.duration, 1))
                HStack {
                    Text(timeString(playback.currentTime))
                    Spacer()
                    Text(timeString(playback.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 24)

            Button(action: playback.togglePlayback) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30))
                    .frame(width: 76, height: 76)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .clipShape(Circle())
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .background(Color(red: 0.035, green: 0.035, blue: 0.045).ignoresSafeArea())
        .foregroundColor(.white)
    }

    private func timeString(_ value: Double) -> String {
        guard value.isFinite else { return "0:00" }
        let total = max(0, Int(value))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
