import SwiftUI

struct PanelView: View {
    @ObservedObject var store: HistoryStore
    let onPick: (Item) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selected = 0
    @FocusState private var searchFocused: Bool

    private var filtered: [Item] {
        let base = store.items.filter { query.isEmpty || (!$0.isImage && $0.text.localizedCaseInsensitiveContains(query)) }
        return base.filter(\.pinned) + base.filter { !$0.pinned }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Buscar…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .padding(12)
                .focused($searchFocused)
                .onKeyPress(.downArrow) { move(1); return .handled }
                .onKeyPress(.upArrow) { move(-1); return .handled }
                .onKeyPress(.return) { pickSelected(); return .handled }
                .onKeyPress(.escape) { onClose(); return .handled }
                .onChange(of: query) { _, _ in selected = 0 }
            Divider()
            if filtered.isEmpty {
                Text(store.items.isEmpty ? "Nada copiado ainda" : "Sem resultados")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                                row(item, index: index)
                                    .id(item.id)
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: selected) { _, new in
                        if filtered.indices.contains(new) { proxy.scrollTo(filtered[new].id) }
                    }
                }
            }
        }
        .frame(width: 440, height: 520)
        .background(.regularMaterial)
        .onAppear { searchFocused = true }
    }

    private func row(_ item: Item, index: Int) -> some View {
        HStack(spacing: 8) {
            if item.pinned {
                Image(systemName: "pin.fill").font(.caption).foregroundStyle(.orange)
            }
            if item.isImage {
                if let image = store.thumbnail(for: item) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 80, alignment: .leading)
                } else {
                    Label("Imagem indisponível", systemImage: "photo")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(item.text)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if index < 9 {
                Text("⌘\(index + 1)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(index == selected ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { onPick(item) }
        .contextMenu {
            Button(item.pinned ? "Desafixar" : "Fixar") { store.togglePin(item) }
            Button("Excluir", role: .destructive) { store.delete(item) }
        }
        .background(
            Button("") { if index < 9, filtered.indices.contains(index) { onPick(filtered[index]) } }
                .keyboardShortcut(KeyEquivalent(Character("\(min(index + 1, 9))")), modifiers: .command)
                .opacity(0)
                .disabled(index >= 9)
        )
    }

    private func move(_ delta: Int) {
        guard !filtered.isEmpty else { return }
        selected = max(0, min(filtered.count - 1, selected + delta))
    }

    private func pickSelected() {
        if filtered.indices.contains(selected) { onPick(filtered[selected]) }
    }
}
