import AVFoundation
import Combine
import Foundation

struct IRCaptureResult: Equatable {
    let durationsMicros: [UInt32]
    let sampleRate: Double
    let edgeCount: Int
    let peakLevel: Float

    var durationMillis: Int {
        Int(
            durationsMicros.reduce(UInt64(0)) {
                $0 + UInt64($1)
            } / 1000
        )
    }
}

@MainActor
final class IRLearner: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var inputDescription = "Sin comprobar"
    @Published private(set) var inputChannels = 0
    @Published private(set) var inputPortType = ""
    @Published private(set) var isExternalInput = false
    @Published private(set) var availableInputDescriptions: [String] = []
    @Published private(set) var sampleRate: Double = 0
    @Published private(set) var permissionGranted = false
    @Published private(set) var lastResult: IRCaptureResult?
    @Published private(set) var validationActive = false
    @Published private(set) var validationCount = 0
    @Published private(set) var consistency: Double?
    @Published private(set) var status =
        "Conecta un receptor IR a una entrada de audio y pulsa «Comprobar entrada»."

    private var recorder: AVAudioRecorder?
    private var captureURL: URL?

    private let preferredSampleRate = 48_000.0
    private let captureSeconds = 3.5
    private var validationCaptures: [IRCaptureResult] = []

    override init() {
        super.init()
        refreshPermissionState()
    }

    func refreshPermissionState() {
        let session = AVAudioSession.sharedInstance()

        switch session.recordPermission {
        case .granted:
            permissionGranted = true
        case .denied, .undetermined:
            permissionGranted = false
        @unknown default:
            permissionGranted = false
        }
    }

    func requestPermissionAndCheckInput() {
        let session = AVAudioSession.sharedInstance()

        switch session.recordPermission {
        case .granted:
            permissionGranted = true
            checkInput()

        case .denied:
            permissionGranted = false
            status =
                "El permiso de micrófono está desactivado. Actívalo en Ajustes para poder aprender señales."

        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    self.permissionGranted = granted

                    if granted {
                        self.checkInput()
                    } else {
                        self.status =
                            "Sin permiso de micrófono no se puede usar la función Aprender."
                    }
                }
            }

        @unknown default:
            permissionGranted = false
            status =
                "No se pudo determinar el permiso de entrada de audio."
        }
    }

    func checkInput() {
        do {
            let session = AVAudioSession.sharedInstance()

            try session.setCategory(
                .record,
                mode: .measurement,
                options: []
            )

            try session.setPreferredSampleRate(
                preferredSampleRate
            )

            availableInputDescriptions =
                (session.availableInputs ?? []).map { port in
                    "\(port.portName) · \(port.portType.rawValue)"
                }

            if let external =
                (session.availableInputs ?? []).first(where: {
                    $0.portType != .builtInMic
                })
            {
                try? session.setPreferredInput(external)
            }

            try session.setActive(true)

            sampleRate = session.sampleRate
            updateInputInfo(session.currentRoute.inputs.first)

            if inputChannels <= 0 {
                status =
                    "No aparece ninguna entrada de audio. El emisor IR puede seguir transmitiendo, pero para aprender necesitas un receptor conectado a una entrada de audio."
            } else if !isExternalInput {
                status =
                    "La única entrada activa es el micrófono interno del iPhone. Este accesorio no ofrece una entrada externa, así que no puede aprender IR con el hardware conectado."
            } else {
                status =
                    "Entrada externa detectada. Esto confirma la ruta de audio; todavía hay que comprobar que el hardware conectado sea realmente un receptor IR válido."
            }
        } catch {
            status =
                "No se pudo configurar la entrada: \(error.localizedDescription)"
        }
    }

    private func updateInputInfo(
        _ input: AVAudioSessionPortDescription?
    ) {
        inputChannels =
            input?.channels?.count ?? 0
        inputPortType =
            input?.portType.rawValue ?? ""
        isExternalInput =
            input != nil
            && input?.portType != .builtInMic

        inputDescription =
            "\(input?.portName ?? "Sin entrada") · \(inputChannels) canal(es)"
    }

    func beginValidatedCapture() {
        validationActive = true
        validationCaptures = []
        validationCount = 0
        consistency = nil
        lastResult = nil
        status =
            "Validación x3 preparada. Haz tres capturas del MISMO botón. Empieza con la toma 1."
    }

    func cancelValidation() {
        validationActive = false
        validationCaptures = []
        validationCount = 0
        consistency = nil
        status =
            "Validación cancelada. Puedes hacer una captura normal."
    }

    func startCapture() {
        if !validationActive {
            lastResult = nil
            consistency = nil
        }

        let session = AVAudioSession.sharedInstance()

        guard session.recordPermission == .granted else {
            requestPermissionAndCheckInput()
            return
        }

        do {
            try session.setCategory(
                .record,
                mode: .measurement,
                options: []
            )

            try session.setPreferredSampleRate(
                preferredSampleRate
            )

            availableInputDescriptions =
                (session.availableInputs ?? []).map { port in
                    "\(port.portName) · \(port.portType.rawValue)"
                }

            if let external =
                (session.availableInputs ?? []).first(where: {
                    $0.portType != .builtInMic
                })
            {
                try? session.setPreferredInput(external)
            }

            try session.setActive(true)

            sampleRate = session.sampleRate
            updateInputInfo(session.currentRoute.inputs.first)

            guard inputChannels > 0 else {
                status =
                    "No hay una entrada de audio disponible para capturar el mando."
                return
            }

            guard isExternalInput else {
                status =
                    "Captura bloqueada: iOS está usando el micrófono interno del iPhone. Conecta una interfaz que exponga una entrada de audio externa para el receptor IR."
                return
            }

            let url =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "ir-learning-\(UUID().uuidString).caf"
                )

            captureURL = url

            let settings: [String: Any] = [
                AVFormatIDKey:
                    Int(kAudioFormatLinearPCM),
                AVSampleRateKey:
                    session.sampleRate,
                AVNumberOfChannelsKey:
                    1,
                AVLinearPCMBitDepthKey:
                    16,
                AVLinearPCMIsFloatKey:
                    false,
                AVLinearPCMIsBigEndianKey:
                    false,
            ]

            let recorder =
                try AVAudioRecorder(
                    url: url,
                    settings: settings
                )

            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()

            guard recorder.record(
                forDuration: captureSeconds
            ) else {
                status =
                    "No se pudo iniciar la grabación."
                return
            }

            self.recorder = recorder
            isRecording = true

            status =
                "Escuchando… pulsa ahora UNA vez el botón del mando y mantenlo apuntando al receptor."
        } catch {
            isRecording = false
            status =
                "Error al iniciar la captura: \(error.localizedDescription)"
        }
    }

    func stopCapture() {
        guard isRecording else { return }
        recorder?.stop()
    }

    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        let url = recorder.url

        Task { @MainActor [weak self] in
            guard let self else { return }

            self.isRecording = false
            self.recorder = nil

            guard flag else {
                self.status =
                    "La captura terminó con un error."
                return
            }

            self.analyze(url: url)
        }
    }

    private func analyze(
        url: URL
    ) {
        do {
            let file =
                try AVAudioFile(
                    forReading: url
                )

            let format =
                file.processingFormat

            guard format.channelCount >= 1 else {
                status =
                    "La captura no contiene ningún canal de audio."
                return
            }

            let capacity =
                AVAudioFrameCount(file.length)

            guard
                let buffer =
                    AVAudioPCMBuffer(
                        pcmFormat: format,
                        frameCapacity: capacity
                    )
            else {
                status =
                    "No se pudo crear el búfer de análisis."
                return
            }

            try file.read(into: buffer)

            guard
                let samples =
                    buffer.floatChannelData?[0]
            else {
                status =
                    "No se pudieron leer las muestras capturadas."
                return
            }

            let count =
                Int(buffer.frameLength)

            guard count > 100 else {
                status =
                    "La captura es demasiado corta."
                return
            }

            var values =
                Array(
                    UnsafeBufferPointer(
                        start: samples,
                        count: count
                    )
                )

            let mean =
                values.reduce(0.0, +)
                / Float(values.count)

            var peak: Float = 0

            for index in values.indices {
                values[index] -= mean
                peak = max(
                    peak,
                    abs(values[index])
                )
            }

            guard peak > 0.01 else {
                status =
                    "La entrada está prácticamente en silencio. Comprueba el receptor IR y su conexión."
                return
            }

            guard
                let result =
                    detectEdges(
                        samples: values,
                        sampleRate:
                            format.sampleRate,
                        peakLevel: peak
                    )
            else {
                status =
                    "He recibido audio, pero no una trama IR suficientemente clara. Acerca el mando al receptor y vuelve a intentarlo."
                return
            }

            if validationActive {
                validationCaptures.append(result)
                validationCount =
                    validationCaptures.count

                if validationCaptures.count >= 3 {
                    let score =
                        IRSignalAnalyzer.captureConsistency(
                            validationCaptures
                        )

                    consistency = score

                    if let consensus =
                        IRSignalAnalyzer.consensus(
                            captures:
                                validationCaptures
                        )
                    {
                        lastResult =
                            consensus
                    } else {
                        lastResult =
                            result
                    }

                    validationActive =
                        false

                    let percent =
                        Int(
                            (
                                score
                                ?? 0
                            ) * 100
                        )

                    status =
                        "Validación terminada: \(percent) % de consistencia entre las 3 tomas. Se ha creado una señal consenso."
                } else {
                    status =
                        "Toma \(validationCaptures.count)/3 guardada. Pulsa «INICIAR CAPTURA» y repite exactamente el mismo botón."
                }
            } else {
                lastResult = result

                status =
                    "Señal detectada: \(result.edgeCount) flancos, \(result.durationMillis) ms. Revísala y pulsa «PROBAR CÓDIGO»."
            }
        } catch {
            status =
                "No se pudo analizar la captura: \(error.localizedDescription)"
        }

        try? FileManager.default.removeItem(
            at: url
        )
    }

    private func detectEdges(
        samples: [Float],
        sampleRate: Double,
        peakLevel: Float
    ) -> IRCaptureResult? {
        guard samples.count > 3 else {
            return nil
        }

        var derivatives =
            [Float](
                repeating: 0,
                count: samples.count
            )

        var maximumDerivative: Float = 0

        for index in 1..<samples.count {
            let d =
                abs(
                    samples[index]
                    - samples[index - 1]
                )

            derivatives[index] = d
            maximumDerivative =
                max(
                    maximumDerivative,
                    d
                )
        }

        guard maximumDerivative > 0.002 else {
            return nil
        }

        // The IR receiver output reaches the audio input through an
        // AC-coupled path. Long logic levels can decay toward zero,
        // but every transition creates a strong edge. Detecting edge
        // positions is therefore more robust than thresholding the
        // absolute audio level.
        let threshold =
            max(
                maximumDerivative * 0.16,
                0.004
            )

        let minSeparationFrames =
            max(
                2,
                Int(sampleRate * 0.00008)
            )

        var edges: [Int] = []
        var lastAccepted =
            -minSeparationFrames

        var index = 1

        while index < derivatives.count - 1 {
            let value =
                derivatives[index]

            if value >= threshold
                && value >= derivatives[index - 1]
                && value >= derivatives[index + 1]
                && index - lastAccepted
                    >= minSeparationFrames
            {
                edges.append(index)
                lastAccepted = index

                index +=
                    minSeparationFrames
            } else {
                index += 1
            }
        }

        guard edges.count >= 8 else {
            return nil
        }

        var rawDurations: [UInt32] = []

        for pair in zip(
            edges,
            edges.dropFirst()
        ) {
            let frames =
                pair.1 - pair.0

            let micros =
                Int(
                    round(
                        Double(frames)
                        * 1_000_000.0
                        / sampleRate
                    )
                )

            if micros >= 100
                && micros <= 200_000
            {
                rawDurations.append(
                    UInt32(micros)
                )
            }
        }

        guard rawDurations.count >= 6 else {
            return nil
        }

        // Trim obvious noise before the first plausible IR leader/data
        // section and after the useful frame.
        let trimmed =
            trimCapture(
                rawDurations
            )

        guard trimmed.count >= 6 else {
            return nil
        }

        return IRCaptureResult(
            durationsMicros: trimmed,
            sampleRate: sampleRate,
            edgeCount: edges.count,
            peakLevel: peakLevel
        )
    }

    private func trimCapture(
        _ input: [UInt32]
    ) -> [UInt32] {
        guard !input.isEmpty else {
            return []
        }

        var start = 0

        // Button clicks and cable noise often create isolated very short
        // intervals. Look for the first locally coherent IR section.
        while start + 4 < input.count {
            let window =
                input[start..<(start + 5)]

            let plausible =
                window.filter {
                    $0 >= 180
                    && $0 <= 20_000
                }.count

            if plausible >= 4 {
                break
            }

            start += 1
        }

        var output =
            Array(input.dropFirst(start))

        // A long idle interval at the very end is not part of the command.
        while
            let last = output.last,
            last > 160_000
        {
            output.removeLast()
        }

        return output
    }
}
