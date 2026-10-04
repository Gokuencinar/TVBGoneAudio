import SwiftUI

struct RemoteBrandPickerView: View {
    let category: IRDeviceCategory
    let transmitter: IRTransmitter
    @ObservedObject var customRemotes: CustomRemoteStore

    @StateObject private var library = OnlineIRLibrary()
    @State private var searchText = ""

    private var filteredBrands: [String] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return library.brands
        }

        return library.brands.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if library.isLoadingBrands && library.brands.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)

                    Text("Cargando marcas…")
                        .font(.headline)

                    Text("Estamos preparando los perfiles compatibles para \(category.shortTitle).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            } else if library.brands.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(IRCyberPalette.warning)

                    Text("No se pudieron cargar marcas")
                        .font(.title3.bold())

                    Text(library.brandStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Reintentar") {
                        Task {
                            await library.loadBrands(
                                category: category,
                                filter: .all
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(IRCyberPalette.cyan)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            } else {
                List {
                    Section {
                        ForEach(filteredBrands, id: \.self) { brand in
                            NavigationLink {
                                RemotePairingWizardView(
                                    category: category,
                                    brand: brand,
                                    transmitter: transmitter,
                                    customRemotes: customRemotes,
                                    library: library
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(
                                            cornerRadius: 10,
                                            style: .continuous
                                        )
                                        .fill(IRCyberPalette.cyan.opacity(0.10))
                                        .frame(width: 38, height: 38)

                                        Image(systemName: category.systemImage)
                                            .foregroundStyle(IRCyberPalette.cyan)
                                    }

                                    Text(brand)
                                        .font(.body.weight(.medium))
                                }
                                .frame(minHeight: 44)
                            }
                        }
                    } header: {
                        Text("\(library.brands.count) marcas disponibles")
                    } footer: {
                        Text("Elige la marca. Después probaremos perfiles uno a uno, igual que un asistente de mando universal.")
                    }
                }
                .listStyle(.plain)
            }
        }
        .irOLEDScreen()
        .navigationTitle(category.shortTitle)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Buscar marca"
        )
        .task(id: category.id) {
            await library.loadBrands(
                category: category,
                filter: .all
            )
        }
    }
}

private struct RemotePairingWizardView: View {
    let category: IRDeviceCategory
    let brand: String
    let transmitter: IRTransmitter
    @ObservedObject var customRemotes: CustomRemoteStore
    @ObservedObject var library: OnlineIRLibrary

    @State private var candidates: [OnlineIRRemote] = []
    @State private var candidateIndex = 0
    @State private var loadedRemote: OnlineIRLoadedRemote?
    @State private var resolvedSteps: [ResolvedPairingStep] = []
    @State private var stepIndex = 0
    @State private var powerAlternatives: [ImportedIRSignal] = []
    @State private var powerAlternativeIndex = 0
    @State private var testedCurrentStep = false
    @State private var isBusy = true
    @State private var statusText = "Buscando perfiles…"
    @State private var terminalMessage: String?
    @State private var skippedProfiles = 0

    private var currentStep: ResolvedPairingStep? {
        guard resolvedSteps.indices.contains(stepIndex) else {
            return nil
        }

        return resolvedSteps[stepIndex]
    }

