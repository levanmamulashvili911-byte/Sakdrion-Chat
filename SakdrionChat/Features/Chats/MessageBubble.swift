import SwiftUI

struct ReplyContext: Equatable {
    var author: String
    var preview: String
}

struct MessageBubble: View {
    let message: Message
    let isMine: Bool
    var senderName: String?
    var replyContext: ReplyContext?
    /// Last bubble of a run from the same sender — only this one shows the meta line.
    var isTailEnd: Bool = true

    private var textColor: Color {
        isMine ? Palette.bubbleOutgoingText : Palette.bubbleIncomingText
    }

    private var secondaryColor: Color {
        isMine ? Color.white.opacity(0.75) : Palette.textTertiary
    }

    private var background: Color {
        isMine ? Palette.bubbleOutgoing : Palette.bubbleIncoming
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                bubble
                if !message.reactions.isEmpty {
                    reactionRow
                }
            }

            if !isMine { Spacer(minLength: 48) }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let senderName, !isMine {
                Text(senderName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.avatarInk[Palette.tintIndex(for: senderName)])
            }

            if let replyContext {
                replyBlock(replyContext)
            }

            if message.isDeleted {
                Label("This message was deleted", systemImage: "nosign")
                    .font(.system(size: 15))
                    .italic()
                    .foregroundStyle(secondaryColor)
            } else {
                if let attachment = message.attachment {
                    AttachmentContent(attachment: attachment, isMine: isMine)
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.sakMessage)
                        .foregroundStyle(textColor)
                        .textSelection(.enabled)
                }
            }

            metaLine
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(background)
        .clipShape(BubbleShape(isMine: isMine, isTailEnd: isTailEnd))
        .overlay {
            if !isMine {
                BubbleShape(isMine: isMine, isTailEnd: isTailEnd)
                    .stroke(Palette.separator, lineWidth: 1)
            }
        }
        .shadow(color: Color.black.opacity(isMine ? 0 : 0.03), radius: 3, y: 1)
    }

    private func replyBlock(_ context: ReplyContext) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isMine ? Color.white.opacity(0.85) : Palette.accent)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(context.author)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(isMine ? Color.white : Palette.accent)
                Text(context.preview)
                    .font(.system(size: 13))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isMine ? Color.white.opacity(0.16) : Palette.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var metaLine: some View {
        HStack(spacing: 4) {
            if message.isEdited && !message.isDeleted {
                Text("edited")
                    .font(.system(size: 10.5))
                    .foregroundStyle(secondaryColor)
            }
            Text(Format.time(message.date))
                .font(.system(size: 10.5))
                .foregroundStyle(secondaryColor)
            if isMine, !message.isDeleted {
                MessageStatusIcon(
                    status: message.status,
                    tint: message.status == .read ? Color.white : Color.white.opacity(0.7)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var reactionRow: some View {
        HStack(spacing: 4) {
            ForEach(message.groupedReactions, id: \.emoji) { item in
                HStack(spacing: 2) {
                    Text(item.emoji).font(.system(size: 12))
                    if item.count > 1 {
                        Text("\(item.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Palette.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(Palette.separator, lineWidth: 1) }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Bubble shape

/// Rounded on all corners, with the sender-side bottom corner tightened on the
/// last bubble of a run — a quiet nod to a tail without drawing one.
struct BubbleShape: Shape {
    var isMine: Bool
    var isTailEnd: Bool

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(cornerRadii: radii, style: .continuous).path(in: rect)
    }

    private var radii: RectangleCornerRadii {
        let radius = Metrics.bubbleCorner
        let tight: CGFloat = isTailEnd ? 6 : radius
        return RectangleCornerRadii(
            topLeading: radius,
            bottomLeading: isMine ? radius : tight,
            bottomTrailing: isMine ? tight : radius,
            topTrailing: radius
        )
    }
}

// MARK: - Attachments

struct AttachmentContent: View {
    let attachment: Attachment
    let isMine: Bool

    var body: some View {
        switch attachment.kind {
        case .photo:
            PhotoAttachmentView(attachment: attachment)
        case .voice:
            VoiceAttachmentView(attachment: attachment, isMine: isMine)
        case .document:
            DocumentAttachmentView(attachment: attachment, isMine: isMine)
        case .location:
            LocationAttachmentView(attachment: attachment)
        }
    }
}

/// Photos are represented by a stable gradient placeholder — no photo library
/// round-trip is needed to demonstrate the layout.
struct PhotoAttachmentView: View {
    let attachment: Attachment

    private var colors: [Color] {
        let tints: [[Color]] = [
            [Color(hex: 0xBFD4FF), Color(hex: 0x8FB4FF)],
            [Color(hex: 0xC9EFDF), Color(hex: 0x94D9BE)],
            [Color(hex: 0xFFD9CF), Color(hex: 0xFFB3A0)],
            [Color(hex: 0xE4D6FB), Color(hex: 0xC3AAF3)],
            [Color(hex: 0xFFE7BF), Color(hex: 0xFFCE84)],
            [Color(hex: 0xCDEAF3), Color(hex: 0x9BD3E6)]
        ]
        return tints[abs(attachment.colorSeed) % tints.count]
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 232, height: 168)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct VoiceAttachmentView: View {
    let attachment: Attachment
    let isMine: Bool

    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var playback: Task<Void, Never>?

    private var tint: Color { isMine ? .white : Palette.accent }
    private var trackTint: Color { isMine ? Color.white.opacity(0.35) : Palette.accent.opacity(0.25) }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isMine ? Palette.accent : .white)
                    .frame(width: 32, height: 32)
                    .background(tint, in: Circle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 2) {
                ForEach(Array(waveform.enumerated()), id: \.offset) { index, height in
                    Capsule()
                        .fill(Double(index) / Double(waveform.count) <= progress ? tint : trackTint)
                        .frame(width: 2.5, height: 6 + height * 20)
                }
            }
            .frame(height: 28)

            Text(Format.duration(remaining))
                .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                .foregroundStyle(isMine ? Color.white.opacity(0.85) : Palette.textSecondary)
        }
        .frame(width: 210)
        .onDisappear { stopPlayback() }
    }

    /// Simulated playback: the progress bar advances in real time for the
    /// recorded length, then resets on the next tap.
    @MainActor
    private func togglePlayback() {
        Haptics.tap()
        if isPlaying {
            stopPlayback()
            return
        }
        if progress >= 1 { progress = 0 }
        isPlaying = true
        playback = Task {
            let duration = attachment.duration ?? 0
            if duration > 0 {
                while !Task.isCancelled, progress < 1 {
                    try? await Task.sleep(for: .milliseconds(100))
                    progress = min(1, progress + 0.1 / duration)
                }
            }
            isPlaying = false
        }
    }

    @MainActor
    private func stopPlayback() {
        playback?.cancel()
        playback = nil
        isPlaying = false
    }

    private var waveform: [Double] {
        attachment.waveform.isEmpty ? MockData.waveform(seed: attachment.colorSeed) : attachment.waveform
    }

    private var remaining: TimeInterval {
        let total = attachment.duration ?? 0
        return isPlaying || progress > 0 ? total * (1 - progress) : total
    }
}

struct DocumentAttachmentView: View {
    let attachment: Attachment
    let isMine: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isMine ? Color.white.opacity(0.2) : Palette.accentSoft)
                .frame(width: 36, height: 42)
                .overlay {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isMine ? .white : Palette.accent)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(isMine ? .white : Palette.textPrimary)
                    .lineLimit(1)
                Text(attachment.byteSize.map(Format.fileSize) ?? "Document")
                    .font(.system(size: 12))
                    .foregroundStyle(isMine ? Color.white.opacity(0.75) : Palette.textSecondary)
            }
        }
        .frame(width: 208, alignment: .leading)
    }
}

struct LocationAttachmentView: View {
    let attachment: Attachment

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xE8F0E6), Color(hex: 0xD7E7F5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                MapLines()
                    .stroke(Color.white.opacity(0.9), lineWidth: 3)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Palette.danger)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .frame(width: 232, height: 128)

            Text(attachment.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(width: 232, alignment: .leading)
                .background(Palette.surfaceSunken)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Decorative "streets" behind the location pin.
private struct MapLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.62))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.48))
        path.move(to: CGPoint(x: rect.width * 0.32, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.44, y: rect.height))
        path.move(to: CGPoint(x: rect.width * 0.74, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.68, y: rect.height))
        return path
    }
}

#Preview {
    VStack(spacing: 10) {
        MessageBubble(
            message: Message(senderID: UUID(), text: "Morning! Did the new build land?", status: .read),
            isMine: false,
            senderName: "Nino Beridze"
        )
        MessageBubble(
            message: Message(senderID: UUID(), text: "Yep, pushed it last night. Light theme is in.", status: .read),
            isMine: true,
            replyContext: ReplyContext(author: "Nino Beridze", preview: "Did the new build land?")
        )
        MessageBubble(
            message: Message(
                senderID: UUID(),
                attachment: Attachment(kind: .voice, duration: 14, colorSeed: 3, waveform: MockData.waveform(seed: 3)),
                status: .delivered
            ),
            isMine: false
        )
    }
    .padding()
    .background(Palette.background)
}
