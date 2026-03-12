import SwiftUI
import AppKit

// MARK: - Main App

@main
struct SharedComputingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

// MARK: - Content View (Root)

struct ContentView: View {
    @StateObject private var trainer = TrainerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar: mode toggle + step indicators
            TopToolbar(trainer: trainer)
            Divider()

            if trainer.viewMode == .fourScreen {
                FourScreenGrid(trainer: trainer)
            } else {
                SequentialWizard(trainer: trainer)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Top Toolbar

struct TopToolbar: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        HStack(spacing: 12) {
            // App icon + title
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Text("SharedComputing")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()

            // Step indicators (sequential mode only)
            if trainer.viewMode == .sequential {
                HStack(spacing: 4) {
                    ForEach(1...4, id: \.self) { step in
                        StepIndicator(
                            step: step,
                            label: stepLabel(step),
                            isActive: trainer.currentScreen == step,
                            isCompleted: trainer.currentScreen > step
                        )
                        .onTapGesture { trainer.currentScreen = step }

                        if step < 4 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Mode toggle
            Picker("View", selection: $trainer.viewMode) {
                Label("Sequential", systemImage: "list.number")
                    .tag(ViewMode.sequential)
                Label("4-Screen", systemImage: "square.grid.2x2")
                    .tag(ViewMode.fourScreen)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func stepLabel(_ step: Int) -> String {
        switch step {
        case 1: return "Setup"
        case 2: return "Model"
        case 3: return "Connect"
        case 4: return "Results"
        default: return ""
        }
    }
}

struct StepIndicator: View {
    let step: Int
    let label: String
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor : (isCompleted ? Color.green : Color.secondary.opacity(0.3)))
                    .frame(width: 22, height: 22)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(step)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isActive ? .white : .secondary)
                }
            }
            Text(label)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Sequential Wizard

struct SequentialWizard: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Screen content
            Group {
                switch trainer.currentScreen {
                case 1: Screen1_DatasetSetupView(trainer: trainer)
                case 2: Screen2_ModelTrainingView(trainer: trainer)
                case 3: Screen3_DeviceConnectionView(trainer: trainer)
                case 4: Screen4_ResultsView(trainer: trainer)
                default: Screen1_DatasetSetupView(trainer: trainer)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation buttons
            HStack {
                if trainer.currentScreen > 1 {
                    Button(action: { trainer.currentScreen -= 1 }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Text("Step \(trainer.currentScreen) of 4")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if trainer.currentScreen < 4 {
                    Button(action: { trainer.currentScreen += 1 }) {
                        HStack(spacing: 4) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - 4-Screen Grid (Debug Mode)

struct FourScreenGrid: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 1) {
                ScreenPanel(title: "1 · Dataset Setup", color: .blue) {
                    Screen1_DatasetSetupView(trainer: trainer)
                }
                ScreenPanel(title: "2 · Model & Training", color: .purple) {
                    Screen2_ModelTrainingView(trainer: trainer)
                }
            }
            HStack(spacing: 1) {
                ScreenPanel(title: "3 · Device Connection", color: .orange) {
                    Screen3_DeviceConnectionView(trainer: trainer)
                }
                ScreenPanel(title: "4 · Results & Logs", color: .green) {
                    Screen4_ResultsView(trainer: trainer)
                }
            }
        }
        .background(Color.gray.opacity(0.3))
    }
}

struct ScreenPanel<Content: View>: View {
    let title: String
    let color: Color
    let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Screen 1: Dataset & Environment Setup

struct Screen1_DatasetSetupView: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                ScreenTitle(icon: "folder.badge.gearshape", title: "Dataset & Environment Setup",
                            subtitle: "Select your dataset and configure Python environment")

                // Dataset
                SectionHeader("Dataset")
                DatasetPicker(trainer: trainer)

                Divider().padding(.vertical, 4)

                // Python path
                SectionHeader("Python")
                PythonPathField(trainer: trainer)

                Divider().padding(.vertical, 4)

                // TEMP: Python version check
                SectionHeader("Python Version Check")
                TempBadge()
                PythonVersionCheck(trainer: trainer)
            }
            .padding(20)
        }
    }
}

// MARK: - Screen 2: Model & Training Configuration

struct Screen2_ModelTrainingView: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                ScreenTitle(icon: "brain", title: "Model & Training",
                            subtitle: "Choose model architecture and set training hyperparameters")

                // TEMP: Model selector
                SectionHeader("Model Architecture")
                TempBadge()
                ModelSelectorPlaceholder(trainer: trainer)

                Divider().padding(.vertical, 4)

                // Training config (existing)
                SectionHeader("Training Hyperparameters")
                StepperField(label: "Rounds", value: $trainer.rounds, range: 1...200)
                StepperField(label: "Local epochs per round", value: $trainer.localEpochs, range: 1...50)
                StepperField(label: "Batch size", value: $trainer.batchSize, range: 1...128)

                Divider().padding(.vertical, 4)

                SectionHeader("Advanced")
                LRField(lr: $trainer.lr)
                StepperField(label: "Round timeout (s)", value: $trainer.timeout, range: 30...600)

                Divider().padding(.vertical, 4)

                // TEMP: Device specs
                SectionHeader("This Device")
                TempBadge()
                DeviceInfoPlaceholder()
            }
            .padding(20)
        }
    }
}

