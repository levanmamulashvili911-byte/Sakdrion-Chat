import SwiftUI

/// The message input bar: reply/edit banner, growing text field, attachments and
/// a mic that turns into a send button once there's something to send.
struct Composer: View {
    @Binding var text: String
    var replyBanner: ReplyContext?
    var isEditing: Bool
    var onCancelBanner: () -> Void
    var onSend: () -> Void
    var onAttach: () -> Void
    var onVoiceNote: (TimeInterval, [Double]) -> Void

    @FocusState private var isFocused: Bool
    @State private var isRecording = false
    @State private var recordedSeconds: TimeInterval = 0
    @State private var levels: [Double] = []
    @State private var recorder: Task<Void, Never>?

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if let replyBanner {
                banner(replyBanner)
            }

            if isRecording {
                recordingBar
            } else {
                inputBar
            }
        }
        .background(Palette.surface)
        .hairlineTop()
        .onDisappear { recorder?.cancel() }
    }

    // MARK: - Bars

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            CircleIconButton(
                systemImage: "plus",
                size: 36,
                background: Palette.surfaceSunken,
                foreground: Palette.textSecondary
            ) {
                isFocused = false
                onAttach()
            }

            HStack(alignment: .bottom, spacing: 6) {
                TextField("Message", text: $text, axis: .vertical)
                    .font(.sakMessage)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .padding(.vertical, 8)
                    .padding(.leading, 12)

                if !canSend {
                    Button {
                        Haptics.tap()
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 17))
                            .foregroundStyle(Palette.textTertiary)
                            .padding(.trailing, 10)
                            .padding(.bottom, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Palette.surfaceSunken)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            sendOrRecordButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var sendOrRecordButton: some View {
        Button {
            if canSend || isEditing {
                onSend()
                Haptics.tap()
            } else {
                startRecording()
            }
        } label: {
            Circle()
                .fill(Palette.accent)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: canSend ? "arrow.up" : "mic.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.18), value: canSend)
        .padding(.bottom, 1)
    }

    private var recordingBar: some View {
        HStack(spacing: 12) {
            Button {
                cancelRecording()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.danger)
            }
            .buttonStyle(.plain)

            Circle()
                .fill(Palette.danger)
                .frame(width: 8, height: 8)
                .opacity(Int(recordedSeconds * 2) % 2 == 0 ? 1 : 0.25)

            Text(Format.duration(recordedSeconds))
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(Palette.textPrimary)

            HStack(spacing: 2) {
                ForEach(Array(levels.suffix(24).enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(Palette.accent.opacity(0.55))
                        .frame(width: 2.5, height: 4 + level * 20)
                }
            }
            .frame(height: 26, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                finishRecording()
            } label: {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .transition(.opacity)
    }

    private func banner(_ context: ReplyContext) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.accent)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(isEditing ? "Editing message" : context.author)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                Text(context.preview)
                    .font(.sakCaption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                onCancelBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    // MARK: - Recording

    @MainActor
    private func startRecording() {
        isFocused = false
        recordedSeconds = 0
        levels = []
        Haptics.soft()
        withAnimation(.easeInOut(duration: 0.2)) { isRecording = true }

        recorder?.cancel()
        recorder = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                recordedSeconds += 0.1
                // Roughly three new waveform bars per second, capped for layout.
                if levels.count < 60, Int(recordedSeconds * 10) % 3 == 0 {
                    levels.append(Double.random(in: 0.25...1))
                }
            }
        }
    }

    @MainActor
    private func cancelRecording() {
        recorder?.cancel()
        Haptics.tap()
        withAnimation(.easeInOut(duration: 0.2)) { isRecording = false }
    }

    @MainActor
    private func finishRecording() {
        recorder?.cancel()
        let duration = max(1, recordedSeconds)
        let captured = levels.isEmpty ? MockData.waveform(seed: Int(duration * 10)) : levels
        withAnimation(.easeInOut(duration: 0.2)) { isRecording = false }
        onVoiceNote(duration, captured)
        Haptics.tap()
    }
}

// MARK: - Attachment sheet

struct AttachmentSheet: View {
    var onSelect: (Attachment.Kind) -> Void

    @Environment(\.dismiss) private var dismiss

    private let options: [(kind: Attachment.Kind, title: String, icon: String, tint: Color)] = [
        (.photo, "Photo", "photo.fill", Palette.accent),
        (.document, "Document", "doc.fill", Palette.warning),
        (.location, "Location", "mappin.and.ellipse", Palette.danger),
        (.voice, "Audio file", "waveform", Palette.success)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Palette.separator)
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text("Share")
                .font(.sakHeadline)
                .foregroundStyle(Palette.textPrimary)

            HStack(spacing: 14) {
                ForEach(options, id: \.title) { option in
                    Button {
                        onSelect(option.kind)
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(option.tint.opacity(0.14))
                                .frame(width: 58, height: 58)
                                .overlay {
                                    Image(systemName: option.icon)
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(option.tint)
                                }
                            Text(option.title)
                                .font(.sakCaption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Palette.surface)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.hidden)
    }
}
