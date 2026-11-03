import SwiftUI

struct RootView: View {
    @EnvironmentObject private var playback: PlaybackManager
    @StateObject private var settings = AppSettings()
    @StateObject private var playlists = PlaylistStore()
    @StateObject private var downloads = DownloadManager()
    @State private var selectedTab = 0
    @State private var showingPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.035, green: 0.035, blue: 0.045).ignoresSafeArea()
            TabView(selection: $selectedTab) {
                HomeScreen(showingPlayer: $showingPlayer).tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
                ExploreScreen().tabItem { Label("Explore", systemImage: "safari") }.tag(1)
                SearchScreen(showingPlayer: $showingPlayer).tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(2)
                LibraryScreen(showingPlayer: $showingPlayer).tabItem { Label("Library", systemImage: "square.stack") }.tag(3)
                SettingsScreen(downloads: downloads).tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(4)
            }
            .tint(.white)
            if playback.currentTrack != nil {
                MiniPlayer(showingPlayer: $showingPlayer)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 48)
            }
        }
        .environmentObject(settings)
        .environmentObject(playlists)
        .environmentObject(downloads)
        .sheet(isPresented: $showingPlayer) { NowPlayingScreen() }
        .alert(item: Binding(
            get: { playback.notice.map(NoticeMessage.init) },
            set: { _ in playback.notice = nil }
        )) { notice in
            Alert(title: Text("BitChord"), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
    }
}

private struct NoticeMessage: Identifiable {
    let id = UUID()
    let message: String
    init(_ message: String) { self.message = message }
}

