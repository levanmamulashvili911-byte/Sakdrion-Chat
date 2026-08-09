import SwiftUI

/// Full-screen call UI. One view covers ringing, dialing, connected and ended —
/// the phase lives in `CallCenter`, this only renders it.
struct CallScreen: View {
    @Environment(CallCenter.self) private var callCenter

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                Spacer(minLength: 24)
                peerBlock
                Spacer()
                controls
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .overlay(alignment: .topTrailing) {
            if callCenter.isVideoEnabled {
                selfPreview
                    .padding(.top, 60)
                    .padding(.trailing, 20)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: callCenter.isVideoEnabled)
        .animation(.easeInOut(duration: 0.25), value: callCenter.phase)
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdrop: some View {
        if callCenter.isVideoEnabled {
            LinearGradient(
                colors: [Color(hex: 0x3A4A63), Color(hex: 0x1E2836)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 160, weight: .thin))
                    .foregroundStyle(Color.white.opacity(0.08))
            }
        } else {
            LinearGradient(
                colors: [Color(light: 0xF7FAFF, dark: 0x11151B), Color(light: 0xE7EEFB, dark: 0x0C1015)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var onVideoBackdrop: Bool { callCenter.isVideoEnabled }

    private var primaryText: Color {
        onVideoBackdrop ? .white : Palette.textPrimary
    }

    private var secondaryText: Color {
        onVideoBackdrop ? Color.white.opacity(0.75) : Palette.textSecondary
    }

    // MARK: - Peer

    private var peerBlock: some View {
        VStack(spacing: 14) {
            if !callCenter.isVideoEnabled {
                ZStack {
                    if callCenter.phase == .dialing || callCenter.phase == .ringing {
                        PulsingRing()
                    }
                    if let peer = callCenter.peer {
                        AvatarView(contact: peer, size: 132)
                    }
                }
                .frame(height: 150)
            }

            Text(callCenter.peer?.name ?? "Unknown")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(primaryText)

            HStack(spacing: 6) {
                if callCenter.phase == .active {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(secondaryText)
                }
                Text(callCenter.statusText)
                    .font(.system(size: 16, weight: .regular).monospacedDigit())
                    .foregroundStyle(secondaryText)
            }

            if callCenter.phase == .active {
                Text("End-to-end encrypted")
                    .font(.system(size: 12))
                    .foregroundStyle(onVideoBackdrop ? Color.white.opacity(0.55) : Palette.textTertiary)
            }
        }
        .padding(.top, callCenter.isVideoEnabled ? 40 : 0)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var selfPreview: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(
                colors: [Color(hex: 0x5C6B85), Color(hex: 0x39465A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 96, height: 132)
            .overlay {
                Image(systemName: callCenter.isUsingFrontCamera ? "person.crop.square" : "camera.rotate")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .overlay(alignment: .bottom) {
                Text("You")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.bottom, 6)
            }
            .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        switch callCenter.phase {
        case .ringing:
            incomingControls
        case .ended:
            EmptyView()
        default:
            activeControls
        }
    }

    private var activeControls: some View {
        VStack(spacing: 26) {
            HStack(spacing: 18) {
                CallToggle(
                    icon: callCenter.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill",
                    label: callCenter.isMicrophoneMuted ? "Unmute" : "Mute",
                    isOn: callCenter.isMicrophoneMuted,
                    onDark: onVideoBackdrop
                ) {
                    callCenter.toggleMute()
                }

                CallToggle(
                    icon: callCenter.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill",
                    label: "Speaker",
                    isOn: callCenter.isSpeakerOn,
                    onDark: onVideoBackdrop
                ) {
                    callCenter.toggleSpeaker()
                }

                CallToggle(
                    icon: callCenter.isVideoEnabled ? "video.fill" : "video.slash.fill",
                    label: "Video",
                    isOn: callCenter.isVideoEnabled,
                    onDark: onVideoBackdrop
                ) {
                    callCenter.toggleVideo()
                }

                CallToggle(
                    icon: "arrow.triangle.2.circlepath.camera.fill",
                    label: "Flip",
                    isOn: false,
                    isEnabled: callCenter.isVideoEnabled,
                    onDark: onVideoBackdrop
                ) {
                    callCenter.flipCamera()
                }
            }

            Button {
                callCenter.end()
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(Palette.danger, in: Circle())
                    .shadow(color: Palette.danger.opacity(0.35), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
    }

    private var incomingControls: some View {
        HStack(spacing: 70) {
            VStack(spacing: 10) {
                Button {
                    callCenter.decline()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(Palette.danger, in: Circle())
                }
                .buttonStyle(.plain)

                Text("Decline")
                    .font(.sakCaption)
                    .foregroundStyle(secondaryText)
            }

            VStack(spacing: 10) {
                Button {
                    callCenter.accept()
                } label: {
                    Image(systemName: callCenter.kind == .video ? "video.fill" : "phone.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(Palette.success, in: Circle())
                }
                .buttonStyle(.plain)

                Text("Accept")
                    .font(.sakCaption)
                    .foregroundStyle(secondaryText)
            }
        }
    }
}

// MARK: - Pieces

struct CallToggle: View {
    let icon: String
    let label: String
    let isOn: Bool
    var isEnabled: Bool = true
    var onDark: Bool = false
    let action: () -> Void

    private var background: Color {
        if isOn { return onDark ? Color.white : Palette.accent }
        return onDark ? Color.white.opacity(0.16) : Palette.surface
    }

    private var foreground: Color {
        if isOn { return onDark ? Color(hex: 0x1E2836) : .white }
        return onDark ? .white : Palette.textSecondary
    }

    var body: some View {
        VStack(spacing: 7) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(foreground)
                    .frame(width: 58, height: 58)
                    .background(background, in: Circle())
                    .overlay {
                        if !isOn && !onDark {
                            Circle().strokeBorder(Palette.separator, lineWidth: 1)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.4)

            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(onDark ? Color.white.opacity(0.75) : Palette.textSecondary)
        }
    }
}

/// Soft expanding ring behind the avatar while a call is ringing.
struct PulsingRing: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(Palette.accent.opacity(0.12))
                    .frame(width: 150, height: 150)
                    .scaleEffect(isAnimating ? 1.35 : 0.95)
                    .opacity(isAnimating ? 0 : 0.9)
                    .animation(
                        .easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(Double(index) * 0.9),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}

#Preview {
    CallScreen()
        .environment(CallCenter())
}
