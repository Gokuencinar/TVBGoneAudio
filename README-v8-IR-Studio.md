# IR Universal 3.0 — Build 8 "IR Studio"

This version turns the project into a broader IR toolkit while preserving the
known-working audio IR transmitter path and the TV scan order.

## New in v8

### IR learning
- Fixes AVAudioRecorderDelegate conformance from the v7 prototype.
- Normal single-take learning.
- Optional validated x3 capture: capture the same button three times.
- Computes a consistency percentage between captures.
- Builds a median/consensus RAW waveform when captures agree.

### Signal analysis
- Visual MARK/SPACE waveform viewer.
- Heuristic protocol identification for:
  - NEC / NEC Extended
  - Samsung32
  - JVC
  - Sony SIRC12/15/20
  - Kaseikyo / Panasonic
  - RCA
  - Pioneer
  - probable RC5 / RC6 Manchester patterns
- Shows decoded bytes when safe to do so.
- Keeps RAW as the source of truth even if protocol recognition is uncertain.

### Database matching
- Compares learned RAW timing patterns against the bundled power/off database.
- Shows the closest candidates with a similarity percentage.
- Useful for investigating OEM-shared remotes such as TD Systems/Elitelux.

### Flipper compatibility
- Import `.ir` text files.
- Imports RAW signals directly.
- Imports parsed NEC, NECext, Samsung32, SIRC, RC5, RC6, JVC, Kaseikyo, RCA
  and Pioneer signals.
- Export every learned signal as a standard RAW Flipper `.ir` file.

### Custom remotes
- Create a multi-button remote from learned/imported signals.
- TV, air-conditioner and projector categories.
- Persistent custom remotes stored locally.
- Dedicated two-column remote-control UI.

### Guided learning
- Optional guided button sequence for TVs, ACs and projectors.
- Automatically suggests Power, volume, input, navigation, temperature, etc.

### Existing features retained
- Universal scan with fast / identify modes.
- Pause, resume, previous and next during scanning.
- `FUNCIONÓ` workflow.
- Manual wheel code picker and search.
- Persistent one-tap saved devices.
- 36/38/40 kHz diagnostics.
- Expanded Flipper-IRDB build database and custom app icon.

## Hardware note

IR learning requires a demodulating IR receiver connected to an audio input.
The stereo LED transmitter itself is output-only unless the physical accessory
also contains a receiver/input path.

A fixed 38 kHz receiver removes the optical carrier before the audio capture,
so the app stores the carrier setting separately from the learned envelope.
