import SwiftUI

private typealias TL = OnboardingTimeline

struct RestorePointsPage: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var holdProgress: CGFloat = 0
    @State private var holdVisible = false
    @State private var rowPressed = false
    @State private var menuShown = false
    @State private var menuHighlighted = false
    @State private var chipVisible = false
    @State private var chipLanded = false
    @State private var tap: CGFloat = 0
    @State private var tapShown = false
    @State private var rewindSpin: CGFloat = 0
    @State private var rewindShown = false
    @State private var plusPulse: CGFloat = 0
    @State private var plusBump = false
    @State private var plusLabelShown = false

    private let width: CGFloat = 300
    private let navHeight: CGFloat = 30
    private let gap: CGFloat = 12
    private let rowHeight: CGFloat = 64
    private let cardHeight: CGFloat = 100
    private let chipHeight: CGFloat = 48

    private var rowY: CGFloat { navHeight + gap }
    private var cardY: CGFloat { rowY + rowHeight + gap }
    private var chipStartY: CGFloat { rowY + (rowHeight - chipHeight) / 2 }
    private var chipEndY: CGFloat { cardY + 42 }
    private var totalHeight: CGFloat { cardY + cardHeight }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            illustration
                .reveal(isActive)
                .parallax(depth: 1)

            OnboardingHeadline(
                title: "Restore points",
                subtitle: "Optional. Long-press an app to save a named snapshot, or tap + on the Restore tab to add an old zip. Roll back in one tap.",
                isActive: isActive,
                startIndex: 1
            )

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .task(id: isActive) { await run(active: isActive) }
    }

    private var illustration: some View {
        ZStack(alignment: .topLeading) {
            navBar
            dropdownCard.offset(y: cardY)
            appRow.offset(y: rowY)

            PointEntry()
                .frame(width: width - 24, height: chipHeight)
                .shadow(color: Color.black.opacity(chipLanded ? 0.04 : 0.18),
                        radius: chipLanded ? 1 : 8, x: 0, y: chipLanded ? 0 : 4)
                .opacity(chipVisible ? 1 : 0)
                .offset(x: 12, y: chipLanded ? chipEndY : chipStartY)

            contextMenu
                .offset(x: 44, y: rowY + rowHeight - 8)

            TapRipple(progress: tap)
                .opacity(tapShown ? 1 : 0)
                .offset(x: width - 80, y: chipEndY + chipHeight / 2 - 22)
        }
        .frame(width: width, height: totalHeight, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private var navBar: some View {
        HStack(spacing: 8) {
            Text("Restore")
                .font(.subheadline.weight(.bold))
            Spacer()
            Text("Add an old zip")
                .font(.caption.weight(.semibold))
                .foregroundColor(.accentColor)
                .opacity(plusLabelShown ? 1 : 0)
            ZStack {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: 26, height: 26)
                    .scaleEffect(1 + plusPulse * 0.9)
                    .opacity(plusPulse > 0 ? Double(1 - plusPulse) : 0)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.accentColor)
                    .scaleEffect(plusBump ? 1.25 : 1)
            }
        }
        .frame(width: width, height: navHeight)
    }

    private var appRow: some View {
        MiniAppRow(highlighted: rowPressed)
            .overlay(
                ZStack {
                    HoldRing(progress: holdProgress)
                        .opacity(holdVisible ? 1 : 0)
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.accentColor)
                        .rotationEffect(.degrees(Double(-360 * rewindSpin)))
                        .opacity(rewindShown ? 1 : 0)
                }
                .padding(.trailing, 12),
                alignment: .trailing
            )
            .frame(width: width)
    }

    private var dropdownCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Restore Points")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)

            Text("No restore points yet")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: chipHeight + 4)
                .opacity(chipLanded ? 0 : 1)
        }
        .frame(width: width, height: cardHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var contextMenu: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
            Text("Save as Restore Point\u{2026}")
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(menuHighlighted ? 0.15 : 0))
        )
        .scaleEffect(menuShown ? 1 : 0.5, anchor: .topLeading)
        .opacity(menuShown ? 1 : 0)
    }

    @MainActor
    private func run(active: Bool) async {
        reset()
        guard active else { return }

        if reduceMotion {
            chipVisible = true
            chipLanded = true
            plusLabelShown = true
            return
        }

        guard await TL.sleep(0.9) else { return }

        while true {
            TL.snap { holdProgress = 0 }
            withAnimation(.easeOut(duration: 0.2)) {
                holdVisible = true
                rowPressed = true
            }
            withAnimation(.linear(duration: 0.9)) { holdProgress = 1 }
            guard await TL.sleep(0.95) else { return }

            withAnimation(.easeOut(duration: 0.15)) { holdVisible = false }
            withAnimation(OnboardingStyle.snappy) { menuShown = true }
            guard await TL.sleep(0.8) else { return }
            withAnimation(.easeInOut(duration: 0.15)) { menuHighlighted = true }
            guard await TL.sleep(0.4) else { return }

            withAnimation(.easeOut(duration: 0.2)) {
                menuShown = false
                menuHighlighted = false
                rowPressed = false
                chipVisible = true
            }
            guard await TL.sleep(0.15) else { return }
            withAnimation(OnboardingStyle.softSpring) { chipLanded = true }
            guard await TL.sleep(1.2) else { return }

            TL.snap {
                tap = 0
                tapShown = true
                rewindSpin = 0
            }
            withAnimation(.easeOut(duration: 0.6)) { tap = 1 }
            guard await TL.sleep(0.35) else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                tapShown = false
                rewindShown = true
                rowPressed = true
            }
            withAnimation(.easeInOut(duration: 0.9)) { rewindSpin = 1 }
            guard await TL.sleep(1.1) else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                rewindShown = false
                rowPressed = false
            }
            guard await TL.sleep(0.4) else { return }

            TL.snap { plusPulse = 0 }
            withAnimation(.easeOut(duration: 0.25)) { plusLabelShown = true }
            withAnimation(OnboardingStyle.snappy) { plusBump = true }
            withAnimation(.easeOut(duration: 0.9)) { plusPulse = 1 }
            guard await TL.sleep(0.3) else { return }
            withAnimation(OnboardingStyle.snappy) { plusBump = false }
            guard await TL.sleep(1.8) else { return }

            withAnimation(.easeInOut(duration: 0.3)) {
                plusLabelShown = false
                chipVisible = false
            }
            guard await TL.sleep(0.6) else { return }
            reset()
            guard await TL.sleep(0.3) else { return }
        }
    }

    @MainActor
    private func reset() {
        TL.snap {
            holdProgress = 0
            holdVisible = false
            rowPressed = false
            menuShown = false
            menuHighlighted = false
            chipVisible = false
            chipLanded = false
            tap = 0
            tapShown = false
            rewindSpin = 0
            rewindShown = false
            plusPulse = 0
            plusBump = false
            plusLabelShown = false
        }
    }
}

private struct PointEntry: View {
    var body: some View {
        HStack(spacing: 10) {
            AppTile(symbol: "gamecontroller.fill", size: 30, tint: .orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Before boss fight")
                    .font(.subheadline.weight(.semibold))
                Text("Just now")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
