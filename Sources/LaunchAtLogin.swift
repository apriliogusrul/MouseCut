import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        get {
            return SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status == .enabled {
                        return
                    }
                    try SMAppService.mainApp.register()
                    print("Successfully registered launch at login.")
                } else {
                    if SMAppService.mainApp.status == .notFound || SMAppService.mainApp.status == .notRegistered {
                        return
                    }
                    try SMAppService.mainApp.unregister()
                    print("Successfully unregistered launch at login.")
                }
            } catch {
                print("Error setting Launch at Login: \(error.localizedDescription)")
            }
        }
    }
}
