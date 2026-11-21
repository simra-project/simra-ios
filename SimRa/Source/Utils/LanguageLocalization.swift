import Foundation
import ObjectiveC.runtime

private final class LanguageAwareBundle: Bundle, @unchecked Sendable {
    override func localizedString(
        forKey key: String,
        value: String?,
        table tableName: String?
    ) -> String {
        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "auto"
        guard language != "auto",
              let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return localizedBundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

enum LanguageLocalization {
    private static let installBundleOverride: Void = {
        object_setClass(Bundle.main, LanguageAwareBundle.self)
    }()

    static func apply(_ languageCode: String) {
        if languageCode == "auto" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        }

        _ = installBundleOverride
    }
}
