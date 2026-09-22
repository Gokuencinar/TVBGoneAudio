# TVBGoneAudio / IR Universal — v6

Universal infrared controller for iPhone audio IR dongles.

## v6 highlights

- New four-tab interface: Control, Codes, My devices and Diagnostics.
- Manual code selection with an iOS wheel picker.
- Search by brand, model, ID or database source.
- Fast scan and slower Identify mode.
- Pause, resume, previous and next controls during a scan.
- "FUNCIONÓ" captures the current and recent codes so the working one can be saved.
- Persistent favorite devices in UserDefaults.
- One-tap power for saved TVs, air conditioners and projectors.
- Better code details: source, carrier frequency and duration.
- 36/38/40 kHz diagnostic tests.
- New app icon.
- Additional parsed Flipper protocols: Kaseikyo, RCA and Pioneer.
- Existing working TV scan ordering is preserved: Universal -> TV-B-Gone -> Flipper-IRDB.

## Required iPhone audio settings

- Media volume: 100%
- Settings > Accessibility > Audio/Visual > Mono Audio: OFF
- Balance: centered

The app requests 96 kHz output but always uses the actual sample rate negotiated
with the Lightning audio path. Signals whose carrier cannot be represented
safely are skipped instead of being sent at the wrong frequency.
