import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

struct HotKey: Codable, Equatable {
    var keyCode: UInt32
    /// Modificadores no formato Carbon (cmdKey, shiftKey, optionKey, controlKey).
    var modifiers: UInt32
    var keyLabel: String

    static let standard = HotKey(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | shiftKey), keyLabel: "C")
    private static let defaultsKey = "hotkey"

    static func load() -> HotKey {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode(HotKey.self, from: data) else { return .standard }
        return saved
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + keyLabel
    }

    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    /// nil quando o evento não tem nenhum modificador (atalho global precisa de pelo menos um).
    init?(event: NSEvent) {
        var mods: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        guard mods != 0 else { return nil }
        let chars = event.charactersIgnoringModifiers ?? ""
        let label: String
        switch Int(event.keyCode) {
        case kVK_Space: label = "Espaço"
        case kVK_Return: label = "↩"
        case kVK_Tab: label = "⇥"
        case kVK_Delete: label = "⌫"
        default:
            let printable = chars.unicodeScalars.allSatisfy { $0.value >= 0x21 && $0.value < 0xF700 }
            label = printable && !chars.isEmpty ? chars.uppercased() : "Tecla \(event.keyCode)"
        }
        self.init(keyCode: UInt32(event.keyCode), modifiers: mods, keyLabel: label)
    }
}

struct SettingsView: View {
    /// Tenta registrar o novo atalho; retorna false se o sistema recusar (ex.: já em uso).
    let onHotKeyChange: (HotKey) -> Bool

    @State private var hotKey = HotKey.load()
    @State private var recording = false
    @State private var monitor: Any?
    @State private var error: String?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var needsApproval = SMAppService.mainApp.status == .requiresApproval

    var body: some View {
        Form {
            LabeledContent("Abrir histórico") {
                HStack {
                    Button(recording ? "Aperte o novo atalho…" : hotKey.display) { recording ? stopRecording() : startRecording() }
                        .frame(minWidth: 150)
                    Button("Restaurar") { apply(.standard) }
                        .disabled(hotKey == .standard)
                }
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            } else if recording {
                Text("Use pelo menos um modificador (⌘ ⌥ ⌃ ⇧). Esc cancela.").font(.caption).foregroundStyle(.secondary)
            }
            Toggle("Iniciar com o Mac", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            if needsApproval {
                Text("Aprove o Clip em Ajustes do Sistema → Geral → Itens de Login.")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        error = nil
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
            } else if let new = HotKey(event: event) {
                apply(new)
                stopRecording()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func apply(_ new: HotKey) {
        if onHotKeyChange(new) {
            hotKey = new
            error = nil
        } else {
            error = "\(new.display) não pôde ser registrado (provavelmente já está em uso)."
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            self.error = "Não foi possível alterar o início automático: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status != .notRegistered
        needsApproval = SMAppService.mainApp.status == .requiresApproval
    }
}
