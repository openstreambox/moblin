import SwiftUI

// The look of the rig screens. With the OSB_BRAND build condition (set in
// Config/Fork.xcconfig) they use the OpenStreamBox look: paper and forest
// ink, the latch-case mark, and a status drawn as a shape, a word and a
// colour together. Without it they use the system's own colours.
//
// Rules of the look:
// - Copper is the latch in the mark and nothing else.
// - Status colours are for status only. HIDE is a heavy outline in the text
// - Flat: hairline borders, small corners, no shadows.

private func themed(light: UInt32, dark: UInt32, system: UIColor) -> Color {
    #if OSB_BRAND
    Color(uiColor: UIColor { traits in
        let hex = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                       green: CGFloat((hex >> 8) & 0xFF) / 255,
                       blue: CGFloat(hex & 0xFF) / 255,
                       alpha: 1)
    })
    #else
    Color(uiColor: system)
    #endif
}

enum HubLook {
    // Light is "paper", dark is "ink".
    static let background = themed(light: 0xF4F1E8, dark: 0x14211E, system: .systemGroupedBackground)
    static let surface = themed(light: 0xFFFCF5, dark: 0x1D302A, system: .secondarySystemGroupedBackground)
    static let surfaceMuted = themed(light: 0xE9E5D9, dark: 0x263C35, system: .tertiarySystemGroupedBackground)
    static let text = themed(light: 0x172320, dark: 0xF4F1E8, system: .label)
    static let textMuted = themed(light: 0x53635C, dark: 0xBCCBC2, system: .secondaryLabel)
    static let border = themed(light: 0xCCD2C8, dark: 0x54675C, system: .separator)
    static let borderStrong = themed(light: 0x7E8B84, dark: 0x6B8073, system: .opaqueSeparator)
    static let decision = themed(light: 0x172320, dark: 0xF4F1E8, system: .label)
    static let onDecision = themed(light: 0xFFFCF5, dark: 0x14211E, system: .systemBackground)
    static let latch = themed(light: 0xA63F20, dark: 0xFFAF88, system: .systemOrange)
    static let live = themed(light: 0xE5484D, dark: 0xFF6B62, system: .systemRed)
    static let steady = themed(light: 0x246442, dark: 0x93D6A7, system: .systemGreen)
    static let caution = themed(light: 0x805100, dark: 0xF0C56D, system: .systemOrange)
    static let urgent = themed(light: 0xA32B35, dark: 0xFF9DA6, system: .systemRed)

    // Over the camera picture, which is dark whatever the theme is.
    static let liveOnVideo = Color(red: 1, green: 0.42, blue: 0.38)
    static let steadyOnVideo = Color(red: 0.58, green: 0.84, blue: 0.65)
    static let cautionOnVideo = Color(red: 0.94, green: 0.77, blue: 0.43)
    static let urgentOnVideo = Color(red: 1, green: 0.62, blue: 0.65)

    static let radiusControl: CGFloat = 6
    static let radiusCard: CGFloat = 8
    static let hairline: CGFloat = 1
    static let heavy: CGFloat = 2
    static let minTouchTarget: CGFloat = 44
    static let stack: CGFloat = 12
    static let screenEdge: CGFloat = 16

    // Section labels: small capitals in the mono face.
    static let label = Font.caption.monospaced().weight(.semibold)
    // Codes, counts and measurements.
    static let number = Font.body.monospaced()

    static func color(_ kind: HubStatusKind) -> Color {
        switch kind {
        case .live:
            live
        case .connected:
            steady
        case .connecting, .unknown, .ready:
            textMuted
        case .hidden:
            text
        case .caution:
            caution
        case .problem:
            urgent
        }
    }

    static func colorOnVideo(_ kind: HubStatusKind) -> Color {
        switch kind {
        case .live:
            liveOnVideo
        case .connected:
            steadyOnVideo
        case .caution:
            cautionOnVideo
        case .problem:
            urgentOnVideo
        case .unknown:
            .gray
        case .connecting, .hidden, .ready:
            .white
        }
    }
}

