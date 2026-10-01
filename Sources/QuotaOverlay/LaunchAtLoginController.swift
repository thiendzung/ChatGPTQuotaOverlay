import Foundation
import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case off
    case on
    case requiresApproval
    case unavailable
}

final class LaunchAtLoginController {
    var state: LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .off
        case .enabled:
            return .on
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func toggle() {
        do {
            switch state {
            case .off:
                try SMAppService.mainApp.register()
            case .on:
                try SMAppService.mainApp.unregister()
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            case .unavailable:
                break
            }
        } catch {
            // Registration failures are intentionally not persisted or logged.
            // The menu re-reads SMAppService.status on its next open.
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
