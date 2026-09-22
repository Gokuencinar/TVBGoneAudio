# TVBGoneAudio

iOS infrared transmitter for stereo audio IR dongles.

## Device sections

The app now has three independent power-off scans:

- **TV**: the existing universal front-set + the original TV-B-Gone regional
  database + additional modern TV POWER/OFF signals from Flipper-IRDB.
- **Aire**: POWER/OFF signals from air-conditioner remotes.
- **Proyector**: POWER/OFF signals from projector remotes.

The TV ordering intentionally keeps the original working sequence first so
devices that already responded to the previous version should respond at the
same point in the scan.

## Audio IR

The output is stereo, with the right channel inverted relative to the left.
For opposed-LED audio IR adapters the generated audio tone is half the desired
IR carrier. Each MARK burst restarts at phase zero.

On the iPhone:

- Media volume: 100%
- Settings > Accessibility > Audio/Visual > Mono Audio: OFF
- Balance: centered

The app requests 96 kHz output but uses the actual rate negotiated by the
Lightning audio path. Codes whose carrier cannot be represented safely are
skipped rather than transmitted at an incorrect frequency.

## Building

GitHub Actions:

1. downloads/generates the original TV-B-Gone database;
2. fetches the pinned Flipper-IRDB TV/AC/projector folders;
3. generates `GeneratedFlipperPowerDatabase.swift`;
4. builds an unsigned iPhone app;
5. packages `TVBGoneAudio.ipa` as an Actions artifact.

See `THIRD_PARTY.md` for database attribution and licensing.