// The shape half of a status, drawn in a 12-unit box. The word beside it
// carries the meaning for VoiceOver, so the shape itself is hidden from it.
struct HubStatusShape: Shape {
    let kind: HubStatusKind

    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 12
        var path = Path()
        func ring() {
            path.addEllipse(in: CGRect(x: 1.4, y: 1.4, width: 9.2, height: 9.2))
            path.addEllipse(in: CGRect(x: 3, y: 3, width: 6, height: 6))
        }
        switch kind {
        case .live:
            path.addEllipse(in: CGRect(x: 1, y: 1, width: 10, height: 10))
        case .connected:
            path.move(to: CGPoint(x: 6, y: 0.5))
            path.addLine(to: CGPoint(x: 11.5, y: 6))
            path.addLine(to: CGPoint(x: 6, y: 11.5))
            path.addLine(to: CGPoint(x: 0.5, y: 6))
            path.closeSubpath()
        case .connecting:
            ring()
            path.addEllipse(in: CGRect(x: 4.7, y: 4.7, width: 2.6, height: 2.6))
        case .ready:
            ring()
        case .hidden:
            ring()
            path.move(to: CGPoint(x: 6, y: 3))
            path.addArc(center: CGPoint(x: 6, y: 6),
                        radius: 3,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(90),
                        clockwise: false)
            path.closeSubpath()
        case .caution:
            path.move(to: CGPoint(x: 6, y: 0.8))
            path.addLine(to: CGPoint(x: 11.6, y: 11))
            path.addLine(to: CGPoint(x: 0.4, y: 11))
            path.closeSubpath()
        case .problem:
            path.addRect(CGRect(x: 1, y: 1, width: 10, height: 10))
        case .unknown:
            // A ring struck through: the disc with two segments cut out.
            path.addEllipse(in: CGRect(x: 1.4, y: 1.4, width: 9.2, height: 9.2))
            path.move(to: CGPoint(x: 7.65, y: 3.5))
            path.addArc(center: CGPoint(x: 6, y: 6),
                        radius: 3,
                        startAngle: .degrees(-56.6),
                        endAngle: .degrees(146.6),
                        clockwise: true)
            path.closeSubpath()
            path.move(to: CGPoint(x: 4.35, y: 8.5))
            path.addArc(center: CGPoint(x: 6, y: 6),
                        radius: 3,
                        startAngle: .degrees(123.4),
                        endAngle: .degrees(-33.4),
                        clockwise: true)
            path.closeSubpath()
        }
        let side = unit * 12
        return path
            .applying(CGAffineTransform(scaleX: unit, y: unit))
            .applying(CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2))
    }
}

struct HubStatusMarkView: View {
    let kind: HubStatusKind
    var onVideo = false
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 14

    var body: some View {
        HubStatusShape(kind: kind)
            .fill(onVideo ? HubLook.colorOnVideo(kind) : HubLook.color(kind), style: FillStyle(eoFill: true))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// The latch case: a case with a handle and a lid seam split by one latch.
// Under 32 points it uses the heavier cut.
private struct HubMarkCase: Shape {
    let small: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if small {
            path.move(to: CGPoint(x: 23, y: 18.5))
            path.addLine(to: CGPoint(x: 23, y: 10.5))
            path.addLine(to: CGPoint(x: 41, y: 10.5))
            path.addLine(to: CGPoint(x: 41, y: 18.5))
            path.addRoundedRect(in: CGRect(x: 8.5, y: 18.5, width: 47, height: 35),
                                cornerSize: CGSize(width: 4, height: 4))
            path.move(to: CGPoint(x: 8.5, y: 31))
            path.addLine(to: CGPoint(x: 27.5, y: 31))
            path.move(to: CGPoint(x: 36.5, y: 31))
            path.addLine(to: CGPoint(x: 55.5, y: 31))
        } else {
            path.move(to: CGPoint(x: 23, y: 18))
            path.addLine(to: CGPoint(x: 23, y: 12))
            path.addArc(tangent1End: CGPoint(x: 23, y: 10), tangent2End: CGPoint(x: 25, y: 10), radius: 2)
            path.addLine(to: CGPoint(x: 39, y: 10))
            path.addArc(tangent1End: CGPoint(x: 41, y: 10), tangent2End: CGPoint(x: 41, y: 12), radius: 2)
            path.addLine(to: CGPoint(x: 41, y: 18))
            path.addRoundedRect(in: CGRect(x: 8, y: 18, width: 48, height: 36),
                                cornerSize: CGSize(width: 4, height: 4))
            path.move(to: CGPoint(x: 8, y: 31))
            path.addLine(to: CGPoint(x: 28, y: 31))
            path.move(to: CGPoint(x: 36, y: 31))
            path.addLine(to: CGPoint(x: 56, y: 31))
        }
        return path.applying(CGAffineTransform(scaleX: rect.width / 64, y: rect.height / 64))
    }
}

private struct HubMarkLatch: Shape {
    let small: Bool

    func path(in rect: CGRect) -> Path {
        let latch = small
            ? CGRect(x: 27.5, y: 25, width: 9, height: 17)
            : CGRect(x: 28, y: 26, width: 8, height: 15)
        return Path(roundedRect: latch, cornerRadius: 1)
            .applying(CGAffineTransform(scaleX: rect.width / 64, y: rect.height / 64))
    }
}

struct HubMarkView: View {
    let size: CGFloat

