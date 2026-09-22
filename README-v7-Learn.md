# IR Universal v7 — Learn IR

This patch builds on v6 and adds a real IR learning workflow.

## Learning requirements

The current stereo audio IR LED transmitter is an output device. It cannot
learn a remote by itself. Learning requires an IR receiver whose demodulated
output is connected to an iPhone audio input (for example through a suitable
Lightning/headset audio interface).

A common fixed-frequency IR receiver removes the optical carrier before the
signal reaches iOS, so the app asks the user to select the carrier (36/38/40/56
kHz) separately.

## Learning workflow

1. Open **Aprender**.
2. Connect the IR receiver to an audio input.
3. Grant microphone permission.
4. Tap **Comprobar entrada**.
5. Choose the receiver/carrier frequency.
6. Tap **INICIAR CAPTURA**.
7. Press one remote button once.
8. The app records a short PCM capture and detects signal edges.
9. Test the reconstructed IR command with the existing audio IR transmitter.
10. Save it if it works.

Learned waveforms are stored persistently and can be added to **Mis equipos**.

## Signal reconstruction

The microphone/audio path is AC-coupled. Instead of assuming stable high/low
logic levels, the learner detects strong sample-to-sample edges and converts
the distance between consecutive edges into raw IR timings in microseconds.

This is intentionally a RAW-learning system: the app does not need to know
whether an unknown remote uses NEC, RC5, Kaseikyo or another protocol.
