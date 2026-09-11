import Foundation

public enum ExecutableResolverError: Error, LocalizedError {
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let name):
            return "\(name) is unavailable. Run scripts/setup-receiver.sh and try again."
        }
    }
}

public enum ExecutableResolver {
    public static func uxPlay(
        explicit: URL? = nil,
        bundle: Bundle = .main,
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> URL {
        if let explicit {
            guard isExecutable(explicit) else { throw ExecutableResolverError.unavailable("UxPlay") }
            return explicit
        }
        let candidates = [
            bundle.bundleURL.appendingPathComponent("Contents/Helpers/uxplay"),
            workingDirectory.appendingPathComponent(".deps/uxplay/bin/uxplay")
        ]
        guard let match = candidates.first(where: isExecutable) else {
            throw ExecutableResolverError.unavailable("UxPlay")
        }
        return match
    }

    public static func gstLaunch(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> URL {
        let pathDirectories = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        let candidates = pathDirectories + [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/Library/Frameworks/GStreamer.framework/Versions/1.0/bin"
        ]
        for directory in candidates {
            let url = URL(fileURLWithPath: directory).appendingPathComponent("gst-launch-1.0")
            if isExecutable(url) { return url }
        }
        throw ExecutableResolverError.unavailable("GStreamer")
    }

    public static func processEnvironment(base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        let additions = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/Library/Frameworks/GStreamer.framework/Versions/1.0/bin"
        ]
        let oldPath = base["PATH"] ?? "/usr/bin:/bin"
        return base.merging([
            "PATH": (additions + [oldPath]).joined(separator: ":"),
            "UXPLAYRC": "/dev/null"
        ]) { _, new in new }
    }

    private static func isExecutable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }
}
