import SwiftUI
import AppKit

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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 720)
                .background(WindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
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
    @State private var trainer = TrainerViewModel()

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

// MARK: ─── Screen 4 : Results & Logs ─────────────────────────────────

struct Screen4: View {
    @Bindable var trainer: TrainerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Results header
            VStack(alignment: .leading, spacing: DS.sp16) {
                HStack {
                    PageHeader(icon: "chart.xyaxis.line", title: "Results", sub: "Live metrics & logs", tint: DS.success)
                    Spacer()
                    VStack(alignment: .trailing, spacing: DS.sp4) {
                        TempTag()
                        Picker("", selection: $trainer.connectionType) {
                            Text("LAN").tag("LAN"); Text("WiFi").tag("WiFi")
                        }
                        .pickerStyle(.segmented).frame(width: 100)
                    }
                }

                // DB table
                VStack(alignment: .leading, spacing: 0) {
                    HStack { Label_("Database Records"); Spacer(); TempTag() }
                    DBTable(trainer: trainer)
                }
                .glassCard(inset: 0)
            }
            .padding(DS.sp24)

            // Terminal
            TerminalPanel(trainer: trainer)
        }
    }
}

struct DBTable: View {
    let trainer: TrainerViewModel

    private let cols: [(String, CGFloat)] = [
        ("Node", 80), ("Time", 60), ("Status", 70), ("Model", 80), ("Data", 50), ("Link", 50)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(cols, id: \.0) { col in
                    Text(col.0.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: col.1, alignment: .leading)
                }
            }
            .padding(.horizontal, DS.sp16).padding(.vertical, DS.sp8)
            .background(Color.black.opacity(0.2))

            if trainer.isRunning || !trainer.log.isEmpty {
                DBRow(node: "Master", time: "—", status: trainer.isRunning ? "Live" : "Done",
                      model: "ResNet18", data: "—", link: trainer.connectionType, isLive: trainer.isRunning)
                ForEach(0..<max(trainer.workerCount, 1), id: \.self) { i in
                    DBRow(node: "W\(i+1)", time: "—", status: "Compute",
                          model: "ResNet18", data: "—", link: trainer.connectionType, isLive: true)
                }
            } else {
                Text("No data yet — start a training session")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity).padding(.vertical, DS.sp32)
            }
        }
    }
}

struct DBRow: View {
    let node, time, status, model, data, link: String
    var isLive: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Text(node).fontWeight(.medium).frame(width: 80, alignment: .leading)
            Text(time).frame(width: 60, alignment: .leading)
            Text(status)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isLive ? DS.success : DS.cyan)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background((isLive ? DS.success : DS.cyan).opacity(0.12))
                .clipShape(Capsule())
                .frame(width: 70, alignment: .leading)
            Text(model).frame(width: 80, alignment: .leading)
            Text(data).frame(width: 50, alignment: .leading)
            Text(link).frame(width: 50, alignment: .leading)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, DS.sp16).padding(.vertical, DS.sp8)
    }
}

// MARK: - Terminal

struct TerminalPanel: View {
    @Bindable var trainer: TrainerViewModel
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.sp8) {
                HStack(spacing: DS.sp4) {
                    Circle().fill(DS.success).frame(width: 6, height: 6)
                    Text("Terminal").font(.system(size: 13, weight: .semibold))
                }
                Spacer()
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox).font(.system(size: 11))
                Button { trainer.log = "" } label: {
                    Image(systemName: "trash").font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear terminal output")
            }
            .padding(.horizontal, DS.sp16).padding(.vertical, DS.sp8)
            .background(Color.black.opacity(0.25))

            ScrollViewReader { proxy in
                ScrollView {
                    Text(trainer.log.isEmpty ? "Output will appear here…" : trainer.log)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(trainer.log.isEmpty ? .white.opacity(0.2) : DS.success.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.sp16)
                        .id("end")
                }
                .background(Color.black.opacity(0.4))
                .onChange(of: trainer.log) {
                    if autoScroll { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("end", anchor: .bottom) } }
                }
            }

            if trainer.isRunning {
                HStack(spacing: DS.sp8) {
                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                    Text("Training…").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    if let ip = trainer.masterIP {
                        Text("\(ip):8000")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DS.cyan.opacity(0.7))
                    }
                }
                .padding(.horizontal, DS.sp16).padding(.vertical, DS.sp8)
                .background(Color.black.opacity(0.2))
            }
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
    }
}

// MARK: - View Mode

enum ViewMode: String, CaseIterable {
    case sequential, fourScreen
}

// MARK: - ViewModel (@Observable)

@Observable
@MainActor
final class TrainerViewModel {
    var currentScreen: Int   = 1
    var viewMode: ViewMode   = .sequential

    var datasetPath: String   = ""
    var rounds: Int           = 15
    var localEpochs: Int      = 2
    var batchSize: Int        = 8
    var lr: Double            = 0.001
    var timeout: Int          = 120
    var pythonPath: String    = ""
    var detectedClasses: [String] = []
    var log: String           = ""
    var isRunning: Bool       = false
    var statusMessage: String? = nil
    var masterIP: String?     = nil
    var waitingForWorkers: Bool = false
    var workerCount: Int        = 0

    var pythonVersion: String?  = nil
    var selectedModel: String   = "resnet18"
    var connectionType: String  = "LAN"

