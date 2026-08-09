import Foundation
import Observation
import SwiftUI

/// Drives the call UI: ringing, connecting, in-call timer and the audio route
/// toggles. A production build would back this with CallKit + WebRTC; the
/// surface here is deliberately the same shape so the views wouldn't change.
@MainActor
@Observable
final class CallCenter {
    enum Phase: Equatable {
        case idle
        /// We placed the call and are waiting for the other side.
        case dialing
        /// The other side is calling us.
        case ringing
        case connecting
        case active
        case ended(reason: String)
    }

    private(set) var phase: Phase = .idle
    private(set) var peer: Contact?
    private(set) var chatID: UUID?
    private(set) var kind: CallRecord.Kind = .audio
    private(set) var connectedAt: Date?
    private(set) var elapsed: TimeInterval = 0

    var isMicrophoneMuted = false
    var isSpeakerOn = false
    var isVideoEnabled = false
    var isUsingFrontCamera = true

    /// True while any call UI should cover the app.
    var isPresentingFullScreen: Bool {
        switch phase {
        case .idle: false
        default: true
        }
    }

    var isRinging: Bool { phase == .ringing }

    /// True when this call arrived from the other side, including after we answer.
    private(set) var isIncomingCall = false

    var statusText: String {
        switch phase {
        case .idle: ""
        case .dialing: "Calling…"
        case .ringing: kind == .audio ? "Incoming voice call" : "Incoming video call"
        case .connecting: "Connecting…"
        case .active: Format.duration(elapsed)
        case .ended(let reason): reason
        }
    }

    private var ticker: Task<Void, Never>?
    private var scriptedTransition: Task<Void, Never>?
    private weak var store: AppStore?

    init(store: AppStore? = nil) {
        self.store = store
    }

    func attach(store: AppStore) {
        self.store = store
    }

    // MARK: - Placing and receiving

    func startCall(with peer: Contact, chatID: UUID?, kind: CallRecord.Kind) {
        guard phase == .idle else { return }
        reset()
        self.peer = peer
        self.chatID = chatID
        self.kind = kind
        isIncomingCall = false
        isVideoEnabled = kind == .video
        isSpeakerOn = kind == .video
        phase = .dialing
        Haptics.soft()

        // The peer picks up after a short, slightly random delay.
        scriptedTransition = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int.random(in: 1_800...3_200)))
            guard !Task.isCancelled else { return }
            self?.connect()
        }
    }

    func receiveCall(from peer: Contact, chatID: UUID?, kind: CallRecord.Kind) {
        guard phase == .idle else { return }
        reset()
        self.peer = peer
        self.chatID = chatID
        self.kind = kind
        isIncomingCall = true
        isVideoEnabled = false
        phase = .ringing
        Haptics.warning()

        // Nobody rings forever.
        scriptedTransition = Task { [weak self] in
            try? await Task.sleep(for: .seconds(25))
            guard !Task.isCancelled else { return }
            self?.missed()
        }
    }

    func accept() {
        guard phase == .ringing else { return }
        scriptedTransition?.cancel()
        isVideoEnabled = kind == .video
        isSpeakerOn = kind == .video
        phase = .connecting
        scriptedTransition = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            self?.connect()
        }
    }

    func decline() {
        guard let peer else { return dismiss() }
        scriptedTransition?.cancel()
        store?.logCall(peerID: peer.id, chatID: chatID, kind: kind, outcome: .declined, duration: 0)
        finish(reason: "Declined")
    }

    /// Hangs up, logging the call the way it actually went.
    func end() {
        guard let peer else { return dismiss() }
        scriptedTransition?.cancel()
        ticker?.cancel()
        let duration = elapsed
        let wasConnected = connectedAt != nil
        let outcome: CallRecord.Outcome = isIncomingCall
            ? (wasConnected ? .incoming : .missed)
            : .outgoing
        store?.logCall(peerID: peer.id, chatID: chatID, kind: kind, outcome: outcome, duration: duration)
        finish(reason: wasConnected ? "Call ended · \(Format.duration(duration))" : "Call cancelled")
    }

    // MARK: - Controls

    func toggleMute() {
        isMicrophoneMuted.toggle()
        Haptics.tap()
    }

    func toggleSpeaker() {
        isSpeakerOn.toggle()
        Haptics.tap()
    }

    func toggleVideo() {
        isVideoEnabled.toggle()
        if isVideoEnabled { isSpeakerOn = true }
        Haptics.tap()
    }

    func flipCamera() {
        isUsingFrontCamera.toggle()
        Haptics.tap()
    }

    // MARK: - Internals

    private func connect() {
        phase = .active
        connectedAt = .now
        elapsed = 0
        Haptics.success()
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, let start = self.connectedAt, !Task.isCancelled else { return }
                self.elapsed = Date.now.timeIntervalSince(start)
            }
        }
    }

    private func missed() {
        guard let peer else { return dismiss() }
        store?.logCall(peerID: peer.id, chatID: chatID, kind: kind, outcome: .missed, duration: 0)
        finish(reason: "Missed call")
    }

    private func finish(reason: String) {
        ticker?.cancel()
        phase = .ended(reason: reason)
        Haptics.soft()
        scriptedTransition = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1_100))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private func dismiss() {
        reset()
        phase = .idle
    }

    private func reset() {
        ticker?.cancel()
        ticker = nil
        peer = nil
        chatID = nil
        connectedAt = nil
        elapsed = 0
        isIncomingCall = false
        isMicrophoneMuted = false
        isSpeakerOn = false
        isVideoEnabled = false
        isUsingFrontCamera = true
    }
}
