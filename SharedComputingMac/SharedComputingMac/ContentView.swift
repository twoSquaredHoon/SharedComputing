import SwiftUI
import AppKit
import Darwin

// ╔═══════════════════════════════════════════════════════════════════╗
// ║  SharedComputing — Omakase UI                                    ║
// ║                                                                   ║
// ║  Design System:                                                   ║
// ║    Palette  : Cyan (#00D4FF) · Purple (#A855F7) · Amber (#F59E0B) ║
// ║    Neutrals : White @ 90/60/40/20/10/5% opacity                   ║
// ║    Spacing  : 4 · 8 · 12 · 16 · 24 · 32                         ║
// ║    Radii    : 8 (small) · 12 (medium) · 16 (card) · 20 (panel)   ║
// ║    Type     : SF Pro — 11/13/15/17/22                             ║
// ╚═══════════════════════════════════════════════════════════════════╝

// MARK: - Design Tokens

private enum DS {
    // Ant Design Core (Dark Theme)
    static let cyan   = Color(red: 0.086, green: 0.467, blue: 1.0)
    static let purple = Color(red: 0.447, green: 0.180, blue: 0.820)
    static let amber  = Color(red: 0.980, green: 0.678, blue: 0.078)

    // Semantic
    static let success = Color(red: 0.322, green: 0.769, blue: 0.102)
    static let danger  = Color(red: 1.0, green: 0.302, blue: 0.310)

    // Backgrounds (Ant Design Dark)
    static let bg1 = Color(red: 0.08, green: 0.08, blue: 0.08) // #141414
    static let bg2 = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let bg3 = Color(red: 0.08, green: 0.08, blue: 0.08)

    // Spacing scale
    static let sp4:  CGFloat = 4
    static let sp8:  CGFloat = 8
    static let sp12: CGFloat = 12
    static let sp16: CGFloat = 16
    static let sp24: CGFloat = 24
    static let sp32: CGFloat = 32

    // Corner radii (Ant Design Default)
    static let r8:  CGFloat = 6
    static let r12: CGFloat = 8
    static let r16: CGFloat = 8
    static let r20: CGFloat = 8
}

// MARK: - Main App

@main
struct SharedComputingApp: App {
    @State private var trainer = TrainerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(trainer: trainer)
                .frame(minWidth: 960, minHeight: 720)
                .background(WindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit SharedComputing") {
                    trainer.shutdown()
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Reusable Style Components

struct GlassCard: ViewModifier {
    var radius: CGFloat = DS.r12
    var inset: CGFloat = DS.sp16

    func body(content: Content) -> some View {
        content
            .padding(inset)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12)) // #1f1f1f Container
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color(red: 0.26, green: 0.26, blue: 0.26), lineWidth: 1) // #424242 Border
            )
    }
}

extension View {
    func glassCard(radius: CGFloat = DS.r16, inset: CGFloat = DS.sp16) -> some View {
        modifier(GlassCard(radius: radius, inset: inset))
    }
}

// Uniform text field
struct GlassTextField: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, DS.sp12)
            .padding(.vertical, DS.sp8)
            .background(Color(red: 0.08, green: 0.08, blue: 0.08)) // #141414
            .clipShape(RoundedRectangle(cornerRadius: DS.r8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.r8, style: .continuous)
                    .stroke(Color(red: 0.26, green: 0.26, blue: 0.26), lineWidth: 1) // #424242 border
            )
            .font(.system(size: 13))
    }
}

// Two button tiers: Primary (filled) and Secondary (ghost)
struct PrimaryButton: ButtonStyle {
    var color: Color = DS.cyan
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .padding(.vertical, DS.sp8)
            .padding(.horizontal, DS.sp16)
            .background(
                RoundedRectangle(cornerRadius: DS.r8, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .contentShape(Rectangle())
    }
}

struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.6 : 0.88))
            .padding(.vertical, DS.sp8)
            .padding(.horizontal, DS.sp16)
            .background(
                RoundedRectangle(cornerRadius: DS.r8, style: .continuous)
                    .fill(Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.r8, style: .continuous)
                    .stroke(Color(red: 0.26, green: 0.26, blue: 0.26), lineWidth: 1) // #424242
            )
            .contentShape(Rectangle())
    }
}

