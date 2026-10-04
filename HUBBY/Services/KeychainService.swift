import Foundation
import Security

enum Keychain {
    static func set(_ value: String, key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum Keys {
        static let eraBaseURL       = "era_base_url"
        static let eraEndpointPath  = "era_endpoint_path"
        static let eraAPIKey        = "era_api_key"
        static let feedURL          = "snapshot_feed_url"
        static let feedToken        = "snapshot_feed_token"
        static let liveHUDURL       = "live_hud_url"
        static let lowBalanceThreshold = "low_balance_threshold"
        static let gmailThreatQuery = "gmail_threat_query"
        static let gmailLeadQuery   = "gmail_lead_query"
        // VEGA backend
        static let vegaBackendURL   = "vega_backend_url"
        static let vegaSessionToken = "vega_session_token"
    }
}
