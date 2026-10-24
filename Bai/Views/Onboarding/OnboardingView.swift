import SwiftUI

extension View {
    func onboardingCover() -> some View {
        modifier(OnboardingCoverModifier())
    }
}

private struct OnboardingCoverModifier: ViewModifier {
    @AppStorage(OnboardingView.seenKey) private var hasSeen = false

    func body(content: Content) -> some View {
        content.fullScreenCover(
            isPresented: Binding(
                get: { !hasSeen },
                set: { if !$0 { hasSeen = true } }
            )
        ) {
            OnboardingView { hasSeen = true }
        }
    }
}

struct OnboardingView: View {
    static let seenKey = "hasSeenOnboarding"

    let onFinish: () -> Void

    @State private var index = 0

    private let pageCount = 3
    private let tints: [Color] = [.blue, .indigo, .orange]

    private var isLast: Bool { index == pageCount - 1 }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            background

            VStack(spacing: 0) {
                topBar
                pager
                PageDots(count: pageCount, current: index)
                    .padding(.vertical, 20)
                continueButton
                    .padding(.horizontal, OnboardingStyle.pageSideInset)
                    .padding(.bottom, 24)
            }
        }
        .onChange(of: index) { _ in OnboardingHaptics.tick() }
    }

    private var background: some View {
        ZStack {
            ForEach(0..<pageCount, id: \.self) { i in
                LinearGradient(colors: [tints[i].opacity(0.22), Color.clear],
                               startPoint: .top, endPoint: .center)
                    .opacity(index == i ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: index)
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button("Skip") { onFinish() }
                .font(.body)
                .opacity(isLast ? 0 : 1)
                .disabled(isLast)
                .animation(.easeInOut(duration: 0.2), value: isLast)
        }
        .frame(height: 44)
        .padding(.horizontal, 24)
    }

    private var pager: some View {
        TabView(selection: $index) {
            ForEach(0..<pageCount, id: \.self) { i in
                GeometryReader { proxy in
                    page(i, isActive: index == i)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .environment(\.onboardingParallax, parallaxOffset(of: proxy))
                }
                .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func parallaxOffset(of proxy: GeometryProxy) -> CGFloat {
        proxy.frame(in: .global).minX / max(proxy.size.width, 1)
    }

    private var continueButton: some View {
        Button(action: advance) {
            ZStack {
                Text("Continue").opacity(isLast ? 0 : 1)
                Text("Get Started").opacity(isLast ? 1 : 0)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isLast ? "Get Started" : "Continue")
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: isLast)
    }

    private func advance() {
        if isLast {
            OnboardingHaptics.success()
            onFinish()
        } else {
            withAnimation(.easeInOut(duration: 0.35)) { index += 1 }
        }
    }

    @ViewBuilder
    private func page(_ i: Int, isActive: Bool) -> some View {
        switch i {
        case 0:
            WelcomePage(isActive: isActive)

        case 1:
            BackupFlowPage(isActive: isActive)

        default:
            RestorePointsPage(isActive: isActive)
        }
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.accentColor : Color(.tertiaryLabel))
                    .frame(width: i == current ? 22 : 8, height: 8)
            }
        }
        .animation(OnboardingStyle.snappy, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onFinish: {})
        OnboardingView(onFinish: {})
            .preferredColorScheme(.dark)
    }
}