// Wide CTA
struct WideButton: ButtonStyle {
    var color: Color = DS.cyan
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.sp12)
            .background(
                RoundedRectangle(cornerRadius: DS.r12, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Root

struct ContentView: View {
    @Bindable var trainer: TrainerViewModel

    var body: some View {
        ZStack {
            DS.bg1
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(trainer: trainer)

                if trainer.viewMode == .fourScreen {
                    FourScreenGrid(trainer: trainer)
                } else {
                    SequentialWizard(trainer: trainer)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Top Bar

struct TopBar: View {
    @Bindable var trainer: TrainerViewModel

    var body: some View {
        HStack(spacing: DS.sp12) {
            // Brand
            HStack(spacing: DS.sp8) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.cyan)
                    .frame(width: 28, height: 28)
                    .background(DS.cyan.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("SharedComputing")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 72) // traffic-light offset

            Spacer()

            // Step rail — always show all labels with fixed widths
            if trainer.viewMode == .sequential {
                HStack(spacing: 0) {
                    ForEach(Array(stepData.enumerated()), id: \.offset) { idx, step in
                        StepPill(number: idx + 1, label: step,
                                 isActive: trainer.currentScreen == idx + 1,
                                 isDone: trainer.currentScreen > idx + 1)
                            .onTapGesture { trainer.currentScreen = idx + 1 }

                        if idx < 3 {
                            Rectangle()
                                .fill(trainer.currentScreen > idx + 1
                                      ? DS.cyan.opacity(0.5)
                                      : Color.white.opacity(0.1))
                                .frame(width: 20, height: 2)
                        }
                    }
                }
                .fixedSize()
                .padding(.vertical, DS.sp4)
                .padding(.horizontal, DS.sp8)
                .background(Color.clear)
            }

            Spacer()

            Picker("", selection: $trainer.viewMode) {
                Image(systemName: "rectangle.split.1x2").tag(ViewMode.sequential)
                Image(systemName: "square.grid.2x2").tag(ViewMode.fourScreen)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
            .padding(.trailing, DS.sp16)
        }
        .padding(.vertical, DS.sp12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08)) // #141414 Ant dark header
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color(red: 0.26, green: 0.26, blue: 0.26)), alignment: .bottom) // #424242 Border
    }

    private var stepData: [String] { ["Setup", "Model", "Connect", "Results"] }
}

struct StepPill: View {
    let number: Int
    let label: String
    let isActive: Bool
    let isDone: Bool

    var body: some View {
        HStack(spacing: DS.sp4) {
            ZStack {
                Circle()
                    .fill(isActive ? DS.cyan : (isDone ? DS.success : Color.white.opacity(0.08)))
                    .frame(width: 22, height: 22)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isActive ? .black : .white.opacity(0.5))
                }
            }
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? .white : (isDone ? .white.opacity(0.7) : .white.opacity(0.4)))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, DS.sp8)
        .padding(.vertical, DS.sp4)
    }
}

// MARK: - Sequential Wizard

struct SequentialWizard: View {
    @Bindable var trainer: TrainerViewModel

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch trainer.currentScreen {
                case 1: Screen1(trainer: trainer)
                case 2: Screen2(trainer: trainer)
                case 3: Screen3(trainer: trainer)
                case 4: Screen4(trainer: trainer)
                default: Screen1(trainer: trainer)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom nav
            HStack {
                if trainer.currentScreen > 1 {
                    Button { trainer.currentScreen -= 1 } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(SecondaryButton())
                }
                Spacer()
                Text("Step \(trainer.currentScreen) of 4")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                if trainer.currentScreen < 4 {
                    Button { trainer.currentScreen += 1 } label: {
                        Label("Next", systemImage: "chevron.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(PrimaryButton())
                }
            }
            .padding(.horizontal, DS.sp24)
            .padding(.vertical, DS.sp12)
            .background(Color(red: 0.08, green: 0.08, blue: 0.08))
            .overlay(Rectangle().frame(height: 1).foregroundStyle(Color(red: 0.26, green: 0.26, blue: 0.26)), alignment: .top)
        }
    }
}

// MARK: - 4-Screen Grid

struct FourScreenGrid: View {
    @Bindable var trainer: TrainerViewModel

    var body: some View {
        GeometryReader { geo in
            let half = (geo.size.height - DS.sp16 * 3) / 2
            VStack(spacing: DS.sp16) {
                HStack(spacing: DS.sp16) {
                    GridPanel(title: "1 · Setup", dot: DS.cyan) { Screen1(trainer: trainer) }
                        .frame(height: half)
                    GridPanel(title: "2 · Model", dot: DS.purple) { Screen2(trainer: trainer) }
                        .frame(height: half)
                }
                HStack(spacing: DS.sp16) {
                    GridPanel(title: "3 · Connect", dot: DS.amber) { Screen3(trainer: trainer) }
                        .frame(height: half)
                    GridPanel(title: "4 · Results", dot: DS.success) { Screen4(trainer: trainer) }
                        .frame(height: half)
                }
            }
            .padding(DS.sp16)
        }
    }
}

struct GridPanel<C: View>: View {
    let title: String
    let dot: Color
    @ViewBuilder let content: C

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.sp8) {
                Circle().fill(dot).frame(width: 6, height: 6)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, DS.sp12)
            .padding(.vertical, DS.sp8)
            .background(Color.black.opacity(0.15))

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.12)) // Container depth
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: DS.r12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.r12, style: .continuous)
                .stroke(Color(red: 0.26, green: 0.26, blue: 0.26), lineWidth: 1)
        )
    }
}

// MARK: - Shared Typography

struct PageHeader: View {
    let icon: String
    let title: String
    let sub: String
    var tint: Color = DS.cyan

    var body: some View {
        HStack(spacing: DS.sp12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DS.r8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text(sub)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

struct Label_: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.4))
            .tracking(1)
            .padding(.bottom, DS.sp8)
    }
}

struct TempTag: View {
    var body: some View {
        Text("TEMP")
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(DS.amber)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DS.amber.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(DS.amber.opacity(0.3), lineWidth: 1))
    }
}

struct PreviewTag: View {
    var body: some View {
        Text("PREVIEW")
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(DS.amber)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DS.amber.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(DS.amber.opacity(0.3), lineWidth: 1))
    }
}

struct TelemetryRow: View {
    let icon: String
    let label: String
    let value: String
    let progress: Double
    let tint: Color

    var body: some View {
        HStack(spacing: DS.sp12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(tint.opacity(0.6))
                .frame(width: 20, alignment: .center)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 40, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(tint.opacity(0.5))
                        .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
                }
            }
            .frame(height: 6)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, DS.sp4)
    }
}

// MARK: ─── Screen 1 : Dataset & Environment ─────────────────────────

