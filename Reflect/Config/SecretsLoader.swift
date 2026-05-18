import Foundation

/// Reads `Secrets.plist` from the app bundle.
///
/// The file is `.gitignored` so each developer keeps a local copy. Copy
/// `Secrets.example.plist` and fill in your keys.
enum SecretsLoader {
    private static var plist: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") else {
            print("⚠️ Secrets.plist not found in bundle — using AppConfig fallback values")
            return nil
        }
        guard
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            print("⚠️ Secrets.plist found but could not be parsed")
            return nil
        }
        return dict
    }()

    static func groqAPIKey() -> String {
        guard let key = plist?["GROQ_API_KEY"] as? String, !key.isEmpty else {
            print("⚠️ GROQ_API_KEY missing/empty in Secrets.plist")
            return AppConfig.placeholderAPIKey
        }
        let masked = key.count > 8 ? "\(key.prefix(4))…\(key.suffix(4))" : "***"
        print("🔑 Loaded Groq key (\(masked))")
        return key
    }

    static func supabaseURL() -> URL {
        guard let urlString = plist?["SUPABASE_URL"] as? String, let url = URL(string: urlString) else {
            print("⚠️ SUPABASE_URL missing/invalid in Secrets.plist — using AppConfig placeholder")
            return AppConfig.supabaseURL
        }
        print("🔑 Loaded Supabase URL from Secrets.plist")
        return url
    }

    static func supabaseAnonKey() -> String {
        guard let key = plist?["SUPABASE_ANON_KEY"] as? String, !key.isEmpty else {
            print("⚠️ SUPABASE_ANON_KEY missing/empty in Secrets.plist — using AppConfig placeholder")
            return AppConfig.supabaseAnonKey
        }
        print("🔑 Loaded Supabase Anon Key from Secrets.plist")
        return key
    }
}
