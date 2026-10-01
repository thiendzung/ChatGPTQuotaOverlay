import Foundation
import Security

/// Resolves only the Codex executable bundled inside an OpenAI-signed
/// ChatGPT/Codex desktop application. Arbitrary PATH binaries are never used.
enum CodexBinaryResolver {
    private static let openAITeamID = "2DC432GLL2"
    private static let acceptedBundleIDs: Set<String> = ["com.openai.chat", "com.openai.codex"]

    static func resolve() -> URL? {
        for appURL in chatGPTApplicationCandidates() {
            guard isAcceptedBundle(appURL) else {
                continue
            }

            let root = appURL.resolvingSymlinksInPath().standardizedFileURL
            let relativeCandidates = [
                "Contents/Resources/codex-cli/bin/codex",
                "Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
                "Contents/Resources/codex"
            ]

            for relative in relativeCandidates {
                let candidate = appURL.appendingPathComponent(relative)
                let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL

                guard resolved.path.hasPrefix(root.path + "/Contents/"),
                      FileManager.default.isExecutableFile(atPath: resolved.path),
                      isOpenAISigned(resolved) else {
                    continue
                }
                return resolved
            }
        }
        return nil
    }

    private static func chatGPTApplicationCandidates() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true),
            home.appendingPathComponent("Applications/ChatGPT.app", isDirectory: true),
            home.appendingPathComponent("Applications/Codex.app", isDirectory: true)
        ]
    }

    private static func isAcceptedBundle(_ url: URL) -> Bool {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return false }
        return acceptedBundleIDs.contains(bundleID)
    }

    private static func isOpenAISigned(_ url: URL) -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode else {
            return false
        }

        var requirement: SecRequirement?
        let requirementString = "anchor apple generic and certificate leaf[subject.OU] = \"\(openAITeamID)\"" as CFString
        guard SecRequirementCreateWithString(requirementString, SecCSFlags(), &requirement) == errSecSuccess,
              let requirement else {
            return false
        }

        let rawFlags = kSecCSStrictValidate | kSecCSCheckAllArchitectures
        let flags = SecCSFlags(rawValue: rawFlags)
        return SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess
    }
}