struct Screen1: View {
    @Bindable var trainer: TrainerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.sp24) {
                PageHeader(icon: "folder.fill.badge.gearshape",
                           title: "Dataset & Environment",
                           sub: "Select your dataset and configure the Python runtime")

                // Dataset
                VStack(alignment: .leading, spacing: DS.sp8) {
                    Label_("Dataset Path")
                    HStack(spacing: DS.sp8) {
                        TextField("./data", text: $trainer.datasetPath)
                            .textFieldStyle(GlassTextField())
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                trainer.datasetPath = url.path
                                trainer.detectClasses()
                            }
                        }
                        .buttonStyle(SecondaryButton())
                        .accessibilityLabel("Browse for dataset folder")
                    }
                    if !trainer.detectedClasses.isEmpty {
                        HStack(spacing: DS.sp4) {
                            Image(systemName: "tag.fill").font(.system(size: 10)).foregroundStyle(DS.success)
                            Text("\(trainer.detectedClasses.count) classes: \(trainer.detectedClasses.joined(separator: ", "))")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .glassCard()

                // Python
                VStack(alignment: .leading, spacing: DS.sp16) {
                    Label_("Python Environment")

                    VStack(alignment: .leading, spacing: DS.sp4) {
                        Text("Executable").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                        HStack(spacing: DS.sp8) {
                            TextField("/usr/local/bin/python3", text: $trainer.pythonPath)
                                .textFieldStyle(GlassTextField())
                            Button("Auto-detect") {
                                let c = [
                                    NSHomeDirectory() + "/venv_shared/bin/python3",
                                    NSHomeDirectory() + "/Documents/2.Area/SharedComputing/.venv/bin/python3",
                                    NSHomeDirectory() + "/.venv/bin/python3",
                                ]
                                trainer.pythonPath = c.first { FileManager.default.fileExists(atPath: $0) }
                                    ?? NSHomeDirectory() + "/venv_shared/bin/python3"
                            }
                            .buttonStyle(SecondaryButton())
                            .accessibilityLabel("Auto-detect Python path")
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.sp4) {
                        Text("master.py").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                        HStack(spacing: DS.sp8) {
                            TextField("/path/to/master.py", text: $trainer.masterScriptPath)
                                .textFieldStyle(GlassTextField())
                            Button("Find") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = true; panel.canChooseDirectories = false
                                panel.allowsMultipleSelection = false
                                panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
                                if panel.runModal() == .OK, let url = panel.url {
                                    trainer.masterScriptPath = url.path
                                }
                            }
                            .buttonStyle(SecondaryButton())
                            .accessibilityLabel("Find master.py script")
                        }
                        if !trainer.masterScriptPath.isEmpty {
                            Text(trainer.masterScriptPath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(DS.cyan.opacity(0.7))
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
                .glassCard()

                // Python version
                VStack(alignment: .leading, spacing: DS.sp8) {
                    HStack { Label_("Version Check"); Spacer(); TempTag() }
                    HStack(spacing: DS.sp12) {
                        Image(systemName: trainer.pythonVersion != nil ? "checkmark.circle.fill" : "questionmark.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(trainer.pythonVersion != nil ? DS.success : .white.opacity(0.3))
                        Text(trainer.pythonVersion ?? "Not checked yet")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(trainer.pythonVersion != nil ? .white : .white.opacity(0.45))
                        Spacer()
                        Button("Check") { trainer.checkPythonVersion() }
                            .buttonStyle(SecondaryButton())
                            .accessibilityLabel("Check Python version")
                            .disabled(trainer.pythonPath.isEmpty)
                    }
                }
                .glassCard()
            }
            .padding(DS.sp24)
        }
    }
}

// MARK: ─── Screen 2 : Model & Training ──────────────────────────────

struct Screen2: View {
    @Bindable var trainer: TrainerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.sp24) {
                PageHeader(icon: "brain.head.profile",
                           title: "Model & Training",
                           sub: "Architecture selection and hyperparameters",
                           tint: DS.purple)

                // Model selector
                VStack(alignment: .leading, spacing: DS.sp8) {
                    HStack { Label_("Architecture"); Spacer(); TempTag() }
                    Picker("Architecture", selection: $trainer.selectedModel) {
                        Text("ResNet18").tag("resnet18")
                        Text("ResNet34 (soon)").tag("resnet34")
                        Text("VGG16 (soon)").tag("vgg16")
                        Text("MobileNetV2 (soon)").tag("mobilenetv2")
                    }
                    .pickerStyle(.radioGroup)

                    if trainer.selectedModel != "resnet18" {
                        HStack(spacing: DS.sp8) {
                            Image(systemName: "info.circle.fill").foregroundStyle(DS.amber)
                            Text("Only ResNet18 is currently supported.")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(DS.sp8)
                        .background(DS.amber.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: DS.r8, style: .continuous))
                    }
                }
                .glassCard()
                
                // Training mode
                VStack(alignment: .leading, spacing: DS.sp8) {
                    HStack { Label_("Training Mode"); Spacer(); TempTag() }
                    Picker("Mode", selection: $trainer.selectedMode) {
                        Text("Quality").tag("quality")
                        Text("Speed").tag("speed")
                    }
                    .pickerStyle(.radioGroup)

                    HStack(spacing: DS.sp8) {
                        Image(systemName: trainer.selectedMode == "quality" ? "sparkles" : "bolt.fill")
                            .foregroundStyle(trainer.selectedMode == "quality" ? DS.purple : DS.amber)
                        Text(trainer.selectedMode == "quality"
                             ? "Each worker trains on the full dataset. Weights are averaged via FedAvg."
                             : "Dataset is split between workers. Faster training, less overlap.")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(DS.sp8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: DS.r8, style: .continuous))
                }
                .glassCard()

                // Hyperparameters
                VStack(alignment: .leading, spacing: DS.sp12) {
                    Label_("Hyperparameters")
                    ParamRow("Rounds", value: $trainer.rounds, range: 1...200)
                    ParamRow("Local Epochs", value: $trainer.localEpochs, range: 1...50)
                    ParamRow("Batch Size", value: $trainer.batchSize, range: 1...128)

                    HStack {
                        Text("Learning Rate").font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        TextField("", value: $trainer.lr, format: .number)
                            .textFieldStyle(GlassTextField())
                            .frame(width: 80).multilineTextAlignment(.trailing)
                    }

                    ParamRow("Timeout (s)", value: $trainer.timeout, range: 30...600)
                }
                .glassCard()

                // Device
                VStack(alignment: .leading, spacing: DS.sp8) {
                    HStack { Label_("This Device"); Spacer(); TempTag() }
                    SpecRow(icon: "cpu.fill", label: "CPU", val: "\(ProcessInfo.processInfo.processorCount) Cores", tint: DS.cyan)
                    SpecRow(icon: "memorychip.fill", label: "RAM",
                            val: ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory),
                            tint: DS.purple)
                    SpecRow(icon: "bolt.fill", label: "Accelerator", val: "Metal (MPS)", tint: DS.amber)
                }
                .glassCard()
            }
            .padding(DS.sp24)
        }
    }
}

