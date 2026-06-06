import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var shortcutRecorderWindow: ShortcutRecorderWindow?
    var mouseButtonRecorderWindow: MouseButtonRecorderWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register default actions: Buttons 4 and 5 mapped by default
        UserDefaults.standard.register(defaults: [
            "mappedButtons": [3, 4],
            "buttonAction_3": "None",
            "buttonAction_4": "None"
        ])
        
        // Create the Status Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "mouse", accessibilityDescription: "MouseCut") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "🖱️"
            }
        }
        
        buildMenu()
        
        // Start Event Tap if Accessibility permission is already granted
        if AXIsProcessTrusted() {
            EventTap.shared.start()
        } else {
            // Prompt on first launch if not trusted
            promptAccessibility()
        }
    }
    
    func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        // App title
        let titleItem = NSMenuItem(title: "MouseCut v1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // Dynamic Mouse Buttons
        let mappedButtons = UserDefaults.standard.array(forKey: "mappedButtons") as? [Int] ?? [3, 4]
        let sortedButtons = mappedButtons.sorted()
        
        if sortedButtons.isEmpty {
            let emptyItem = NSMenuItem(title: "No mouse buttons remapped", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for button in sortedButtons {
                let friendlyName = friendlyButtonName(for: button)
                let buttonItem = NSMenuItem(title: friendlyName, action: nil, keyEquivalent: "")
                let buttonMenu = NSMenu()
                setupSubmenu(buttonMenu, buttonKey: "buttonAction_\(button)")
                buttonItem.submenu = buttonMenu
                menu.addItem(buttonItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add Button Mapping Option
        let addMappingItem = NSMenuItem(title: "Add Button Mapping...", action: #selector(addButtonMapping(_:)), keyEquivalent: "")
        addMappingItem.target = self
        menu.addItem(addMappingItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Launch at Login
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchItem)
        
        // Accessibility Permission Status
        let isTrusted = AXIsProcessTrusted()
        let permissionItem = NSMenuItem(
            title: isTrusted ? "✓ Accessibility Permission Granted" : "⚠️ Grant Accessibility...",
            action: isTrusted ? nil : #selector(grantAccessibilityPermission(_:)),
            keyEquivalent: ""
        )
        permissionItem.target = self
        if !isTrusted {
            permissionItem.toolTip = "Accessibility permission is required to intercept mouse clicks globally."
        }
        menu.addItem(permissionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit MouseCut", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    func setupSubmenu(_ submenu: NSMenu, buttonKey: String) {
        let currentAction = UserDefaults.standard.string(forKey: buttonKey) ?? "None"
        
        let actions = [
            "None",
            "Mission Control",
            "Show Desktop",
            "Copy (⌘C)",
            "Paste (⌘V)",
            "Next Space (⌃→)",
            "Previous Space (⌃←)",
            "Previous Desktop",
            "Next Desktop",
            "Custom Shortcut..."
        ]
        
        for action in actions {
            var title = action
            if action == "Custom Shortcut..." {
                let keyCode = UserDefaults.standard.integer(forKey: "\(buttonKey)_keyCode")
                if keyCode != 0 {
                    let formatted = formatSavedShortcut(buttonKey: buttonKey)
                    title = "Custom: \(formatted)"
                }
            }
            
            let item = NSMenuItem(title: title, action: #selector(selectAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ["buttonKey": buttonKey, "action": action]
            
            if currentAction == action {
                item.state = .on
            } else {
                item.state = .off
            }
            
            submenu.addItem(item)
        }
        
        // Add Remove Mapping Option
        submenu.addItem(NSMenuItem.separator())
        let removeItem = NSMenuItem(title: "Remove Mapping", action: #selector(removeButtonMapping(_:)), keyEquivalent: "")
        removeItem.target = self
        removeItem.representedObject = buttonKey
        submenu.addItem(removeItem)
    }
    
    @objc func selectAction(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let buttonKey = info["buttonKey"],
              let actionName = info["action"] else {
            return
        }
        
        if actionName == "Custom Shortcut..." {
            shortcutRecorderWindow = ShortcutRecorderWindow { [weak self] keyCode, flags in
                UserDefaults.standard.set(Int(keyCode), forKey: "\(buttonKey)_keyCode")
                UserDefaults.standard.set(Int(flags.rawValue), forKey: "\(buttonKey)_flags")
                UserDefaults.standard.set("Custom Shortcut...", forKey: buttonKey)
                
                self?.buildMenu()
                print("Custom shortcut recorded: KeyCode \(keyCode), flags \(flags.rawValue)")
            }
            
            NSApp.activate(ignoringOtherApps: true)
            shortcutRecorderWindow?.makeKeyAndOrderFront(nil)
        } else {
            UserDefaults.standard.set(actionName, forKey: buttonKey)
            buildMenu()
        }
    }
    
    @objc func addButtonMapping(_ sender: NSMenuItem) {
        if !AXIsProcessTrusted() {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "MouseCut needs Accessibility permission to detect mouse button clicks globally. Please grant it in System Settings and try again."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                promptAccessibility()
            }
            return
        }
        
        mouseButtonRecorderWindow = MouseButtonRecorderWindow { [weak self] buttonNumber in
            var mappedButtons = UserDefaults.standard.array(forKey: "mappedButtons") as? [Int] ?? [3, 4]
            if !mappedButtons.contains(buttonNumber) {
                mappedButtons.append(buttonNumber)
                UserDefaults.standard.set(mappedButtons, forKey: "mappedButtons")
                UserDefaults.standard.set("None", forKey: "buttonAction_\(buttonNumber)")
            }
            self?.buildMenu()
            print("Added mouse button mapping for button \(buttonNumber)")
        }
        
        NSApp.activate(ignoringOtherApps: true)
        mouseButtonRecorderWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func removeButtonMapping(_ sender: NSMenuItem) {
        guard let buttonKey = sender.representedObject as? String else { return }
        let parts = buttonKey.components(separatedBy: "_")
        guard parts.count == 2, let buttonNum = Int(parts[1]) else { return }
        
        var mappedButtons = UserDefaults.standard.array(forKey: "mappedButtons") as? [Int] ?? [3, 4]
        if let index = mappedButtons.firstIndex(of: buttonNum) {
            mappedButtons.remove(at: index)
        }
        UserDefaults.standard.set(mappedButtons, forKey: "mappedButtons")
        
        UserDefaults.standard.removeObject(forKey: buttonKey)
        UserDefaults.standard.removeObject(forKey: "\(buttonKey)_keyCode")
        UserDefaults.standard.removeObject(forKey: "\(buttonKey)_flags")
        
        buildMenu()
        print("Removed mouse button mapping for button \(buttonNum)")
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }
    
    @objc func grantAccessibilityPermission(_ sender: NSMenuItem) {
        promptAccessibility()
    }
    
    @objc func quitApp(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
    
    // NSMenuDelegate
    func menuWillOpen(_ menu: NSMenu) {
        buildMenu()
        
        if AXIsProcessTrusted() && !EventTap.shared.isRunning {
            EventTap.shared.start()
        }
    }
    
    private func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func formatSavedShortcut(buttonKey: String) -> String {
        let keyCode = UserDefaults.standard.integer(forKey: "\(buttonKey)_keyCode")
        let flagsRaw = UInt64(UserDefaults.standard.integer(forKey: "\(buttonKey)_flags"))
        
        var modifierStr = ""
        if (flagsRaw & CGEventFlags.maskSecondaryFn.rawValue) != 0 { modifierStr += "Fn " }
        if (flagsRaw & CGEventFlags.maskControl.rawValue) != 0 { modifierStr += "⌃" }
        if (flagsRaw & CGEventFlags.maskAlternate.rawValue) != 0 { modifierStr += "⌥" }
        if (flagsRaw & CGEventFlags.maskShift.rawValue) != 0 { modifierStr += "⇧" }
        if (flagsRaw & CGEventFlags.maskCommand.rawValue) != 0 { modifierStr += "⌘" }
        
        let keyStr = ActionHandler.formatKeyCode(UInt16(keyCode))
        return "\(modifierStr)\(keyStr)"
    }
    
    private func friendlyButtonName(for buttonNumber: Int) -> String {
        switch buttonNumber {
        case 2:
            return "Mouse Button 3 (Middle Click)"
        case 3:
            return "Mouse Button 4 (Side Back)"
        case 4:
            return "Mouse Button 5 (Side Forward)"
        default:
            return "Mouse Button \(buttonNumber + 1)"
        }
    }
}
