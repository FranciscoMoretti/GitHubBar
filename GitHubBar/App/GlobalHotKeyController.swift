import AppKit
import Carbon.HIToolbox
import OSLog

struct GitHubBarShortcut {
    enum Key {
        case g

        var carbonKeyCode: UInt32 {
            switch self {
            case .g: UInt32(kVK_ANSI_G)
            }
        }

        var keyEquivalent: String {
            switch self {
            case .g: "g"
            }
        }
    }

    let key: Key
    let modifiers: NSEvent.ModifierFlags

    static let openMenu = GitHubBarShortcut(
        key: .g,
        modifiers: [.command, .option]
    )

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if modifiers.contains(.option) { value |= UInt32(optionKey) }
        if modifiers.contains(.control) { value |= UInt32(controlKey) }
        if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    var displayString: String {
        modifiers.shortcutDisplayString(for: key.keyEquivalent)
    }
}

extension NSEvent.ModifierFlags {
    func shortcutDisplayString(for keyEquivalent: String) -> String {
        var value = ""
        if contains(.control) { value += "⌃" }
        if contains(.option) { value += "⌥" }
        if contains(.shift) { value += "⇧" }
        if contains(.command) { value += "⌘" }
        return value + keyEquivalent.uppercased()
    }
}

@MainActor
final class GlobalHotKeyController {
    enum RegistrationError: Error {
        case eventHandler(OSStatus)
        case hotKey(OSStatus)
    }

    nonisolated(unsafe) private var eventHandler: EventHandlerRef?
    nonisolated(unsafe) private var hotKey: EventHotKeyRef?
    private let action: () -> Void

    init(shortcut: GitHubBarShortcut, action: @escaping () -> Void) throws {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            globalHotKeyEventHandler,
            1,
            &eventType,
            userData,
            &eventHandler
        )
        guard handlerStatus == noErr else {
            throw RegistrationError.eventHandler(handlerStatus)
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let hotKeyStatus = RegisterEventHotKey(
            shortcut.key.carbonKeyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard hotKeyStatus == noErr else {
            if let eventHandler { RemoveEventHandler(eventHandler) }
            eventHandler = nil
            throw RegistrationError.hotKey(hotKeyStatus)
        }
        if ProcessInfo.processInfo.environment["GITHUBBAR_SHORTCUT_DEBUG"] == "1" {
            print("GitHubBar shortcut registered")
        }
        Self.logger.info("Registered global menu shortcut")
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    fileprivate func performAction() {
        if ProcessInfo.processInfo.environment["GITHUBBAR_SHORTCUT_DEBUG"] == "1" {
            print("GitHubBar shortcut received")
        }
        Self.logger.debug("Received global menu shortcut")
        action()
    }

    private static let signature: OSType = 0x47484252 // GHBR
    private static let logger = Logger(
        subsystem: "com.franciscomoretti.githubbar",
        category: "shortcut"
    )
}

private let globalHotKeyEventHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let controller = Unmanaged<GlobalHotKeyController>
        .fromOpaque(userData)
        .takeUnretainedValue()
    Task { @MainActor in
        controller.performAction()
    }
    return noErr
}