// MARK: - Screen 3: Device Connection & Visualization

struct Screen3_DeviceConnectionView: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                ScreenTitle(icon: "network", title: "Device Connection",
                            subtitle: "Connect workers and manage distributed training")

                // Connection status
                SectionHeader("Master Node")
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.accentColor)
                        Text("Master IP:")
                            .font(.callout)
                        Text(trainer.masterIP ?? "Not running")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundColor(trainer.masterIP != nil ? .primary : .secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))

                    HStack {
                        Image(systemName: "desktopcomputer")
                            .foregroundColor(.orange)
                        Text("Workers connected:")
                            .font(.callout)
                        Text("\(trainer.workerCount)")
                            .font(.system(.callout, design: .monospaced))
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                }

                Divider().padding(.vertical, 4)

                // Start / Stop / Begin
                SectionHeader("Training Control")
                VStack(spacing: 10) {
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

                    if trainer.isRunning && trainer.workerCount > 0 {
                        Button(action: { trainer.sendEnter() }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Begin Training (all workers connected)")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }

                    if let status = trainer.statusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Divider().padding(.vertical, 4)

                // TEMP: Network topology visualization
                SectionHeader("Network Topology")
                TempBadge()
                TopologyPlaceholder(trainer: trainer)

                Divider().padding(.vertical, 4)

                // TEMP: Per-worker specs
                SectionHeader("Worker Details")
                TempBadge()
                WorkerCardsPlaceholder(workerCount: trainer.workerCount)
            }
            .padding(20)
        }
    }
}

// MARK: - Screen 4: Results & Logs

struct Screen4_ResultsView: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // TEMP: DB Results panel (top half)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ScreenTitle(icon: "chart.bar.xaxis", title: "Results", subtitle: "Training results and logs")
                    Spacer()
                    // TEMP: LAN/WiFi toggle
                    TempBadgeInline()
                    Picker("Connection", selection: $trainer.connectionType) {
                        Text("LAN").tag("LAN")
                        Text("WiFi").tag("WiFi")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }

                // TEMP: DB display panel
                TempBadge()
                DBResultsPlaceholder(trainer: trainer)
            }
            .padding(16)

            Divider()

            // Existing log panel (bottom half)
            LogPanel(trainer: trainer)
        }
    }
}

// MARK: - Existing Subviews (kept as-is)

struct ScreenTitle: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 8)
    }
}

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
            }
        }
    }
}

// MARK: - TEMP Placeholder Components

struct TempBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 9))
            Text("TEMP — Placeholder for future implementation")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.orange.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        )
    }
}

struct TempBadgeInline: View {
    var body: some View {
        Text("TEMP")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.orange)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.15)))
    }
}

// TEMP: Python version check
struct PythonVersionCheck: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        HStack {
            Image(systemName: trainer.pythonVersion != nil ? "checkmark.circle.fill" : "questionmark.circle")
                .foregroundColor(trainer.pythonVersion != nil ? .green : .secondary)
            Text(trainer.pythonVersion ?? "Click 'Check' to verify Python version")
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(trainer.pythonVersion != nil ? .primary : .secondary)
            Spacer()
            Button("Check") {
                trainer.checkPythonVersion()
            }
            .buttonStyle(.bordered)
            .disabled(trainer.pythonPath.isEmpty)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
    }
}

// TEMP: Model selector
struct ModelSelectorPlaceholder: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Architecture", selection: $trainer.selectedModel) {
                Text("ResNet18").tag("resnet18")
                Text("ResNet34 (coming soon)").tag("resnet34")
                Text("VGG16 (coming soon)").tag("vgg16")
                Text("MobileNetV2 (coming soon)").tag("mobilenetv2")
            }
            .pickerStyle(.radioGroup)

            if trainer.selectedModel != "resnet18" {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Only ResNet18 is currently supported. Other models will be enabled in future updates.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.1)))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
    }
}

