import SwiftUI

enum MascotMood: Equatable {
    case idle, happy, excited, thinking, shush, worried
}

/// Hush's mascot: a round violet creature that shushes. Drawn in SwiftUI with
/// a small state machine (moods), continuous breathing and blinking, and a
/// squash-and-stretch hop on every reaction, in the spirit of a Rive rig.
/// With Reduce Motion on it holds still and only changes expression.
struct MascotView: View {
    var mood: MascotMood = .idle
    var size: CGFloat = 120
    /// Where the eyes look, each axis -1...1.
    var look: CGSize = .zero
    /// Change this to make the mascot react without changing mood.
    var reaction = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blinking = false
    @State private var hop: CGFloat = 0
    @State private var squash: CGFloat = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let breathe = 1 + 0.025 * sin(t * 2.4)
            let bob = size * 0.025 * sin(t * 1.6)
            ZStack {
                shadow(lift: hop)
                creature
                    .scaleEffect(x: 1 / (squash * breathe), y: squash * breathe, anchor: .bottom)
                    .offset(y: bob + hop)
                    .rotationEffect(.degrees(mood == .thinking ? -6 : 0))
                if mood == .excited {
                    sparkles(t: t)
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: mood)
        .onChange(of: mood) { _, newMood in react(to: newMood) }
        .onChange(of: reaction) { _, _ in react(to: mood) }
        .task { await blinkForever() }
        .accessibilityHidden(true)
    }

    // MARK: Drawing

    private var creature: some View {
        let s = size
        return ZStack {
            // Ears
            HStack(spacing: s * 0.34) {
                Ellipse().fill(Theme.primaryShade).frame(width: s * 0.2, height: s * 0.26)
                Ellipse().fill(Theme.primaryShade).frame(width: s * 0.2, height: s * 0.26)
            }
            .offset(y: -s * 0.3)

            // Body
            RoundedRectangle(cornerRadius: s * 0.4, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x9C86FF), Theme.primary], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.84, height: s * 0.76)
                .overlay(alignment: .top) {
                    // Soft highlight for volume
                    Ellipse()
                        .fill(.white.opacity(0.25))
                        .frame(width: s * 0.42, height: s * 0.12)
                        .offset(x: -s * 0.12, y: s * 0.06)
                }
                .offset(y: s * 0.06)

            // Belly
            Ellipse()
                .fill(.white.opacity(0.18))
                .frame(width: s * 0.5, height: s * 0.28)
                .offset(y: s * 0.26)

            // Cheeks
            HStack(spacing: s * 0.42) {
                Ellipse().fill(Color(hex: 0xFF8FB1).opacity(0.6)).frame(width: s * 0.12, height: s * 0.07)
                Ellipse().fill(Color(hex: 0xFF8FB1).opacity(0.6)).frame(width: s * 0.12, height: s * 0.07)
            }
            .offset(y: s * 0.12)

            eyes.offset(y: -s * 0.02)
            mouth.offset(y: s * 0.17)

