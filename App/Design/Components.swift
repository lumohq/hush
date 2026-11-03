import SwiftUI

// MARK: - Chunky buttons

/// A Duolingo-style button: a solid face sitting on a darker lip that it
/// presses down into.
struct ChunkyButtonStyle: ButtonStyle {
    var fill = Theme.primary
    var shade = Theme.primaryShade
    var foreground = Color.white
    var stroke: Color?

    static let secondary = ChunkyButtonStyle(
        fill: Theme.surface, shade: Theme.borderShade, foreground: Theme.primary, stroke: Theme.border
    )

    func makeBody(configuration: Configuration) -> some View {
        ChunkyButtonBody(configuration: configuration, style: self)
    }
}

private struct ChunkyButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let style: ChunkyButtonStyle
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        // The lip is a background so it never affects layout; the face moves
        // down onto it when pressed.
        configuration.label
            .font(.hushBodyBold)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(isEnabled ? style.foreground : Theme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(shape.fill(isEnabled ? style.fill : Theme.border))
            .overlay(shape.strokeBorder(style.stroke ?? .clear, lineWidth: 2))
            .offset(y: pressed ? Theme.lip : 0)
            .background(shape.fill(isEnabled ? style.shade : Theme.borderShade).offset(y: Theme.lip))
            .padding(.bottom, Theme.lip)
        .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
        .onChange(of: pressed) { _, isPressed in
            if isPressed { Haptics.tap() }
        }
    }
}

/// Chunky card used for tiles and answer options.
struct ChunkyCardStyle: ButtonStyle {
    var isSelected = false
    var tint = Theme.primary

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(isSelected ? tint.opacity(0.12) : Theme.surface))
            .background(shape.fill(Theme.surface))
            .overlay(shape.strokeBorder(isSelected ? tint : Theme.border, lineWidth: 2))
            .offset(y: pressed ? Theme.lip : 0)
            .background(shape.fill(isSelected ? tint : Theme.borderShade).offset(y: Theme.lip))
            .padding(.bottom, Theme.lip)
        .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}

// MARK: - Icons

/// A Fluent Emoji 3D image from the asset catalog, or a two-letter language
/// code where Fluent has no artwork (it has no country flags).
enum AppIcon: Equatable {
    case fluent(String)
    case language(String)
}

struct IconGlyph: View {
    let icon: AppIcon
    let size: CGFloat

    var body: some View {
        Group {
            switch icon {
            case .fluent(let name):
                Image("fluent-\(name)")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            case .language(let code):
                Text(code)
                    .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// An icon on a softly tinted rounded square.
struct IconBadge: View {
    let icon: AppIcon
    var tint = Theme.primary
    var size: CGFloat = 48

    var body: some View {
        IconGlyph(icon: icon, size: size * 0.72)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }
}

// MARK: - Answer option

/// A big tappable answer. Selection is shown by border, tint and a check,
/// never colour alone, and VoiceOver reports it as selected.
struct OptionCard: View {
    let icon: AppIcon
    let title: String
    var subtitle: String?
    var badge: String?
    var tint = Theme.primary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 16) {
                IconBadge(icon: icon, tint: tint)
                VStack(alignment: .leading, spacing: 4) {
                    if let badge {
                        Text(badge)
                            .font(.hushCaption)
                            .foregroundStyle(Theme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Theme.primary.opacity(0.12), in: Capsule())
                    }
                    Text(title)
                        .font(.hushBodyBold)
                        .foregroundStyle(Theme.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(.hushCaption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? tint : Theme.border, lineWidth: 2)
                        .background(Circle().fill(isSelected ? tint : .clear))
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .scaleEffect(isSelected ? 1 : 0.2)
                        .opacity(isSelected ? 1 : 0)
                }
                .frame(width: 28, height: 28)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isSelected)
                .accessibilityHidden(true)
            }
            .padding(16)
        }
        .buttonStyle(ChunkyCardStyle(isSelected: isSelected, tint: tint))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Progress

struct ProgressTrack: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border)
                Capsule()
                    .fill(Theme.success)
                    .frame(width: max(16, geometry.size.width * progress))
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.35))
                            .frame(height: 4)
                            .padding(.horizontal, 8)
                            .padding(.top, 3)
                    }
            }
        }
        .frame(height: 16)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

// MARK: - Speech bubble

