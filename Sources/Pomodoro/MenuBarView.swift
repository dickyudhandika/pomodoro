import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: TimerModel
    @Environment(\.colorScheme) var scheme
    @Environment(\.openWindow) var openWindow

    var t: ShadTheme { scheme == .dark ? .dark : .light }

    var body: some View {
        VStack(spacing: 0) {
            // Phase progress bar at very top
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(t.border)
                    Rectangle()
                        .fill(model.phase.accent)
                        .frame(width: geo.size.width * model.progress)
                        .animation(.linear(duration: 0.5), value: model.progress)
                }
            }
            .frame(height: 3)

            VStack(spacing: 14) {
                // Phase + task
                VStack(spacing: 3) {
                    Text(model.phase.rawValue.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(t.mutedFg)

                    Text(model.timeString)
                        .font(.system(size: 44, weight: .light, design: .monospaced))
                        .foregroundStyle(t.foreground)

                    if !model.taskName.isEmpty {
                        Text(model.taskName)
                            .font(.system(size: 11))
                            .foregroundStyle(t.mutedFg)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.top, 1)
                    }
                }
                .padding(.top, 16)

                // Separator
                Rectangle()
                    .fill(t.border)
                    .frame(height: 1)

                // Controls
                HStack(spacing: 8) {
                    // Start / Pause — primary button
                    Button(action: { model.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text(model.isRunning ? "Pause" : "Start")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(t.primaryFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 8).fill(t.primary))
                    }
                    .buttonStyle(.plain)

                    // Open main window — outline icon button
                    Button(action: {
                        openWindow(id: "main")
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }) {
                        Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(t.mutedFg)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(t.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(t.border, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 240)
        .background(t.background)
    }
}
