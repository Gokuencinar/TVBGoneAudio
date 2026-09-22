import AVFoundation
import Foundation

@MainActor
final class IRTransmitter: ObservableObject {
    @Published private(set) var isSending = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var sentCount = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var skippedCount = 0
    @Published private(set) var routeDescription = "Sin configurar"
    @Published private(set) var sampleRate: Double = 0
    @Published private(set) var warning: String?
    @Published private(set) var currentCodeID: String?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var sessionToken = UUID()
    private var currentCodes: [IRCode] = []

    private let interCodeGapSeconds = 0.205
    private let prePadMicros: UInt64 = 15_000

    init() {
        engine.attach(player)
    }

    func codeCount(for category: IRDeviceCategory, region: TVRegion) -> Int {
        codes(for: category, region: region).count
    }

    func start(category: IRDeviceCategory, region: TVRegion) {
        start(codes: codes(for: category, region: region))
    }

    func testCarrier() {
        let code = IRCode(
            id: "test-38k",
            carrierHz: 38_000,
            durationsMicros: [1_000_000, 20_000]
        )
        transmitSingle(code, label: "Prueba de portadora 38 kHz")
    }

    func stop() {
        sessionToken = UUID()

        if player.isPlaying {
            player.stop()
        }
        if engine.isRunning {
            engine.stop()
        }

        isSending = false
        currentCodeID = nil
    }

    private func codes(
        for category: IRDeviceCategory,
        region: TVRegion
    ) -> [IRCode] {
        switch category {
        case .television:
            // Preserve the exact ordering that already powered off the user's
            // TD Systems: universal front-set + TV-B-Gone first.
            // The new Flipper-IRDB collection is appended afterwards.
            return (
                UniversalPowerCodes.codes
                + region.codes
                + GeneratedFlipperPowerDatabase.televisions
            )

        case .airConditioner:
            return GeneratedFlipperPowerDatabase.airConditioners

        case .projector:
            return GeneratedFlipperPowerDatabase.projectors
        }
    }

    private func start(codes: [IRCode]) {
        stop()

        progress = 0
        sentCount = 0
        totalCount = 0
        skippedCount = 0

        do {
            let format = try configureAudio()

            currentCodes = codes

            guard !currentCodes.isEmpty else {
                warning = "No hay códigos disponibles para esta categoría."
                return
            }

            try startEngine(format: format)

            totalCount = currentCodes.count
            sentCount = 0
            skippedCount = 0
            progress = 0
            isSending = true
            warning = audioWarning(for: format.sampleRate)

            let token = UUID()
            sessionToken = token

            schedule(
                index: 0,
                token: token,
                format: format
            )
        } catch {
            warning =
                "No se pudo iniciar el audio: \(error.localizedDescription)"
            isSending = false
        }
    }

