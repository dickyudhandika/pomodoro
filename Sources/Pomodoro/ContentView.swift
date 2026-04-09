import SwiftUI

// MARK: - Color helpers

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255
        )
    }
}

// MARK: - shadcn design tokens (oklch → hex approximations)

struct ShadTheme {
    let background: Color  // --background
    let foreground: Color  // --foreground
    let card:       Color  // --card
    let border:     Color  // --border
    let muted:      Color  // --muted
    let mutedFg:    Color  // --muted-foreground
    let primary:    Color  // --primary
    let primaryFg:  Color  // --primary-foreground

    // Light: oklch(1 0 0) bg, oklch(0.145 0 0) fg, oklch(0.922 0 0) border
    static let light = ShadTheme(
        background: Color(hex: "FFFFFF"),
        foreground: Color(hex: "252626"),
        card:       Color(hex: "FFFFFF"),
        border:     Color(hex: "E8E8E8"),
        muted:      Color(hex: "F5F5F5"),
        mutedFg:    Color(hex: "8E8F91"),
        primary:    Color(hex: "252626"),
        primaryFg:  Color(hex: "FAFAFA")
    )

    // Dark: oklch(0.145 0 0) bg, oklch(0.985 0 0) fg, oklch(1 0 0 / 10%) border
    static let dark = ShadTheme(
        background: Color(hex: "252626"),
        foreground: Color(hex: "FAFAFA"),
        card:       Color(hex: "353637"),
        border:     Color(white: 1, opacity: 0.10),
        muted:      Color(hex: "414243"),
        mutedFg:    Color(hex: "A1A1AA"),
        primary:    Color(hex: "E8E8E8"),
        primaryFg:  Color(hex: "353637")
    )
}

// MARK: - Phase accent colors

extension Phase {
    var accent: Color {
        switch self {
        case .work:       return Color(hex: "E84C3D")
        case .shortBreak: return Color(hex: "40B87C")
        case .longBreak:  return Color(hex: "4080EB")
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @ObservedObject var model: TimerModel
    @State private var showAnalytics = false
    @Environment(\.colorScheme) var scheme

    var t: ShadTheme { scheme == .dark ? .dark : .light }

    var body: some View {
        ZStack {
            t.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                phaseTabs
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                Spacer()
                timerRing
                Spacer()
                taskInput
                    .padding(.horizontal, 20)
                controls
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
                pomodoroDots
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 360, height: 500)
        .sheet(isPresented: $showAnalytics) {
            AnalyticsView(store: model.store)
        }
    }

    // MARK: - Top bar

    var topBar: some View {
        HStack {
            Spacer()
            Button(action: { showAnalytics = true }) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(t.mutedFg)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(t.background)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(t.border, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.top, 14)
        }
    }

    // MARK: - Phase tabs  (shadcn <Tabs> component)

    var phaseTabs: some View {
        HStack(spacing: 2) {
            ForEach(Phase.allCases, id: \.self) { phase in
                Button(phase.rawValue) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        model.select(phase: phase)
                    }
                }
                .buttonStyle(TabTriggerStyle(
                    isSelected: model.phase == phase,
                    theme: t
                ))
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        // TabsList: bg-muted, rounded-md (8px), h-10
        .background(RoundedRectangle(cornerRadius: 8).fill(t.muted))
    }

    // MARK: - Timer ring

    var timerRing: some View {
        ZStack {
            // Track — border color, 4px
            Circle()
                .stroke(t.border, lineWidth: 4)
                .frame(width: 180, height: 180)

            // Progress arc
            Circle()
                .trim(from: 0, to: model.progress)
                .stroke(
                    model.phase.accent,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: model.progress)

            // Center content
            VStack(spacing: 3) {
                Text(model.timeString)
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(t.foreground)

                Text(model.phase.rawValue.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(t.mutedFg)

                if !model.taskName.isEmpty {
                    Text(model.taskName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(model.phase.accent)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 130)
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Task input  (shadcn <Input> component)
    // h-10 = 40px, rounded-md = 8px, border border-input, px-3

    var taskInput: some View {
        TextField("What are you working on?", text: $model.taskName)
            .font(.system(size: 13))
            .foregroundStyle(t.foreground)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(t.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(t.border, lineWidth: 1)
                    )
            )
            .disabled(model.hasActiveTask)
            .tint(model.phase.accent)
    }

    // MARK: - Controls

    var controls: some View {
        HStack(spacing: 8) {
            // Stop (when active task) or Reset
            if model.hasActiveTask {
                Button(action: { model.stopTask() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(model.phase.accent)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(OutlineIconButtonStyle(theme: t))
            } else {
                Button(action: { model.reset() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(t.mutedFg)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(OutlineIconButtonStyle(theme: t))
            }

            // Play / Pause — primary button (h-11 = 44px, rounded-md, bg-primary)
            Button(action: { model.toggle() }) {
                HStack(spacing: 7) {
                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(model.isRunning ? "Pause" : "Start")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(t.primaryFg)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(t.primary))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            // Skip — ghost icon button
            Button(action: { model.skip() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(t.mutedFg)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(OutlineIconButtonStyle(theme: t))
        }
    }

    // MARK: - Pomodoro dots

    var pomodoroDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(i < (model.completedPomodoros % 4) ? model.phase.accent : t.border)
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: model.completedPomodoros)
            }
        }
    }
}

// MARK: - Button Styles

/// Mimics shadcn <TabsTrigger>:
/// active → bg-background, rounded-sm (6px), shadow-sm
/// inactive → transparent, muted-foreground text
struct TabTriggerStyle: ButtonStyle {
    let isSelected: Bool
    let theme: ShadTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? theme.foreground : theme.mutedFg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.card)
                            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Mimics shadcn outline variant icon button:
/// border, rounded-md (8px), transparent bg, hover → bg-accent fill
struct OutlineIconButtonStyle: ButtonStyle {
    let theme: ShadTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? theme.muted : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.border, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
