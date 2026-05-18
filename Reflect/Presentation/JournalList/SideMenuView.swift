import SwiftUI

/// Slide-in side menu: tutorial, colour guide, privacy, settings.
struct SideMenuView: View {
    @Binding var showSettings: Bool
    @State private var showTutorial = false
    @State private var showColorGuide = false
    @State private var showPrivacy = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                profileHeader
                Divider().background(ReflectTheme.separator)
                menuList
                Spacer()
                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReflectTheme.canvas)
            .navigationDestination(isPresented: $showTutorial) { TutorialView() }
            .navigationDestination(isPresented: $showColorGuide) { ColorGuideView() }
            .navigationDestination(isPresented: $showPrivacy) { PrivacyView() }
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(ReflectTheme.accent)
            Text("Your reflections")
                .font(ReflectTheme.serif(24, weight: .bold))
                .foregroundStyle(ReflectTheme.textPrimary)
            Text("Voice-first journaling")
                .font(ReflectTheme.rounded(13, weight: .medium))
                .foregroundStyle(ReflectTheme.textMuted)
        }
        .padding(.top, 60)
        .padding(.horizontal, ReflectTheme.spacingLG)
        .padding(.bottom, ReflectTheme.spacingXL)
    }

    private var menuList: some View {
        VStack(alignment: .leading, spacing: 20) {
            MenuRow(icon: "questionmark.circle", title: "How it works") { showTutorial = true }
            MenuRow(icon: "paintpalette", title: "Colour guide") { showColorGuide = true }
            MenuRow(icon: "lock.shield", title: "Data & privacy") { showPrivacy = true }
            MenuRow(icon: "gearshape", title: "Settings") { showSettings = true }
        }
        .padding(.horizontal, ReflectTheme.spacingLG)
        .padding(.vertical, ReflectTheme.spacingXL)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ReflectMe iOS v1.0.2")
                .font(ReflectTheme.mono(12, weight: .semibold))
                .foregroundStyle(ReflectTheme.textMuted)
            Text("Built with care")
                .font(ReflectTheme.rounded(12))
                .foregroundStyle(ReflectTheme.textMuted.opacity(0.8))
        }
        .padding(.horizontal, ReflectTheme.spacingLG)
        .padding(.bottom, 40)
    }
}

private struct MenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(ReflectTheme.textPrimary.opacity(0.8))
                    .frame(width: 24)
                Text(title)
                    .font(ReflectTheme.rounded(17, weight: .medium))
                    .foregroundStyle(ReflectTheme.textPrimary)
                Spacer()
            }
        }
    }
}
