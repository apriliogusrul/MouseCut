import AppKit
import CoreGraphics

class MouseButtonRecorderWindow: NSWindow {
    var onSave: ((Int) -> Void)?
    
    private let instructionLabel = NSTextField(labelWithString: "Click the extra mouse button you want to remap.")
    private let statusLabel = NSTextField(labelWithString: "Waiting for click...")
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    
    private var eventMonitor: Any?
    
    init(onSave: @escaping (Int) -> Void) {
        self.onSave = onSave
        
        let styleMask: NSWindow.StyleMask = [.titled, .closable]
        super.init(contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
                   styleMask: styleMask,
                   backing: .buffered,
                   defer: false)
        
        self.title = "Record Mouse Button"
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
        
        statusLabel.frame = NSRect(x: 20, y: 60, width: 280, height: 40)
        statusLabel.alignment = .center
        statusLabel.font = NSFont.boldSystemFont(ofSize: 15)
        statusLabel.textColor = .systemBlue
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.drawsBackground = false
        contentView.addSubview(statusLabel)
        
        cancelButton.frame = NSRect(x: 115, y: 15, width: 90, height: 32)
        cancelButton.target = self
        cancelButton.action = #selector(cancelPressed)
        contentView.addSubview(cancelButton)
    }
    
    private func startMonitoring() {
        // 1. Monitor local left/right clicks to guide the user (but let them click Cancel)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            
            // Check if clicking inside Cancel button
            let clickPoint = self.contentView?.convert(event.locationInWindow, from: nil) ?? .zero
            if self.cancelButton.frame.contains(clickPoint) {
                return event
            }
            
            self.statusLabel.stringValue = "Left/Right click ignored. Click an extra button."
            self.statusLabel.textColor = .systemRed
            return event
        }
        
        // 2. Set up the global event tap click callback to capture other clicks
        // Ensure event tap is running
        if !EventTap.shared.isRunning {
            EventTap.shared.start()
        }
        
        EventTap.shared.clickCallback = { [weak self] buttonNumber in
            self?.onSave?(buttonNumber)
            self?.closeWindow()
        }
    }
    
    @objc private func cancelPressed() {
        closeWindow()
    }
    
    private func closeWindow() {
        // Reset the event tap callback
        EventTap.shared.clickCallback = nil
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        self.close()
    }
}
