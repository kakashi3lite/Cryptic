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
import os.log

actor ContextSaver {
    static let shared = ContextSaver()
    
    private let logger = Logger(subsystem: "com.cryptic.context", category: "saving")
    private var pendingTask: Task<Void, Never>?
    private var saveMetrics = SaveMetrics()
    
    // Memory management tracking
    private var activeSaves: Set<ObjectIdentifier> = []
    private let maxConcurrentSaves = 5
    
    func scheduleSave(_ context: ModelContext, delay: Duration = .seconds(1)) {
        let contextID = ObjectIdentifier(context)
        
        // Prevent excessive concurrent saves
        guard activeSaves.count < maxConcurrentSaves else {
            logger.warning("Too many concurrent saves (\(activeSaves.count)), deferring")
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                await scheduleSave(context, delay: delay)
            }
            return
        }
        
        // Cancel previous pending save for this context
        pendingTask?.cancel()
        
        pendingTask = Task { [weakContext = WeakModelContext(context)] in
            await trackSave(contextID: contextID) {
                try? await Task.sleep(for: delay)
                await saveNow(weakContext.context)
            }
        }
    }
    
    func saveNow(_ context: ModelContext?) {
        guard let context else { return }
        
        let contextID = ObjectIdentifier(context)
        
        Task {
            await trackSave(contextID: contextID) {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                await MainActor.run {
                    do {
                        try context.save()
                        let saveTime = CFAbsoluteTimeGetCurrent() - startTime
                        Task {
                            await self.updateSaveMetrics(saveTime: saveTime, success: true)
                        }
                        #if DEBUG
                        self.logger.debug("Context saved successfully in \(saveTime, format: .fixed(precision: 3))s")
                        #endif
                    } catch {
                        let saveTime = CFAbsoluteTimeGetCurrent() - startTime
                        Task {
                            await self.updateSaveMetrics(saveTime: saveTime, success: false)
                        }
                        self.logger.error("Save error: \(error.localizedDescription)")
                        
                        // Attempt retry for transient errors
                        if self.isRetryableError(error) {
                            Task {
                                try? await Task.sleep(for: .seconds(1))
                                await self.saveNow(context)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func trackSave<T>(contextID: ObjectIdentifier, operation: () async -> T) async -> T {
        activeSaves.insert(contextID)
        defer { 
            Task { 
                await removeActiveSave(contextID: contextID) 
            } 
        }
        return await operation()
    }
    
    private func removeActiveSave(contextID: ObjectIdentifier) {
        activeSaves.remove(contextID)
    }
    
    private func updateSaveMetrics(saveTime: TimeInterval, success: Bool) {
        saveMetrics.recordSave(time: saveTime, success: success)
        
        // Log metrics periodically
        if saveMetrics.totalSaves % 10 == 0 {
            logger.info("Save metrics: \(saveMetrics.totalSaves) saves, \(saveMetrics.successRate, format: .percent) success, avg time: \(saveMetrics.averageTime, format: .fixed(precision: 3))s")
        }
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSCocoaErrorDomain:
                return [NSFileWriteFileExistsError, NSFileWriteVolumeReadOnlyError].contains(nsError.code)
            default:
                return false
            }
        }
        return false
    }
    
    // MARK: - Public API
    
    func getSaveMetrics() -> SaveMetrics {
        return saveMetrics
    }
    
    func getActiveSaveCount() -> Int {
        return activeSaves.count
    }
    
    func forceSave(_ context: ModelContext) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try await MainActor.run {
            try context.save()
        }
        
        let saveTime = CFAbsoluteTimeGetCurrent() - startTime
        await updateSaveMetrics(saveTime: saveTime, success: true)
        
        logger.info("Forced save completed in \(saveTime, format: .fixed(precision: 3))s")
    }
}

// MARK: - Save Metrics

struct SaveMetrics {
    private(set) var totalSaves: Int = 0
    private(set) var successfulSaves: Int = 0
    private(set) var totalTime: TimeInterval = 0
    
    var successRate: Double {
        guard totalSaves > 0 else { return 0 }
        return Double(successfulSaves) / Double(totalSaves)
    }
    
    var averageTime: TimeInterval {
        guard totalSaves > 0 else { return 0 }
        return totalTime / Double(totalSaves)
    }
    
    mutating func recordSave(time: TimeInterval, success: Bool) {
        totalSaves += 1
        totalTime += time
        if success {
            successfulSaves += 1
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

