import SwiftUI
import UIKit

enum OnboardingStyle {
    static let spring     = Animation.spring(response: 0.55, dampingFraction: 0.78)
    static let softSpring = Animation.spring(response: 0.90, dampingFraction: 0.85)
    static let snappy     = Animation.spring(response: 0.32, dampingFraction: 0.68)

    static let entranceDelay: Double = 0.12
    static let stagger: Double       = 0.12

    static let drawDuration: Double  = 1.1
    static let floatDuration: Double = 2.4
    static let floatDistance: CGFloat = 6

    static let tileSize: CGFloat = 120
    static let pageSideInset: CGFloat = 32

    static let parallaxStrength: CGFloat = 60
}

enum OnboardingHaptics {
    static func tick() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private struct OnboardingParallaxKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var onboardingParallax: CGFloat {
        get { self[OnboardingParallaxKey.self] }
        set { self[OnboardingParallaxKey.self] = newValue }
    }
}

private struct ParallaxModifier: ViewModifier {
    let depth: CGFloat
    @Environment(\.onboardingParallax) private var pageOffset
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.offset(x: reduceMotion ? 0 : -pageOffset * OnboardingStyle.parallaxStrength * depth)
    }
}

private struct RevealModifier: ViewModifier {
    let isActive: Bool
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animation: Animation {
        guard isActive else { return .easeOut(duration: 0.12) }
        if reduceMotion { return .easeInOut(duration: 0.25) }
        let delay = OnboardingStyle.entranceDelay + Double(index) * OnboardingStyle.stagger
        return OnboardingStyle.spring.delay(delay)
    }

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .offset(y: (isActive || reduceMotion) ? 0 : 18)
            .animation(animation, value: isActive)
    }
}

extension View {
    func reveal(_ isActive: Bool, index: Int = 0) -> some View {
        modifier(RevealModifier(isActive: isActive, index: index))
    }

    func parallax(depth: CGFloat = 1) -> some View {
        modifier(ParallaxModifier(depth: depth))
    }
}

struct AppTile: View {
    let symbol: String
    var size: CGFloat = OnboardingStyle.tileSize
    var tint: Color = .accentColor

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
            .fill(LinearGradient(colors: [tint, tint.opacity(0.65)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundColor(.white)
            )
            .shadow(color: tint.opacity(0.35), radius: size * 0.14, x: 0, y: size * 0.07)
    }
}

struct OnboardingHeadline: View {
    let title: String
    let subtitle: String
    let isActive: Bool

    var startIndex: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.75)
                .lineLimit(2)
                .reveal(isActive, index: startIndex)

            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .reveal(isActive, index: startIndex + 1)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, OnboardingStyle.pageSideInset)
    }
}

struct MiniAppRow: View {
    var symbol: String = "gamecontroller.fill"
    var name: String = "My Game"
    var detail: String = "com.example.mygame"
    var tint: Color = .orange
    var highlighted: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            AppTile(symbol: symbol, size: 40, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.accentColor.opacity(highlighted ? 0.6 : 0), lineWidth: 2)
        )
        .scaleEffect(highlighted ? 0.97 : 1)
    }
}

struct ZipBadge: View {
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "doc.zipper")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.accentColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

struct FingerDot: View {
    var pressed: Bool = false

    var body: some View {
        Circle()
            .fill(Color.primary.opacity(0.16))
            .overlay(Circle().stroke(Color.primary.opacity(0.35), lineWidth: 1.5))
            .frame(width: 34, height: 34)
            .scaleEffect(pressed ? 0.82 : 1)
    }
}

struct TapRipple: View {
    var progress: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor, lineWidth: 3)
                .frame(width: 44, height: 44)
                .scaleEffect(0.5 + progress * 1.1)
                .opacity(Double(1 - progress))
            FingerDot(pressed: progress > 0 && progress < 0.3)
        }
    }
}

struct HoldRing: View {
    var progress: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            FingerDot(pressed: progress > 0)
        }
        .frame(width: 56, height: 56)
    }
}

enum OnboardingTimeline {
    static func sleep(_ seconds: Double) async -> Bool {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return !Task.isCancelled
    }

    @MainActor
    static func snap(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }
}