// TEMP: Device info
struct DeviceInfoPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoRow(icon: "cpu", label: "CPU", value: ProcessInfo.processInfo.processorCount.description + " cores")
            InfoRow(icon: "memorychip", label: "RAM", value: ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory))
            InfoRow(icon: "gpu", label: "GPU", value: "Apple Silicon (MPS)" )
            InfoRow(icon: "desktopcomputer", label: "OS", value: ProcessInfo.processInfo.operatingSystemVersionString)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(label)
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.callout, design: .monospaced))
        }
    }
}

// TEMP: Topology visualization
struct TopologyPlaceholder: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Master node
            NodeBubble(label: "Master", subtitle: trainer.masterIP ?? "—", color: .blue, icon: "server.rack")

            if trainer.workerCount > 0 {
                // Connection lines
                HStack(spacing: 0) {
                    ForEach(0..<trainer.workerCount, id: \.self) { _ in
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: 2, height: 30)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Worker nodes
                HStack(spacing: 12) {
                    ForEach(0..<trainer.workerCount, id: \.self) { i in
                        NodeBubble(label: "Worker \(i + 1)", subtitle: "Connected", color: .orange, icon: "desktopcomputer")
                    }
                }
            } else {
                Text("No workers connected yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
    }
}

struct NodeBubble: View {
    let label: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 1))
        )
    }
}

// TEMP: Worker detail cards
struct WorkerCardsPlaceholder: View {
    let workerCount: Int

    var body: some View {
        if workerCount == 0 {
            Text("Worker details will appear when workers connect.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        } else {
            VStack(spacing: 8) {
                ForEach(0..<workerCount, id: \.self) { i in
                    HStack {
                        Image(systemName: "desktopcomputer")
                            .foregroundColor(.orange)
                        Text("Worker \(i + 1)")
                            .fontWeight(.medium)
                        Spacer()
                        Text("CPU: — | RAM: — | GPU: —")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                }
            }
        }
    }
}

// TEMP: DB results display
struct DBResultsPlaceholder: View {
    @ObservedObject var trainer: TrainerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Table header
            HStack {
                Text("Device").frame(width: 80, alignment: .leading)
                Text("Time").frame(width: 60, alignment: .leading)
                Text("Status").frame(width: 60, alignment: .center)
                Text("Model").frame(width: 80, alignment: .leading)
                Text("Dataset").frame(width: 60, alignment: .trailing)
                Text("Connection").frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Placeholder rows
            if trainer.isRunning || !trainer.log.isEmpty {
                DBPlaceholderRow(device: "Master", time: "—", status: trainer.isRunning ? "Running" : "Done",
                                 model: "ResNet18", dataset: "—", connection: trainer.connectionType)
                Divider()
                ForEach(0..<max(trainer.workerCount, 1), id: \.self) { i in
                    DBPlaceholderRow(device: "Worker \(i+1)", time: "—", status: "—",
                                     model: "ResNet18", dataset: "—", connection: trainer.connectionType)
                    if i < max(trainer.workerCount, 1) - 1 { Divider() }
                }
            } else {
                Text("No training data yet. Start a training session to see results.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}

struct DBPlaceholderRow: View {
    let device: String
    let time: String
    let status: String
    let model: String
    let dataset: String
    let connection: String

    var body: some View {
        HStack {
            Text(device).frame(width: 80, alignment: .leading)
            Text(time).frame(width: 60, alignment: .leading)
            Text(status)
                .foregroundColor(status == "Running" ? .green : (status == "Done" ? .blue : .secondary))
                .frame(width: 60, alignment: .center)
            Text(model).frame(width: 80, alignment: .leading)
            Text(dataset).frame(width: 60, alignment: .trailing)
            Text(connection).frame(width: 80, alignment: .trailing)
        }
        .font(.system(size: 10, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - View Mode Enum

enum ViewMode: String, CaseIterable {
    case sequential
    case fourScreen
}

// MARK: - ViewModel

class TrainerViewModel: ObservableObject {
    @Published var currentScreen: Int   = 1
    @Published var viewMode: ViewMode   = .sequential

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

    // New state for TEMP components
    @Published var pythonVersion: String?  = nil
    @Published var selectedModel: String   = "resnet18"
    @Published var connectionType: String  = "LAN"

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

    // TEMP: Check python version
    func checkPythonVersion() {
        guard !pythonPath.isEmpty else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = ["--version"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                DispatchQueue.main.async {
                    self.pythonVersion = output
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.pythonVersion = "Error: \(error.localizedDescription)"
            }
        }
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
