import AppKit
import CoreGraphics

class ActionHandler {
    static let shared = ActionHandler()
    
    private init() {}
    
    func triggerAction(actionString: String, buttonKey: String) {
        switch actionString {
        case "Mission Control":
            triggerMissionControl()
        case "Show Desktop":
            triggerShowDesktop()
        case "Copy (⌘C)":
            postKeyboardShortcut(keyCode: 8, flags: .maskCommand) // C is 8
        case "Paste (⌘V)":
            postKeyboardShortcut(keyCode: 9, flags: .maskCommand) // V is 9
        case "Next Space (⌃→)":
            postKeyboardShortcut(keyCode: 124, flags: .maskControl) // Right Arrow is 124
        case "Previous Space (⌃←)":
            postKeyboardShortcut(keyCode: 123, flags: .maskControl) // Left Arrow is 123
        case "Previous Desktop":
            postKeyboardShortcut(keyCode: 31, flags: .maskCommand) // O is 31
        case "Next Desktop":
            postKeyboardShortcut(keyCode: 35, flags: .maskCommand) // P is 35
        case "Custom Shortcut...":
            triggerCustomShortcut(buttonKey: buttonKey)
        default:
            break
        }
    }
    
    func triggerMissionControl() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.exposelauncher") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        } else {
            // Fallback via shell open
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Mission Control"]
            try? process.run()
        }
    }
    
    func triggerShowDesktop() {
        // Simulate Command + F3 (F3 is virtual keycode 99)
        postKeyboardShortcut(keyCode: 99, flags: .maskCommand)
    }
    
    func triggerCustomShortcut(buttonKey: String) {
        let keyCode = UserDefaults.standard.integer(forKey: "\(buttonKey)_keyCode")
        let flagsRaw = UserDefaults.standard.integer(forKey: "\(buttonKey)_flags")
        
        // If they have never recorded one, do nothing
        guard keyCode != 0 else { return }
        
        let flags = CGEventFlags(rawValue: UInt64(flagsRaw))
        postKeyboardShortcut(keyCode: CGKeyCode(keyCode), flags: flags)
    }
    
    func postKeyboardShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Key down
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        
        // Key up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // Utility to format keycodes to user-friendly string
    static func formatKeyCode(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "↩" // Return
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "⇥" // Tab
        case 49: return "Space"
        case 50: return "`"
        case 51: return "⌫" // Delete
        case 53: return "⎋" // Escape
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 109: return "F10"
        case 111: return "F12"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 54, 55:
            return "Cmd"
        case 56, 60:
            return "Shift"
        case 57:
            return "CapsLock"
        case 58, 61:
            return "Alt"
        case 59, 62:
            return "Ctrl"
        case 63:
            return "Fn"
        default:
            return "Key#\(keyCode)"
        }
    }
}