struct ParamRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    init(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) {
        self.label = label; self._value = value; self.range = range
    }

    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
            Spacer()
            Stepper(value: $value, in: range) {
                Text("\(value)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

struct SpecRow: View {
    let icon: String; let label: String; let val: String; let tint: Color
    var body: some View {
        HStack(spacing: DS.sp12) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(label).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(val).font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: ─── Screen 3 : Device Connection ──────────────────────────────

struct Screen3: View {
    @Bindable var trainer: TrainerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.sp24) {
                PageHeader(icon: "network",
                           title: "Device Connection",
                           sub: "Manage nodes and start distributed training",
                           tint: DS.amber)

                // Status cards
                HStack(spacing: DS.sp16) {
                    StatusCard(icon: "server.rack", title: "Master",
                               value: trainer.masterIP ?? "Offline",
                               live: trainer.masterIP != nil, tint: DS.cyan)
                    StatusCard(icon: "desktopcomputer", title: "Workers",
                               value: "\(trainer.workerCount) connected",
                               live: trainer.workerCount > 0, tint: DS.amber)
                }

                // Controls
                VStack(alignment: .leading, spacing: DS.sp12) {
                    Label_("Control Panel")

                    Button(action: trainer.isRunning ? trainer.stop : trainer.start) {
                        HStack(spacing: DS.sp8) {
                            Image(systemName: trainer.isRunning ? "stop.fill" : "play.fill")
                            Text(trainer.isRunning ? "Stop Server" : "Start Server")
                        }
                    }
                    .buttonStyle(WideButton(color: trainer.isRunning ? DS.danger : DS.cyan))
                    .disabled(!trainer.isRunning && trainer.datasetPath.isEmpty && trainer.masterScriptPath.isEmpty)

                    if trainer.isRunning && trainer.workerCount > 0 {
                        Button { trainer.sendEnter() } label: {
                            HStack(spacing: DS.sp8) {
                                Image(systemName: "bolt.fill")
                                Text("Begin Training")
                            }
                        }
                        .buttonStyle(WideButton(color: DS.success))
                    }

                    Button { trainer.killBackend() } label: {
                        HStack(spacing: DS.sp8) {
                            Image(systemName: "power.dotted")
                            Text("Kill Backend")
                        }
                    }
                    .buttonStyle(WideButton(color: DS.danger.opacity(0.7)))
                    if let s = trainer.statusMessage {
                        Text(s)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, DS.sp4)
                    }
                }
                .glassCard()

                // Topology
                VStack(alignment: .leading, spacing: DS.sp8) {
                    HStack { Label_("Network Topology"); Spacer(); TempTag() }
                    TopoView(trainer: trainer)
                }
                .glassCard()

                // Local device telemetry
                VStack(alignment: .leading, spacing: DS.sp8) {
                    Label_("This Device")

                    TelemetryRow(icon: "cpu.fill", label: "CPU",
                                 value: String(format: "%.1f %%", trainer.localMetrics.cpuUsage),
                                 progress: trainer.localMetrics.cpuUsage / 100,
                                 tint: telemetryColor(trainer.localMetrics.cpuUsage))
                    TelemetryRow(icon: "memorychip.fill", label: "RAM",
                                 value: String(format: "%.1f / %.1f GB", trainer.localMetrics.ramUsed, trainer.localMetrics.ramTotal),
                                 progress: trainer.localMetrics.ramTotal > 0 ? trainer.localMetrics.ramUsed / trainer.localMetrics.ramTotal : 0,
                                 tint: telemetryColor(trainer.localMetrics.ramTotal > 0 ? trainer.localMetrics.ramUsed / trainer.localMetrics.ramTotal * 100 : 0))
                    TelemetryRow(icon: "bolt.fill", label: "GPU",
                                 value: trainer.localMetrics.gpuUsage >= 0 ? String(format: "%.1f %%", trainer.localMetrics.gpuUsage) : "N/A",
                                 progress: trainer.localMetrics.gpuUsage >= 0 ? trainer.localMetrics.gpuUsage / 100 : 0,
                                 tint: trainer.localMetrics.gpuUsage >= 0 ? telemetryColor(trainer.localMetrics.gpuUsage) : .gray)
                    TelemetryRow(icon: "thermometer.medium", label: "Temp",
                                 value: trainer.localMetrics.temperature >= 0 ? String(format: "%.0f °C", trainer.localMetrics.temperature) : "N/A",
                                 progress: trainer.localMetrics.temperature >= 0 ? min(trainer.localMetrics.temperature / 110, 1) : 0,
                                 tint: trainer.localMetrics.temperature >= 0 ? telemetryColor(trainer.localMetrics.temperature) : .gray)
                }
                .glassCard()

                // Remote worker telemetry
                VStack(alignment: .leading, spacing: DS.sp8) {
                    Label_("Worker Telemetry")

                    if trainer.remoteWorkerMetrics.isEmpty {
                        Text("No workers connected — metrics unavailable")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, DS.sp8)
                    } else {
                        ForEach(trainer.remoteWorkerMetrics) { worker in
                            WorkerMetricsCard(worker: worker)
                        }
                    }
                }
                .glassCard()
            }
            .padding(DS.sp24)
        }
    }

    private func telemetryColor(_ pct: Double) -> Color {
        if pct < 60 { return DS.success }
        if pct < 80 { return DS.amber }
        return DS.danger
    }
}