private struct HomeScreen: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Binding var showingPlayer: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("BITCHORD").font(.caption.bold()).tracking(3).foregroundColor(.white.opacity(0.55))
                            Text("Listen again.").font(.largeTitle.bold())
                        }
                        Spacer()
                        Image(systemName: "waveform").font(.title).padding(12).background(Color.white.opacity(0.08)).clipShape(Circle())
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "Recently played", subtitle: "Pick up where you left off")
                        ForEach(Track.previews) { track in
                            TrackRow(track: track, action: {
                                playback.play(track)
                                showingPlayer = true
                            })
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "Made for your library", subtitle: "Your personal listening space")
                        HStack(spacing: 12) {
                            FeatureTile(title: "Your queue", subtitle: "Up next", symbol: "text.line.first.and.arrowtriangle.forward")
                            FeatureTile(title: "Your downloads", subtitle: "Listen offline", symbol: "arrow.down.circle")
                        }
                    }
                    Text("Connect a compatible music source in Settings to search and play catalogue results.")
                        .font(.footnote).foregroundColor(.white.opacity(0.45))
                }
                .padding(20)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct ExploreScreen: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Explore").font(.largeTitle.bold())
                    Text("Find something for the moment.")
                        .foregroundColor(.white.opacity(0.55))
                    ForEach([
                        ("Late night", "Slow down with atmospheric sounds", "moon.stars.fill"),
                        ("Focus", "Keep your attention on the task", "sparkle"),
                        ("Discover", "Find music beyond your rotation", "safari.fill"),
                        ("Recently added", "Return to new releases", "plus.circle.fill")
                    ], id: \.0) { item in
                        HStack(spacing: 14) {
                            Image(systemName: item.2).font(.title2).frame(width: 52, height: 52)
                                .background(Color.white.opacity(0.08)).cornerRadius(12)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.0).font(.headline)
                                Text(item.1).font(.caption).foregroundColor(.white.opacity(0.55))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.white.opacity(0.4))
                        }
                        .padding(12).background(Color.white.opacity(0.035)).cornerRadius(14)
                    }
                    Text("Personalised shelves and mood mixes will be connected to the YouTube Music feed in a later integration stage.")
                        .font(.footnote).foregroundColor(.white.opacity(0.45))
                }
                .padding(20)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct SearchScreen: View {
    @EnvironmentObject private var playback: PlaybackManager
    @EnvironmentObject private var settings: AppSettings
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Search").font(.largeTitle.bold())
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.5))
                    TextField("Songs, artists, albums", text: $query)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit { Task { await search() } }
                    if !query.isEmpty {
                        Button { query = ""; results = []; errorMessage = nil } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.45))
                        }
                    }
                }
                .padding(14).background(Color.white.opacity(0.09)).cornerRadius(12)
                if isSearching { ProgressView("Searching…").tint(.white).foregroundColor(.white.opacity(0.6)) }
                if let errorMessage = errorMessage {
                    Text(errorMessage).font(.footnote).foregroundColor(.orange)
                }
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(results) { track in
                            TrackRow(track: track, action: {
                                if track.streamURL != nil { playback.play(track) }
                                else { openYouTube(track) }
                            }, secondaryAction: { playback.addToQueue(track) })
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @MainActor
    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { results = []; return }
        isSearching = true
        errorMessage = nil
        results = []
        do {
            let youtube = try await YouTubeMusicCatalog().search(term)
            var combined = youtube
            if !settings.addonBaseURL.isEmpty,
               let addon = try? AddonCatalog(baseURLString: settings.addonBaseURL) {
                if let addonResults = try? await addon.search(term) { combined = addonResults + youtube }
            }
            results = combined
            if combined.isEmpty { errorMessage = "No results found." }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    private func openYouTube(_ track: Track) {
        guard let id = track.providerID,
              let url = URL(string: "https://music.youtube.com/watch?v=\(id)") else { return }
        UIApplication.shared.open(url)
    }
}

private struct LibraryScreen: View {
    @EnvironmentObject private var playback: PlaybackManager
    @EnvironmentObject private var playlists: PlaylistStore
    @EnvironmentObject private var downloads: DownloadManager
    @Binding var showingPlayer: Bool
    @State private var newPlaylistName = ""
    @State private var showingCreate = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Playlists")) {
                    if playlists.playlists.isEmpty {
                        Text("Your playlists will appear here.").foregroundColor(.secondary)
                    }
                    ForEach(playlists.playlists) { playlist in
                        HStack {
                            Image(systemName: "music.note.list")
                            Text(playlist.name)
                            Spacer()
                            Text("\(playlist.trackIDs.count)").foregroundColor(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { playlists.playlists[$0] }.forEach(playlists.delete)
                    }
                    Button { showingCreate = true } label: { Label("Create playlist", systemImage: "plus") }
                }
                Section(header: Text("Offline")) {
                    HStack {
                        Label("Downloaded files", systemImage: "arrow.down.circle")
                        Spacer()
                        Text("\(downloads.downloadedFiles.count)").foregroundColor(.secondary)
                    }
                }
                Section(header: Text("Queue")) {
                    if playback.queue.isEmpty {
                        Text("Your queue is empty.").foregroundColor(.secondary)
                    }
                    ForEach(Array(playback.queue.enumerated()), id: \.element.id) { index, track in
                        HStack {
                            Text(track.title)
                            Spacer()
                            Text(track.artist).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("Your Library")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { showingCreate = true } label: { Image(systemName: "plus") } } }
            .alert("New playlist", isPresented: $showingCreate) {
                TextField("Playlist name", text: $newPlaylistName)
                Button("Create") { playlists.create(newPlaylistName); newPlaylistName = "" }
                Button("Cancel", role: .cancel) { newPlaylistName = "" }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct SettingsScreen: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var downloads: DownloadManager
    @State private var showingDownloads = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Music sources")) {
                    Text("Compatible addon URL")
                    TextField("https://your-addon.example", text: $settings.addonBaseURL)
                        .autocapitalization(.none).keyboardType(.URL).disableAutocorrection(true)
                    Text("The addon must expose /search and return tracks with id, title, artist and a direct stream URL. Only configure servers you trust.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section(header: Text("Playback")) {
                    Picker("Audio quality", selection: $settings.preferredQuality) {
                        Text("Best available").tag("Best available")
                        Text("High").tag("High")
                        Text("Standard").tag("Standard")
                    }
                }
                Section(header: Text("Offline library")) {
                    Button { downloads.refresh(); showingDownloads = true } label: {
                        HStack {
                            Text("Downloaded files")
                            Spacer()
                            Text("\(downloads.downloadedFiles.count)").foregroundColor(.secondary)
                        }
                    }
                }
                Section(header: Text("Account")) {
                    Label("Google / YouTube Music sign-in", systemImage: "person.crop.circle")
                    Text("Account cookie authentication is not implemented in this iOS 15 foundation. Never paste your Google password or session cookies into an untrusted app.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section(header: Text("About")) {
                    HStack { Text("BitChord for iOS"); Spacer(); Text("iOS 15+").foregroundColor(.secondary) }
                    Link("Project source", destination: URL(string: "https://github.com/cgvLPL/BitChord.Legacy/tree/ios/ios15-port")!)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingDownloads) { DownloadsScreen(downloads: downloads) }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct DownloadsScreen: View {
    @ObservedObject var downloads: DownloadManager
    var body: some View {
        NavigationView {
            List(downloads.downloadedFiles, id: \.absoluteString) { file in
                Label(file.deletingPathExtension().lastPathComponent, systemImage: "music.note")
            }
            .navigationTitle("Downloads")
        }
    }
}

private struct TrackRow: View {
    let track: Track
    let action: () -> Void
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    ArtworkView(url: track.artworkURL)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title).font(.subheadline.weight(.semibold)).foregroundColor(.white).lineLimit(1)
                        Text("\(track.artist) • \(track.album)").font(.caption).foregroundColor(.white.opacity(0.55)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(PlainButtonStyle())
            if let secondaryAction = secondaryAction {
                Button(action: secondaryAction) {
                    Image(systemName: "text.badge.plus").foregroundColor(.white.opacity(0.7)).padding(8)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct ArtworkView: View {
    let url: URL?
    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    artworkPlaceholder
                }
            } else { artworkPlaceholder }
        }
        .frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 9))
    }
    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.09))
            .overlay(Image(systemName: "waveform").foregroundColor(.white.opacity(0.65)))
    }
}

