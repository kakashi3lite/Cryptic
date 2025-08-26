//
//  ContextSaving.swift
//  Cryptic
//
//  Best-practice context saving utilities for SwiftUI 6 + SwiftData.
//

import Foundation
import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

actor ContextSaver {
    static let shared = ContextSaver()

    private var pendingTask: Task<Void, Never>?

    func scheduleSave(_ context: ModelContext, delay: Duration = .seconds(1)) {
        pendingTask?.cancel()
        pendingTask = Task { [weakContext = WeakModelContext(context)] in
            try? await Task.sleep(for: delay)
            await saveNow(weakContext.context)
        }
    }

    func saveNow(_ context: ModelContext?) {
        guard let context else { return }
        Task { @MainActor in
            do { try context.save() } catch {
                #if DEBUG
                print("[ContextSaver] Save error: \(error)")
                #endif
            }
        }
    }
}

// Wrapper to avoid capturing ModelContext strongly across actors.
private struct WeakModelContext {
    weak var box: AnyObject?
    init(_ context: ModelContext) { self.box = context as AnyObject }
    var context: ModelContext? { box as? ModelContext }
}

struct SaveOnScenePhase: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase != .active else { return }
                saveWithBackgroundAllowance()
            }
            .task(id: scenePhase) {
                // Also coalesce a save shortly after becoming inactive.
                if scenePhase == .inactive { await debounceAndSave() }
            }
            .onReceive(memoryWarningPublisher) { _ in
                ContextSaver.shared.scheduleSave(modelContext, delay: .seconds(0))
            }
    }

    private func saveWithBackgroundAllowance() {
        #if canImport(UIKit)
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "ContextSave")
        ContextSaver.shared.saveNow(modelContext)
        UIApplication.shared.endBackgroundTask(bgTask)
        #else
        ContextSaver.shared.saveNow(modelContext)
        #endif
    }

    private func debounceAndSave() async {
        ContextSaver.shared.scheduleSave(modelContext, delay: .seconds(0.75))
    }

    private var memoryWarningPublisher: NotificationCenter.Publisher {
        #if canImport(UIKit)
        return NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
        #else
        return NotificationCenter.default.publisher(for: Notification.Name("") )
        #endif
    }
}

extension View {
    func autosaveModelContext() -> some View { modifier(SaveOnScenePhase()) }
}

