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

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var sessionToken = UUID()
    private var currentCodes: [IRCode] = []

    private let interCodeGapSeconds = 0.205
    private let prePadMicros: UInt64 = 15_000

    init() {
        engine.attach(player)
    }

    /// Extended mode: a compact set of common/current power codes first,
    /// followed by the full TV-B-Gone database for the selected region.
    func start(region: TVRegion) {
        let codes = UniversalPowerCodes.codes + region.codes
        start(codes: codes)
    }

    func testVestelTDSystems() {
        transmitSingle(
            UniversalPowerCodes.vestelTDSystemsTest,
            label: "Prueba TD Systems/Vestel RC5"
        )
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
        if player.isPlaying { player.stop() }
        if engine.isRunning { engine.stop() }
        isSending = false
        progress = 0
        sentCount = 0
        totalCount = 0
        skippedCount = 0
    }

    private func start(codes: [IRCode]) {
        stop()

        do {
            let format = try configureAudio()

            currentCodes = codes
            guard !currentCodes.isEmpty else {
                warning = "La base de códigos está vacía."
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
            schedule(index: 0, token: token, format: format)
        } catch {
            warning = "No se pudo iniciar el audio: \(error.localizedDescription)"
            isSending = false
        }
    }

    private func transmitSingle(_ code: IRCode, label: String) {
        stop()

        do {
            let format = try configureAudio()

            guard carrierIsRepresentable(code.carrierHz, sampleRate: format.sampleRate) else {
                warning = "\(label): la salida de audio no puede representar esa portadora con \(Int(format.sampleRate)) Hz."
                return
            }

            try startEngine(format: format)
            warning = audioWarning(for: format.sampleRate)

            let buffer = render(code: code, format: format, addGap: true)
            player.scheduleBuffer(
                buffer,
                at: nil,
                options: [],
                completionCallbackType: .dataPlayedBack
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.player.stop()
                    self?.engine.stop()
                }
            }
            player.play()
        } catch {
            warning = "\(label): \(error.localizedDescription)"
        }
    }

    private func configureAudio() throws -> AVAudioFormat {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])

        // 96 kHz is requested so that adapters/DACs which actually support it
        // can reproduce higher TV-B-Gone carriers. Apple's common audio path
        // may negotiate 48 kHz; the app always uses the real negotiated rate.
        try session.setPreferredSampleRate(96_000)
        if session.maximumOutputNumberOfChannels >= 2 {
            try? session.setPreferredOutputNumberOfChannels(2)
        }
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)

        sampleRate = session.sampleRate

        let output = session.currentRoute.outputs.first
        let channels = output?.channels?.count ?? 0
        routeDescription = "\(output?.portName ?? "Salida desconocida") · \(channels) canal(es)"

        guard channels >= 2 else {
            throw NSError(
                domain: "TVBGoneAudio",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "La ruta de salida no aparece como estéreo. Este adaptador necesita 2 canales."
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
                userInfo: [NSLocalizedDescriptionKey: "No se pudo crear el formato PCM estéreo."]
            )
        }

        return format
    }

    private func startEngine(format: AVAudioFormat) throws {
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0
        engine.prepare()
        try engine.start()
        player.volume = 1.0
        player.play()
    }

    private func audioWarning(for rate: Double) -> String? {
        if rate < 47_000 {
            return "Salida a \(Int(rate)) Hz. Mantén el volumen multimedia al 100 %, Audio mono DESACTIVADO y el balance centrado."
        }

        return "Salida: \(Int(rate)) Hz. Volumen multimedia al 100 %, Audio mono DESACTIVADO y balance centrado."
    }

    private func carrierIsRepresentable(_ carrierHz: Int, sampleRate: Double) -> Bool {
        let carrier = carrierHz == 0 ? 38_000.0 : Double(carrierHz)
        let tone = carrier / 2.0
        // Leave margin below Nyquist for the real DAC/reconstruction filter.
        return tone <= sampleRate * 0.45
    }

    private func schedule(index: Int, token: UUID, format: AVAudioFormat) {
        guard isSending, token == sessionToken else { return }

        guard index < currentCodes.count else {
            isSending = false
            progress = 1
            sentCount = totalCount
            player.stop()
            engine.stop()
            return
        }

        let code = currentCodes[index]

        // Never silently turn an unsupported high carrier into a different
        // frequency. Skip it instead. This is important on 48 kHz DACs.
        if !carrierIsRepresentable(code.carrierHz, sampleRate: format.sampleRate) {
            skippedCount += 1
            sentCount = index + 1
            progress = Double(index + 1) / Double(max(1, totalCount))
            schedule(index: index + 1, token: token, format: format)
            return
        }

        let buffer = render(code: code, format: format, addGap: true)
        player.scheduleBuffer(
            buffer,
            at: nil,
            options: [],
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isSending, token == self.sessionToken else { return }
                self.sentCount = index + 1
                self.progress = Double(index + 1) / Double(max(1, self.totalCount))
                self.schedule(index: index + 1, token: token, format: format)
            }
        }
    }

    private func render(
        code: IRCode,
        format: AVAudioFormat,
        addGap: Bool
    ) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let signalMicros = code.durationsMicros.reduce(UInt64(0)) { $0 + UInt64($1) }
        let gapMicros: UInt64 =
            addGap ? UInt64(interCodeGapSeconds * 1_000_000.0) : 0

        let totalMicros = prePadMicros + signalMicros + gapMicros
        let frameCount = AVAudioFrameCount(
            ceil(Double(totalMicros) * sr / 1_000_000.0)
        )

        let safeFrameCount = max(frameCount, 1)
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: safeFrameCount
        )!
        buffer.frameLength = safeFrameCount

        guard let left = buffer.floatChannelData?[0],
              let right = buffer.floatChannelData?[1] else {
            return buffer
        }

        let length = Int(buffer.frameLength)
        for i in 0..<length {
            left[i] = 0
            right[i] = 0
        }

        let requestedCarrier =
            code.carrierHz == 0 ? 38_000.0 : Double(code.carrierHz)
        let audioHz = requestedCarrier / 2.0
        let phaseIncrement = 2.0 * Double.pi * audioHz / sr
        let amplitude: Float = 0.999

        var cursor = Int(
            round(Double(prePadMicros) * sr / 1_000_000.0)
        )

        for (segmentIndex, micros) in code.durationsMicros.enumerated() {
            let frames = Int(
                round(Double(micros) * sr / 1_000_000.0)
            )
            let end = min(length, cursor + frames)
            let isMark = segmentIndex % 2 == 0

            if isMark {
                // Important for audio-IR adapters: restart each carrier burst
                // at phase zero instead of resuming an arbitrary old phase.
                var phase = 0.0
                while cursor < end {
                    let sample = amplitude * Float(sin(phase))
                    left[cursor] = sample
                    right[cursor] = -sample
                    phase += phaseIncrement
                    if phase >= 2.0 * Double.pi {
                        phase -= 2.0 * Double.pi
                    }
                    cursor += 1
                }
            } else {
                // Buffer was pre-zeroed; only advance through the space.
                cursor = end
            }
        }

        return buffer
    }
}
