import SwiftUI
import AppKit

// MARK: - Main App

@main
struct SharedComputingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 700, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var trainer = TrainerViewModel()

    var body: some View {
        HSplitView {
            SetupPanel(trainer: trainer)
                .frame(minWidth: 300, maxWidth: 340)
            LogPanel(trainer: trainer)
                .frame(minWidth: 360)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Setup Panel

struct SetupPanel: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(spacing: 10) {
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("SharedComputing")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Dataset
                    SectionHeader("Dataset")
                    DatasetPicker(trainer: trainer)

                    Divider().padding(.vertical, 4)

                    // Training config
                    SectionHeader("Training")
                    StepperField(label: "Rounds", value: $trainer.rounds, range: 1...200)
                    StepperField(label: "Local epochs per round", value: $trainer.localEpochs, range: 1...50)
                    StepperField(label: "Batch size", value: $trainer.batchSize, range: 1...128)

                    Divider().padding(.vertical, 4)

                    // Advanced
                    SectionHeader("Advanced")
                    LRField(lr: $trainer.lr)
                    StepperField(label: "Round timeout (s)", value: $trainer.timeout, range: 30...600)

                    Divider().padding(.vertical, 4)

                    // Python path
                    SectionHeader("Python")
                    PythonPathField(trainer: trainer)

                }
                .padding(20)
            }

            Divider()

            // Start / Stop button
            VStack(spacing: 8) {
                Button(action: trainer.isRunning ? trainer.stop : trainer.start) {
                    HStack {
                        Image(systemName: trainer.isRunning ? "stop.fill" : "play.fill")
                        Text(trainer.isRunning ? "Stop Training" : "Start Training")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(trainer.isRunning ? .red : .accentColor)
                .disabled(trainer.datasetPath.isEmpty && !trainer.isRunning)

                if let status = trainer.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Log Panel

struct LogPanel: View {
    @ObservedObject var trainer: TrainerViewModel
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Training Log")
                    .font(.headline)
                Spacer()
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button(action: { trainer.log = "" }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Log output
            ScrollViewReader { proxy in
                ScrollView {
                    Text(trainer.log.isEmpty ? "Training output will appear here..." : trainer.log)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(trainer.log.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .id("bottom")
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: trainer.log) { _ in
                    if autoScroll {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            }

            // Status bar
            if trainer.isRunning {
                Divider()
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                    Text("Training in progress...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let ip = trainer.masterIP {
                        Text("Master: \(ip):8000")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                if trainer.workerCount > 0 {
                    Divider()
                    HStack {
                        Text("Workers connected: \(trainer.workerCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("▶ Begin Training") {
                            trainer.sendEnter()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .padding(.trailing, 12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - Subviews

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.bottom, 2)
    }
}

struct DatasetPicker: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("./data", text: $trainer.datasetPath)
                    .textFieldStyle(.roundedBorder)
                Button("Browse...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        trainer.datasetPath = url.path
                        trainer.detectClasses()
                    }
                }
                .buttonStyle(.bordered)
            }
            if !trainer.detectedClasses.isEmpty {
                Text("Classes: \(trainer.detectedClasses.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StepperField: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
            Spacer()
            Stepper(value: $value, in: range) {
                Text("\(value)")
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

struct LRField: View {
    @Binding var lr: Double

    var body: some View {
        HStack {
            Text("Learning rate")
                .font(.callout)
            Spacer()
            TextField("", value: $lr, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct PythonPathField: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Python executable
            VStack(alignment: .leading, spacing: 4) {
                Text("Python executable")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    TextField("/usr/local/bin/python3", text: $trainer.pythonPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Auto-detect") {
                        let candidates = [
                            NSHomeDirectory() + "/venv_shared/bin/python3",
                            NSHomeDirectory() + "/Documents/2.Area/SharedComputing/.venv/bin/python3",
                            NSHomeDirectory() + "/.venv/bin/python3",
                        ]
                        if let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                            trainer.pythonPath = found
                        } else {
                            trainer.pythonPath = NSHomeDirectory() + "/venv_shared/bin/python3"
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            // master.py path
            VStack(alignment: .leading, spacing: 4) {
                Text("master.py path")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    TextField("/path/to/master.py", text: $trainer.masterScriptPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Find") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.allowsMultipleSelection = false
                        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
                        if panel.runModal() == .OK, let url = panel.url {
                            trainer.masterScriptPath = url.path
                        }
                    }
                    .buttonStyle(.bordered)
                }
                if !trainer.masterScriptPath.isEmpty {
                    Text(trainer.masterScriptPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }
}

// MARK: - ViewModel

class TrainerViewModel: ObservableObject {
    @Published var datasetPath: String   = ""
    @Published var rounds: Int           = 15
    @Published var localEpochs: Int      = 2
    @Published var batchSize: Int        = 8
    @Published var lr: Double            = 0.001
    @Published var timeout: Int          = 120
    @Published var pythonPath: String    = ""
    @Published var detectedClasses: [String] = []
    @Published var log: String           = ""
    @Published var isRunning: Bool       = false
    @Published var statusMessage: String? = nil
    @Published var masterIP: String?     = nil
    @Published var waitingForWorkers: Bool = false
    @Published var workerCount: Int        = 0

    private var process: Process?
    private var masterFileHandle: FileHandle?
    private var slaveFd: Int32 = -1
    private var ptyMasterFd: Int32 = -1
    @Published var masterScriptPath: String = ""

    init() {
        // Default python path — prefer venv over system python
        let candidates = [
            NSHomeDirectory() + "/venv_shared/bin/python3",
            NSHomeDirectory() + "/Documents/2.Area/SharedComputing/.venv/bin/python3",
            NSHomeDirectory() + "/Documents/2. Area/SharedComputing/.venv/bin/python3",
            NSHomeDirectory() + "/.venv/bin/python3",
        ]
        pythonPath = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? ""

        // Default master.py path — same folder as app or Documents
        let appDir = Bundle.main.bundlePath
        let candidates2 = [
            (appDir as NSString).deletingLastPathComponent + "/master.py",
            NSHomeDirectory() + "/Documents/2.Area/SharedComputing/master.py",
            NSHomeDirectory() + "/Documents/2. Area/SharedComputing/master.py",
            NSHomeDirectory() + "/Documents/SharedComputing/master.py",
        ]
        masterScriptPath = candidates2.first { FileManager.default.fileExists(atPath: $0) } ?? ""
    }

    func detectClasses() {
        guard !datasetPath.isEmpty else { return }
        let url = URL(fileURLWithPath: datasetPath)
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        detectedClasses = contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { $0.lastPathComponent }
            .filter { !$0.hasPrefix(".") }
            .sorted()
    }

    func start() {
        guard !pythonPath.isEmpty else {
            statusMessage = "⚠ Set the Python path first."
            return
        }

        // Find master.py
        if masterScriptPath.isEmpty || !FileManager.default.fileExists(atPath: masterScriptPath) {
            statusMessage = "⚠ Could not find master.py — place it next to the app or update the path."
            return
        }

        let dataset = datasetPath.isEmpty
            ? (masterScriptPath as NSString).deletingLastPathComponent + "/data"
            : datasetPath

        let args: [String] = [
            masterScriptPath,
            "--dataset", dataset,
            "--rounds",  "\(rounds)",
            "--epochs",  "\(localEpochs)",
            "--batch",   "\(batchSize)",
            "--lr",      "\(lr)",
            "--timeout", "\(timeout)",
        ]

        // Clean up any previous run
        cleanup()

        process = Process()
        process?.executableURL = URL(fileURLWithPath: pythonPath)
        process?.arguments = args
        process?.currentDirectoryURL = URL(fileURLWithPath:
            (masterScriptPath as NSString).deletingLastPathComponent)

        // Propagate environment + force unbuffered Python output
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        process?.environment = env

        // Use a PTY so the process gets a real terminal (stdin works)
        let ptyFds = openpty()
        guard ptyFds.master >= 0, ptyFds.slave >= 0 else {
            statusMessage = "✗ Failed to allocate PTY"
            return
        }

        self.ptyMasterFd = ptyFds.master
        self.slaveFd = ptyFds.slave

        let slaveHandle = FileHandle(fileDescriptor: ptyFds.slave, closeOnDealloc: false)
        process?.standardOutput = slaveHandle
        process?.standardError  = slaveHandle
        process?.standardInput  = slaveHandle

        // Retain the FileHandle so readabilityHandler survives start() scope
        masterFileHandle = FileHandle(fileDescriptor: ptyFds.master, closeOnDealloc: false)
        masterFileHandle?.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.log += text
                if let range = text.range(of: #"http://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"#, options: .regularExpression) {
                    let match = String(text[range])
                    self?.masterIP = match.replacingOccurrences(of: "http://", with: "")
                }
                if text.contains("Worker registered"),
                   let range = text.range(of: "total: [0-9]+", options: .regularExpression) {
                    let numStr = String(text[range]).replacingOccurrences(of: "total: ", with: "")
                    self?.workerCount = Int(numStr) ?? 0
                }
            }
        }

        process?.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.cleanup()
                self?.isRunning = false
                self?.statusMessage = "Training finished."
            }
        }

        // Kill anything on port 8000 before starting
        let killer = Process()
        killer.executableURL = URL(fileURLWithPath: "/bin/sh")
        killer.arguments = ["-c", "kill $(lsof -ti:8000) 2>/dev/null; sleep 1"]
        try? killer.run()
        killer.waitUntilExit()

        do {
            try process?.run()
            // Close slave fd in parent — child inherited it via fork
            close(slaveFd)
            slaveFd = -1
            isRunning = true
            statusMessage = "Training started — connect workers then click Begin Training."
            log += "▶ Started: \(pythonPath) \(args.dropFirst().joined(separator: " "))\n\n"
        } catch {
            statusMessage = "✗ Failed to start: \(error.localizedDescription)"
            cleanup()
        }
    }

    func stop() {
        process?.terminate()
        cleanup()
        isRunning = false
        statusMessage = "Training stopped."
        log += "\n⛔ Stopped by user.\n"
    }

    private func cleanup() {
        masterFileHandle?.readabilityHandler = nil
        masterFileHandle = nil
        if slaveFd >= 0 {
            close(slaveFd)
            slaveFd = -1
        }
        if ptyMasterFd >= 0 {
            close(ptyMasterFd)
            ptyMasterFd = -1
        }
        process = nil
        workerCount = 0
        masterIP = nil
    }

    func sendEnter() {
        guard ptyMasterFd >= 0 else { return }
        var newline: UInt8 = 10
        write(ptyMasterFd, &newline, 1)
    }
}

private func openpty() -> (master: Int32, slave: Int32) {
    var master: Int32 = 0
    var slave: Int32 = 0
    var winsize = winsize()
    winsize.ws_col = 220
    winsize.ws_row = 50
    _ = Darwin.openpty(&master, &slave, nil, nil, &winsize)
    return (master, slave)
}