    private var currentSignal: ImportedIRSignal? {
        guard let currentStep else {
            return nil
        }

        if
            currentStep.step.kind == .power,
            powerAlternatives.indices.contains(
                powerAlternativeIndex
            )
        {
            return powerAlternatives[
                powerAlternativeIndex
            ]
        }

        return currentStep.signal
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                headerCard

                if isBusy {
                    loadingCard
                } else if let terminalMessage {
                    terminalCard(terminalMessage)
                } else if let currentStep {
                    testCard(currentStep)
                }
            }
            .padding()
        }
        .irOLEDScreen()
        .navigationTitle(brand)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await startWizard()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                    .fill(IRCyberPalette.cyan.opacity(0.12))
                    .frame(width: 50, height: 50)

                    Image(systemName: category.systemImage)
                        .font(.title2.bold())
                        .foregroundStyle(IRCyberPalette.cyan)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(brand)
                        .font(.title3.bold())

                    Text(category.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text("Prueba cada botón y dinos si responde el aparato. Si no funciona, cambiaremos automáticamente al siguiente perfil IR.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .irCard(cornerRadius: 18)
    }

    private var loadingCard: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)

            Text(statusText)
                .font(.headline)
                .multilineTextAlignment(.center)

            if !candidates.isEmpty {
                Text("Perfil \(min(candidateIndex + 1, candidates.count)) de \(candidates.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal)
        .irCard(cornerRadius: 20)
    }

    private func terminalCard(
        _ message: String
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(IRCyberPalette.warning)

            Text("No quedan perfiles compatibles")
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("VOLVER A INTENTAR") {
                Task {
                    await startWizard(forceDeepSearch: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(IRCyberPalette.cyan)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .irCard(cornerRadius: 20)
    }

    private func testCard(
        _ resolved: ResolvedPairingStep
    ) -> some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PASO \(stepIndex + 1) / \(resolvedSteps.count)")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(IRCyberPalette.cyan)

                    Text(resolved.step.question)
                        .font(.title3.bold())
                }

                Spacer()

                Text("\(candidateIndex + 1)/\(candidates.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button {
                guard let currentSignal else {
                    return
                }

                transmitter.send(code: currentSignal.code)
                testedCurrentStep = true
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: resolved.step.systemImage)
                        .font(.system(size: 34, weight: .bold))

                    Text(resolved.step.buttonTitle)
                        .font(.headline.bold())
                }
                .frame(maxWidth: .infinity, minHeight: 104)
            }
            .buttonStyle(.borderedProminent)
            .tint(
                resolved.step.kind == .power
                ? IRCyberPalette.signalRed
                : IRCyberPalette.cyan
            )

            Text(
                testedCurrentStep
                ? "¿Ha respondido correctamente el aparato?"
                : "Pulsa el botón de prueba y observa el aparato."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            if
                resolved.step.kind == .power,
                powerAlternatives.count > 1
            {
                Text(
                    "Código POWER \(powerAlternativeIndex + 1) de \(powerAlternatives.count) en este perfil"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    rejectCurrentProfile()
                } label: {
                    Label(
                        "NO FUNCIONA",
                        systemImage: "xmark"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(IRCyberPalette.signalRed)
                .disabled(!testedCurrentStep)

                Button {
                    acceptCurrentStep()
                } label: {
                    Label(
                        "SÍ FUNCIONA",
                        systemImage: "checkmark"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!testedCurrentStep)
            }

            if let loadedRemote {
                VStack(spacing: 4) {
                    Text(loadedRemote.model ?? loadedRemote.name)
                        .font(.caption.bold())
                        .lineLimit(2)

                    Text(loadedRemote.sourceDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .irCard(cornerRadius: 22)
    }

    @MainActor
    private func startWizard(
        forceDeepSearch: Bool = false
    ) async {
        isBusy = true
        terminalMessage = nil
        statusText = "Buscando perfiles de \(brand)…"
        candidates = []
        candidateIndex = 0
        loadedRemote = nil
        resolvedSteps = []
        stepIndex = 0
        powerAlternatives = []
        powerAlternativeIndex = 0
        testedCurrentStep = false
        skippedProfiles = 0

        await library.search(
            brand: brand,
            model: "",
            category: category,
            filter: .all,
            deep: forceDeepSearch
        )

        var found = library.results

        if found.isEmpty && !forceDeepSearch {
            statusText = "Ampliando la búsqueda…"

            await library.search(
                brand: brand,
                model: "",
                category: category,
                filter: .all,
                deep: true
            )

            found = library.results
        }

        candidates = found

        guard !candidates.isEmpty else {
            isBusy = false
            terminalMessage = library.status
            return
        }

        await loadCurrentCandidate()
    }

    @MainActor
    private func loadCurrentCandidate() async {
        loadedRemote = nil
        resolvedSteps = []
        stepIndex = 0
        powerAlternatives = []
        powerAlternativeIndex = 0
        testedCurrentStep = false

        while candidateIndex < candidates.count {
            let candidate = candidates[candidateIndex]
            isBusy = true
            statusText = "Preparando perfil \(candidateIndex + 1) de \(candidates.count)…"

            do {
                let loaded = try await library.download(candidate)
                let steps = resolveSteps(
                    for: loaded.signals,
                    category: category
                )

                guard !steps.isEmpty else {
                    skippedProfiles += 1
                    candidateIndex += 1
                    continue
                }

                loadedRemote = loaded
                resolvedSteps = steps
                stepIndex = 0
                powerAlternatives =
                    PairingSignalMatcher.signals(
                        for: steps[0].step,
                        in: loaded.signals
                    )
                powerAlternativeIndex = 0
                testedCurrentStep = false
                isBusy = false
                return
            } catch {
                skippedProfiles += 1
                candidateIndex += 1
            }
        }

        isBusy = false
        terminalMessage =
            skippedProfiles > 0
            ? "Se probaron o descartaron \(skippedProfiles) perfiles, pero ninguno respondió correctamente o contenía una función de prueba válida."
            : "No se encontraron perfiles utilizables para esta marca."
    }

    private func rejectCurrentProfile() {
        IRHaptics.tap()

        if
            currentStep?.step.kind == .power,
            powerAlternatives.indices.contains(
                powerAlternativeIndex + 1
            )
        {
            powerAlternativeIndex += 1
            testedCurrentStep = false
            return
        }

        candidateIndex += 1

        Task {
            await loadCurrentCandidate()
        }
    }

    private func acceptCurrentStep() {
        IRHaptics.success()

        let nextIndex = stepIndex + 1

        if resolvedSteps.indices.contains(nextIndex) {
            stepIndex = nextIndex
            testedCurrentStep = false
            return
        }

        saveCurrentRemote()
    }

    private func saveCurrentRemote() {
        guard let loadedRemote else {
            return
        }

        customRemotes.createImported(
            name: loadedRemote.name,
            category: category,
            signals: loadedRemote.signals,
            brand: loadedRemote.brand ?? brand,
            model: loadedRemote.model,
            sourceDescription:
                loadedRemote.sourceDescription,
            sourcePath: loadedRemote.sourcePath
        )
    }

    private func resolveSteps(
        for signals: [ImportedIRSignal],
        category: IRDeviceCategory
    ) -> [ResolvedPairingStep] {
        let candidates = signals.map {
            (
                signal: $0,
                normalized:
                    PairingSignalMatcher.normalize($0.name)
            )
        }

        let desired = PairingStep.steps(for: category)
        var resolved: [ResolvedPairingStep] = []
        var used = Set<UUID>()

        for step in desired {
            guard
                let signal = PairingSignalMatcher.signal(
                    for: step,
                    candidates: candidates
                ),
                used.insert(signal.id).inserted
            else {
                continue
            }

            resolved.append(
                ResolvedPairingStep(
                    step: step,
                    signal: signal
                )
            )
        }

        guard
            let firstDesired = desired.first,
            resolved.first?.step.kind == firstDesired.kind
        else {
            return []
        }

        return Array(resolved.prefix(3))
    }
}

private struct ResolvedPairingStep {
    let step: PairingStep
    let signal: ImportedIRSignal
}

private struct PairingStep {
    enum Kind: Equatable {
        case power
        case volumeUp
        case input
        case temperatureUp
        case mode
        case ok
        case home
        case channelUp
        case speedUp
        case swing
        case eject
        case play
        case menu
        case shutter
        case zoomIn
    }

    let kind: Kind
    let buttonTitle: String
    let question: String
    let systemImage: String
    let exactAliases: Set<String>
    let containsAliases: [String]

    static func steps(
        for category: IRDeviceCategory
    ) -> [PairingStep] {
        switch category {
        case .television:
            return [.power, .volumeUp, .input]
        case .airConditioner:
            return [.power, .temperatureUp, .mode]
        case .setTopBox:
            return [.power, .channelUp, .ok]
        case .fan:
            return [.power, .speedUp, .swing]
        case .streamingBox:
            return [.power, .home, .ok]
        case .dvdPlayer:
            return [.power, .play, .eject]
        case .projector:
            return [.power, .input, .menu]
        case .avReceiver, .soundbar:
            return [.power, .volumeUp, .input]
        case .camera:
            return [.shutter, .zoomIn]
        }
    }

    static let power = PairingStep(
        kind: .power,
        buttonTitle: "PROBAR ENCENDIDO / APAGADO",
        question: "¿Se ha encendido o apagado?",
        systemImage: "power",
        exactAliases: [
            "power", "power toggle", "power on off", "pwr",
            "on off", "standby", "power on", "power off",
            "on", "off", "encender", "apagar",
        ],
        containsAliases: ["power toggle", "power on off"]
    )

    static let volumeUp = PairingStep(
        kind: .volumeUp,
        buttonTitle: "PROBAR VOLUMEN +",
        question: "¿Ha subido el volumen?",
        systemImage: "speaker.plus.fill",
        exactAliases: [
            "vol plus", "volume plus", "volume up", "vol up",
            "subir volumen", "vup",
        ],
        containsAliases: ["volume up", "vol up", "vol plus"]
    )

    static let input = PairingStep(
        kind: .input,
        buttonTitle: "PROBAR ENTRADA",
        question: "¿Ha cambiado la fuente o entrada?",
        systemImage: "rectangle.on.rectangle",
        exactAliases: [
            "input", "input select", "source", "source select",
            "av", "tv av", "entrada",
        ],
        containsAliases: ["input ", "source "]
    )

    static let temperatureUp = PairingStep(
        kind: .temperatureUp,
        buttonTitle: "PROBAR TEMP +",
        question: "¿Ha subido la temperatura?",
        systemImage: "thermometer.medium",
        exactAliases: [
            "temp plus", "temperature plus", "temp up",
            "temperature up", "subir temperatura",
        ],
        containsAliases: ["temp up", "temp plus", "temperature up"]
    )

    static let mode = PairingStep(
        kind: .mode,
        buttonTitle: "PROBAR MODO",
        question: "¿Ha cambiado el modo?",
        systemImage: "arrow.triangle.2.circlepath",
        exactAliases: ["mode", "modo"],
        containsAliases: []
    )

    static let ok = PairingStep(
        kind: .ok,
        buttonTitle: "PROBAR OK",
        question: "¿Ha respondido al botón OK?",
        systemImage: "checkmark.circle.fill",
        exactAliases: ["ok", "enter", "select", "confirm", "center"],
        containsAliases: []
    )

    static let home = PairingStep(
        kind: .home,
        buttonTitle: "PROBAR INICIO",
        question: "¿Ha abierto la pantalla de inicio?",
        systemImage: "house.fill",
        exactAliases: ["home", "smart home", "portal", "inicio"],
        containsAliases: []
    )

    static let channelUp = PairingStep(
        kind: .channelUp,
        buttonTitle: "PROBAR CANAL +",
        question: "¿Ha cambiado al canal siguiente?",
        systemImage: "chevron.up",
        exactAliases: [
            "ch plus", "channel plus", "channel up", "ch up",
            "ch next", "program plus", "prog plus", "canal plus",
        ],
        containsAliases: ["channel up", "ch up", "ch next", "ch plus"]
    )

    static let speedUp = PairingStep(
        kind: .speedUp,
        buttonTitle: "PROBAR VELOCIDAD +",
        question: "¿Ha cambiado la velocidad?",
        systemImage: "wind",
        exactAliases: [
            "speed plus", "speed up", "fan speed plus", "fan speed up",
            "velocidad plus", "velocidad mas",
        ],
        containsAliases: ["speed up", "speed plus"]
    )

    static let swing = PairingStep(
        kind: .swing,
        buttonTitle: "PROBAR OSCILACIÓN",
        question: "¿Ha cambiado la oscilación?",
        systemImage: "arrow.left.and.right",
        exactAliases: ["swing", "oscillate", "oscilacion"],
        containsAliases: []
    )

    static let eject = PairingStep(
        kind: .eject,
        buttonTitle: "PROBAR EJECT",
        question: "¿Ha abierto o cerrado la bandeja?",
        systemImage: "eject.fill",
        exactAliases: ["eject", "open close", "open", "close", "expulsar"],
        containsAliases: []
    )

    static let play = PairingStep(
        kind: .play,
        buttonTitle: "PROBAR PLAY",
        question: "¿Ha comenzado la reproducción?",
        systemImage: "play.fill",
        exactAliases: ["play", "media play"],
        containsAliases: []
    )

    static let menu = PairingStep(
        kind: .menu,
        buttonTitle: "PROBAR MENÚ",
        question: "¿Ha abierto el menú?",
        systemImage: "list.bullet",
        exactAliases: ["menu", "settings", "options", "ajustes"],
        containsAliases: []
    )

    static let shutter = PairingStep(
        kind: .shutter,
        buttonTitle: "PROBAR DISPARADOR",
        question: "¿Ha disparado la cámara?",
        systemImage: "camera.fill",
        exactAliases: [
            "shutter", "shoot", "capture", "take photo", "photo",
            "disparador",
        ],
        containsAliases: ["shutter", "capture"]
    )

    static let zoomIn = PairingStep(
        kind: .zoomIn,
        buttonTitle: "PROBAR ZOOM +",
        question: "¿Ha aumentado el zoom?",
        systemImage: "plus.magnifyingglass",
        exactAliases: ["zoom in", "zoom plus", "zoom tele", "tele"],
        containsAliases: ["zoom in", "zoom plus"]
    )
}

private enum PairingSignalMatcher {
    static func signals(
        for step: PairingStep,
        in signals: [ImportedIRSignal]
    ) -> [ImportedIRSignal] {
        let candidates = signals.map {
            (
                signal: $0,
                normalized: normalize($0.name)
            )
        }

        var matched: [ImportedIRSignal] = []

        for candidate in candidates {
            let isExact = step.exactAliases.contains(
                candidate.normalized
            )
            let isPartial = step.containsAliases.contains {
                candidate.normalized.contains($0)
            }

            guard isExact || isPartial else {
                continue
            }

            let duplicate = matched.contains {
                $0.code.carrierHz
                    == candidate.signal.code.carrierHz
                && $0.code.durationsMicros
                    == candidate.signal.code.durationsMicros
            }

            if !duplicate {
                matched.append(candidate.signal)
            }
        }

        return matched
    }

    static func signal(
        for step: PairingStep,
        candidates:
            [(signal: ImportedIRSignal, normalized: String)]
    ) -> ImportedIRSignal? {
        if let exact = candidates.first(
            where: {
                step.exactAliases.contains($0.normalized)
            }
        ) {
            return exact.signal
        }

        if let partial = candidates.first(
            where: { candidate in
                step.containsAliases.contains {
                    candidate.normalized.contains($0)
                }
            }
        ) {
            return partial.signal
        }

        return nil
    }

    static func normalize(
        _ value: String
    ) -> String {
        var normalized = value
            .folding(
                options: [
                    .diacriticInsensitive,
                    .caseInsensitive,
                ],
                locale: .current
            )
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "+", with: " plus ")

        normalized = normalized.replacingOccurrences(
            of: " - ",
            with: " minus "
        )

        if normalized.hasSuffix("-") {
            normalized.removeLast()
            normalized += " minus"
        }

        normalized = normalized
            .replacingOccurrences(of: "-", with: " ")

        return normalized
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
