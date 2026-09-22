import AVFoundation
import Foundation

@MainActor
final class IRTransmitter: ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var isPaused = false
    @Published private(set) var isPreviewing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var sentCount = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var skippedCount = 0
    @Published private(set) var routeDescription = "Sin configurar"
    @Published private(set) var sampleRate: Double = 0
    @Published private(set) var outputChannels: Int = 0
    @Published private(set) var outputPortType = ""
    @Published private(set) var isExternalOutput = false
    @Published private(set) var outputRouteSuitableForIR = false
    @Published private(set) var warning: String?
    @Published private(set) var currentCodeID: String?
    @Published private(set) var currentCodeName: String?
    @Published private(set) var recentCodeIDs: [String] = []

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private var sessionToken = UUID()
    private var currentCodes: [IRCode] = []
    private var currentIndex = 0
    private var currentPace: ScanPace = .fast
    private var currentCategory: IRDeviceCategory = .television

    private let prePadMicros: UInt64 = 15_000

    init() {
        engine.attach(player)
    }

    func codeCount(
        for category: IRDeviceCategory,
        region: TVRegion
    ) -> Int {
        IRCodeCatalog.codes(
            for: category,
            region: region
        ).count
    }

    func start(
        category: IRDeviceCategory,
        region: TVRegion,
        pace: ScanPace
    ) {
        stop(resetProgress: true)

        let codes = IRCodeCatalog.codes(
            for: category,
            region: region
        )

        guard !codes.isEmpty else {
            warning = "No hay códigos disponibles para esta categoría."
            return
        }

        currentCategory = category
        currentCodes = codes
        currentIndex = 0
        currentPace = pace
        recentCodeIDs = []

        do {
            let format = try configureAudio()
            try startEngine(format: format)

            totalCount = currentCodes.count
            sentCount = 0
            skippedCount = 0
            progress = 0
            isScanning = true
            isPaused = false
            warning = audioWarning(for: format.sampleRate)

            let token = UUID()
            sessionToken = token
            scheduleCurrent(
                token: token,
                format: format
            )
        } catch {
            warning =
                "No se pudo iniciar el audio: \(error.localizedDescription)"
            isScanning = false
        }
    }

    func pause() {
        guard isScanning, !isPaused else { return }

        sessionToken = UUID()
        player.stop()
        if engine.isRunning {
            engine.stop()
        }

        isPaused = true
        isPreviewing = false
    }

    func resume() {
        guard isScanning, isPaused else { return }

        do {
            let format = try configureAudio()
            try startEngine(format: format)

            isPaused = false
            let token = UUID()
            sessionToken = token

            scheduleCurrent(
                token: token,
                format: format
            )
        } catch {
            warning =
                "No se pudo reanudar: \(error.localizedDescription)"
        }
    }

    func step(_ delta: Int) {
        guard isScanning, !currentCodes.isEmpty else { return }

        if !isPaused {
            pause()
        }

        currentIndex = min(
            max(0, currentIndex + delta),
            currentCodes.count - 1
        )

        sentCount = currentIndex
        progress =
            Double(currentIndex)
            / Double(max(1, totalCount))

        preview(
            code: currentCodes[currentIndex],
            preserveScan: true
        )
    }

    func stop() {
        stop(resetProgress: false)
    }

    func candidateCodes() -> [IRCode] {
        let ids = Array(recentCodeIDs.reversed().prefix(4))
        return ids.compactMap { id in
            currentCodes.first { $0.id == id }
                ?? IRCodeCatalog.code(
                    id: id,
                    category: currentCategory
                )
        }
    }

    func markWorked() -> [IRCode] {
        if isScanning && !isPaused {
            pause()
        }
        return candidateCodes()
    }

    func send(
        code: IRCode
    ) {
        preview(
            code: code,
            preserveScan: false
        )
    }

    func inspectOutputRoute() {
        do {
            let format = try configureAudio()
            warning = audioWarning(for: format.sampleRate)
        } catch {
            warning =
                "Salida no compatible: \(error.localizedDescription)"
        }
    }

    func testCarrier(
        hz: Int
    ) {
        let code = IRCode(
            id: "test-\(hz)",
            carrierHz: hz,
            durationsMicros: [1_000_000, 20_000]
        )

        preview(
            code: code,
            preserveScan: false
        )
    }

    private func stop(
        resetProgress: Bool
    ) {
        sessionToken = UUID()

        if player.isPlaying {
            player.stop()
        }
        if engine.isRunning {
            engine.stop()
        }

        isScanning = false
        isPaused = false
        isPreviewing = false
        currentCodeID = nil
        currentCodeName = nil

        if resetProgress {
            progress = 0
            sentCount = 0
            totalCount = 0
            skippedCount = 0
        }
    }

    private func preview(
        code: IRCode,
        preserveScan: Bool
    ) {
        let wasScanning = isScanning
        let wasPaused = isPaused

        sessionToken = UUID()
        if player.isPlaying {
            player.stop()
        }
        if engine.isRunning {
            engine.stop()
        }

        do {
            let format = try configureAudio()

            guard carrierIsRepresentable(
                code.carrierHz,
                sampleRate: format.sampleRate
            ) else {
                warning =
                    "La salida de \(Int(format.sampleRate)) Hz no puede representar con margen la portadora de \(code.carrierHz) Hz."
                return
            }

            try startEngine(format: format)
            warning = audioWarning(for: format.sampleRate)
            currentCodeID = code.id
            currentCodeName = code.displayName
            remember(code)

            if !preserveScan {
                isPreviewing = true
            }

            let buffer = render(
                code: code,
                format: format,
                gapSeconds: 0.10
            )

            let token = UUID()
            sessionToken = token

            player.scheduleBuffer(
                buffer,
                at: nil,
                options: [],
                completionCallbackType: .dataPlayedBack
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self,
                          self.sessionToken == token else {
                        return
                    }

                    self.player.stop()
                    if self.engine.isRunning {
                        self.engine.stop()
                    }

                    self.isPreviewing = false

                    if preserveScan {
                        self.isScanning = wasScanning
                        self.isPaused = wasPaused
                    } else {
                        self.currentCodeID = nil
                        self.currentCodeName = nil
                    }
                }
            }

            player.play()
        } catch {
            warning =
                "No se pudo transmitir: \(error.localizedDescription)"
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
        outputChannels = channels
        outputPortType = output?.portType.rawValue ?? ""
        isExternalOutput =
            output != nil
            && output?.portType != .builtInSpeaker
            && output?.portType != .builtInReceiver

        if let output {
            switch output.portType {
            case .headphones, .usbAudio, .lineOut:
                outputRouteSuitableForIR = channels >= 2
            default:
                outputRouteSuitableForIR = false
            }
        } else {
            outputRouteSuitableForIR = false
        }

        routeDescription =
            "\(output?.portName ?? "Salida desconocida") · \(channels) canal(es)"

        guard channels >= 2 else {
            throw NSError(
                domain: "TVBGoneAudio",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "La ruta no aparece como estéreo. Este emisor necesita 2 canales."
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
        "Salida \(Int(rate)) Hz · Audio mono DESACTIVADO · balance centrado · volumen 100 %."
    }

    private func carrierIsRepresentable(
        _ carrierHz: Int,
        sampleRate: Double
    ) -> Bool {
        let carrier =
            carrierHz == 0
            ? 38_000.0
            : Double(carrierHz)

        let audioTone =
            carrier / 2.0

        return audioTone <= sampleRate * 0.45
    }

    private func scheduleCurrent(
        token: UUID,
        format: AVAudioFormat
    ) {
        guard
            isScanning,
            !isPaused,
            token == sessionToken
        else {
            return
        }

        guard currentIndex < currentCodes.count else {
            finishScan()
            return
        }

        let code = currentCodes[currentIndex]

        currentCodeID = code.id
        currentCodeName = code.displayName

        if !carrierIsRepresentable(
            code.carrierHz,
            sampleRate: format.sampleRate
        ) {
            skippedCount += 1
            advanceAfterCode(
                token: token,
                format: format
            )
            return
        }

        remember(code)

        let buffer = render(
            code: code,
            format: format,
            gapSeconds: currentPace.gapSeconds
        )

        player.scheduleBuffer(
            buffer,
            at: nil,
            options: [],
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor in
                guard
                    let self,
                    self.isScanning,
                    !self.isPaused,
                    token == self.sessionToken
                else {
                    return
                }

                self.advanceAfterCode(
                    token: token,
                    format: format
                )
            }
        }
    }

    private func advanceAfterCode(
        token: UUID,
        format: AVAudioFormat
    ) {
        sentCount = currentIndex + 1
        progress =
            Double(sentCount)
            / Double(max(1, totalCount))

        currentIndex += 1

        if currentIndex >= currentCodes.count {
            finishScan()
        } else {
            scheduleCurrent(
                token: token,
                format: format
            )
        }
    }

    private func finishScan() {
        isScanning = false
        isPaused = false
        isPreviewing = false
        progress = 1
        sentCount = totalCount
        currentCodeID = nil
        currentCodeName = nil

        player.stop()
        if engine.isRunning {
            engine.stop()
        }
    }

    private func remember(_ code: IRCode) {
        recentCodeIDs.removeAll { $0 == code.id }
        recentCodeIDs.append(code.id)

        if recentCodeIDs.count > 8 {
            recentCodeIDs.removeFirst(
                recentCodeIDs.count - 8
            )
        }
    }

    private func render(
        code: IRCode,
        format: AVAudioFormat,
        gapSeconds: Double
    ) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate

        let signalMicros =
            code.durationsMicros.reduce(UInt64(0)) {
                $0 + UInt64($1)
            }

        let gapMicros =
            UInt64(max(0, gapSeconds) * 1_000_000.0)

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
                var phase = 0.0

                while cursor < end {
                    let sample =
                        amplitude
                        * Float(sin(phase))

                    left[cursor] = sample
                    right[cursor] = -sample

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