            if mood == .shush {
                // A paw raised to the lips: "shh".
                Capsule()
                    .fill(Color(hex: 0xC9BCFF))
                    .overlay(Capsule().stroke(Theme.primaryShade.opacity(0.5), lineWidth: s * 0.012))
                    .frame(width: s * 0.09, height: s * 0.22)
                    .offset(x: s * 0.02, y: s * 0.16)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var eyes: some View {
        let s = size
        HStack(spacing: s * 0.14) {
            eye
            eye
        }
        .offset(x: look.width * s * 0.03, y: (mood == .thinking ? -0.5 : look.height) * s * 0.03)
    }

    @ViewBuilder
    private var eye: some View {
        let s = size
        switch mood {
        case .happy, .shush:
            // Content, closed "^" eyes.
            ArcShape(bulgeUp: true)
                .stroke(Color(hex: 0x24184F), style: StrokeStyle(lineWidth: s * 0.04, lineCap: .round))
                .frame(width: s * 0.14, height: s * 0.07)
                .frame(width: s * 0.18, height: s * 0.22)
        default:
            ZStack {
                Ellipse().fill(.white)
                Circle()
                    .fill(Color(hex: 0x24184F))
                    .frame(width: s * (mood == .excited ? 0.12 : 0.1))
                    .overlay(Circle().fill(.white).frame(width: s * 0.03).offset(x: s * 0.02, y: -s * 0.02))
                    .offset(x: look.width * s * 0.025, y: (mood == .worried ? 0.4 : look.height) * s * 0.03)
            }
            .frame(width: s * 0.18, height: s * 0.22)
            .scaleEffect(y: blinking ? 0.08 : 1)
            .overlay(alignment: .top) {
                if mood == .worried {
                    // Tilted brow
                    Capsule()
                        .fill(Color(hex: 0x24184F))
                        .frame(width: s * 0.14, height: s * 0.03)
                        .rotationEffect(.degrees(-12))
                        .offset(y: -s * 0.05)
                }
            }
        }
    }

    @ViewBuilder
    private var mouth: some View {
        let s = size
        let ink = Color(hex: 0x24184F)
        switch mood {
        case .idle:
            ArcShape(bulgeUp: false)
                .stroke(ink, style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                .frame(width: s * 0.16, height: s * 0.06)
        case .happy, .excited:
            OpenSmile()
                .fill(ink)
                .overlay(alignment: .bottom) {
                    Ellipse().fill(Color(hex: 0xFF7A9A)).frame(width: s * 0.1, height: s * 0.05)
                }
                .clipShape(OpenSmile())
                .frame(width: s * (mood == .excited ? 0.24 : 0.2), height: s * 0.11)
        case .thinking:
            Circle()
                .stroke(ink, lineWidth: s * 0.03)
                .frame(width: s * 0.06)
                .offset(x: s * 0.05)
        case .shush:
            Capsule().fill(ink).frame(width: s * 0.1, height: s * 0.03)
        case .worried:
            ArcShape(bulgeUp: true)
                .stroke(ink, style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                .frame(width: s * 0.14, height: s * 0.05)
        }
    }

    private func shadow(lift: CGFloat) -> some View {
        Ellipse()
            .fill(Theme.primaryShade.opacity(0.18))
            .frame(width: size * 0.6 * (1 + lift / size), height: size * 0.07)
            .offset(y: size * 0.47)
    }

    private func sparkles(t: Double) -> some View {
        ForEach(0..<3, id: \.self) { index in
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.12, weight: .bold))
                .foregroundStyle(Theme.warning)
                .scaleEffect(sparkleScale(index: index, t: t))
                .offset(sparkleOffset(index: index, t: t))
        }
    }

    private func sparkleScale(index: Int, t: Double) -> CGFloat {
        CGFloat(0.7 + 0.3 * sin(t * 4 + Double(index)))
    }

    private func sparkleOffset(index: Int, t: Double) -> CGSize {
        let angle = Double(index) * 2.1 + t * 1.5
        let x = CGFloat(cos(angle)) * size * 0.55
        let y = CGFloat(sin(angle)) * size * 0.4 - size * 0.1
        return CGSize(width: x, height: y)
    }

    // MARK: Motion

    /// Squash, hop, land: the classic bounce.
    private func react(to mood: MascotMood) {
        guard !reduceMotion else { return }
        let height: CGFloat = switch mood {
        case .excited: 0.22
        case .happy, .shush: 0.14
        default: 0.05
        }
        withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) { squash = 0.86 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
                squash = 1.08
                hop = -size * height
            }
            try? await Task.sleep(nanoseconds: 240_000_000)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) {
                squash = 1
                hop = 0
            }
        }
    }

    private func blinkForever() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64.random(in: 2_200_000_000...4_800_000_000))
            guard !reduceMotion else { continue }
            withAnimation(.easeIn(duration: 0.07)) { blinking = true }
            try? await Task.sleep(nanoseconds: 110_000_000)
            withAnimation(.easeOut(duration: 0.09)) { blinking = false }
        }
    }
}

/// A gentle arc: "^" when `bulgeUp`, a smile when not.
private struct ArcShape: Shape {
    var bulgeUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let edgeY = bulgeUp ? rect.maxY : rect.minY
        path.move(to: CGPoint(x: rect.minX, y: edgeY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: edgeY),
            control: CGPoint(x: rect.midX, y: bulgeUp ? rect.minY - rect.height : rect.maxY + rect.height)
        )
        return path
    }
}

/// A "D" lying on its back: an open, laughing mouth.
private struct OpenSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2))
        path.closeSubpath()
        return path
    }
}
