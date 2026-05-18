import SwiftUI
@preconcurrency import SwiftData

/// App settings: version, total reflections, theme toggle, destructive
/// clear-all, and a few links.
struct SettingsView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [JournalEntry]
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                aboutSection
                appearanceSection
                dataSection
                authSection
                linksSection
                creditsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(ReflectTheme.rounded(16, weight: .semibold))
                        .foregroundStyle(ReflectTheme.accent)
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

    private var authSection: some View {
        Section("Account") {
            Button(role: .destructive) {
                Task {
                    try? await services.authService.signOut()
                    dismiss()
                }
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                    Text("Sign out")
                        .font(ReflectTheme.rounded(15))
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version").font(ReflectTheme.rounded(15))
                Spacer()
                Text(appVersion).font(ReflectTheme.mono(14)).foregroundStyle(ReflectTheme.textMuted)
            }
            HStack {
                Text("Total reflections").font(ReflectTheme.rounded(15))
                Spacer()
                Text("\(entries.count)").font(ReflectTheme.mono(14)).foregroundStyle(ReflectTheme.textMuted)
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Toggle(isOn: $isDarkMode) {
                HStack {
                    Image(systemName: "moon.fill").font(.system(size: 14))
                    Text("Dark mode").font(ReflectTheme.rounded(15))
                }
            }
            .tint(ReflectTheme.accent)
        }
    }

    private var dataSection: some View {
        Section {
            Button(role: .destructive) { showClearConfirmation = true } label: {
                HStack {
                    Image(systemName: "trash").font(.system(size: 14))
                    Text("Clear all reflections").font(ReflectTheme.rounded(15))
                }
            }
        } header: { Text("Data") }
        footer: { Text("Permanently deletes every journal entry.").font(ReflectTheme.rounded(12)) }
    }

    private var linksSection: some View {
        Section("Links") {
            Link(destination: URL(string: "https://github.com")!) {
                HStack {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(ReflectTheme.textPrimary)
                    Text("Source code")
                        .font(ReflectTheme.rounded(15))
                        .foregroundStyle(ReflectTheme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11))
                        .foregroundStyle(ReflectTheme.textMuted)
                }
            }
        }
    }

    private var creditsSection: some View {
        Section {
            VStack(spacing: ReflectTheme.spacingSM) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28))
                    .foregroundStyle(ReflectTheme.accent)
                Text("Reflect")
                    .font(ReflectTheme.serif(18, weight: .semibold))
                    .foregroundStyle(ReflectTheme.textPrimary)
                Text("Your mind, untangled.")
                    .font(ReflectTheme.rounded(13))
                    .foregroundStyle(ReflectTheme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ReflectTheme.spacingMD)
            .listRowBackground(Color.clear)
        }
    }

    private func clearAll() {
        for entry in entries {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