struct WorkerMetricsCard: View {
    let worker: WorkerMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: DS.sp8) {
            HStack(spacing: DS.sp8) {
                Image(systemName: "desktopcomputer")
                    .foregroundStyle(worker.stale ? .gray : DS.amber)
                Text(worker.id)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(worker.stale ? 0.4 : 0.9))
                Spacer()
                if worker.stale {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("Stale")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(DS.amber)
                }
            }
            TelemetryRow(icon: "cpu.fill", label: "CPU",
                         value: String(format: "%.1f %%", worker.cpu),
                         progress: worker.cpu / 100,
                         tint: cardColor(worker.cpu))
            TelemetryRow(icon: "memorychip.fill", label: "RAM",
                         value: String(format: "%.1f / %.1f GB", worker.ramUsed, worker.ramTotal),
                         progress: worker.ramTotal > 0 ? worker.ramUsed / worker.ramTotal : 0,
                         tint: cardColor(worker.ramTotal > 0 ? worker.ramUsed / worker.ramTotal * 100 : 0))
            TelemetryRow(icon: "bolt.fill", label: "GPU",
                         value: worker.gpu != nil ? String(format: "%.1f %%", worker.gpu!) : "N/A",
                         progress: worker.gpu != nil ? (worker.gpu! / 100) : 0,
                         tint: worker.gpu != nil ? cardColor(worker.gpu!) : .gray)
            TelemetryRow(icon: "thermometer.medium", label: "Temp",
                         value: worker.temp != nil ? String(format: "%.0f °C", worker.temp!) : "N/A",
                         progress: worker.temp != nil ? min(worker.temp! / 110, 1) : 0,
                         tint: worker.temp != nil ? cardColor(worker.temp!) : .gray)
        }
        .padding(DS.sp12)
        .background(Color.white.opacity(worker.stale ? 0.02 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: DS.r8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.r8, style: .continuous)
                .stroke(worker.stale ? DS.amber.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func cardColor(_ pct: Double) -> Color {
        if pct < 60 { return DS.success }
        if pct < 80 { return DS.amber }
        return DS.danger
    }
}

struct StatusCard: View {
    let icon: String; let title: String; let value: String; let live: Bool; let tint: Color
    var body: some View {
        HStack(spacing: DS.sp12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(live ? DS.success : .white.opacity(0.4))
            }
            Spacer()
            Circle()
                .fill(live ? DS.success : Color.white.opacity(0.15))
                .frame(width: 8, height: 8)
        }
        .glassCard(radius: DS.r12)
    }
}

struct TopoView: View {
    let trainer: TrainerViewModel
    var body: some View {
        VStack(spacing: DS.sp16) {
            NodeDot(label: "Master", sub: trainer.masterIP ?? "Offline", color: DS.cyan, icon: "server.rack")
            if trainer.workerCount > 0 {
                HStack(spacing: 0) {
                    ForEach(0..<trainer.workerCount, id: \.self) { _ in
                        Rectangle()
                            .fill(LinearGradient(colors: [DS.cyan.opacity(0.5), DS.amber.opacity(0.5)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 2, height: 32)
                            .frame(maxWidth: .infinity)
                    }
                }
                HStack(spacing: DS.sp12) {
                    ForEach(0..<trainer.workerCount, id: \.self) { i in
                        NodeDot(label: "W\(i+1)", sub: "Online", color: DS.amber, icon: "desktopcomputer")
                    }
                }
            } else {
                Text("Waiting for connections…")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.3))
                    .padding(.vertical, DS.sp16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.sp12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DS.r8, style: .continuous))
    }
}

struct NodeDot: View {
    let label: String; let sub: String; let color: Color; let icon: String
    var body: some View {
        VStack(spacing: DS.sp4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .clipShape(Circle())
                .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 1))
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            Text(sub).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
        }
    }
}

// MARK: ─── Screen 4 : Results ───────────────────────────────────────

struct RunRecord: Identifiable {
    let id: Int
    let status: String
    let startedAt: String
    let finishedAt: String?
    let modelName: String
    let trainingMode: String
    let rounds: Int
    let bestValAccuracy: Double?
    let testAccuracy: Double?
    let totalTrainingSeconds: Double?
    let workerCount: Int
    let datasetImages: Int
}

struct Screen4: View {
    @Bindable var trainer: TrainerViewModel
    @State private var runs: [RunRecord] = []
    @State private var selectedRunId: Int? = nil
    @State private var refreshTimer: Timer? = nil