private struct MiniPlayer: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Binding var showingPlayer: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: playback.currentTrack?.artworkURL)
            Button { showingPlayer = true } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(playback.currentTrack?.title ?? "Not Playing").font(.subheadline.bold()).foregroundColor(.white).lineLimit(1)
                    Text(playback.currentTrack?.artist ?? "").font(.caption).foregroundColor(.white.opacity(0.6)).lineLimit(1)
                }
            }.buttonStyle(PlainButtonStyle())
            Spacer()
            Button(action: playback.togglePlayback) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").font(.title3).frame(width: 36, height: 36)
            }
        }
        .padding(9).background(Color(white: 0.13)).cornerRadius(14)
        .onTapGesture { showingPlayer = true }
    }
}

private struct NowPlayingScreen: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Environment(\.presentationMode) private var presentationMode
    @State private var lyrics: [LyricLine] = []
    @State private var lyricsMessage = "Lyrics have not been loaded."

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Done") { presentationMode.wrappedValue.dismiss() }
                Spacer()
                Text("NOW PLAYING").font(.caption.bold()).tracking(2)
                Spacer()
                Button { } label: { Image(systemName: "ellipsis").frame(width: 40) }
            }.padding(.top, 20)

            ArtworkView(url: playback.currentTrack?.artworkURL)
                .frame(maxWidth: 320).aspectRatio(1, contentMode: .fit)
                .background(Color.white.opacity(0.06)).cornerRadius(20)
                .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                Text(playback.currentTrack?.title ?? "Not Playing").font(.title2.bold()).lineLimit(1)
                Text(playback.currentTrack?.artist ?? "").foregroundColor(.white.opacity(0.6))
            }

            VStack(spacing: 6) {
                Slider(value: Binding(get: { playback.currentTime }, set: { playback.seek(to: $0) }),
                       in: 0...max(playback.duration, 1))
                HStack {
                    Text(timeString(playback.currentTime))
                    Spacer()
                    Text(timeString(playback.duration))
                }.font(.caption.monospacedDigit()).foregroundColor(.white.opacity(0.55))
            }

            HStack(spacing: 42) {
                Button(action: playback.playPrevious) { Image(systemName: "backward.end.fill").font(.title2) }
                Button(action: playback.togglePlayback) {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28)).frame(width: 68, height: 68)
                        .background(Color.white).foregroundColor(.black).clipShape(Circle())
                }
                Button(action: playback.playNext) { Image(systemName: "forward.end.fill").font(.title2) }
            }

            HStack {
                Text("Lyrics").font(.headline)
                Spacer()
                Button("Load") { Task { await loadLyrics() } }.font(.caption)
            }
            if lyrics.isEmpty {
                Text(lyricsMessage).font(.footnote).foregroundColor(.white.opacity(0.5)).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(lyrics) { line in
                            Text(line.text)
                                .font(.title3.weight(abs(line.time - playback.currentTime) < 2 ? .bold : .regular))
                                .foregroundColor(abs(line.time - playback.currentTime) < 2 ? .white : .white.opacity(0.42))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .background(Color(red: 0.035, green: 0.035, blue: 0.045).ignoresSafeArea())
        .foregroundColor(.white)
    }

    private func loadLyrics() async {
        guard let track = playback.currentTrack else { return }
        do {
            let result = try await LyricsService().fetch(title: track.title, artist: track.artist, duration: playback.duration)
            await MainActor.run {
                lyrics = result
                lyricsMessage = result.isEmpty ? "No synced lyrics were found." : ""
            }
        } catch {
            await MainActor.run { lyricsMessage = error.localizedDescription }
        }
    }

    private func timeString(_ value: Double) -> String {
        guard value.isFinite else { return "0:00" }
        let total = max(0, Int(value))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct SectionHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title2.bold())
            Text(subtitle).font(.caption).foregroundColor(.white.opacity(0.5))
        }
    }
}

private struct FeatureTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.title2)
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(Color.white.opacity(0.07)).cornerRadius(14)
    }
}
