import Foundation
import Combine
import Security
import CommonCrypto

struct YouTubeMusicAccount: Codable {
    let cookieHeader: String
    let sapisid: String
    let authUser: String
    let pageID: String?
    let visitorData: String?
    let clientVersion: String?
    let loggedIn: Bool
    let accountName: String?
    let savedAt: Date
}

final class YouTubeMusicAuthStore: ObservableObject {
    @Published private(set) var account: YouTubeMusicAccount?
    @Published var errorMessage: String?
    private let service = "com.bitchord.ios.youtube-session"
    private let accountKey = "primary"

    init() { account = load() }

    var isSignedIn: Bool { account?.loggedIn == true }

    func save(cookieHeader: String, config: [String: Any]) throws {
        let cookies = cookieHeader.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        let sapisidCookie = cookies.first { item in
            let name = item.split(separator: "=", maxSplits: 1).first.map(String.init) ?? ""
            return ["SAPISID", "__Secure-3PAPISID", "__Secure-1PAPISID"].contains(name)
        }
        guard let sapisidCookie, let separator = sapisidCookie.firstIndex(of: "=") else {
            throw AuthError.missingSessionCookie
        }
        let sapisid = String(sapisidCookie[sapisidCookie.index(after: separator)...])
        guard !sapisid.isEmpty else { throw AuthError.missingSessionCookie }

        let account = YouTubeMusicAccount(
            cookieHeader: cookieHeader,
            sapisid: sapisid,
            authUser: String(describing: config["authUser"] ?? config["SESSION_INDEX"] ?? "0"),
            pageID: (config["pageId"] as? String) ?? (config["DELEGATED_SESSION_ID"] as? String),
            visitorData: (config["visitorData"] as? String) ?? (config["VISITOR_DATA"] as? String),
            clientVersion: (config["clientVersion"] as? String) ?? (config["INNERTUBE_CLIENT_VERSION"] as? String),
            loggedIn: (config["loggedIn"] as? Bool) ?? (config["LOGGED_IN"] as? Bool) ?? true,
            accountName: config["ACCOUNT_NAME"] as? String,
            savedAt: Date()
        )
        let data = try JSONEncoder().encode(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw AuthError.keychain(status) }
        DispatchQueue.main.async { self.account = account }
    }

    func signOut() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ] as CFDictionary)
        account = nil
    }

    func applyAuthentication(to request: inout URLRequest) {
        guard let account = account, account.loggedIn else { return }
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let origin = "https://music.youtube.com"
        let input = "\(timestamp) \(account.sapisid) \(origin)"
        let digest = input.data(using: .utf8).map { data -> String in
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            data.withUnsafeBytes { bytes in
                _ = CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &hash)
            }
            return hash.map { String(format: "%02x", $0) }.joined()
        } ?? ""
        request.setValue("SAPISIDHASH \(timestamp)_\(digest)", forHTTPHeaderField: "Authorization")
        request.setValue(account.cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue(account.authUser, forHTTPHeaderField: "X-Goog-AuthUser")
        if let pageID = account.pageID, !pageID.isEmpty {
            request.setValue(pageID, forHTTPHeaderField: "X-Goog-PageId")
        }
        if let visitorData = account.visitorData {
            request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        request.setValue(origin, forHTTPHeaderField: "Origin")
        request.setValue(origin + "/", forHTTPHeaderField: "Referer")
    }

    private func load() -> YouTubeMusicAccount? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(YouTubeMusicAccount.self, from: data)
    }

    enum AuthError: LocalizedError {
        case missingSessionCookie
        case keychain(OSStatus)
        var errorDescription: String? {
            switch self {
            case .missingSessionCookie:
                return "YouTube Music did not provide a valid signed-in session. Confirm that you reached music.youtube.com and try again."
            case .keychain(let status):
                return "The secure session could not be saved (Keychain error \(status))."
            }
        }
    }
}