    var selectedRun: RunRecord? {
        runs.first { $0.id == selectedRunId }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left — run history list
            VStack(spacing: 0) {
                HStack {
                    PageHeader(icon: "chart.xyaxis.line", title: "Results", sub: "Training history", tint: DS.success)
                    Spacer()
                    Button {
                        fetchRuns()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(DS.sp16)

                if runs.isEmpty {
                    VStack(spacing: DS.sp8) {
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.15))
                        Text("No runs yet")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: DS.sp4) {
                            ForEach(runs) { run in
                                RunListRow(run: run, isSelected: selectedRunId == run.id)
                                    .onTapGesture { selectedRunId = run.id }
                            }
                        }
                        .padding(DS.sp8)
                    }
                }
            }
            .frame(width: 220)
            .background(Color(red: 0.10, green: 0.10, blue: 0.10))
            .overlay(Rectangle().frame(width: 1).foregroundStyle(Color(red: 0.26, green: 0.26, blue: 0.26)), alignment: .trailing)

            // Right — detail view
            Group {
                if let run = selectedRun {
                    RunDetailView(run: run)
                } else {
                    VStack(spacing: DS.sp8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.15))
                        Text("Select a run to view details")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            fetchRuns()
            // Auto-refresh while training is live
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                fetchRuns()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        .onChange(of: trainer.isRunning) {
            fetchRuns()
        }
    }

    private func fetchRuns() {
        guard let url = URL(string: "http://localhost:8080/runs") else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { data, _, _ in
            guard let data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            let parsed: [RunRecord] = arr.compactMap { d in
                guard let id = d["id"] as? Int,
                      let status = d["status"] as? String else { return nil }
                return RunRecord(
                    id: id,
                    status: status,
                    startedAt: (d["started_at"] as? String) ?? "—",
                    finishedAt: d["finished_at"] as? String,
                    modelName: (d["model_name"] as? String) ?? "—",
                    trainingMode: (d["training_mode"] as? String) ?? "—",
                    rounds: (d["rounds"] as? Int) ?? 0,
                    bestValAccuracy: (d["best_val_accuracy"] as? NSNumber)?.doubleValue,
                    testAccuracy: (d["test_accuracy"] as? NSNumber)?.doubleValue,
                    totalTrainingSeconds: (d["total_training_seconds"] as? NSNumber)?.doubleValue,
                    workerCount: (d["registered_worker_count"] as? Int) ?? 0,
                    datasetImages: (d["dataset_total_images"] as? Int) ?? 0
                )
            }.sorted { $0.id > $1.id }
            DispatchQueue.main.async {
                self.runs = parsed
                // Auto-select latest if none selected
                if self.selectedRunId == nil, let first = parsed.first {
                    self.selectedRunId = first.id
                }
            }
        }.resume()
    }
}

struct RunListRow: View {
    let run: RunRecord
    let isSelected: Bool

    var statusColor: Color {
        switch run.status {
        case "succeeded", "done": return DS.success
        case "failed", "error", "stopped": return DS.danger
        default: return DS.amber
        }
    }

    var body: some View {
        HStack(spacing: DS.sp8) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("Run #\(run.id)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.8))
                Text(run.status.capitalized)
                    .font(.system(size: 10))
                    .foregroundStyle(statusColor.opacity(0.8))
            }
            Spacer()
            if let acc = run.testAccuracy {
                Text(String(format: "%.1f%%", acc * 100))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.success)
            }
        }
        .padding(.horizontal, DS.sp12)
        .padding(.vertical, DS.sp8)
        .background(isSelected ? DS.cyan.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DS.r8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.r8, style: .continuous)
                .stroke(isSelected ? DS.cyan.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct RunDetailView: View {
    let run: RunRecord

    var statusColor: Color {
        switch run.status {
        case "succeeded", "done": return DS.success
        case "failed", "error", "stopped": return DS.danger
        default: return DS.amber
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.sp16) {

                // Header
                HStack(spacing: DS.sp12) {
                    VStack(alignment: .leading, spacing: DS.sp4) {
                        HStack(spacing: DS.sp8) {
                            Text("Run #\(run.id)")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                            Text(run.status.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(statusColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(statusColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text(formattedDate(run.startedAt))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    // Big accuracy badge
                    if let acc = run.testAccuracy {
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f%%", acc * 100))
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.success)
                            Text("Test Accuracy")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    } else if run.status != "done" {
                        VStack(spacing: 2) {
                            Text("—")
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.2))
                            Text("In Progress")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.amber.opacity(0.7))
                        }
                    }
                }
                .glassCard()

                // Accuracy metrics
                if run.bestValAccuracy != nil || run.testAccuracy != nil {
                    HStack(spacing: DS.sp12) {
                        if let val = run.bestValAccuracy {
                            MetricTile(label: "Best Val Accuracy", value: String(format: "%.1f%%", val * 100), tint: DS.cyan)
                        }
                        if let test = run.testAccuracy {
                            MetricTile(label: "Test Accuracy", value: String(format: "%.1f%%", test * 100), tint: DS.success)
                        }
                        if let secs = run.totalTrainingSeconds {
                            MetricTile(label: "Total Time", value: formatDuration(secs), tint: DS.purple)
                        }
                    }
                }

                // Config
                VStack(alignment: .leading, spacing: DS.sp12) {
                    Label_("Configuration")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.sp8) {
                        ConfigRow(label: "Model", value: run.modelName.uppercased())
                        ConfigRow(label: "Mode", value: run.trainingMode.capitalized)
                        ConfigRow(label: "Rounds", value: "\(run.rounds)")
                        ConfigRow(label: "Workers", value: "\(run.workerCount)")
                        ConfigRow(label: "Dataset", value: "\(run.datasetImages) images")
                        if let secs = run.totalTrainingSeconds {
                            ConfigRow(label: "Avg/Round", value: formatDuration(secs / Double(max(run.rounds, 1))))
                        }
                    }
                }
                .glassCard()
            }
            .padding(DS.sp16)
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = f.date(from: iso) {
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .short
            return out.string(from: date)
        }
        return iso
    }

    private func formatDuration(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: DS.sp4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.sp12)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.r8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.r8, style: .continuous).stroke(tint.opacity(0.2), lineWidth: 1))
    }
}

