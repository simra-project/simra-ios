import Foundation
import ObjectiveC.runtime

private final class LanguageAwareBundle: Bundle, @unchecked Sendable {
    override func localizedString(
        forKey key: String,
        value: String?,
        table tableName: String?
    ) -> String {
        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "auto"
        guard
            language != "auto",
            let resourcePath = Bundle.main.path(forResource: language, ofType: "lproj"),
            let languageBundle = Bundle(path: resourcePath)
        else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }

        return languageBundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

enum LanguageLocalization {
    private static var didInstall = false

    static func apply(_ languageCode: String) {
        if languageCode == "auto" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        }

        guard !didInstall else {
            return
        }

        object_setClass(Bundle.main, LanguageAwareBundle.self)
        didInstall = true
    }
}
