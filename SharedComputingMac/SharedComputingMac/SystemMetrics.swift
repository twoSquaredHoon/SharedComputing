import Foundation
import IOKit

// MARK: - Local System Metrics

@Observable
@MainActor
final class SystemMetrics {
    var cpuUsage: Double = 0     // 0–100%
    var ramUsed: Double = 0      // GB
    var ramTotal: Double = 0     // GB
    var gpuUsage: Double = -1    // 0–100%, -1 = unavailable
    var temperature: Double = -1 // °C, -1 = unavailable

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var previousCPUTicks: [processor_cpu_load_info] = []

    init() {
        ramTotal = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    func startPolling() {
        // Prime the initial CPU tick snapshot
        _ = readCPUUsage()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    private func poll() {
        cpuUsage = readCPUUsage()
        let ram = readRAMUsage()
        ramUsed = ram.used
        ramTotal = ram.total
        gpuUsage = readGPUUsage()
        temperature = readTemperature()
    }

    // MARK: - CPU via Mach Kernel

    private func readCPUUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )
        guard result == KERN_SUCCESS, let info = cpuInfo else { return 0 }

        var currentTicks: [processor_cpu_load_info] = []
        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            var tick = processor_cpu_load_info()
            tick.cpu_ticks.0 = UInt32(bitPattern: info[offset + Int(CPU_STATE_USER)])
            tick.cpu_ticks.1 = UInt32(bitPattern: info[offset + Int(CPU_STATE_SYSTEM)])
            tick.cpu_ticks.2 = UInt32(bitPattern: info[offset + Int(CPU_STATE_IDLE)])
            tick.cpu_ticks.3 = UInt32(bitPattern: info[offset + Int(CPU_STATE_NICE)])
            currentTicks.append(tick)
        }

        // Deallocate
        let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        var totalUsage: Double = 0
        if !previousCPUTicks.isEmpty && previousCPUTicks.count == currentTicks.count {
            for i in 0..<currentTicks.count {
                let cur = currentTicks[i]
                let prev = previousCPUTicks[i]
                let userDelta   = Double(cur.cpu_ticks.0 - prev.cpu_ticks.0)
                let systemDelta = Double(cur.cpu_ticks.1 - prev.cpu_ticks.1)
                let idleDelta   = Double(cur.cpu_ticks.2 - prev.cpu_ticks.2)
                let niceDelta   = Double(cur.cpu_ticks.3 - prev.cpu_ticks.3)
                let total = userDelta + systemDelta + idleDelta + niceDelta
                if total > 0 {
                    totalUsage += (userDelta + systemDelta) / total * 100.0
                }
            }
            totalUsage /= Double(currentTicks.count)
        }

