import SwiftUI
@preconcurrency import SwiftData

/// Slide-in side menu per design: profile header, single primary nav item
/// ("Journal" active = mustard-50 background), secondary nav items below,
/// then a blue-700 streak card pinned to the bottom (real consecutive-day
/// math from the user's actual entries).
struct SideMenuView: View {
    @Binding var showSettings: Bool

    @Environment(ServiceContainer.self) private var services
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var showTutorial = false
    @State private var showColorGuide = false
    @State private var showPrivacy = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                profileHeader
                    .padding(.top, 60)
                    .padding(.horizontal, ReflectTheme.edge)
                    .padding(.bottom, 20)

                Divider().background(ReflectTheme.separator)
                    .padding(.horizontal, ReflectTheme.edge)

                navItems
                    .padding(.horizontal, 12)
                    .padding(.top, 14)

                Spacer()

                streakCard
                    .padding(.horizontal, ReflectTheme.edge)
                    .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReflectTheme.canvas.ignoresSafeArea())
            .navigationDestination(isPresented: $showTutorial)  { TutorialView() }
            .navigationDestination(isPresented: $showColorGuide) { ColorGuideView() }
            .navigationDestination(isPresented: $showPrivacy)    { PrivacyView() }
        }
    }

    // MARK: - Sub-views

    private var profileHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [ReflectTheme.mustard300, ReflectTheme.rust],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 4,
                        endRadius: 48
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Text(userInitial)
                        .font(ReflectTheme.serif(18, weight: .medium))
                        .foregroundStyle(.white)
                )
                .shadow(color: ReflectTheme.softShadow, radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(userDisplayName)
                    .font(ReflectTheme.serif(17, weight: .medium))
                    .foregroundStyle(ReflectTheme.ink)
                Text(userSubtitle)
                    .font(ReflectTheme.rounded(12))
                    .foregroundStyle(ReflectTheme.inkSoft)
            }
        }
    }

    private var navItems: some View {
        VStack(spacing: 2) {
            NavItem(icon: "book.closed", label: "Journal", active: true) { }
            NavItem(icon: "safari", label: "Tutorial") { showTutorial = true }
            NavItem(icon: "paintpalette", label: "Color guide") { showColorGuide = true }
            NavItem(icon: "gear", label: "Settings") { showSettings = true }
        }
    }

    private var streakCard: some View {
        let streak = currentStreak
        let total = entries.count
        return VStack(alignment: .leading, spacing: 8) {
            Text("Streak")
                .eyebrowStyle(color: ReflectTheme.mustard300)

            (Text("\(streak) day\(streak == 1 ? "" : "s")\n").foregroundStyle(.white)
            + Text(streak > 0 ? "of returning." : "to begin.")
                .italic()
                .foregroundStyle(ReflectTheme.mustard300))
                .font(ReflectTheme.serif(24, weight: .medium))
                .lineSpacing(2)

            Text("\(total) total reflection\(total == 1 ? "" : "s")")
                .font(ReflectTheme.rounded(11))
                .foregroundStyle(Color.white.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ReflectTheme.blue700)
        )
    }

    // MARK: - Streak math

    /// Number of consecutive calendar days (ending today, or yesterday if the
    /// user hasn't journalled yet today) with at least one entry. Zero if
    /// the user has never journalled or hasn't done so for >1 day.
    private var currentStreak: Int {
        guard !entries.isEmpty else { return 0 }
        let cal = Calendar.current
        let entryDays = Set(entries.map { cal.startOfDay(for: $0.date) })

        var cursor = cal.startOfDay(for: Date())
        if !entryDays.contains(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            if !entryDays.contains(cursor) { return 0 }
        }

        var streak = 0
        while entryDays.contains(cursor) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    // MARK: - Identity

    private var userDisplayName: String {
        if services.authService.isLocalBypass { return "Local mode" }
        if let id = services.authService.currentUserID {
            return "Reflector · " + String(id.prefix(6))
        }
        return "Guest"
    }

    private var userSubtitle: String {
        if services.authService.isLocalBypass { return "Not signed in" }
        return services.authService.isAuthenticated ? "Signed in" : "Sign in to sync"
    }

    private var userInitial: String {
        services.authService.isAuthenticated ? "R" : "·"
    }
}

private struct NavItem: View {
    let icon: String
    let label: String
    var active: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(active ? ReflectTheme.mustard700 : ReflectTheme.inkSoft)
                    .frame(width: 28)
                Text(label)
                    .font(ReflectTheme.rounded(15, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? ReflectTheme.mustard700 : ReflectTheme.ink)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(active ? ReflectTheme.mustard50 : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
