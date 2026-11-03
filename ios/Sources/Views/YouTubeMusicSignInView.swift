import SwiftUI
import WebKit

struct YouTubeMusicSignInView: View {
    @ObservedObject var authStore: YouTubeMusicAuthStore
    @Environment(\.presentationMode) private var presentationMode
    @State private var captureRequest = 0
    @State private var hasReachedMusic = false
    @State private var isSaving = false
    @State private var message: String?
    @State private var capturedCookie = ""
    @State private var capturedConfig: [String: Any] = [:]

    private let signInURL = URL(string: "https://accounts.google.com/ServiceLogin?ltmpl=music&service=youtube&prompt=select_account&continue=https%3A%2F%2Fmusic.youtube.com%2F")!

    var body: some View {
        NavigationView {
            YouTubeMusicWebView(
                url: signInURL,
                captureRequest: captureRequest,
                onPageReady: { ready in hasReachedMusic = ready },
                onSession: { cookie, config in
                    capturedCookie = cookie
                    capturedConfig = config
                    message = nil
                },
                onUnavailable: {
                    message = "The signed-in YouTube Music session is not ready yet. Finish choosing your Google account or channel, then try again."
                }
            )
            .overlay(alignment: .bottom) {
                if hasReachedMusic {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32)).foregroundColor(.green)
                        Text("YouTube Music is ready").font(.headline)
                        Text("Choose the correct profile or Brand channel in the page above. When it shows the identity you want, confirm it here.")
                            .font(.footnote).multilineTextAlignment(.center).foregroundColor(.secondary)
                        Button(isSaving ? "Saving…" : "Use this account") {
                            captureRequest += 1
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                }
            }
            .overlay(alignment: .top) {
                if let message = message {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(10)
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .padding()
                }
            }
            .navigationTitle("Sign in to YouTube Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: capturedCookie) { cookie in
            guard !cookie.isEmpty else { return }
            Task { await saveSession(cookie: cookie, config: capturedConfig) }
        }
    }

    @MainActor
    private func saveSession(cookie: String, config: [String: Any]) async {
        isSaving = true
        do {
            try authStore.save(cookieHeader: cookie, config: config)
            presentationMode.wrappedValue.dismiss()
        } catch {
            message = error.localizedDescription
        }
        isSaving = false
    }
}

private struct YouTubeMusicWebView: UIViewRepresentable {
    let url: URL
    let captureRequest: Int
    let onPageReady: (Bool) -> Void
    let onSession: (String, [String: Any]) -> Void
    let onUnavailable: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPageReady: onPageReady, onSession: onSession, onUnavailable: onUnavailable)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.load(url, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.captureIfRequested(captureRequest, from: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onPageReady: (Bool) -> Void
        private let onSession: (String, [String: Any]) -> Void
        private let onUnavailable: () -> Void
        private var lastCaptureRequest = 0

        init(onPageReady: @escaping (Bool) -> Void,
             onSession: @escaping (String, [String: Any]) -> Void,
             onUnavailable: @escaping () -> Void) {
            self.onPageReady = onPageReady
            self.onSession = onSession
            self.onUnavailable = onUnavailable
        }

        func load(_ url: URL, in webView: WKWebView) {
            let store = webView.configuration.websiteDataStore
            store.httpCookieStore.getAllCookies { cookies in
                let googleCookies = cookies.filter {
                    let domain = $0.domain.lowercased()
                    return domain.contains("google.com") || domain.contains("youtube.com")
                }
                let group = DispatchGroup()
                googleCookies.forEach { cookie in
                    group.enter()
                    store.httpCookieStore.delete(cookie) { group.leave() }
                }
                group.notify(queue: .main) {
                    webView.load(URLRequest(url: url))
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let ready = webView.url?.absoluteString.hasPrefix("https://music.youtube.com") == true
            onPageReady(ready)
        }

        func captureIfRequested(_ request: Int, from webView: WKWebView) {
            guard request > 0, request != lastCaptureRequest else { return }
            lastCaptureRequest = request
            guard webView.url?.absoluteString.hasPrefix("https://music.youtube.com") == true else {
                onUnavailable()
                return
            }

            let probe = """
            (function () {
              try {
                if (!window.ytcfg || !window.ytcfg.get) return null;
                var get = function (key) {
                  var value = window.ytcfg.get(key);
                  return (value === undefined || value === null || value === '') ? null : String(value);
                };
                var delegated = get('DELEGATED_SESSION_ID');
                var dataSync = get('DATASYNC_ID');
                return {
                  loggedIn: !!window.ytcfg.get('LOGGED_IN'),
                  pageId: delegated || (dataSync ? dataSync.split('||')[0] : null),
                  dataSyncId: dataSync,
                  authUser: get('SESSION_INDEX'),
                  visitorData: get('VISITOR_DATA'),
                  clientVersion: get('INNERTUBE_CLIENT_VERSION')
                };
              } catch (e) { return null; }
            })();
            """

            webView.evaluateJavaScript(probe) { [weak self, weak webView] result, _ in
                guard let self = self else { return }
                guard let webView = webView,
                      let config = result as? [String: Any],
                      config["loggedIn"] as? Bool == true else {
                    self.onUnavailable()
                    return
                }
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                    let accepted = cookies.filter {
                        let domain = $0.domain.lowercased()
                        return domain.contains("youtube.com") || domain.contains("google.com")
                    }
                    let cookieHeader = accepted.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                    let hasSAPISID = accepted.contains {
                        ["SAPISID", "__Secure-3PAPISID", "__Secure-1PAPISID"].contains($0.name)
                    }
                    guard hasSAPISID, !cookieHeader.isEmpty else {
                        DispatchQueue.main.async { self.onUnavailable() }
                        return
                    }
                    var values = config
                    if values["pageId"] == nil,
                       let dataSyncID = values["dataSyncId"] as? String {
                        values["pageId"] = dataSyncID.components(separatedBy: "||").first
                    }
                    DispatchQueue.main.async {
                        self.onSession(cookieHeader, values)
                    }
                }
            }
        }
    }
}