    var localMetrics = SystemMetrics()
    var remoteWorkerMetrics: [WorkerMetrics] = []
    @ObservationIgnored private var metricsTimer: Timer?

    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var masterFileHandle: FileHandle?
    @ObservationIgnored private var slaveFd: Int32 = -1
    @ObservationIgnored private var ptyMasterFd: Int32 = -1
    var masterScriptPath: String = ""

    init() {
        let candidates = [
            NSHomeDirectory() + "/venv_shared/bin/python3",
            NSHomeDirectory() + "/Documents/2.Area/SharedComputing/.venv/bin/python3",
            NSHomeDirectory() + "/.venv/bin/python3",
        ]
        pythonPath = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? ""

        let appDir = Bundle.main.bundlePath
        let candidates2 = [
            (appDir as NSString).deletingLastPathComponent + "/master.py",
            NSHomeDirectory() + "/Documents/2.Area/SharedComputing/master.py",
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
                DispatchQueue.main.async { self.pythonVersion = output }
            }
        } catch {
            DispatchQueue.main.async { self.pythonVersion = "Error: \(error.localizedDescription)" }
        }
    }

    func start() {
        guard !pythonPath.isEmpty else { statusMessage = "⚠ Set Python path first."; return }
        if masterScriptPath.isEmpty || !FileManager.default.fileExists(atPath: masterScriptPath) {
            statusMessage = "⚠ Could not find master.py"; return
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

        cleanup()

        process = Process()
        process?.executableURL = URL(fileURLWithPath: pythonPath)
        process?.arguments = args
        process?.currentDirectoryURL = URL(fileURLWithPath:
            (masterScriptPath as NSString).deletingLastPathComponent)
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        process?.environment = env

        let ptyFds = openpty()
        guard ptyFds.master >= 0, ptyFds.slave >= 0 else {
            statusMessage = "✗ Failed to allocate PTY"; return
        }

        self.ptyMasterFd = ptyFds.master
        self.slaveFd = ptyFds.slave

        let slaveHandle = FileHandle(fileDescriptor: ptyFds.slave, closeOnDealloc: false)
        process?.standardOutput = slaveHandle
        process?.standardError  = slaveHandle
        process?.standardInput  = slaveHandle

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
                self?.stopMetricsPolling()
                self?.cleanup()
                self?.isRunning = false
                self?.statusMessage = "Training finished."
            }
        }

        let killer = Process()
        killer.executableURL = URL(fileURLWithPath: "/bin/sh")
        killer.arguments = ["-c", "kill $(lsof -ti:8000) 2>/dev/null; sleep 1"]
        try? killer.run()
        killer.waitUntilExit()

        do {
            try process?.run()
            close(slaveFd); slaveFd = -1
            isRunning = true
            statusMessage = "Server started — connect workers, then begin training."
            log += "▶ \(pythonPath) \(args.dropFirst().joined(separator: " "))\n\n"
            startMetricsPolling()
        } catch {
            statusMessage = "✗ \(error.localizedDescription)"
            cleanup()
        }
    }

    func stop() {
        stopMetricsPolling()
        process?.terminate(); cleanup()
        isRunning = false; statusMessage = "Stopped."
        log += "\n⛔ Stopped by user.\n"
    }

    private func cleanup() {
        masterFileHandle?.readabilityHandler = nil; masterFileHandle = nil
        if slaveFd >= 0 { close(slaveFd); slaveFd = -1 }
        if ptyMasterFd >= 0 { close(ptyMasterFd); ptyMasterFd = -1 }
        process = nil; workerCount = 0; masterIP = nil
    }

    func sendEnter() {
        guard ptyMasterFd >= 0 else { return }
        var nl: UInt8 = 10; write(ptyMasterFd, &nl, 1)
    }

    // MARK: - Remote Worker Metrics Polling

    private func startMetricsPolling() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchWorkerMetrics()
            }
        }
    }

    private func stopMetricsPolling() {
        metricsTimer?.invalidate()
        metricsTimer = nil
        remoteWorkerMetrics = []
    }

    private func fetchWorkerMetrics() {
        guard let ip = masterIP else { return }
        let urlString = "http://\(ip):8000/workers/metrics"
        guard let url = URL(string: urlString) else { return }
        let request = URLRequest(url: url, timeoutInterval: 5)
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            var metrics: [WorkerMetrics] = []
            for (wid, value) in json {
                guard let dict = value as? [String: Any] else { continue }
                let cpu = (dict["cpu"] as? NSNumber)?.doubleValue ?? 0
                let ramUsed = (dict["ram_used"] as? NSNumber)?.doubleValue ?? 0
                let ramTotal = (dict["ram_total"] as? NSNumber)?.doubleValue ?? 0
                let gpu = (dict["gpu"] as? NSNumber)?.doubleValue
                let temp = (dict["temp"] as? NSNumber)?.doubleValue
                let stale = (dict["stale"] as? Bool) ?? false
                metrics.append(WorkerMetrics(id: wid, cpu: cpu, ramUsed: ramUsed, ramTotal: ramTotal, gpu: gpu, temp: temp, stale: stale))
            }
            DispatchQueue.main.async {
                self?.remoteWorkerMetrics = metrics.sorted { $0.id < $1.id }
            }
        }.resume()
    }
}

private func openpty() -> (master: Int32, slave: Int32) {
    var m: Int32 = 0, s: Int32 = 0
    var ws = winsize(); ws.ws_col = 220; ws.ws_row = 50
    _ = Darwin.openpty(&m, &s, nil, nil, &ws)
    return (m, s)
}
