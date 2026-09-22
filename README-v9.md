# IR Universal 3.1 — Build 9

Changes:
- Fixes the missing Learn tab icon on iOS 16 by using `mic.fill`.
- Replaces the app icon with a cleaner Power + IR-waves design.
- Adds `Auto` carrier mode to IR learning.
- Auto carrier is inferred from the decoded protocol:
  - RC5 / RC6 -> 36 kHz
  - NEC / Samsung / JVC / RCA / Kaseikyo -> 38 kHz
  - Sony SIRC / Pioneer -> 40 kHz
  - unknown -> 38 kHz fallback
- The UI explicitly explains that a demodulating IR receiver removes the optical carrier, so this is protocol-based inference rather than direct carrier measurement.
- Diagnostics now explains why full volume, centered balance and stereo (Mono Audio off) matter for anti-phase audio IR transmitters.
