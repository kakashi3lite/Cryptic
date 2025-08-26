//
//  MemoryManager.swift
//  Cryptic
//
//  Advanced memory management for Metal operations and large data processing.
//

import Foundation
import Metal
import os.log

@MainActor
class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    
    private let logger = Logger(subsystem: "com.cryptic.memory", category: "management")
    
    // Memory tracking
    @Published private(set) var currentMemoryUsage: Int64 = 0
    @Published private(set) var peakMemoryUsage: Int64 = 0
    @Published private(set) var memoryPressureLevel: MemoryPressureLevel = .normal
    
    // Thresholds (in bytes)
    private let warningThreshold: Int64 = 100 * 1024 * 1024  // 100MB
    private let criticalThreshold: Int64 = 200 * 1024 * 1024 // 200MB
    
    // Memory pools
    private var metalBufferPool: [MTLBuffer] = []
    private var dataBufferPool: [Data] = []
    private let poolCleanupThreshold = 10
    
    private init() {
        startMemoryMonitoring()
        setupMemoryWarningObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateMemoryUsage()
            }
        }
    }
    
    private func updateMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        currentMemoryUsage = usage
        
        if usage > peakMemoryUsage {
            peakMemoryUsage = usage
        }
        
        updateMemoryPressureLevel(usage)
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func updateMemoryPressureLevel(_ usage: Int64) {
        let newLevel: MemoryPressureLevel
        
        if usage > criticalThreshold {
            newLevel = .critical
        } else if usage > warningThreshold {
            newLevel = .warning
        } else {
            newLevel = .normal
        }
        
        if newLevel != memoryPressureLevel {
            memoryPressureLevel = newLevel
            logger.info("Memory pressure level changed to: \(newLevel.rawValue)")\n            \n            if newLevel == .critical {\n                performEmergencyCleanup()\n            } else if newLevel == .warning {\n                performPreventiveCleanup()\n            }\n        }\n    }\n    \n    private func setupMemoryWarningObserver() {\n#if canImport(UIKit)\n        NotificationCenter.default.addObserver(\n            self,\n            selector: #selector(handleMemoryWarning),\n            name: UIApplication.didReceiveMemoryWarningNotification,\n            object: nil\n        )\n#endif\n    }\n    \n    @objc private func handleMemoryWarning() {\n        logger.warning("System memory warning received")\n        performEmergencyCleanup()\n    }\n    \n    // MARK: - Memory Pool Management\n    \n    func borrowMetalBuffer(device: MTLDevice, length: Int) -> MTLBuffer? {\n        // Try to reuse from pool first\n        for (index, buffer) in metalBufferPool.enumerated() {\n            if buffer.length >= length {\n                let reusedBuffer = metalBufferPool.remove(at: index)\n                logger.debug("Reused Metal buffer of size \\(reusedBuffer.length)")\n                return reusedBuffer\n            }\n        }\n        \n        // Create new buffer if pool is empty or no suitable buffer found\n        guard let newBuffer = device.makeBuffer(length: length, options: .storageModeShared) else {\n            logger.error("Failed to create Metal buffer of size \\(length)")\n            return nil\n        }\n        \n        logger.debug("Created new Metal buffer of size \\(length)")\n        return newBuffer\n    }\n    \n    func returnMetalBuffer(_ buffer: MTLBuffer) {\n        guard metalBufferPool.count < poolCleanupThreshold else {\n            logger.debug("Metal buffer pool full, discarding buffer")\n            return\n        }\n        \n        metalBufferPool.append(buffer)\n        logger.debug("Returned Metal buffer to pool")\n    }\n    \n    func borrowDataBuffer(capacity: Int) -> Data {\n        // Try to reuse from pool\n        for (index, data) in dataBufferPool.enumerated() {\n            if data.count >= capacity {\n                let reusedData = dataBufferPool.remove(at: index)\n                logger.debug("Reused data buffer of size \\(reusedData.count)")\n                return Data(reusedData.prefix(capacity))\n            }\n        }\n        \n        // Create new buffer\n        let newData = Data(count: capacity)\n        logger.debug("Created new data buffer of size \\(capacity)")\n        return newData\n    }\n    \n    func returnDataBuffer(_ data: Data) {\n        guard dataBufferPool.count < poolCleanupThreshold else {\n            logger.debug("Data buffer pool full, discarding buffer")\n            return\n        }\n        \n        dataBufferPool.append(data)\n        logger.debug("Returned data buffer to pool")\n    }\n    \n    // MARK: - Memory Cleanup\n    \n    private func performPreventiveCleanup() {\n        logger.info("Performing preventive memory cleanup")\n        \n        // Reduce pool sizes\n        if metalBufferPool.count > 5 {\n            metalBufferPool.removeFirst(metalBufferPool.count - 5)\n        }\n        \n        if dataBufferPool.count > 5 {\n            dataBufferPool.removeFirst(dataBufferPool.count - 5)\n        }\n        \n        // Force garbage collection\n        DispatchQueue.global(qos: .utility).async {\n            autoreleasepool {\n                // Empty autoreleasepool to encourage cleanup\n            }\n        }\n    }\n    \n    private func performEmergencyCleanup() {\n        logger.warning("Performing emergency memory cleanup")\n        \n        // Clear all pools\n        metalBufferPool.removeAll()\n        dataBufferPool.removeAll()\n        \n        // Notify other components to free resources\n        NotificationCenter.default.post(\n            name: .crypticMemoryPressure,\n            object: nil,\n            userInfo: ["level": memoryPressureLevel]\n        )\n        \n        // Force immediate garbage collection\n        for _ in 0..<3 {\n            autoreleasepool {\n                // Multiple autoreleasepool drains\n            }\n        }\n    }\n    \n    // MARK: - Resource Tracking\n    \n    func withManagedResource<T>(\n        _ operation: () throws -> T,\n        cleanup: () -> Void = {}\n    ) rethrows -> T {\n        let initialMemory = getCurrentMemoryUsage()\n        \n        defer {\n            cleanup()\n            \n            // Check for memory leaks\n            let finalMemory = getCurrentMemoryUsage()\n            let memoryDelta = finalMemory - initialMemory\n            \n            if memoryDelta > 10 * 1024 * 1024 { // 10MB threshold\n                logger.warning("Potential memory leak detected: \\(memoryDelta) bytes not released")\n            }\n        }\n        \n        return try operation()\n    }\n    \n    func withManagedAsyncResource<T>(\n        _ operation: () async throws -> T,\n        cleanup: @escaping () async -> Void = {}\n    ) async rethrows -> T {\n        let initialMemory = getCurrentMemoryUsage()\n        \n        defer {\n            Task {\n                await cleanup()\n                \n                // Check for memory leaks\n                let finalMemory = self.getCurrentMemoryUsage()\n                let memoryDelta = finalMemory - initialMemory\n                \n                if memoryDelta > 10 * 1024 * 1024 { // 10MB threshold\n                    self.logger.warning("Potential memory leak detected: \\(memoryDelta) bytes not released")\n                }\n            }\n        }\n        \n        return try await operation()\n    }\n    \n    // MARK: - Public API\n    \n    func getMemoryStats() -> MemoryStats {\n        return MemoryStats(\n            currentUsage: currentMemoryUsage,\n            peakUsage: peakMemoryUsage,\n            pressureLevel: memoryPressureLevel,\n            metalBufferPoolSize: metalBufferPool.count,\n            dataBufferPoolSize: dataBufferPool.count\n        )\n    }\n    \n    func shouldDeferHeavyOperation() -> Bool {\n        return memoryPressureLevel == .critical\n    }\n    \n    func recommendedBatchSize(baseSize: Int) -> Int {\n        switch memoryPressureLevel {\n        case .normal:\n            return baseSize\n        case .warning:\n            return baseSize / 2\n        case .critical:\n            return baseSize / 4\n        }\n    }\n}\n\n// MARK: - Supporting Types\n\nenum MemoryPressureLevel: String, CaseIterable {\n    case normal = "Normal"\n    case warning = "Warning"\n    case critical = "Critical"\n}\n\nstruct MemoryStats {\n    let currentUsage: Int64\n    let peakUsage: Int64\n    let pressureLevel: MemoryPressureLevel\n    let metalBufferPoolSize: Int\n    let dataBufferPoolSize: Int\n    \n    var currentUsageMB: Double {\n        Double(currentUsage) / (1024 * 1024)\n    }\n    \n    var peakUsageMB: Double {\n        Double(peakUsage) / (1024 * 1024)\n    }\n}\n\nextension Notification.Name {\n    static let crypticMemoryPressure = Notification.Name("CrypticMemoryPressure")\n}