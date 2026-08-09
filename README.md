# Sakdrion Chat

A minimalistic iOS messaging and calling app in the spirit of WhatsApp, Signal and
Telegram — built in SwiftUI with a light-first design.

<p align="left">
  <img src="SakdrionChat/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="120" alt="App icon">
</p>

## Running it

Requirements: **Xcode 16 or newer**, iOS 17.0+ simulator or device.

```bash
open SakdrionChat.xcodeproj
```

Select the `SakdrionChat` scheme and run. There is no backend and no third-party
dependency — the app runs entirely on device.

On first launch you go through phone-number onboarding (any number, any 6-digit
code) and then land in a pre-seeded set of conversations so every screen has
something real to show.

## What's in it

**Chats**
- Chat list with pins, mutes, unread badges, drafts, archive and search across
  titles and message bodies
- Swipe actions (pin / mute / archive / delete) and matching context menus
- Conversation view with day separators, grouped runs of messages, delivery
  ticks (sending → sent → delivered → read), reply quoting, emoji reactions,
  edit, delete-for-me / delete-for-everyone and a live typing indicator
- Attachments: photos, documents, location and voice notes with a scrubbing
  waveform; the composer records voice notes with a live level meter
- One-to-one and group chats, with group member lists and per-chat info screens

**Calls**
- Call history with outgoing / incoming / missed / declined states and durations
- Full-screen call UI for voice and video: ringing with a pulsing ring, connect
  animation, live duration timer, mute, speaker, video toggle, camera flip and a
  picture-in-picture self view
- Incoming call screen with accept / decline, reachable any time from
  Settings → Demo → *Simulate incoming call*

**Contacts and Settings**
- Alphabetical contacts with a detail sheet that can message, call or video call
- Profile editing, appearance (system / light / dark), privacy toggles (last
  seen, read receipts, typing indicators), notification and storage screens

## Design

Light-first and deliberately quiet: a soft `#F5F7FA` field, white surfaces, one
calm blue accent (`#2F6BF0`), 1px hairline separators, and continuous corner
radii throughout. Every colour is a semantic token in `Palette` with a matching
dark value, so dark mode is the same layout on a dimmed palette rather than a
second design.

## Project layout

```
SakdrionChat/
├── App/                 App entry, root tabs, cross-tab navigator
├── DesignSystem/        Palette, metrics, typography, shared components
├── Models/              Contact, Chat, Message, CallRecord, Preferences, formatting
├── Services/            AppStore (state + intents), CallCenter, persistence, seed data
└── Features/
    ├── Onboarding/      Phone → code → profile
    ├── Chats/           List, conversation, bubbles, composer, info, new chat
    ├── Calls/           History and the full-screen call UI
    ├── Contacts/        Directory and contact detail
    └── Settings/        Profile, appearance, privacy, notifications, storage, about
```

`AppStore` is the single source of truth: views call intents on it and never
mutate models directly. State is persisted as one atomic JSON snapshot in
Application Support, coalesced so bursts of edits become a single write.

## Simulated transport

There is no server. `AppStore` and `CallCenter` simulate the parts a transport
layer would own, keeping the view layer honest:

- outgoing messages walk through sending → sent → delivered → read
- contacts show a typing indicator and then answer (toggle in Settings → Demo)
- placed calls connect after a short delay; unanswered incoming calls time out
  and land in history as missed

Swapping in a real backend means replacing `MockData`, the simulation hooks in
`AppStore`, and the body of `CallCenter` (CallKit + WebRTC) — the model types and
every view stay as they are.
