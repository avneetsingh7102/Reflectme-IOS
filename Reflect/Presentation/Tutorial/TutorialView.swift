import SwiftUI

/// 4-step onboarding carousel matching the Reflect Mobile design.
///
/// Each step shows: kicker eyebrow ("01 · SPEAK"), serif H1, body paragraph,
/// step-specific illustration, dot indicator (current dot stretches to a pill),
/// and a dark CTA ("Next" / "Get started").
struct TutorialView: View {
    @State private var step = 1
    var onFinish: () -> Void = {}

    private struct Step {
        let kicker: String
        let title: String
        let body: String
        let illo: Illustration
    }

    private enum Illustration { case mic, map, cards, patterns }

    private let steps: [Step] = [
        .init(kicker: "01 · Speak",
              title: "Talk it through.",
              body: "Tap the mic and say whatever’s on your mind. No prompts, no formatting — just your voice.",
              illo: .mic),
        .init(kicker: "02 · See",
              title: "Watch it surface.",
              body: "Each thought becomes a node on your map — soft circles that grow and connect as themes return.",
              illo: .map),
        .init(kicker: "03 · Explore",
              title: "Wander your week.",
              body: "Tap any node to see the entries behind it, with quotes pulled from what you actually said.",
              illo: .cards),
        .init(kicker: "04 · Find patterns",
              title: "Notice the shape.",
              body: "When two ideas keep meeting, we’ll draw the line — and explain why.",
              illo: .patterns),
    ]

    var body: some View {
        let s = steps[step - 1]
        ZStack {
            ReflectTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                illustration(for: s.illo)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, ReflectTheme.spacingLG)
                copy(for: s)
                    .padding(.bottom, ReflectTheme.spacingMD)
                indicator
                    .padding(.top, ReflectTheme.spacingLG)
                cta
                    .padding(.top, ReflectTheme.spacingLG)
                    .padding(.bottom, ReflectTheme.spacingXL)
            }
            .padding(.horizontal, ReflectTheme.edge)
        }
    }

    // MARK: - Sub-views

    private var topBar: some View {
        HStack {
            Spacer()
            Button("Skip") { onFinish() }
                .font(ReflectTheme.rounded(14, weight: .medium))
                .foregroundStyle(ReflectTheme.inkSoft)
        }
        .padding(.top, 12)
    }

    private func copy(for s: Step) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(s.kicker)
                .eyebrowStyle(color: ReflectTheme.mustard500)
            Text(s.title)
                .font(.system(size: 32, weight: .medium, design: .serif))
                .foregroundStyle(ReflectTheme.ink)
            Text(s.body)
                .font(ReflectTheme.serif(16))
                .foregroundStyle(ReflectTheme.inkSoft)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var indicator: some View {
        HStack(spacing: 8) {
            ForEach(1...steps.count, id: \.self) { i in
                Capsule()
                    .fill(i == step ? ReflectTheme.primary : ReflectTheme.surface4)
                    .frame(width: i == step ? 22 : 6, height: 6)
                    .animation(ReflectTheme.springSnappy, value: step)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var cta: some View {
        Button(action: advance) {
            Text(step == steps.count ? "Get started" : "Next")
                .font(ReflectTheme.rounded(15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(ReflectTheme.blue700))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Illustrations

    @ViewBuilder
    private func illustration(for kind: Illustration) -> some View {
        switch kind {
        case .mic:
            VStack(spacing: 14) {
                PulsingRing(mode: .listening, size: 160)
                Text("Tap to begin")
                    .eyebrowStyle(color: ReflectTheme.mustard500)
            }
        case .map:        TutorialMiniMap()
        case .cards:      TutorialCardsIllo()
        case .patterns:   TutorialPatternsIllo()
        }
    }

    private func advance() {
        if step >= steps.count { onFinish(); return }
        withAnimation(ReflectTheme.springGentle) { step += 1 }
    }
}

// MARK: - Mini illustrations

private struct TutorialMiniMap: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            // Three curved edges
            let edges: [(CGPoint, CGPoint, CGPoint)] = [
                (CGPoint(x: w * 0.15, y: h * 0.25), CGPoint(x: w * 0.50, y: h * 0.60),
                 CGPoint(x: w * 0.78, y: h * 0.30)),
                (CGPoint(x: w * 0.15, y: h * 0.25), CGPoint(x: w * 0.28, y: h * 0.62),
                 CGPoint(x: w * 0.50, y: h * 0.80)),
                (CGPoint(x: w * 0.78, y: h * 0.30), CGPoint(x: w * 0.60, y: h * 0.60),
                 CGPoint(x: w * 0.50, y: h * 0.80)),
            ]
            for (a, c, b) in edges {
                var p = Path()
                p.move(to: a); p.addQuadCurve(to: b, control: c)
                ctx.stroke(p, with: .color(ReflectTheme.separator), lineWidth: 1)
            }
            // Nodes
            let nodes: [(CGPoint, CGFloat, Color)] = [
                (CGPoint(x: w * 0.15, y: h * 0.25), 22, ReflectTheme.emoCuriosity),
                (CGPoint(x: w * 0.78, y: h * 0.30), 30, ReflectTheme.emoJoy),
                (CGPoint(x: w * 0.50, y: h * 0.80), 26, ReflectTheme.emoSadness),
                (CGPoint(x: w * 0.92, y: h * 0.74), 12, ReflectTheme.emoAnger),
            ]
            for (c, r, color) in nodes {
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.85)))
            }
        }
        .frame(width: 260, height: 220)
    }
}

