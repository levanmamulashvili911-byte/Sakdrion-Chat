import SwiftUI

// MARK: - Avatar

struct AvatarView: View {
    var initials: String
    var colorSeed: Int
    var size: CGFloat = Metrics.avatarMedium
    var isOnline: Bool = false
    var systemImage: String?

    private var tint: Color { Palette.avatarTints[Palette.tintIndex(colorSeed)] }
    private var ink: Color { Palette.avatarInk[Palette.tintIndex(colorSeed)] }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(tint)
                .frame(width: size, height: size)
                .overlay {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: size * 0.42, weight: .medium))
                            .foregroundStyle(ink)
                    } else {
                        Text(initials)
                            .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                            .foregroundStyle(ink)
                    }
                }

            if isOnline {
                Circle()
                    .fill(Palette.success)
                    .frame(width: size * 0.24, height: size * 0.24)
                    .overlay {
                        Circle().strokeBorder(Palette.surface, lineWidth: size * 0.05)
                    }
                    .offset(x: size * 0.02, y: size * 0.02)
            }
        }
        .frame(width: size, height: size)
    }
}

extension AvatarView {
    init(contact: Contact, size: CGFloat = Metrics.avatarMedium, showPresence: Bool = false) {
        self.init(
            initials: contact.initials,
            colorSeed: contact.colorSeed,
            size: size,
            isOnline: showPresence && contact.isOnline,
            systemImage: nil
        )
    }

    static func group(seed: Int, size: CGFloat = Metrics.avatarMedium) -> AvatarView {
        AvatarView(initials: "", colorSeed: seed, size: size, isOnline: false, systemImage: "person.2.fill")
    }
}

// MARK: - Cards and rows

/// A grouped block of rows on the sunken background — the app's substitute for
/// `.insetGrouped` lists, so spacing and corners stay consistent.
struct Card<Content: View>: View {
    var padding: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(padding)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerLarge, style: .continuous))
    }
}

struct CardRow<Trailing: View>: View {
    var icon: String
    var iconTint: Color = Palette.accent
    var title: String
    var subtitle: String?
    var showsChevron: Bool = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(iconTint.opacity(0.14))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconTint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.sakBody)
                    .foregroundStyle(Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.sakCaption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            Spacer(minLength: 8)

            trailing

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.horizontal, Metrics.hPadding)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

extension CardRow where Trailing == EmptyView {
    init(icon: String, iconTint: Color = Palette.accent, title: String, subtitle: String? = nil, showsChevron: Bool = false) {
        self.init(icon: icon, iconTint: iconTint, title: title, subtitle: subtitle, showsChevron: showsChevron) {
            EmptyView()
        }
    }
}

struct CardDivider: View {
    var leadingInset: CGFloat = Metrics.hPadding + 44

    var body: some View {
        Rectangle()
            .fill(Palette.separator)
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }
}

struct SectionLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.sakMicro)
            .kerning(0.6)
            .foregroundStyle(Palette.textTertiary)
            .padding(.horizontal, Metrics.hPadding + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Controls

struct CircleIconButton: View {
    var systemImage: String
    var size: CGFloat = 40
    var background: Color = Palette.surface
    var foreground: Color = Palette.accent
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Circle()
                .fill(background)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(foreground)
                }
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton: View {
    var title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            ZStack {
                Text(title)
                    .font(.sakHeadline)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView().tint(.white)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isEnabled ? Palette.accent : Palette.accent.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

struct EmptyStateView: View {
    var icon: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Palette.accentSoft)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Palette.accent)
                }
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            Text(message)
                .font(.sakSubhead)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

/// The small pill used for unread counts and the archived-chats badge.
struct CountBadge: View {
    var count: Int
    var isMuted: Bool = false

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(isMuted ? Palette.textTertiary : Palette.accent, in: Capsule())
    }
}

/// Three-dot "typing…" animation used in the chat list and conversation header.
struct TypingDots: View {
    var tint: Color = Palette.accent
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                    .opacity(phase == index ? 1 : 0.32)
                    .scaleEffect(phase == index ? 1.15 : 1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: phase)
        .task {
            // Cancelled automatically when the view goes away.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(280))
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Modifiers

extension View {
    func cardStyle() -> some View {
        background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerLarge, style: .continuous))
    }

    /// Applies a light hairline top border — used by the composer and call bars.
    func hairlineTop() -> some View {
        overlay(alignment: .top) {
            Rectangle().fill(Palette.separator).frame(height: 1)
        }
    }
}
