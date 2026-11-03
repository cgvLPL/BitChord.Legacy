import Foundation
import Combine

final class AppSettings: ObservableObject {
    @Published var addonBaseURL: String {
        didSet { UserDefaults.standard.set(addonBaseURL, forKey: "bitchord.addon.url") }
    }
    @Published var preferredQuality: String {
        didSet { UserDefaults.standard.set(preferredQuality, forKey: "bitchord.quality") }
    }

    init() {
        addonBaseURL = UserDefaults.standard.string(forKey: "bitchord.addon.url") ?? ""
        preferredQuality = UserDefaults.standard.string(forKey: "bitchord.quality") ?? "Best available"
    }
}