        previousCPUTicks = currentTicks
        return totalUsage
    }

    // MARK: - RAM via host_statistics64

    private func readRAMUsage() -> (used: Double, total: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return (0, Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824)
        }
        let pageSize = Double(vm_kernel_page_size)

        // Approximate Activity Monitor's "Memory Used" style number.
        // App memory ~= internal - purgeable, then add wired + compressed.
        let appPages = max(Int64(stats.internal_page_count) - Int64(stats.purgeable_count), 0)
        let usedPages = UInt64(appPages)
            + UInt64(stats.wire_count)
            + UInt64(stats.compressor_page_count)

        let used = Double(usedPages) * pageSize
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        return (used / 1_073_741_824, total / 1_073_741_824)
    }

    // MARK: - GPU via IOKit (Apple Silicon)

    private func readGPUUsage() -> Double {
        let matching = IOServiceMatching("AGXAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return -1
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return -1 }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = propsRef?.takeRetainedValue() as? [String: Any] else {
            return -1
        }

        if let perfStats = props["PerformanceStatistics"] as? [String: Any],
           let utilization = perfStats["Device Utilization %"] as? NSNumber {
            return utilization.doubleValue
        }
        return -1
    }

    // MARK: - Temperature via SMC

    private func readTemperature() -> Double {
        // Attempt to read CPU temperature from AppleSMC
        // Keys: "TC0P" (Intel proximity), "Tp09" (Apple Silicon)
        let matching = IOServiceMatching("AppleSMC")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return -1
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return -1 }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS else {
            return -1
        }
        defer { IOServiceClose(conn) }

        // Try Apple Silicon key first, then Intel
        for key in ["Tp09", "TC0P"] {
            if let temp = readSMCKey(conn: conn, key: key), temp > 0 && temp < 150 {
                return temp
            }
        }
        return -1
    }

    private func readSMCKey(conn: io_connect_t, key: String) -> Double? {
        // SMC communication structures
        struct SMCKeyData {
            struct Vers {
                var major: UInt8 = 0
                var minor: UInt8 = 0
                var build: UInt8 = 0
                var reserved: UInt8 = 0
                var release: UInt16 = 0
            }
            struct PLimitData {
                var version: UInt16 = 0
                var length: UInt16 = 0
                var cpuPLimit: UInt32 = 0
                var gpuPLimit: UInt32 = 0
                var memPLimit: UInt32 = 0
            }
            struct KeyInfo {
                var dataSize: UInt32 = 0
                var dataType: UInt32 = 0
                var dataAttributes: UInt8 = 0
            }

            var key: UInt32 = 0
            var vers: Vers = Vers()
            var pLimitData: PLimitData = PLimitData()
            var keyInfo: KeyInfo = KeyInfo()
            var result: UInt8 = 0
            var status: UInt8 = 0
            var data8: UInt8 = 0
            var data32: UInt32 = 0
            var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
                (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        }

        // Convert key string to UInt32
        let keyChars = Array(key.utf8)
        guard keyChars.count == 4 else { return nil }
        let keyVal = UInt32(keyChars[0]) << 24 | UInt32(keyChars[1]) << 16 |
                     UInt32(keyChars[2]) << 8  | UInt32(keyChars[3])

        // First: get key info
        var inputInfo = SMCKeyData()
        inputInfo.key = keyVal
        inputInfo.data8 = 9 // kSMCGetKeyInfo
        var outputInfo = SMCKeyData()

        let inputSize = MemoryLayout<SMCKeyData>.size
        var outputSize = MemoryLayout<SMCKeyData>.size

        let infoResult = withUnsafeMutablePointer(to: &inputInfo) { inPtr in
            withUnsafeMutablePointer(to: &outputInfo) { outPtr in
                IOConnectCallStructMethod(conn, 2,
                                          inPtr, inputSize,
                                          outPtr, &outputSize)
            }
        }
        guard infoResult == KERN_SUCCESS else { return nil }

        // Second: read the key value
        var inputRead = SMCKeyData()
        inputRead.key = keyVal
        inputRead.keyInfo.dataSize = outputInfo.keyInfo.dataSize
        inputRead.data8 = 5 // kSMCReadKey
        var outputRead = SMCKeyData()

        let readResult = withUnsafeMutablePointer(to: &inputRead) { inPtr in
            withUnsafeMutablePointer(to: &outputRead) { outPtr in
                IOConnectCallStructMethod(conn, 2,
                                          inPtr, inputSize,
                                          outPtr, &outputSize)
            }
        }
        guard readResult == KERN_SUCCESS else { return nil }

        // Parse sp78 format (signed 8.8 fixed-point): common for temperature
        let byte0 = outputRead.bytes.0
        let byte1 = outputRead.bytes.1
        let raw = (Int16(byte0) << 8) | Int16(byte1)
        let temp = Double(raw) / 256.0
        return temp
    }
}

// MARK: - Remote Worker Metrics Model

struct WorkerMetrics: Identifiable {
    let id: String   // worker_id
    var cpu: Double
    var ramUsed: Double
    var ramTotal: Double
    var gpu: Double?
    var temp: Double?
    var stale: Bool
}
