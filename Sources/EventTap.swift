import CoreGraphics
import AppKit

class EventTap {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var clickCallback: ((Int) -> Void)?
    
    static let shared = EventTap()
    
    private init() {}
    
    func start() {
        stop()
        
        // Listen to mouse button presses (otherMouseDown/Up)
        let eventMask = (1 << CGEventType.otherMouseDown.rawValue) | 
                        (1 << CGEventType.otherMouseUp.rawValue)
        
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            if type == .tapDisabledByTimeout || type.rawValue == 4294967295 {
                if let refcon = refcon {
                    let this = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
                    this.reEnable()
                }
                return Unmanaged.passUnretained(event)
            }
            
            if let refcon = refcon {
                let this = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
                if let handledEvent = this.handleEvent(type: type, event: event) {
                    return Unmanaged.passUnretained(handledEvent)
                } else {
                    return nil // Blocks event propagation
                }
            }
            return Unmanaged.passUnretained(event)
        }
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: selfPointer
        )
        
        guard let eventTap = eventTap else {
            print("Failed to create Event Tap. Accessibility permissions likely missing.")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            print("Event Tap successfully started.")
        }
    }
    
    func stop() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)
            self.runLoopSource = nil
        }
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
    }
    
    func reEnable() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            print("Event Tap re-enabled after system timeout.")
        } else {
            start()
        }
    }
    
    var isRunning: Bool {
        return eventTap != nil
    }
    
    private func handleEvent(type: CGEventType, event: CGEvent) -> CGEvent? {
        let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        
        if let callback = clickCallback {
            if type == .otherMouseDown {
                DispatchQueue.main.async {
                    callback(buttonNumber)
                }
            }
            return nil // Consume event during recording
        }
        
        let mappedButtons = UserDefaults.standard.array(forKey: "mappedButtons") as? [Int] ?? [3, 4]
        
        if mappedButtons.contains(buttonNumber) {
            let actionKey = "buttonAction_\(buttonNumber)"
            let actionString = UserDefaults.standard.string(forKey: actionKey) ?? "None"
            
            if actionString == "None" {
                return event
            }
            
            if type == .otherMouseDown {
                print("Mouse Button \(buttonNumber + 1) MouseDown intercepted! Remapped to: \(actionString)")
                ActionHandler.shared.triggerAction(actionString: actionString, buttonKey: actionKey)
            }
            
            // Return nil to consume and block event
            return nil
        }
        
        return event
    }
}
