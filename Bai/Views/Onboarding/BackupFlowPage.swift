import SwiftUI

private typealias TL = OnboardingTimeline

struct BackupFlowPage: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step = 0
    @State private var tap: CGFloat = 0
    @State private var tapTarget = 0
    @State private var fingerOpacity: Double = 0
    @State private var rowPressed = false
    @State private var zipVisible = false
    @State private var zipDropped = false
    @State private var restoredBadge = false

    private let width: CGFloat = 300
    private let height: CGFloat = 160

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)

            VStack(spacing: 22) {
                illustration
                stepChips
            }
            .reveal(isActive)
            .parallax(depth: 1)

            OnboardingHeadline(
                title: "Back up. Restore. Done.",
                subtitle: "Tap an app on the Backup tab to save its data as a zip. Pick that zip on the Restore tab to put it back.",
                isActive: isActive,
                startIndex: 1
            )

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .task(id: isActive) { await run(active: isActive) }
    }

    private var illustration: some View {
        ZStack(alignment: .top) {
            MiniAppRow(highlighted: rowPressed)
                .overlay(
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                        .scaleEffect(restoredBadge ? 1 : 0.3)
                        .opacity(restoredBadge ? 1 : 0)
                        .padding(.trailing, 16),
                    alignment: .trailing
                )
                .frame(width: width)

            VStack(spacing: 6) {
                ZipBadge(size: 52)
                Text("Bai_My Game.zip")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
                    .opacity(zipDropped ? 1 : 0)
            }
            .scaleEffect(zipVisible ? 1 : 0.4)
            .opacity(zipVisible ? 1 : 0)
            .offset(x: zipDropped ? 0 : 96, y: zipDropped ? 88 : 6)

            TapRipple(progress: tap)
                .opacity(fingerOpacity)
                .offset(x: tapTarget == 1 ? -40 : 0, y: tapTarget == 1 ? 10 : 92)
        }
        .frame(width: width, height: height, alignment: .top)
        .accessibilityHidden(true)
    }

    private var stepChips: some View {
        HStack(spacing: 10) {
            StepChip(number: 1, title: "Back up", active: step == 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
            StepChip(number: 2, title: "Restore", active: step == 1)
        }
        .accessibilityHidden(true)
    }

    @MainActor
    private func run(active: Bool) async {
        reset()
        guard active else { return }

        if reduceMotion {
            step = 1
            zipVisible = true
            zipDropped = true
            return
        }

        guard await TL.sleep(0.9) else { return }

        while true {
            withAnimation(.easeInOut(duration: 0.25)) { step = 0 }
            tapOn(1)
            guard await TL.sleep(0.25) else { return }
            withAnimation(OnboardingStyle.snappy) { rowPressed = true }
            guard await TL.sleep(0.3) else { return }
            liftFinger()
            withAnimation(OnboardingStyle.snappy) { rowPressed = false }

            withAnimation(OnboardingStyle.spring) { zipVisible = true }
            guard await TL.sleep(0.5) else { return }
            withAnimation(OnboardingStyle.softSpring) { zipDropped = true }
            guard await TL.sleep(1.3) else { return }

            withAnimation(.easeInOut(duration: 0.25)) { step = 1 }
            guard await TL.sleep(0.3) else { return }
            tapOn(2)
            guard await TL.sleep(0.4) else { return }
            liftFinger()

            withAnimation(OnboardingStyle.softSpring) { zipDropped = false }
            guard await TL.sleep(0.5) else { return }
            withAnimation(.easeIn(duration: 0.2)) { zipVisible = false }
            withAnimation(OnboardingStyle.snappy) { restoredBadge = true }
            guard await TL.sleep(1.5) else { return }
            withAnimation(.easeOut(duration: 0.25)) { restoredBadge = false }
            guard await TL.sleep(0.6) else { return }

            TL.snap { zipDropped = false }
        }
    }

    @MainActor
    private func tapOn(_ target: Int) {
        TL.snap {
            tap = 0
            tapTarget = target
            fingerOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.6)) { tap = 1 }
    }

    @MainActor
    private func liftFinger() {
        withAnimation(.easeOut(duration: 0.2)) { fingerOpacity = 0 }
    }

    @MainActor
    private func reset() {
        TL.snap {
            step = 0
            tap = 0
            tapTarget = 1
            fingerOpacity = 0
            rowPressed = false
            zipVisible = false
            zipDropped = false
            restoredBadge = false
        }
    }
}

private struct StepChip: View {
    let number: Int
    let title: String
    let active: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 20, height: 20)
                .background(Circle().fill(active ? Color.white.opacity(0.25) : Color.primary.opacity(0.08)))
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(active ? Color.accentColor : Color(.secondarySystemBackground)))
        .foregroundColor(active ? .white : .secondary)
        .animation(.easeInOut(duration: 0.25), value: active)
    }
}