    var body: some View {
        #if OSB_BRAND
        let small = size < 32
        ZStack {
            HubMarkCase(small: small)
                .stroke(HubLook.text, lineWidth: (small ? 5 : 4) * size / 64)
            HubMarkLatch(small: small)
                .fill(HubLook.latch)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        #else
        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
            .font(.system(size: size * 0.7))
            .foregroundStyle(HubLook.text)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        #endif
    }
}

struct HubDecisionButtonStyle: ButtonStyle {
    var filled = true
    @Environment(\.isEnabled) private var enabled

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if filled {
            filledBody(configuration)
        } else {
            HubOutlineButtonStyle().makeBody(configuration: configuration)
        }
    }

    private func filledBody(_ configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(HubLook.onDecision)
            .frame(maxWidth: .infinity, minHeight: HubLook.minTouchTarget)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(HubLook.decision, in: RoundedRectangle(cornerRadius: HubLook.radiusControl))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .contentShape(Rectangle())
    }
}

// Everything else: outlined, in the text colour.
struct HubOutlineButtonStyle: ButtonStyle {
    var heavy = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(HubLook.text)
            .frame(maxWidth: .infinity, minHeight: HubLook.minTouchTarget)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(configuration.isPressed ? HubLook.surfaceMuted : HubLook.surface,
                        in: RoundedRectangle(cornerRadius: HubLook.radiusControl))
            .overlay(
                RoundedRectangle(cornerRadius: HubLook.radiusControl)
                    .strokeBorder(heavy ? HubLook.text : HubLook.borderStrong,
                                  lineWidth: heavy ? HubLook.heavy : HubLook.hairline)
            )
            .opacity(enabled ? 1 : 0.4)
            .contentShape(Rectangle())
    }
}

struct HubEyeOffView: View {
    var body: some View {
        Image(systemName: "eye.slash")
            .font(.headline.weight(.bold))
            .accessibilityHidden(true)
    }
}

struct HubHideFace: View {
    let control: HubHideControl

    private var color: Color {
        control.disabled ? HubLook.textMuted : HubLook.text
    }

    private var border: Color {
        control.disabled ? HubLook.border : HubLook.text
    }

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: HubLook.heavy, dash: control.requested ? [6, 4] : [])
    }

    var body: some View {
        HStack(spacing: 8) {
            HubEyeOffView()
            Text(control.word)
                .font(.headline)
                .tracking(control.face == .action ? 1 : 0)
        }
        .foregroundStyle(color)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: HubLook.minTouchTarget)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(control.face == .state || control.disabled ? HubLook.surfaceMuted : HubLook.surface,
                    in: RoundedRectangle(cornerRadius: HubLook.radiusControl))
        .overlay(
            RoundedRectangle(cornerRadius: HubLook.radiusControl)
                .inset(by: HubLook.heavy / 2)
                .stroke(border, style: stroke)
        )
        .contentShape(Rectangle())
    }
}

struct HubPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct HubSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(HubLook.label)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(HubLook.textMuted)
            .accessibilityAddTraits(.isHeader)
    }
}

// A flat card: surface, hairline border, small corners.
struct HubCard<Content: View>: View {
    var muted = false
    var heavy = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(muted ? HubLook.surfaceMuted : HubLook.surface,
                    in: RoundedRectangle(cornerRadius: HubLook.radiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: HubLook.radiusCard)
                .strokeBorder(heavy ? HubLook.text : HubLook.border,
                              lineWidth: heavy ? HubLook.heavy : HubLook.hairline)
        )
    }
}

// A status in full: its shape, the headline and the lines under it. Read
// by VoiceOver as one element.
struct HubStatusView: View {
    let status: HubStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HubStatusMarkView(kind: status.kind)
                Text(status.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let line = status.line {
                Text(line)
                    .font(.body)
                    .foregroundStyle(HubLook.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let phone = status.phone {
                Text(phone)
                    .font(.subheadline)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let note = status.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.spoken)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// Asked for, not confirmed by the hub yet.
struct HubUnconfirmedView: View {
    let title: String
    var line: String?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ProgressView()
                .tint(HubLook.textMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let line {
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(HubLook.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: HubLook.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// Confirmed by the hub's own report.
struct HubConfirmedView: View {
    let kind: HubStatusKind
    let title: String
    var line: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HubStatusMarkView(kind: kind)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let line {
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(HubLook.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// The quiet line under a button: what it does and what it costs.
struct HubHintView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(HubLook.textMuted)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }
}
