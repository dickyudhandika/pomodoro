import SwiftUI

struct AnalyticsView: View {
    @ObservedObject var store: SessionStore
    var onClose: () -> Void = {}
    @Environment(\.colorScheme) var scheme

    var t: ShadTheme { scheme == .dark ? .dark : .light }

    var body: some View {
        ZStack {
            t.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                // shadcn Separator
                Rectangle()
                    .fill(t.border)
                    .frame(height: 1)

                if store.sessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            todaySummary
                            history
                        }
                        .padding(20)
                    }
                }
            }
        }
        .frame(width: 420, height: 540)
    }

    // MARK: - Header

    var header: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Analytics")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(t.foreground)

            Spacer()

            if !store.sessions.isEmpty {
                // Destructive ghost button
                Button("Clear all") { store.clear() }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "E84C3D"))
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
            }

            // Close — ghost icon button, rounded full (circle)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(t.mutedFg)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(t.muted))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Empty state

    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar")
                .font(.system(size: 28))
                .foregroundStyle(t.border)
            Text("No sessions yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(t.foreground)
            Text("Complete your first pomodoro to see stats here.")
                .font(.system(size: 12))
                .foregroundStyle(t.mutedFg)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Today summary

    var todaySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Today")

            // Three stat cards side by side — shadcn Card style
            HStack(spacing: 10) {
                statCard(
                    value: focusTimeStr(store.todayFocusMinutes),
                    label: "Focus time"
                )
                statCard(
                    value: "\(store.todayPomodoros)",
                    label: "Pomodoros"
                )
                statCard(
                    value: "\(store.uniqueTasksToday.count)",
                    label: store.uniqueTasksToday.count == 1 ? "Task" : "Tasks"
                )
            }

            // Task chips
            if !store.uniqueTasksToday.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(store.uniqueTasksToday, id: \.self) { task in
                            // shadcn Badge — secondary variant
                            Text(task)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(t.mutedFg)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(t.muted)
                                        .overlay(Capsule().stroke(t.border, lineWidth: 1))
                                )
                        }
                    }
                }
            }
        }
    }

    // shadcn Card: rounded-xl (10px), border, bg-card
    func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(t.foreground)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(t.mutedFg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(t.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(t.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Session history

    var history: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(store.grouped, id: \.day) { group in
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel(dayLabel(group.day))

                    // Sessions in a single card with dividers — shadcn table/list style
                    VStack(spacing: 0) {
                        ForEach(Array(group.sessions.enumerated()), id: \.element.id) { idx, session in
                            ShadSessionRow(session: session, theme: t)

                            if idx < group.sessions.count - 1 {
                                Rectangle()
                                    .fill(t.border)
                                    .frame(height: 1)
                                    .padding(.leading, 42)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(t.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(t.border, lineWidth: 1)
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Helpers

    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(t.mutedFg)
    }

    func focusTimeStr(_ min: Int) -> String {
        if min == 0 { return "0m" }
        if min < 60 { return "\(min)m" }
        let h = min / 60; let m = min % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date)     { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }
}

// MARK: - Session row

struct ShadSessionRow: View {
    let session: Session
    let theme: ShadTheme

    var body: some View {
        HStack(spacing: 10) {
            // Phase badge — shadcn Badge with accent color tint
            Text(session.phaseRaw)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(accentColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(accentColor.opacity(0.10)))
                .fixedSize()

            // Task + skipped label
            VStack(alignment: .leading, spacing: 1) {
                if !session.taskName.isEmpty {
                    Text(session.taskName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                } else {
                    Text("—")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.mutedFg)
                }
                if session.wasSkipped {
                    Text("skipped")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.mutedFg)
                }
            }

            Spacer()

            // Time + duration
            VStack(alignment: .trailing, spacing: 1) {
                Text(timeStr)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.mutedFg)
                Text("\(session.durationMinutes)m")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.mutedFg.opacity(0.6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    var accentColor: Color {
        switch session.phaseRaw {
        case Phase.work.rawValue:       return Color(hex: "E84C3D")
        case Phase.shortBreak.rawValue: return Color(hex: "40B87C")
        case Phase.longBreak.rawValue:  return Color(hex: "4080EB")
        default:                        return Color(hex: "8E8F91")
        }
    }

    var timeStr: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: session.completedAt)
    }
}
