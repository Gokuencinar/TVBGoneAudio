import AVFoundation
import Foundation

@MainActor
final class IRTransmitter: ObservableObject {
    @Published private(set) var isSending = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var sentCount = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var routeDescription = "Sin configurar"
    @Published private(set) var sampleRate: Double = 0
    @Published private(set) var warning: String?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var sessionToken = UUID()
    private var currentCodes: [IRCode] = []
    private let interCodeGapSeconds = 0.205

    init() {
        engine.attach(player)
    }

    func start(region: TVRegion) {
        stop()
        do {
            try configureAudio()
            currentCodes = region.codes
            guard !currentCodes.isEmpty else {
                warning = "La base de códigos está vacía."
                return
            }

            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 2,
                interleaved: false
            )!

            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.prepare()
            try engine.start()
            player.play()

            totalCount = currentCodes.count
            sentCount = 0
            progress = 0
            isSending = true
            warning = sampleRate < 88_000
                ? "Salida a \(Int(sampleRate)) Hz: algunas portadoras altas se aproximarán al máximo reproducible."
                : nil

            let token = UUID()
            sessionToken = token
            schedule(index: 0, token: token, format: format)
        } catch {
            warning = "No se pudo iniciar el audio: \(error.localizedDescription)"
            isSending = false
        }
    }

    func stop() {
        sessionToken = UUID()
        if player.isPlaying { player.stop() }
        if engine.isRunning { engine.stop() }
        isSending = false
        progress = 0
        sentCount = 0
        totalCount = 0
    }

    func testCarrier() {
        stop()
        do {
            try configureAudio()
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 2,
                interleaved: false
            )!
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.prepare()
            try engine.start()

            let code = IRCode(id: "test-38k", carrierHz: 38_000, durationsMicros: [1_000_000, 20_000])
            let buffer = render(code: code, format: format, addGap: false)
            player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                Task { @MainActor in
                    self?.player.stop()
                    self?.engine.stop()
                }
            }
            player.play()
        } catch {
            warning = "No se pudo reproducir la prueba: \(error.localizedDescription)"
        }
    }

    private func configureAudio() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
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

        let buffer = render(code: currentCodes[index], format: format, addGap: true)
        player.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isSending, token == self.sessionToken else { return }
                self.sentCount = index + 1
                self.progress = Double(index + 1) / Double(max(1, self.totalCount))
                self.schedule(index: index + 1, token: token, format: format)
            }
        }
    }

    private func render(code: IRCode, format: AVAudioFormat, addGap: Bool) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let signalMicros = code.durationsMicros.reduce(0) { $0 + UInt64($1) }
        let gapMicros: UInt64 = addGap ? UInt64(interCodeGapSeconds * 1_000_000) : 0
        let frameCount = AVAudioFrameCount(
            ceil(Double(signalMicros + gapMicros) * sr / 1_000_000.0)
        )

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(frameCount, 1))!
        buffer.frameLength = max(frameCount, 1)

        guard let left = buffer.floatChannelData?[0],
              let right = buffer.floatChannelData?[1] else {
            return buffer
        }

        let requestedCarrier = code.carrierHz == 0 ? 38_000.0 : Double(code.carrierHz)
        let desiredAudioHz = requestedCarrier / 2.0
        let maxAudioHz = sr * 0.45
        let audioHz = min(desiredAudioHz, maxAudioHz)
        let omega = 2.0 * Double.pi * audioHz / sr
        let amplitude: Float = 0.98

        var cursor = 0
        var phase = 0.0

        for (segmentIndex, micros) in code.durationsMicros.enumerated() {
            let frames = Int(round(Double(micros) * sr / 1_000_000.0))
            let end = min(Int(buffer.frameLength), cursor + frames)
            let isMark = segmentIndex % 2 == 0

            if isMark {
                while cursor < end {
                    let value = amplitude * Float(sin(phase))
                    left[cursor] = value
                    right[cursor] = -value
                    phase += omega
                    if phase >= 2.0 * Double.pi { phase -= 2.0 * Double.pi }
                    cursor += 1
                }
            } else {
                while cursor < end {
                    left[cursor] = 0
                    right[cursor] = 0
                    cursor += 1
                }
            }
        }

        while cursor < Int(buffer.frameLength) {
            left[cursor] = 0
            right[cursor] = 0
            cursor += 1
        }

        return buffer
    }
}
