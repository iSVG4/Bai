import SwiftUI

struct WelcomePage: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tileShown = false
    @State private var arcProgress: CGFloat = 0
    @State private var floating = false

    private let ringSize = OnboardingStyle.tileSize + 60
    private let finalArc: CGFloat = 0.9

    var body: some View {
        VStack(spacing: 44) {
            Spacer(minLength: 0)

            illustration
                .parallax(depth: 1)

            OnboardingHeadline(
                title: "Welcome to Bai",
                subtitle: "Back up any app\u{2019}s data in one tap, and restore it whenever you need it.",
                isActive: isActive,
                startIndex: 3
            )

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }

        .task(id: isActive) { await update(active: isActive) }
    }

    private var illustration: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.12), lineWidth: 3)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .trim(from: 0, to: arcProgress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)

            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .offset(y: -ringSize / 2)
                .rotationEffect(.degrees(Double(arcProgress) * 360))
                .opacity(arcProgress > 0.01 ? 1 : 0)

            AppTile(symbol: "externaldrive.fill")
                .scaleEffect(tileShown ? 1 : 0.4)
                .opacity(tileShown ? 1 : 0)
                .offset(y: floating ? -OnboardingStyle.floatDistance : 0)
        }
        .frame(width: ringSize + 16, height: ringSize + 16)
        .accessibilityHidden(true)
    }

    @MainActor
    private func update(active: Bool) async {
        guard active else {
            reset()
            return
        }

        if reduceMotion {
            tileShown = true
            arcProgress = finalArc
            return
        }

        withAnimation(OnboardingStyle.spring.delay(0.05)) { tileShown = true }
        withAnimation(.easeInOut(duration: OnboardingStyle.drawDuration).delay(0.35)) {
            arcProgress = finalArc
        }

        let wait = 0.35 + OnboardingStyle.drawDuration
        try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: OnboardingStyle.floatDuration).repeatForever(autoreverses: true)) {
            floating = true
        }
    }

    @MainActor
    private func reset() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tileShown = false
            arcProgress = 0
            floating = false
        }
    }
}
