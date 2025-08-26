//
//  DraftEditorView.swift
//  Cryptic
//
//  Minimal editor to exercise autosave and model updates.
//

import SwiftUI
import SwiftData

struct DraftEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var draft: Draft
    @State private var proposal: LLMAssistantProposal? = nil
    @State private var preview: EncodeResult? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        Form {
            Picker("Mode", selection: $draft.mode) {
                ForEach(Draft.Mode.allCases, id: \.self) { mode in
                    Text(label(for: mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Section("Message") {
                TextEditor(text: $draft.text)
                    .frame(minHeight: 160)
                HStack {
                    Button { requestProposal() } label: { Label("Suggest", systemImage: "wand.and.stars") }
                    Spacer()
                    Button { generatePreview() } label: { Label("Preview", systemImage: "play.circle") }
                }
            }

            Section("Note") {
                TextField("Optional note", text: Binding($draft.note, replacingNilWith: ""))
            }

            Section("Timestamps") {
                LabeledContent("Created", value: draft.createdAt.formatted(date: .numeric, time: .standard))
                LabeledContent("Updated", value: draft.updatedAt.formatted(date: .numeric, time: .standard))
            }
        }
        .navigationTitle("Draft")
        .onChange(of: draft.text) { _, _ in touchAndSave() }
        .onChange(of: draft.mode) { _, _ in touchAndSave() }
        .onChange(of: draft.note) { _, _ in touchAndSave() }
        .safeAreaInset(edge: .bottom) {
            if let preview { DraftPreviewView(result: preview) }
        }
        .alert("Encode Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func touchAndSave() {
        draft.updatedAt = .now
        ContextSaver.shared.scheduleSave(modelContext)
    }

    private func label(for mode: Draft.Mode) -> String {
        switch mode {
        case .emoji: return "Emoji"
        case .qr: return "QR"
        case .imageStego: return "Image"
        case .audioChirp: return "Audio"
        }
    }

    private func requestProposal() {
        let assistant = HeuristicAssistant()
        let p = assistant.propose(for: draft.text)
        proposal = p
        draft.mode = p.mode
        draft.updatedAt = .now
        ContextSaver.shared.scheduleSave(modelContext)
    }

    private func generatePreview() {
        Task.detached(priority: .userInitiated) {
            do {
                let result = try EncodeCoordinator().encode(draft: draft)
                await MainActor.run { self.preview = result }
            } catch {
                await MainActor.run { self.errorMessage = String(describing: error) }
            }
        }
    }
}

private extension Binding where Value == String? {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(get: { source.wrappedValue ?? defaultValue }, set: { newValue in
            source.wrappedValue = newValue.isEmpty ? nil : newValue
        })
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Draft.self, configurations: config)
    let context = ModelContext(container)
    let draft = Draft(text: "Secret", note: "A note")
    context.insert(draft)
    return NavigationStack {
        DraftEditorView(draft: draft)
    }
    .modelContainer(container)
}