struct ConfigRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, DS.sp12)
        .padding(.vertical, DS.sp8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DS.r8, style: .continuous))
    }
}

// MARK: - View Mode

enum ViewMode: String, CaseIterable {
    case sequential, fourScreen
}

// MARK: - ViewModel (@Observable)
//
// Backend starts when the user hits Start Server — not before.
// Sequence: spawn backend → wait for it → POST /runs → done.

@Observable
@MainActor
final class TrainerViewModel {

    // ── Navigation ──────────────────────────────────────────────────────
    var currentScreen: Int = 1
    var viewMode: ViewMode = .sequential

    // ── Training config ──────────────────────────────────────────────────
    var datasetPath: String    = ""
    var rounds: Int            = 15
    var localEpochs: Int       = 2
    var batchSize: Int         = 8
    var lr: Double             = 0.001
    var timeout: Int           = 120
    var selectedModel: String  = "resnet18"
    var selectedMode: String   = "quality"
    var connectionType: String = "LAN"

    // ── Environment (Screen 1 UI) ────────────────────────────────────────
    var pythonPath: String        = ""
    var masterScriptPath: String  = ""
    var pythonVersion: String?    = nil
    var detectedClasses: [String] = []

    // ── Runtime state ────────────────────────────────────────────────────
    var log: String            = ""
    var isRunning: Bool        = false
    var statusMessage: String? = nil
    var masterIP: String?      = nil
    var workerCount: Int       = 0
    var waitingForWorkers: Bool = false

    // ── Telemetry ────────────────────────────────────────────────────────
    var localMetrics = SystemMetrics()
    var remoteWorkerMetrics: [WorkerMetrics] = []

    // ── Internal ─────────────────────────────────────────────────────────
    @ObservationIgnored private var runId: Int?       = nil
    @ObservationIgnored private let controlURL        = "http://localhost:8080"
    @ObservationIgnored private var pollTimer: Timer? = nil
    @ObservationIgnored private var logOffset: Int    = 0
    @ObservationIgnored private var backendProcess: Process? = nil
    @ObservationIgnored private let projectDir =
        NSHomeDirectory() + "/Documents/2.Area/SharedComputing"

    // MARK: - Init

    init() {
        let pythonCandidates = [
            NSHomeDirectory() + "/venv_shared/bin/python3",
            NSHomeDirectory() + "/Documents/2.Area/SharedComputing/.venv/bin/python3",
            NSHomeDirectory() + "/.venv/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
        pythonPath = pythonCandidates.first {
            FileManager.default.fileExists(atPath: $0)
        } ?? "/usr/bin/python3"

        let scriptCandidates = [
            projectDir + "/master.py",
            NSHomeDirectory() + "/Documents/SharedComputing/master.py",
        ]
        masterScriptPath = scriptCandidates.first {
            FileManager.default.fileExists(atPath: $0)
        } ?? ""

        masterIP = localIPAddress()
    }

    // MARK: - Start Server (user-initiated)

    func start() {
        statusMessage = "Starting…"
        log = ""
        logOffset = 0
        isRunning = false

        // If backend is already up, go straight to creating the run
        checkBackendAlive { [weak self] alive in
            if alive {
                self?.createRun()
            } else {
                self?.spawnBackendThenRun()
            }
        }
    }

    private func checkBackendAlive(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(controlURL)/runs") else { completion(false); return }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { _, response, _ in
            let alive = (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async { completion(alive) }
        }.resume()
    }

    private func spawnBackendThenRun() {
        let backendScript = projectDir + "/backend_service.py"
        guard FileManager.default.fileExists(atPath: backendScript) else {
            statusMessage = "✗ backend_service.py not found at \(projectDir)"
            return
        }

        let ip = localIPAddress() ?? "0.0.0.0"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [backendScript]
        proc.currentDirectoryURL = URL(fileURLWithPath: projectDir)

        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        env["ADVERTISED_HOST"]  = ip
        if !datasetPath.isEmpty { env["DATASET_ROOT"] = datasetPath }
        proc.environment = env
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError  = FileHandle.nullDevice

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.isRunning = false }
        }

