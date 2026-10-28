import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

/// NSPanel sem ativar o app, para o ⌘V ir para o app que estava em foco.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private var hotKeyHandler: (() -> Void)?

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = HistoryStore()
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var timer: Timer?
    private var hotKeyRef: EventHotKeyRef?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpPanel()
        setUpHotKey()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [store] _ in store.poll() }
        enableLaunchAtLoginOnFirstRun()
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clip")
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusClicked)
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Ajustes…", action: #selector(openSettings), keyEquivalent: ",").target = self
            menu.addItem(withTitle: "Limpar histórico (mantém fixados)", action: #selector(clearHistory), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePanel()
        }
    }

    @objc private func clearHistory() { store.clearUnpinned() }

    private func setUpPanel() {
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
    }

    private func setUpHotKey() {
        hotKeyHandler = { [weak self] in self?.togglePanel() }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            hotKeyHandler?()
            return noErr
        }, 1, &spec, nil, nil)
        if !registerHotKey(HotKey.load()) { _ = registerHotKey(.standard) }
    }

    @discardableResult
    private func registerHotKey(_ hotKey: HotKey) -> Bool {
        let previous = hotKeyRef
        var newRef: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x434C4950), id: 1)
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, id, GetApplicationEventTarget(), 0, &newRef)
        guard status == noErr else { return false }
        if let previous { UnregisterEventHotKey(previous) }
        hotKeyRef = newRef
        return true
    }

    private func updateHotKey(_ hotKey: HotKey) -> Bool {
        guard registerHotKey(hotKey) else { return false }
        hotKey.save()
        return true
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(onHotKeyChange: { [weak self] in self?.updateHotKey($0) ?? false })))
            window.title = "Ajustes do Clip"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func enableLaunchAtLoginOnFirstRun() {
        let key = "launchAtLoginConfigured"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? SMAppService.mainApp.register()
    }

    private func togglePanel() {
        panel.isVisible ? closePanel() : showPanel()
    }

    private func showPanel() {
        store.poll()
        panel.contentView = NSHostingView(rootView: PanelView(store: store, onPick: { [weak self] in self?.pick($0) }, onClose: { [weak self] in self?.closePanel() }))
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main!
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: frame.midX - 220, y: frame.midY - 260))
        panel.makeKeyAndOrderFront(nil)
    }

    private func closePanel() { panel.orderOut(nil) }

    func windowDidResignKey(_ notification: Notification) { closePanel() }

    private func pick(_ item: Item) {
        store.copyToPasteboard(item)
        closePanel()
        guard AXIsProcessTrusted() else {
            // Sem Acessibilidade só dá para copiar; reabre o pedido de permissão do sistema.
            _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let src = CGEventSource(stateID: .combinedSessionState)
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: down)
                e?.flags = .maskCommand
                e?.post(tap: .cghidEventTap)
            }
        }
    }
}
