import SwiftUI

// MARK: - Glass Background
struct GlassBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.3, green: 0.7, blue: 1.0),
                Color(red: 0.2, green: 0.9, blue: 0.8),
                Color(red: 0.4, green: 0.6, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Dark Locked Background
struct LockedBackground: View {
    // Pre-generate particle positions to avoid re-randomizing on every render
    private let particles: [(x: CGFloat, y: CGFloat, size: CGFloat)] = (0..<20).map { _ in
        (
            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
            y: CGFloat.random(in: 0...UIScreen.main.bounds.height),
            size: CGFloat.random(in: 2...4)
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.02, blue: 0.1),
                    Color(red: 0.15, green: 0.03, blue: 0.08),
                    Color(red: 0.1, green: 0.01, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Static particles/stars effect (pre-generated positions)
            ForEach(0..<particles.count, id: \.self) { i in
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: particles[i].size)
                    .position(x: particles[i].x, y: particles[i].y)
                    .blur(radius: 2)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass Card
struct GlassCard<Content: View>: View {
    let content: Content
    var isDark: Bool = false

    init(isDark: Bool = false, @ViewBuilder content: () -> Content) {
        self.isDark = isDark
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                ZStack {
                    if isDark {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.red.opacity(0.5),
                                                Color.purple.opacity(0.5)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            )
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: isDark ? Color.red.opacity(0.3) : Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Glass Button
struct GlassButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var isDark: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    if isDark {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.5, green: 0.1, blue: 0.2),
                                        Color(red: 0.3, green: 0.05, blue: 0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.6), Color.purple.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.25))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .foregroundColor(isDark ? .white : .white)
            .shadow(color: isDark ? Color.red.opacity(0.4) : Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

// MARK: - Animated Gradient Mesh
struct AnimatedMeshGradient: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.3, green: 0.7, blue: 1.0),
                Color(red: 0.2, green: 0.9, blue: 0.8),
                Color(red: 0.5, green: 0.6, blue: 1.0),
                Color(red: 0.3, green: 0.7, blue: 1.0)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 12.0) // Slower, smoother animation
                    .repeatForever(autoreverses: true)
            ) {
                animateGradient.toggle()
            }
        }
    }
}
