import Foundation

/// The App Group shared by the app and its widget.
///
/// Set once, as `APP_BUNDLE_PREFIX` in `Config/`; the entitlements and both Info.plists
/// expand it, and this reads it back so no Swift file spells the identifier out.
enum AppGroup {
    static let identifier: String =
        Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String
        ?? "group.com.example.timemoney"
}
