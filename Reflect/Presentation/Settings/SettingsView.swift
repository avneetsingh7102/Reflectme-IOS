import SwiftUI
@preconcurrency import SwiftData

/// Settings — per the Reflect Mobile design:
///   1. "Your space." serif title
///   2. Mustard stats card with total reflections + recording duration
///   3. Grouped sections (General, Data, About) with rounded white cards
///   4. Outlined orange "Sign out" pill at the bottom
struct SettingsView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [JournalEntry]
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ReflectTheme.spacingMD) {
                    Text("Your space.")
                        .font(.system(size: 28, weight: .medium, design: .serif))
                        .foregroundStyle(ReflectTheme.ink)
                        .padding(.horizontal, ReflectTheme.edge)
                        .padding(.top, 6)
                        .padding(.bottom, 6)

                    statsCard
                        .padding(.horizontal, ReflectTheme.spacingMD)

                    group(title: "General") {
                        toggleRow(label: "Dark mode",
                                  sub: "Use a warm dark canvas in the evening",
                                  isOn: $isDarkMode)
                        chevronRow(label: "Default emotion model", detail: "Warm v2")
                    }

                    group(title: "Data") {
                        chevronRow(label: "Export all reflections")
                        chevronRow(label: "iCloud sync", detail: "On")
                        chevronRow(label: "Clear all reflections", danger: true)
                            .onTapGesture { showClearConfirmation = true }
                    }

                    group(title: "About") {
                        chevronRow(label: "Tutorial")
                        chevronRow(label: "Color guide")
                        chevronRow(label: "Privacy policy", external: true)
                        chevronRow(label: "Version", detail: appVersion)
                    }

                    signOutButton
                        .padding(.horizontal, ReflectTheme.spacingMD)
                        .padding(.top, 6)
                        .padding(.bottom, ReflectTheme.spacingXL)
                }
            }
            .background(ReflectTheme.canvas.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(ReflectTheme.rounded(16, weight: .semibold))
                        .foregroundStyle(ReflectTheme.primary)
                }
            }
            .alert("Clear all reflections?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete all", role: .destructive) { clearAll() }
            } message: {
                Text("This will permanently remove all journal entries. This action cannot be undone.")
            }
        }
    }

    // MARK: - Pieces

    private var statsCard: some View {
        HStack(spacing: 14) {
            Text("\(entries.count)")
                .font(ReflectTheme.serif(22, weight: .medium))
                .foregroundStyle(ReflectTheme.mustard700)
                .frame(width: 52, height: 52)
                .background(Circle().fill(ReflectTheme.mustard300))

            VStack(alignment: .leading, spacing: 2) {
                Text("Total reflections")
                    .font(ReflectTheme.serif(17, weight: .medium))
                    .foregroundStyle(ReflectTheme.mustard700)
                Text("Since \(memberSinceLabel) · \(totalDurationLabel) recorded")
                    .font(ReflectTheme.rounded(12))
                    .foregroundStyle(ReflectTheme.mustard700.opacity(0.7))
            }
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ReflectTheme.mustard100)
        )
    }

    @ViewBuilder
    private func group<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .eyebrowStyle()
                .padding(.horizontal, ReflectTheme.spacingMD + 4)

            VStack(spacing: 0) { content() }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: ReflectTheme.softShadow, radius: 6, y: 2)
                )
                .padding(.horizontal, ReflectTheme.spacingMD)
        }
    }

    private func chevronRow(label: String,
                            detail: String = "",
                            danger: Bool = false,
                            external: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(ReflectTheme.serif(16))
                .foregroundStyle(danger ? Color(hex: "BA1A1A") : ReflectTheme.ink)
            Spacer()
            if !detail.isEmpty {
                Text(detail)
                    .font(ReflectTheme.rounded(13))
                    .foregroundStyle(ReflectTheme.inkFaint)
            }
            Image(systemName: external ? "arrow.up.right.square" : "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ReflectTheme.inkFaint)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .overlay(
            Rectangle()
                .fill(ReflectTheme.separator.opacity(0.5))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private func toggleRow(label: String, sub: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(ReflectTheme.serif(16))
                    .foregroundStyle(ReflectTheme.ink)
                Text(sub)
                    .font(ReflectTheme.rounded(12))
                    .foregroundStyle(ReflectTheme.inkSoft)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ReflectTheme.primary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(ReflectTheme.separator.opacity(0.5))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            Task {
                try? await services.authService.signOut()
                dismiss()
            }
        } label: {
            Text("Sign out")
                .font(ReflectTheme.rounded(14, weight: .semibold))
                .foregroundStyle(ReflectTheme.primary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    Capsule()
                        .stroke(ReflectTheme.separator, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed labels

    private var appVersion: String {
        "v " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
    }

    private var memberSinceLabel: String {
        guard let earliest = entries.map(\.date).min() else { return "today" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: earliest)
    }

    private var totalDurationLabel: String {
        // No actual durations stored — approximate at 1 minute per entry as a placeholder.
        let totalSeconds = entries.count * 60
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func clearAll() {
        for entry in entries { modelContext.delete(entry) }
        try? modelContext.save()
    }
}