private struct TutorialCardsIllo: View {
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("INSIGHT").eyebrowStyle(color: ReflectTheme.mustard500)
                Text("Slow mornings")
                    .font(ReflectTheme.serif(20, weight: .medium))
                    .foregroundStyle(ReflectTheme.ink)
                Text("“The lull between coffee and the first task is when most real thinking happens.”")
                    .font(ReflectTheme.serif(13))
                    .foregroundStyle(ReflectTheme.inkSoft)
                    .lineSpacing(2)
            }
            .padding(16)
            .frame(width: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ReflectTheme.canvas)
                    .shadow(color: ReflectTheme.softShadow, radius: 12, y: 4)
            )
            .rotationEffect(.degrees(-3))
            .offset(x: -22, y: 22)

            VStack(alignment: .leading, spacing: 6) {
                Text("REFLECTION").eyebrowStyle(color: ReflectTheme.blue500)
                Text("The shape of weeks")
                    .font(ReflectTheme.serif(20, weight: .medium))
                    .foregroundStyle(ReflectTheme.ink)
            }
            .padding(16)
            .frame(width: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: ReflectTheme.softShadow, radius: 12, y: 4)
            )
            .rotationEffect(.degrees(2))
            .offset(x: 22, y: -32)
        }
        .frame(width: 280, height: 200)
    }
}

private struct TutorialPatternsIllo: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            // Dashed connecting paths
            let path1Pts = (CGPoint(x: w * 0.23, y: h * 0.70),
                            CGPoint(x: w * 0.50, y: h * 0.30),
                            CGPoint(x: w * 0.77, y: h * 0.65))
            var p1 = Path()
            p1.move(to: path1Pts.0)
            p1.addQuadCurve(to: path1Pts.2, control: path1Pts.1)
            ctx.stroke(p1, with: .color(ReflectTheme.mustard500),
                       style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))

            let path2Pts = (CGPoint(x: w * 0.23, y: h * 0.70),
                            CGPoint(x: w * 0.30, y: h * 0.45),
                            CGPoint(x: w * 0.55, y: h * 0.35))
            var p2 = Path()
            p2.move(to: path2Pts.0)
            p2.addQuadCurve(to: path2Pts.2, control: path2Pts.1)
            ctx.stroke(p2, with: .color(ReflectTheme.blue300),
                       style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))

            // Three filled nodes
            let nodes: [(CGPoint, CGFloat, Color)] = [
                (CGPoint(x: w * 0.23, y: h * 0.70), 22, ReflectTheme.emoGratitude),
                (CGPoint(x: w * 0.55, y: h * 0.35), 28, ReflectTheme.emoJoy),
                (CGPoint(x: w * 0.77, y: h * 0.65), 20, ReflectTheme.emoSadness),
            ]
            for (c, r, color) in nodes {
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.85)))
            }
            // Center "growth" label
            ctx.draw(Text("growth")
                        .font(ReflectTheme.rounded(11, weight: .semibold))
                        .foregroundStyle(ReflectTheme.ink),
                     at: CGPoint(x: w * 0.50, y: h * 0.52))
        }
        .frame(width: 240, height: 200)
    }
}