/// What the mascot says, typed out a letter at a time.
struct SpeechBubble: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Reserves the final size so the bubble doesn't grow while typing.
            Text(text).hidden()
            Text(String(text.prefix(shown)))
        }
        .font(.hushHeadline)
        .foregroundStyle(Theme.text)
        .padding(16)
        .background(
            BubbleShape()
                .fill(Theme.surface)
                .overlay(BubbleShape().stroke(Theme.border, lineWidth: 2))
        )
        .accessibilityElement()
        .accessibilityLabel(text)
        .task(id: text) {
            if reduceMotion {
                shown = text.count
                return
            }
            shown = 0
            for index in 0...text.count {
                shown = index
                try? await Task.sleep(nanoseconds: 16_000_000)
                if Task.isCancelled { return }
            }
        }
    }
}

/// Rounded bubble with a tail pointing left, towards the mascot.
private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 10
        let body = rect.insetBy(dx: 0, dy: 0)
        var path = Path(roundedRect: CGRect(x: body.minX + tail, y: body.minY, width: body.width - tail, height: body.height),
                        cornerRadius: Theme.cornerRadius, style: .continuous)
        let y = min(body.maxY - 20, body.minY + 28)
        path.move(to: CGPoint(x: body.minX + tail, y: y - 8))
        path.addLine(to: CGPoint(x: body.minX, y: y))
        path.addLine(to: CGPoint(x: body.minX + tail, y: y + 8))
        return path
    }
}

// MARK: - Confetti

/// Celebration burst for the peak moment. Hidden when Reduce Motion is on.
struct ConfettiView: View {
    private struct Piece {
        let x: Double, drift: Double, speed: Double, spin: Double, size: Double, delay: Double
        let color: Color
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    private let pieces: [Piece] = (0..<90).map { _ in
        Piece(
            x: .random(in: 0...1), drift: .random(in: -60...60), speed: .random(in: 220...420),
            spin: .random(in: -6...6), size: .random(in: 6...12), delay: .random(in: 0...0.5),
            color: [Theme.primary, Theme.success, Theme.warning, Theme.noise, Color(hex: 0x4FC3F7)].randomElement()!
        )
    }

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(start)
                Canvas { canvas, size in
                    for piece in pieces {
                        let t = elapsed - piece.delay
                        guard t > 0 else { continue }
                        let y = -20 + piece.speed * t + 0.5 * 160 * t * t
                        guard y < size.height + 20 else { continue }
                        let x = piece.x * size.width + piece.drift * t
                        var local = canvas
                        local.translateBy(x: x, y: y)
                        local.rotate(by: .radians(piece.spin * t))
                        local.fill(
                            Path(roundedRect: CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2), cornerRadius: 2),
                            with: .color(piece.color)
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Noise wave

/// The signature: a busy wave that settles into a calm line, "the internet
/// without the noise". Still when Reduce Motion is on.
struct NoiseWave: View {
    var calm: Bool
    var color = Theme.primary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                WaveShape(phase: phase * 1.4 + 1.3, amplitude: amplitude * 0.6)
                    .stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                WaveShape(phase: phase * 2, amplitude: amplitude)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
        .animation(.easeOut(duration: 1.6), value: calm)
        .accessibilityHidden(true)
    }

    private var amplitude: Double { calm ? 0.06 : 1 }
}

private struct WaveShape: Shape {
    var phase: Double
    var amplitude: Double

    var animatableData: Double {
        get { amplitude }
        set { amplitude = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = max(rect.width, 1)
        for x in stride(from: 0, through: width, by: 2) {
            let t = x / width
            // Layered frequencies read as noise; the envelope pins the ends.
            let noise = 0.55 * sin(2 * .pi * t * 3 + phase)
                + 0.3 * sin(2 * .pi * t * 7 - phase * 1.3)
                + 0.15 * sin(2 * .pi * t * 13 + phase * 2)
            let y = rect.midY + noise * sin(.pi * t) * amplitude * rect.height / 2
            if x == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

// MARK: - Flow layout

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width && !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        rows.append(current)
        return rows
    }
}

/// A rounded tag, used in plan summaries.
struct Chip: View {
    let icon: AppIcon
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            IconGlyph(icon: icon, size: 20)
            Text(title)
        }
        .font(.hushCaption)
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.primary.opacity(0.1), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.primary.opacity(0.2), lineWidth: 1))
    }
}
