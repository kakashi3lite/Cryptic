    //
//  ContentView.swift
//  Cryptic
//
//  Created by Swanand Tanavade on 8/26/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Query(sort: \Draft.updatedAt, order: .reverse) private var drafts: [Draft]

    var body: some View {
        NavigationSplitView {
            List {
                if !drafts.isEmpty {
                    Section("Drafts") {
                        ForEach(drafts) { draft in
                            NavigationLink {
                                DraftEditorView(draft: draft)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(draft.text.isEmpty ? "(Empty)" : draft.text)
                                        .lineLimit(1)
                                    HStack(spacing: 8) {
                                        Label(label(for: draft.mode), systemImage: icon(for: draft.mode))
                                            .labelStyle(.iconOnly)
                                        Text(draft.updatedAt, format: Date.FormatStyle(date: .numeric, time: .shortened))
                                            .foregroundStyle(.secondary)
                                            .font(.footnote)
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            withAnimation {
                                for index in offsets { modelContext.delete(drafts[index]) }
                                ContextSaver.shared.scheduleSave(modelContext)
                            }
                        }
                    }
                }
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Menu {
                        Button(action: addDraft) { Label("New Draft", systemImage: "square.and.pencil") }
                        Button(action: addItem) { Label("Add Item (demo)", systemImage: "plus") }
                    } label: { Label("Add", systemImage: "plus") }
                }
            }
        } detail: {
            NavigationStack {
                Text("Select a draft or item")
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
            ContextSaver.shared.scheduleSave(modelContext)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
            ContextSaver.shared.scheduleSave(modelContext)
        }
    }

    private func addDraft() {
        withAnimation {
            let draft = Draft()
            modelContext.insert(draft)
            ContextSaver.shared.scheduleSave(modelContext)
        }
    }

    private func label(for mode: Draft.Mode) -> String {
        switch mode {
        case .emoji: return "Emoji"
        case .qr: return "QR"
        case .imageStego: return "Image"
        case .audioChirp: return "Audio"
        }
    }

    private func icon(for mode: Draft.Mode) -> String {
        switch mode {
        case .emoji: return "face.smiling"
        case .qr: return "qrcode"
        case .imageStego: return "photo"
        case .audioChirp: return "waveform"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