    private func transmitSingle(
        _ code: IRCode,
        label: String
    ) {
        stop()

        do {
            let format = try configureAudio()

            guard carrierIsRepresentable(
                code.carrierHz,
                sampleRate: format.sampleRate
            ) else {
                warning =
                    "\(label): la salida no puede representar esa portadora con \(Int(format.sampleRate)) Hz."
                return
            }

            try startEngine(format: format)
            warning = audioWarning(for: format.sampleRate)
            currentCodeID = code.id

            let buffer = render(
                code: code,
                format: format,
                addGap: true
            )

            player.scheduleBuffer(
                buffer,
                at: nil,
                options: [],
                completionCallbackType: .dataPlayedBack
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.player.stop()
                    self?.engine.stop()
                    self?.currentCodeID = nil
                }
            }

            player.play()
        } catch {
            warning =
                "\(label): \(error.localizedDescription)"
        }
    }

    private func configureAudio() throws -> AVAudioFormat {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .playback,
            mode: .default,
            options: []
        )

        try session.setPreferredSampleRate(96_000)

        if session.maximumOutputNumberOfChannels >= 2 {
            try? session.setPreferredOutputNumberOfChannels(2)
        }

        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)

        sampleRate = session.sampleRate

        let output = session.currentRoute.outputs.first
        let channels = output?.channels?.count ?? 0

        routeDescription =
            "\(output?.portName ?? "Salida desconocida") · \(channels) canal(es)"

        guard channels >= 2 else {
            throw NSError(
                domain: "TVBGoneAudio",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "La ruta de salida no aparece como estéreo. Este emisor necesita 2 canales."
                ]
            )
        }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false
        ) else {
            throw NSError(
                domain: "TVBGoneAudio",
                code: 3,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "No se pudo crear el formato PCM estéreo."
                ]
            )
        }

        return format
    }

    private func startEngine(
        format: AVAudioFormat
    ) throws {
        engine.disconnectNodeOutput(player)

        engine.connect(
            player,
            to: engine.mainMixerNode,
            format: format
        )

        engine.mainMixerNode.outputVolume = 1.0
        engine.prepare()

        try engine.start()

        player.volume = 1.0
        player.play()
    }

    private func audioWarning(
        for rate: Double
    ) -> String {
        "Salida: \(Int(rate)) Hz. Volumen multimedia al 100 %, Audio mono DESACTIVADO y balance centrado."
    }

    private func carrierIsRepresentable(
        _ carrierHz: Int,
        sampleRate: Double
    ) -> Bool {
        let carrier =
            carrierHz == 0
            ? 38_000.0
            : Double(carrierHz)

        let audioTone = carrier / 2.0

        // Leave a little margin below Nyquist and the DAC reconstruction filter.
        return audioTone <= sampleRate * 0.45
    }

    private func schedule(
        index: Int,
        token: UUID,
        format: AVAudioFormat
    ) {
        guard isSending,
              token == sessionToken else {
            return
        }

        guard index < currentCodes.count else {
            isSending = false
            progress = 1
            sentCount = totalCount
            currentCodeID = nil

            player.stop()
            engine.stop()
            return
        }

        let code = currentCodes[index]
        currentCodeID = code.id

        if !carrierIsRepresentable(
            code.carrierHz,
            sampleRate: format.sampleRate
        ) {
            skippedCount += 1
            sentCount = index + 1
            progress =
                Double(index + 1)
                / Double(max(1, totalCount))

            schedule(
                index: index + 1,
                token: token,
                format: format
            )
            return
        }

        let buffer = render(
            code: code,
            format: format,
            addGap: true
        )

        player.scheduleBuffer(
            buffer,
            at: nil,
            options: [],
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      self.isSending,
                      token == self.sessionToken else {
                    return
                }

                self.sentCount = index + 1
                self.progress =
                    Double(index + 1)
                    / Double(max(1, self.totalCount))

                self.schedule(
                    index: index + 1,
                    token: token,
                    format: format
                )
            }
        }
    }

    private func render(
        code: IRCode,
        format: AVAudioFormat,
        addGap: Bool
    ) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate

        let signalMicros =
            code.durationsMicros.reduce(UInt64(0)) {
                $0 + UInt64($1)
            }

        let gapMicros: UInt64 =
            addGap
            ? UInt64(interCodeGapSeconds * 1_000_000.0)
            : 0

        let totalMicros =
            prePadMicros
            + signalMicros
            + gapMicros

        let frameCount = AVAudioFrameCount(
            ceil(
                Double(totalMicros)
                * sampleRate
                / 1_000_000.0
            )
        )

        let safeFrameCount =
            max(frameCount, 1)

        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: safeFrameCount
        )!

        buffer.frameLength =
            safeFrameCount

        guard
            let left =
                buffer.floatChannelData?[0],
            let right =
                buffer.floatChannelData?[1]
        else {
            return buffer
        }

        let length =
            Int(buffer.frameLength)

        for i in 0..<length {
            left[i] = 0
            right[i] = 0
        }

        let requestedCarrier =
            code.carrierHz == 0
            ? 38_000.0
            : Double(code.carrierHz)

        // Anti-phase stereo adapters with opposed LEDs create two optical
        // pulses per audio cycle, hence half the desired IR carrier frequency.
        let audioHz =
            requestedCarrier / 2.0

        let phaseIncrement =
            2.0
            * Double.pi
            * audioHz
            / sampleRate

        let amplitude: Float =
            0.999

        var cursor = Int(
            round(
                Double(prePadMicros)
                * sampleRate
                / 1_000_000.0
            )
        )

        for (segmentIndex, micros)
            in code.durationsMicros.enumerated()
        {
            let frames = Int(
                round(
                    Double(micros)
                    * sampleRate
                    / 1_000_000.0
                )
            )

            let end =
                min(
                    length,
                    cursor + frames
                )

            let isMark =
                segmentIndex % 2 == 0

            if isMark {
                // Start every IR burst at phase zero. This matches the behavior
                // of common audio-IR waveform generators and avoids arbitrary
                // burst edges.
                var phase = 0.0

                while cursor < end {
                    let sample =
                        amplitude
                        * Float(sin(phase))

                    left[cursor] =
                        sample

                    right[cursor] =
                        -sample

                    phase += phaseIncrement

                    if phase >=
                        2.0 * Double.pi
                    {
                        phase -=
                            2.0 * Double.pi
                    }

                    cursor += 1
                }
            } else {
                cursor = end
            }
        }

        return buffer
    }
}
