import SwiftUI
import WebKit

struct YouTubeMusicSignInView: View {
    @ObservedObject var authStore: YouTubeMusicAuthStore
    @Environment(\.presentationMode) private var presentationMode
    @State private var cookieHeader = ""
    @State private var config: [String: Any] = [:]
    @State private var hasReachedMusic = false
    @State private var isSaving = false
    @State private var message: String?

    private let signInURL = URL(string: "https://accounts.google.com/ServiceLogin?ltmpl=music&service=youtube&prompt=select_account&continue=https%3A%2F%2Fmusic.youtube.com%2F")!

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if hasReachedMusic {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 42)).foregroundColor(.green)
                        Text("YouTube Music opened").font(.title3.bold())
                        Text("If you have selected the correct Google account or channel, save this session to BitChord.")
                            .font(.footnote).multilineTextAlignment(.center).foregroundColor(.secondary)
                        Button(isSaving ? "Saving…" : "Continue with this account") {
                            Task { await saveSession() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving || cookieHeader.isEmpty)
                    }
                    .padding(24)
                    Spacer()
                    YouTubeMusicWebView(url: signInURL, onSession: { cookies, values in
                        cookieHeader = cookies
                        config = values
                        hasReachedMusic = true
                    })
                    .frame(height: 1)
                } else {
                    YouTubeMusicWebView(url: signInURL, onSession: { cookies, values in
                        cookieHeader = cookies
                        config = values
                        hasReachedMusic = true
                    })
                    .ignoresSafeArea(edges: .bottom)
                }
                if let message = message {
                    Text(message).font(.footnote).foregroundColor(.red).padding()
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
    }

    @MainActor
    private func saveSession() async {
        isSaving = true
        do {
            try authStore.save(cookieHeader: cookieHeader, config: config)
            presentationMode.wrappedValue.dismiss()
        } catch {
            message = error.localizedDescription
        }
        isSaving = false
    }
}

private struct YouTubeMusicWebView: UIViewRepresentable {
    let url: URL
    let onSession: (String, [String: Any]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSession: onSession) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onSession: (String, [String: Any]) -> Void
        private var lastCapture: Date?

        init(onSession: @escaping (String, [String: Any]) -> Void) {
            self.onSession = onSession
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard webView.url?.host?.hasSuffix("youtube.com") == true else { return }
            let script = """
            (() => {
              const cfg = (window.ytcfg && (window.ytcfg.data_ || window.ytcfg.data)) || {};
              const account = document.querySelector('button[aria-label*="Google Account"], button[aria-label*="account"]');
              return JSON.stringify({
                config: {
                  DELEGATED_SESSION_ID: cfg.DELEGATED_SESSION_ID || null,
                  DATASYNC_ID: cfg.DATASYNC_ID || null,
                  SESSION_INDEX: cfg.SESSION_INDEX == null ? "0" : String(cfg.SESSION_INDEX),
                  VISITOR_DATA: cfg.VISITOR_DATA || null,
                  INNERTUBE_CLIENT_VERSION: cfg.INNERTUBE_CLIENT_VERSION || null,
                  LOGGED_IN: cfg.LOGGED_IN === true,
                  ACCOUNT_NAME: account ? account.getAttribute('aria-label') : null
                },
                loggedIn: cfg.LOGGED_IN === true
              });
            })();
            """
            webView.evaluateJavaScript(script) { [weak self] result, _ in
                guard let self = self,
                      let raw = result as? String,
                      let data = raw.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      object["loggedIn"] as? Bool == true else { return }
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    let accepted = cookies.filter {
                        let domain = $0.domain.lowercased()
                        return domain.contains("youtube.com") || domain.contains("google.com")
                    }
                    let header = accepted.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                    guard !header.isEmpty else { return }
                    let config = object["config"] as? [String: Any] ?? [:]
                    DispatchQueue.main.async {
                        self.onSession(header, config)
                    }
                }
            }
        }
    }
}
