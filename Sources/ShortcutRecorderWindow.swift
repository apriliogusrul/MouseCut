import AppKit
import CoreGraphics

class ShortcutRecorderWindow: NSWindow {
    var recordedKeyCode: CGKeyCode?
    var recordedFlags: CGEventFlags?
    var onSave: ((CGKeyCode, CGEventFlags) -> Void)?
    
    private let instructionLabel = NSTextField(labelWithString: "Press the keyboard shortcut you want to assign.")
    private let keysLabel = NSTextField(labelWithString: "Press any keys...")
    private let rawDetailsLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    
    private var eventMonitor: Any?
    
    init(onSave: @escaping (CGKeyCode, CGEventFlags) -> Void) {
        self.onSave = onSave
        
        let styleMask: NSWindow.StyleMask = [.titled, .closable]
        super.init(contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
                   styleMask: styleMask,
                   backing: .buffered,
                   defer: false)
        
        self.title = "Record Shortcut"
        self.isReleasedWhenClosed = false
        self.center()
        
        setupUI()
        startMonitoring()
    }
    
    private func setupUI() {
        let contentView = NSView(frame: self.frame)
        self.contentView = contentView
        
        instructionLabel.frame = NSRect(x: 20, y: 110, width: 280, height: 30)
        instructionLabel.alignment = .center
        instructionLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        instructionLabel.isEditable = false
        instructionLabel.isBordered = false
        instructionLabel.drawsBackground = false
        contentView.addSubview(instructionLabel)
        
        keysLabel.frame = NSRect(x: 20, y: 68, width: 280, height: 32)
        keysLabel.alignment = .center
        keysLabel.font = NSFont.boldSystemFont(ofSize: 18)
        keysLabel.textColor = .systemBlue
        keysLabel.isEditable = false
        keysLabel.isBordered = false
        keysLabel.drawsBackground = false
        contentView.addSubview(keysLabel)
        
        rawDetailsLabel.frame = NSRect(x: 20, y: 46, width: 280, height: 18)
        rawDetailsLabel.alignment = .center
        rawDetailsLabel.font = NSFont.systemFont(ofSize: 10)
        rawDetailsLabel.textColor = .secondaryLabelColor
        rawDetailsLabel.isEditable = false
        rawDetailsLabel.isBordered = false
        rawDetailsLabel.drawsBackground = false
        contentView.addSubview(rawDetailsLabel)
        
        cancelButton.frame = NSRect(x: 60, y: 12, width: 90, height: 32)
        cancelButton.target = self
        cancelButton.action = #selector(cancelPressed)
        contentView.addSubview(cancelButton)
        
        saveButton.frame = NSRect(x: 170, y: 12, width: 90, height: 32)
        saveButton.target = self
        saveButton.action = #selector(savePressed)
        saveButton.isEnabled = false
        contentView.addSubview(saveButton)
    }
    
    private func startMonitoring() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }
            
            // If it's Escape, cancel recording
            if event.type == .keyDown && event.keyCode == 53 { // Escape
                self.cancelPressed()
                return nil
            }
            
            let flags = event.modifierFlags
            
            if event.type == .flagsChanged {
                let hasControl = flags.contains(.control)
                let hasOption = flags.contains(.option)
                let hasShift = flags.contains(.shift)
                let hasCommand = flags.contains(.command)
                let hasFunction = flags.contains(.function)
                
                self.rawDetailsLabel.stringValue = "FlagsChanged - KeyCode: \(event.keyCode), RawFlags: 0x\(String(flags.rawValue, radix: 16))"
                
                if hasControl || hasOption || hasShift || hasCommand || hasFunction {
                    self.recordedKeyCode = event.keyCode
                    self.recordedFlags = flags.toCGEventFlags()
                    
                    let modifierString = self.formatModifiers(flags)
                    self.keysLabel.stringValue = modifierString
                    self.saveButton.isEnabled = true
                }
                return nil
            }
            
            self.recordedKeyCode = event.keyCode
            self.recordedFlags = flags.toCGEventFlags()
            
            let modifierString = self.formatModifiers(flags)
            let keyString = ActionHandler.formatKeyCode(event.keyCode)
            
            self.keysLabel.stringValue = modifierString + keyString
            self.rawDetailsLabel.stringValue = "KeyDown - KeyCode: \(event.keyCode), RawFlags: 0x\(String(flags.rawValue, radix: 16))"
            self.saveButton.isEnabled = true
            
            // Consume event so it doesn't trigger anything in the app
            return nil
        }
    }
    
    @objc private func savePressed() {
        if let keyCode = recordedKeyCode, let flags = recordedFlags {
            onSave?(keyCode, flags)
        }
        closeWindow()
    }
    
    @objc private func cancelPressed() {
        closeWindow()
    }
    
    private func closeWindow() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        self.close()
    }
    
    private func formatModifiers(_ flags: NSEvent.ModifierFlags) -> String {
        var str = ""
        if flags.contains(.function) { str += "Fn " }
        if flags.contains(.control) { str += "⌃" }
        if flags.contains(.option) { str += "⌥" }
        if flags.contains(.shift) { str += "⇧" }
        if flags.contains(.command) { str += "⌘" }
        return str
    }
}

extension NSEvent.ModifierFlags {
    func toCGEventFlags() -> CGEventFlags {
        var cgFlags = CGEventFlags()
        if self.contains(.control) { cgFlags.insert(.maskControl) }
        if self.contains(.option) { cgFlags.insert(.maskAlternate) }
        if self.contains(.shift) { cgFlags.insert(.maskShift) }
        if self.contains(.command) { cgFlags.insert(.maskCommand) }
        if self.contains(.function) { cgFlags.insert(.maskSecondaryFn) }
        return cgFlags
    }
}
