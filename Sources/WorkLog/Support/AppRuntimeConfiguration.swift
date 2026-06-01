import Foundation

struct AppBuildInfo {
    var bundleIdentifier: String
    var version: String
    var build: String
    var releaseChannel: String
}

enum AppRuntimeConfiguration {
    private static let demoDataEnvironmentKey = "WORKLOG_ENABLE_DEMO_DATA"
    private static let demoDataInfoKey = "WorkLogEnableDemoData"
    private static let releaseChannelInfoKey = "WorkLogReleaseChannel"

    static var allowsDemoData: Bool {
        if let environmentValue = ProcessInfo.processInfo.environment[demoDataEnvironmentKey],
           let parsedValue = parseBoolean(environmentValue) {
            return parsedValue
        }

        if let infoValue = Bundle.main.object(forInfoDictionaryKey: demoDataInfoKey) {
            if let boolValue = infoValue as? Bool {
                return boolValue
            }
            if let stringValue = infoValue as? String,
               let parsedValue = parseBoolean(stringValue) {
                return parsedValue
            }
        }

        return false
    }

    static var buildInfo: AppBuildInfo {
        let bundle = Bundle.main
        let info = bundle.infoDictionary ?? [:]

        let bundleIdentifier = bundle.bundleIdentifier
            ?? (info[kCFBundleIdentifierKey as String] as? String)
            ?? "com.sarveshchandra.WorkLog"
        let version = info["CFBundleShortVersionString"] as? String ?? "Development"
        let build = info[kCFBundleVersionKey as String] as? String ?? "0"
        let releaseChannel = info[releaseChannelInfoKey] as? String ?? "development"

        return AppBuildInfo(
            bundleIdentifier: bundleIdentifier,
            version: version,
            build: build,
            releaseChannel: releaseChannel
        )
    }

    private static func parseBoolean(_ value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return nil
        }
    }
}