        do {
            try proc.run()
            backendProcess = proc
            statusMessage = "Backend starting…"
            // Poll until backend responds, then create the run
            waitForBackendThenRun(attempts: 20)
        } catch {
            statusMessage = "✗ Could not start backend: \(error.localizedDescription)"
        }
    }

    private func waitForBackendThenRun(attempts: Int) {
        guard attempts > 0 else {
            statusMessage = "✗ Backend failed to start."
            return
        }
        guard let url = URL(string: "\(controlURL)/runs") else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200 {
                    self?.createRun()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self?.waitForBackendThenRun(attempts: attempts - 1)
                    }
                }
            }
        }.resume()
    }

    private func createRun() {
        let dataset = datasetPath.isEmpty ? "." : datasetPath
        let body: [String: Any] = [
            "dataset_subpath":   dataset,
            "rounds":            rounds,
            "local_epochs":      localEpochs,
            "batch_size":        batchSize,
            "learning_rate":     lr,
            "round_timeout_sec": timeout,
            "mode":              selectedMode,
            "model":             selectedModel,
        ]

        guard let url = URL(string: "\(controlURL)/runs") else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.statusMessage = "✗ \(error.localizedDescription)"
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.statusMessage = "✗ Unexpected response from backend"
                    return
                }
                if let detail = json["detail"] as? String {
                    self.statusMessage = "✗ \(detail)"
                    return
                }
                guard let id = json["run_id"] as? Int else {
                    self.statusMessage = "✗ No run_id in response"
                    return
                }
                self.runId = id
                self.isRunning = true
                self.workerCount = 0
                self.statusMessage = "Ready — connect workers, then begin training."
                self.log += "▶ Run #\(id) started\n\n"
                self.startPolling()
            }
        }.resume()
    }

    // MARK: - Begin training  (POST /runs/{id}/begin)

    func sendEnter() {
        guard let runId else { return }
        guard let url = URL(string: "\(controlURL)/runs/\(runId)/begin") else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        URLSession.shared.dataTask(with: req) { [weak self] _, _, error in
            DispatchQueue.main.async {
                if let error { self?.statusMessage = "✗ \(error.localizedDescription)" }
            }
        }.resume()
    }

    // MARK: - Stop  (POST /runs/{id}/stop)

    func stop() {
        stopPolling()
        guard let runId else {
            isRunning = false; statusMessage = "Stopped."; return
        }
        guard let url = URL(string: "\(controlURL)/runs/\(runId)/stop") else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()

        isRunning = false
        self.runId = nil
        statusMessage = "Stopped."
        log += "\n⛔ Stopped by user.\n"
        remoteWorkerMetrics = []
        workerCount = 0
    }

    // MARK: - App quit

    func shutdown() {
        stopPolling()
        backendProcess?.terminate()
        backendProcess = nil

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", "lsof -ti :8080 | xargs kill -9 2>/dev/null; true"]
        try? proc.run()
        proc.waitUntilExit()
    }
    func killBackend() {
        stopPolling()
        isRunning = false
        runId = nil
        statusMessage = "Backend killed."
        log += "\n💀 Backend killed.\n"
        backendProcess?.terminate()
        backendProcess = nil
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", "lsof -ti :8080 | xargs kill -9 2>/dev/null; true"]
        try? proc.run()
        proc.waitUntilExit()
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchWorkerMetrics()
                self?.fetchLogs()
                self?.fetchRunStatus()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        remoteWorkerMetrics = []
    }

    private func fetchWorkerMetrics() {
        guard let runId,
              let url = URL(string: "\(controlURL)/runs/\(runId)/workers") else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { [weak self] data, _, _ in
            guard let data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            var metrics: [WorkerMetrics] = []
            for dict in arr {
                let id       = (dict["worker_id"] as? String) ?? "?"
                let cpu      = (dict["last_cpu_pct"]      as? NSNumber)?.doubleValue
                    ?? (dict["cpu"] as? NSNumber)?.doubleValue
                    ?? 0
                let ramUsed  = (dict["last_ram_used_gb"]  as? NSNumber)?.doubleValue
                    ?? (dict["ram_used"] as? NSNumber)?.doubleValue
                    ?? 0
                let ramTotal = (dict["ram_total_gb"]      as? NSNumber)?.doubleValue
                    ?? (dict["ram_total"] as? NSNumber)?.doubleValue
                    ?? 0
                let gpu      = (dict["last_gpu_pct"]      as? NSNumber)?.doubleValue
                    ?? (dict["gpu"] as? NSNumber)?.doubleValue
                let temp     = (dict["last_temp_c"]       as? NSNumber)?.doubleValue
                    ?? (dict["temp"] as? NSNumber)?.doubleValue
                let stale    = ((dict["state"] as? String) == "stale")
                    || ((dict["stale"] as? Bool) ?? false)
                metrics.append(WorkerMetrics(
                    id: id, cpu: cpu,
                    ramUsed: ramUsed, ramTotal: ramTotal,
                    gpu: gpu, temp: temp, stale: stale
                ))
            }
            DispatchQueue.main.async {
                self?.remoteWorkerMetrics = metrics.sorted { $0.id < $1.id }
                self?.workerCount = metrics.filter { !$0.stale }.count
            }
        }.resume()
    }

    private func fetchLogs() {
        guard let runId,
              let url = URL(string: "\(controlURL)/runs/\(runId)/logs") else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { [weak self] data, _, _ in
            guard let data,
                  let lines = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                let newChars = lines.count
                if newChars > self.logOffset {
                    let startIndex = lines.index(lines.startIndex, offsetBy: self.logOffset)
                    self.log += String(lines[startIndex...])
                    self.logOffset = newChars
                }
            }
        }.resume()
    }

    private func fetchRunStatus() {
        guard let runId,
              let url = URL(string: "\(controlURL)/runs/\(runId)") else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { [weak self] data, _, _ in
            guard let data,
                  let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                if status == "succeeded" || status == "failed" || status == "stopped"
                    || status == "done" || status == "error" {
                    self.stopPolling()
                    self.isRunning = false
                    self.runId = nil
                    let label = (status == "succeeded" || status == "done")
                        ? "✅ Training finished."
                        : "⚠ Run ended with status: \(status)."
                    self.statusMessage = label
                    self.log += "\n\(label)\n"
                }
            }
        }.resume()
    }

    // MARK: - Dataset helpers

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

    // MARK: - Python version check (Screen 1)

    func checkPythonVersion() {
        guard !pythonPath.isEmpty else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = ["--version"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) {
                pythonVersion = output
            }
        } catch {
            pythonVersion = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Local IP helper

    private func localIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let interface = ptr {
            let flags = Int32(interface.pointee.ifa_flags)
            let addr  = interface.pointee.ifa_addr.pointee
            if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING),
               addr.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(interface.pointee.ifa_addr, socklen_t(addr.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    address = String(cString: hostname)
                    break
                }
            }
            ptr = interface.pointee.ifa_next
        }
        return address
    }
}
