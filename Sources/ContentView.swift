import SwiftUI

struct ContentView: View {
    @StateObject private var transmitter = IRTransmitter()
    @StateObject private var savedDevices = SavedDeviceStore()
    @StateObject private var learnedSignals = LearnedIRStore()
    @StateObject private var learner = IRLearner()
    @StateObject private var customRemotes = CustomRemoteStore()

    @State private var category: IRDeviceCategory = .television
    @State private var region: TVRegion = .europe
    @State private var pace: ScanPace = .fast

    var body: some View {
        TabView {
            ControlView(
                transmitter: transmitter,
                savedDevices: savedDevices,
                category: $category,
                region: $region,
                pace: $pace
            )
            .tabItem {
                Label("Control", systemImage: "power.circle.fill")
            }

            ManualCodeView(
                transmitter: transmitter,
                savedDevices: savedDevices,
                category: $category,
                region: $region
            )
            .tabItem {
                Label("Códigos", systemImage: "dial.medium.fill")
            }

            SavedDevicesView(
                transmitter: transmitter,
                savedDevices: savedDevices,
                customRemotes: customRemotes
            )
            .tabItem {
                Label("Mis equipos", systemImage: "star.fill")
            }

            LearnIRView(
                transmitter: transmitter,
                learner: learner,
                learnedSignals: learnedSignals,
                savedDevices: savedDevices,
                customRemotes: customRemotes,
                category: $category
            )
            .tabItem {
                Label("Aprender", systemImage: "waveform.badge.mic")
            }

            DiagnosticsView(
                transmitter: transmitter
            )
            .tabItem {
                Label("Diagnóstico", systemImage: "waveform.path.ecg")
            }
        }
        .tint(.red)
    }
}

private struct ControlView: View {
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var savedDevices: SavedDeviceStore

    @Binding var category: IRDeviceCategory
    @Binding var region: TVRegion
    @Binding var pace: ScanPace

    @State private var workedCandidates: [IRCode] = []
    @State private var showWorkedSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero

                    DeviceCategoryPicker(
                        category: $category,
                        disabled: transmitter.isScanning
                    )

                    if category == .television {
                        regionPicker
                    }

                    quickDevices

                    scanCard

                    if transmitter.isScanning {
                        activeScanCard
                    }

                    statusCard
                }
                .padding()
            }
            .navigationTitle("IR Universal")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showWorkedSheet) {
                WorkedSheet(
                    candidates: workedCandidates,
                    category: category,
                    savedDevices: savedDevices
                )
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.red.opacity(0.12))
                    .frame(width: 96, height: 96)

                Image(systemName: category.systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.red)
            }

            Text(category.title)
                .font(.title2.bold())

            Text(category.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var regionPicker: some View {
        Picker("Región", selection: $region) {
            ForEach(TVRegion.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .disabled(transmitter.isScanning)
    }

    @ViewBuilder
    private var quickDevices: some View {
        let devices = savedDevices.devices(for: category)

        if !devices.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Acceso rápido", systemImage: "star.fill")
                    .font(.headline)

                ForEach(devices.prefix(3)) { device in
                    Button {
                        guard let code = savedDevices.code(for: device) else {
                            return
                        }
                        transmitter.send(code: code)
                    } label: {
                        HStack {
                            Image(systemName: category.systemImage)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                    .font(.headline)
                                Text(device.codeLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "power")
                                .font(.title3.bold())
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        .thinMaterial,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .disabled(transmitter.isScanning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Barrido universal", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)
                Spacer()
                Text(
                    "\(transmitter.codeCount(for: category, region: region)) códigos"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Picker("Velocidad", selection: $pace) {
                ForEach(ScanPace.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .disabled(transmitter.isScanning)

            Text(pace.help)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                if transmitter.isScanning {
                    transmitter.stop()
                } else {
                    transmitter.start(
                        category: category,
                        region: region,
                        pace: pace
                    )
                }
            } label: {
                Label(
                    transmitter.isScanning
                        ? "DETENER BARRIDO"
                        : category.buttonTitle,
                    systemImage:
                        transmitter.isScanning
                        ? "stop.fill"
                        : "power"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(transmitter.isScanning ? .secondary : .red)
        }
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    private var activeScanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView(value: transmitter.progress)

            HStack {
                Text(
                    "\(transmitter.sentCount) / \(transmitter.totalCount)"
                )
                .font(.caption.monospacedDigit())

                Spacer()

                if transmitter.skippedCount > 0 {
                    Text("\(transmitter.skippedCount) omitidos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let codeName = transmitter.currentCodeName {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Código actual")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(codeName)
                        .font(.subheadline.monospaced())
                        .lineLimit(2)
                }
            }

            HStack(spacing: 10) {
                Button {
                    transmitter.step(-1)
                } label: {
                    Image(systemName: "backward.end.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    if transmitter.isPaused {
                        transmitter.resume()
                    } else {
                        transmitter.pause()
                    }
                } label: {
                    Image(
                        systemName:
                            transmitter.isPaused
                            ? "play.fill"
                            : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    transmitter.step(1)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                workedCandidates =
                    transmitter.markWorked()

                if !workedCandidates.isEmpty {
                    showWorkedSheet = true
                }
            } label: {
                Label("FUNCIONÓ", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                transmitter.routeDescription,
                systemImage: "cable.connector"
            )

            if transmitter.sampleRate > 0 {
                Label(
                    "\(Int(transmitter.sampleRate)) Hz · \(transmitter.outputChannels) canales",
                    systemImage: "waveform"
                )
            }

            Label(
                "Audio mono DESACTIVADO · balance centrado",
                systemImage: "ear.and.waveform"
            )

            if let warning = transmitter.warning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

private struct ManualCodeView: View {
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var savedDevices: SavedDeviceStore

    @Binding var category: IRDeviceCategory
    @Binding var region: TVRegion

    @State private var source: IRSourceFilter = .all
    @State private var searchText = ""
    @State private var selectedCodeID = ""
    @State private var showSaveSheet = false

    private var filteredCodes: [IRCode] {
        IRCodeCatalog.filtered(
            category: category,
            region: region,
            source: source,
            searchText: searchText
        )
    }

    private var selectedCode: IRCode? {
        filteredCodes.first { $0.id == selectedCodeID }
            ?? filteredCodes.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DeviceCategoryPicker(
                        category: $category,
                        disabled: transmitter.isScanning
                    )

                    if category == .television {
                        Picker("Región", selection: $region) {
                            ForEach(TVRegion.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    TextField(
                        "Buscar marca, modelo o código",
                        text: $searchText
                    )
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)

                    Picker("Origen", selection: $source) {
                        ForEach(IRSourceFilter.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filteredCodes.isEmpty {
                        EmptyStateView(
                            title: "Sin códigos",
                            systemImage: "magnifyingglass",
                            message: "Prueba con otra búsqueda u otro origen."
                        )
                    } else {
                        VStack(spacing: 0) {
                            Text("Ruleta de códigos")
                                .font(.headline)
                                .padding(.top)

                            Picker(
                                "Código",
                                selection: Binding(
                                    get: {
                                        selectedCode?.id
                                            ?? filteredCodes[0].id
                                    },
                                    set: { selectedCodeID = $0 }
                                )
                            ) {
                                ForEach(filteredCodes) { code in
                                    Text(code.displayName)
                                        .lineLimit(1)
                                        .tag(code.id)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 180)
                        }
                        .background(
                            .thinMaterial,
                            in: RoundedRectangle(cornerRadius: 20)
                        )

                        if let code = selectedCode {
                            CodeDetailsCard(code: code)

                            HStack(spacing: 12) {
                                Button {
                                    transmitter.send(code: code)
                                } label: {
                                    Label("PROBAR", systemImage: "wave.3.right")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)

                                Button {
                                    showSaveSheet = true
                                } label: {
                                    Label("GUARDAR", systemImage: "star")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding()
                .onAppear {
                    normalizeSelection()
                }
                .onChange(of: category) { _ in
                    normalizeSelection()
                }
                .onChange(of: region) { _ in
                    normalizeSelection()
                }
                .onChange(of: source) { _ in
                    normalizeSelection()
                }
                .onChange(of: searchText) { _ in
                    normalizeSelection()
                }
                .sheet(isPresented: $showSaveSheet) {
                    if let code = selectedCode {
                        SaveDeviceSheet(
                            code: code,
                            category: category,
                            savedDevices: savedDevices
                        )
                    }
                }
            }
            .navigationTitle("Seleccionar código")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func normalizeSelection() {
        let codes = filteredCodes
        guard let first = codes.first else {
            selectedCodeID = ""
            return
        }

        if !codes.contains(where: { $0.id == selectedCodeID }) {
            selectedCodeID = first.id
        }
    }
}

private struct SavedDevicesView: View {
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var savedDevices: SavedDeviceStore
    @ObservedObject var customRemotes: CustomRemoteStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if !customRemotes.remotes.isEmpty {
                        VStack(
                            alignment: .leading,
                            spacing: 10
                        ) {
                            Text("Mandos personalizados")
                                .font(.headline)

                            ForEach(
                                customRemotes.remotes
                            ) { remote in
                                NavigationLink {
                                    CustomRemoteView(
                                        remote: remote,
                                        transmitter:
                                            transmitter
                                    )
                                } label: {
                                    HStack {
                                        Image(
                                            systemName:
                                                "remote.fill"
                                        )
                                        .foregroundStyle(.red)

                                        VStack(
                                            alignment: .leading,
                                            spacing: 2
                                        ) {
                                            Text(remote.name)
                                                .font(.headline)

                                            Text(
                                                "\(remote.buttons.count) botones · \(remote.category.title)"
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(
                                            systemName:
                                                "chevron.right"
                                        )
                                        .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                }
                                .buttonStyle(.plain)
                                .background(
                                    .thinMaterial,
                                    in: RoundedRectangle(
                                        cornerRadius: 18
                                    )
                                )
                                .contextMenu {
                                    Button(
                                        role: .destructive
                                    ) {
                                        customRemotes.remove(
                                            remote
                                        )
                                    } label: {
                                        Label(
                                            "Eliminar mando",
                                            systemImage:
                                                "trash"
                                        )
                                    }
                                }
                            }
                        }
                    }

                    if !savedDevices.devices.isEmpty {
                        VStack(
                            alignment: .leading,
                            spacing: 10
                        ) {
                            Text("Accesos rápidos")
                                .font(.headline)

                            ForEach(
                                savedDevices.devices
                            ) { device in
                                SavedDeviceCard(
                                    device: device,
                                    transmitter:
                                        transmitter,
                                    savedDevices:
                                        savedDevices
                                )
                            }
                        }
                    }

                    if
                        savedDevices.devices.isEmpty
                        && customRemotes.remotes.isEmpty
                    {
                        EmptyStateView(
                            title:
                                "Todavía no hay equipos guardados",
                            systemImage:
                                "remote",
                            message:
                                "Guarda un código que funcione o crea un mando con varios botones aprendidos."
                        )
                        .padding(.top, 80)
                    }
                }
                .padding()
            }
            .navigationTitle("Mis equipos")
        }
    }
}

private struct DiagnosticsView: View {
    @ObservedObject var transmitter: IRTransmitter

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            transmitter.routeDescription,
                            systemImage: "cable.connector"
                        )

                        if transmitter.sampleRate > 0 {
                            Label(
                                "\(Int(transmitter.sampleRate)) Hz",
                                systemImage: "waveform"
                            )

                            Label(
                                "\(transmitter.outputChannels) canales",
                                systemImage: "speaker.wave.2.fill"
                            )
                        }

                        Divider()

                        Label(
                            "Audio mono: DESACTIVADO",
                            systemImage: "checkmark.circle"
                        )

                        Label(
                            "Balance: centrado",
                            systemImage: "slider.horizontal.3"
                        )

                        Label(
                            "Volumen multimedia: 100 %",
                            systemImage: "speaker.wave.3.fill"
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        .thinMaterial,
                        in: RoundedRectangle(cornerRadius: 18)
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prueba de portadora")
                            .font(.headline)

                        Text(
                            "La cámara de otro teléfono puede servir para comprobar que los LED IR emiten, aunque no confirma que la frecuencia sea correcta."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        HStack {
                            ForEach([36_000, 38_000, 40_000], id: \.self) { hz in
                                Button("\(hz / 1000) kHz") {
                                    transmitter.testCarrier(hz: hz)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        .thinMaterial,
                        in: RoundedRectangle(cornerRadius: 18)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cómo funciona")
                            .font(.headline)

                        Text(
                            "La app convierte cada señal IR en audio estéreo antifase. En este tipo de emisor, los dos canales excitan los LED en sentidos opuestos, por eso la frecuencia de audio es aproximadamente la mitad de la portadora IR deseada."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        .thinMaterial,
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                }
                .padding()
            }
            .navigationTitle("Diagnóstico")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct DeviceCategoryPicker: View {
    @Binding var category: IRDeviceCategory
    let disabled: Bool

    var body: some View {
        Picker("Tipo", selection: $category) {
            ForEach(IRDeviceCategory.allCases) { item in
                Text(item.shortTitle).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .disabled(disabled)
    }
}

private struct CodeDetailsCard: View {
    let code: IRCode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(code.displayName)
                .font(.headline)

            LabeledContent("Marca / familia", value: code.brandHint)
            LabeledContent("Origen", value: code.sourceLabel)
            LabeledContent("Portadora", value: "\(code.carrierHz) Hz")
            LabeledContent("Duración", value: "\(code.durationMillis) ms")

            Text(code.id)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }
}

private struct SavedDeviceCard: View {
    let device: SavedIRDevice

    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var savedDevices: SavedDeviceStore

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.red.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: device.category.systemImage)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.headline)

                Text(device.codeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                guard let code = savedDevices.code(for: device) else {
                    return
                }
                transmitter.send(code: code)
            } label: {
                Image(systemName: "power")
                    .font(.title3.bold())
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Button(role: .destructive) {
                savedDevices.remove(device)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }
}

private struct WorkedSheet: View {
    let candidates: [IRCode]
    let category: IRDeviceCategory

    @ObservedObject var savedDevices: SavedDeviceStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        "Como el televisor puede reaccionar unas décimas después de recibir la señal, te muestro el código actual y los anteriores."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("Elige el que crees que funcionó") {
                    ForEach(candidates) { code in
                        NavigationLink {
                            SaveDeviceSheet(
                                code: code,
                                category: category,
                                savedDevices: savedDevices
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(code.displayName)
                                Text(
                                    "\(code.sourceLabel) · \(code.carrierHz) Hz"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("¡Funcionó!")
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SaveDeviceSheet: View {
    let code: IRCode
    let category: IRDeviceCategory

    @ObservedObject var savedDevices: SavedDeviceStore

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Dispositivo") {
                    TextField(
                        category.defaultDeviceName,
                        text: $name
                    )
                }

                Section("Código") {
                    Text(code.displayName)
                    Text(code.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        savedDevices.add(
                            name:
                                name.isEmpty
                                ? category.defaultDeviceName
                                : name,
                            category: category,
                            code: code
                        )
                        dismiss()
                    } label: {
                        Label(
                            "Guardar dispositivo",
                            systemImage: "star.fill"
                        )
                    }
                }
            }
            .navigationTitle("Guardar")
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}


private struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }
}


private struct LearnIRView: View {
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var learner: IRLearner
    @ObservedObject var learnedSignals: LearnedIRStore
    @ObservedObject var savedDevices: SavedDeviceStore
    @ObservedObject var customRemotes: CustomRemoteStore

    @Binding var category: IRDeviceCategory

    @State private var carrierHz = 38_000
    @State private var signalName = "Power"

    @State private var showImporter = false
    @State private var showRemoteBuilder = false
    @State private var importMessage: String?

    @State private var guidedMode = false
    @State private var guidedIndex = 0

    private let carriers =
        [36_000, 38_000, 40_000, 56_000]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    introCard

                    DeviceCategoryPicker(
                        category: $category,
                        disabled:
                            learner.isRecording
                            || transmitter.isScanning
                    )

                    studioTools

                    if guidedMode {
                        guidedCard
                    }

                    inputCard
                    carrierCard
                    captureCard

                    if let result =
                        learner.lastResult
                    {
                        learnedResultCard(
                            result
                        )
                    }

                    learnedList
                }
                .padding()
            }
            .navigationTitle("Aprender IR")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                learner.refreshPermissionState()
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [
                    .flipperIR,
                    .plainText,
                    .data,
                ],
                allowsMultipleSelection: false
            ) { result in
                importIRFile(result)
            }
            .sheet(
                isPresented:
                    $showRemoteBuilder
            ) {
                RemoteBuilderView(
                    learnedSignals:
                        learnedSignals,
                    remoteStore:
                        customRemotes
                )
            }
        }
    }

    private var introCard: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Label(
                "IR Studio",
                systemImage:
                    "waveform.badge.mic"
            )
            .font(.headline)

            Text(
                "Aprende botones de un mando mediante un receptor IR conectado a una entrada de audio, analiza el protocolo, compáralo con la base y crea tus propios mandos."
            )
            .font(.subheadline)

            Text(
                "El LED emisor no puede recibir. Para aprender hace falta un receptor IR demodulado y una entrada de audio compatible."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private var studioTools: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    showImporter = true
                } label: {
                    Label(
                        "Importar .ir",
                        systemImage:
                            "square.and.arrow.down"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showRemoteBuilder = true
                } label: {
                    Label(
                        "Crear mando",
                        systemImage:
                            "remote.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(
                    learnedSignals.signals
                        .isEmpty
                )
            }

            Toggle(
                "Aprendizaje guiado",
                isOn: $guidedMode
            )
            .onChange(
                of: guidedMode
            ) { enabled in
                guidedIndex = 0

                if enabled {
                    signalName =
                        guidedButtons.first
                        ?? "Power"
                }
            }

            if let importMessage {
                Text(importMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private var guidedCard: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Label(
                "Aprendizaje guiado",
                systemImage:
                    "list.number"
            )
            .font(.headline)

            let buttons =
                guidedButtons

            if !buttons.isEmpty {
                Text(
                    "Botón \(min(guidedIndex + 1, buttons.count)) de \(buttons.count)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                    buttons[
                        min(
                            guidedIndex,
                            buttons.count - 1
                        )
                    ]
                )
                .font(.title3.bold())

                ProgressView(
                    value:
                        Double(guidedIndex),
                    total:
                        Double(
                            max(
                                1,
                                buttons.count
                            )
                        )
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private var inputCard: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            HStack {
                Label(
                    "Entrada de audio",
                    systemImage: "mic.fill"
                )
                .font(.headline)

                Spacer()

                if learner.inputChannels > 0 {
                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                }
            }

            Text(
                learner.inputDescription
            )
            .font(.subheadline)

            if learner.sampleRate > 0 {
                Text(
                    "\(Int(learner.sampleRate)) Hz"
                )
                .font(
                    .caption.monospacedDigit()
                )
                .foregroundStyle(.secondary)
            }

            Button {
                learner
                    .requestPermissionAndCheckInput()
            } label: {
                Label(
                    "Comprobar entrada",
                    systemImage:
                        "cable.connector"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private var carrierCard: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(
                "Portadora del mando"
            )
            .font(.headline)

            Picker(
                "Portadora",
                selection: $carrierHz
            ) {
                ForEach(
                    carriers,
                    id: \.self
                ) { hz in
                    Text(
                        "\(hz / 1000) kHz"
                    )
                    .tag(hz)
                }
            }
            .pickerStyle(.segmented)

            Text(
                "Un receptor demodulado elimina la portadora óptica antes de llegar al iPhone, por eso aquí debes indicar la frecuencia del receptor/mando."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private var captureCard: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Text("Captura")
                    .font(.headline)

                Spacer()

                if learner.validationCount > 0 {
                    Text(
                        "x3: \(learner.validationCount)/3"
                    )
                    .font(
                        .caption.monospacedDigit()
                    )
                }
            }

            Text(learner.status)
                .font(.subheadline)
                .foregroundStyle(
                    learner.isRecording
                    ? .red
                    : .secondary
                )

            if let consistency =
                learner.consistency
            {
                LabeledContent(
                    "Consistencia",
                    value:
                        "\(Int(consistency * 100)) %"
                )
            }

            HStack(spacing: 10) {
                Button {
                    if learner.validationActive {
                        learner.cancelValidation()
                    } else {
                        learner.beginValidatedCapture()
                    }
                } label: {
                    Label(
                        learner.validationActive
                            ? "Cancelar x3"
                            : "Validar x3",
                        systemImage:
                            "checkmark.shield"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(learner.isRecording)

                Button {
                    if learner.isRecording {
                        learner.stopCapture()
                    } else {
                        transmitter.stop()
                        learner.startCapture()
                    }
                } label: {
                    Label(
                        learner.isRecording
                            ? "DETENER"
                            : "CAPTURAR",
                        systemImage:
                            learner.isRecording
                            ? "stop.circle.fill"
                            : "record.circle"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    .borderedProminent
                )
                .tint(
                    learner.isRecording
                    ? .secondary
                    : .red
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private func learnedResultCard(
        _ result: IRCaptureResult
    ) -> some View {
        let code =
            IRCode(
                id:
                    "learn-preview",
                carrierHz:
                    carrierHz,
                durationsMicros:
                    result.durationsMicros
            )

        return VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Label(
                "Señal detectada",
                systemImage:
                    "checkmark.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(.green)

            HStack {
                LabeledContent(
                    "Flancos",
                    value:
                        "\(result.edgeCount)"
                )

                LabeledContent(
                    "Duración",
                    value:
                        "\(result.durationMillis) ms"
                )
            }

            IRWaveformView(
                durations:
                    result.durationsMicros
            )

            IRAnalysisCard(
                code: code,
                category: category
            )

            TextField(
                "Nombre del botón",
                text: $signalName
            )
            .textFieldStyle(
                .roundedBorder
            )

            if guidedMode {
                Menu {
                    ForEach(
                        guidedButtons,
                        id: \.self
                    ) { name in
                        Button(name) {
                            signalName = name
                        }
                    }
                } label: {
                    Label(
                        "Elegir nombre rápido",
                        systemImage:
                            "text.badge.checkmark"
                    )
                }
            }

            HStack(spacing: 10) {
                Button {
                    transmitter.send(
                        code: code
                    )
                } label: {
                    Label(
                        "PROBAR",
                        systemImage:
                            "wave.3.right"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    .borderedProminent
                )
                .tint(.red)

                Button {
                    learnedSignals.add(
                        name: signalName,
                        category: category,
                        carrierHz: carrierHz,
                        result: result
                    )

                    advanceGuide()
                } label: {
                    Label(
                        "GUARDAR",
                        systemImage:
                            "square.and.arrow.down"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    @ViewBuilder
    private var learnedList: some View {
        if learnedSignals.signals.isEmpty {
            EmptyStateView(
                title:
                    "Aún no hay botones aprendidos",
                systemImage:
                    "remote",
                message:
                    "Puedes aprenderlos con un receptor IR o importar un archivo .ir de Flipper."
            )
        } else {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                HStack {
                    Text("Biblioteca aprendida")
                        .font(.headline)

                    Spacer()

                    Text(
                        "\(learnedSignals.signals.count)"
                    )
                    .font(
                        .caption.monospacedDigit()
                    )
                    .foregroundStyle(.secondary)
                }

                ForEach(
                    learnedSignals.signals
                ) { signal in
                    NavigationLink {
                        LearnedSignalDetailView(
                            signal: signal,
                            transmitter:
                                transmitter
                        )
                    } label: {
                        HStack {
                            Image(
                                systemName:
                                    signal.category
                                    .systemImage
                            )
                            .foregroundStyle(.red)

                            VStack(
                                alignment: .leading,
                                spacing: 2
                            ) {
                                Text(signal.name)
                                    .font(.headline)

                                Text(
                                    "\(signal.carrierHz / 1000) kHz · \(signal.durationsMicros.count) tiempos"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(
                                systemName:
                                    "chevron.right"
                            )
                            .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    .buttonStyle(.plain)
                    .background(
                        .thinMaterial,
                        in: RoundedRectangle(
                            cornerRadius: 16
                        )
                    )
                    .contextMenu {
                        Button {
                            transmitter.send(
                                code: signal.code
                            )
                        } label: {
                            Label(
                                "Probar",
                                systemImage:
                                    "wave.3.right"
                            )
                        }

                        Button {
                            savedDevices.add(
                                name:
                                    signal.category
                                    .defaultDeviceName,
                                category:
                                    signal.category,
                                code:
                                    signal.code,
                                codeLabel:
                                    signal.name,
                                embedCode: true
                            )
                        } label: {
                            Label(
                                "Añadir a Mis equipos",
                                systemImage:
                                    "star"
                            )
                        }

                        Button(
                            role: .destructive
                        ) {
                            learnedSignals.remove(
                                signal
                            )
                        } label: {
                            Label(
                                "Eliminar",
                                systemImage:
                                    "trash"
                            )
                        }
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
    }

    private var guidedButtons:
        [String] {
        switch category {
        case .television:
            return [
                "Power",
                "Vol +",
                "Vol -",
                "Mute",
                "Channel +",
                "Channel -",
                "Input",
                "Menu",
                "OK",
                "Arriba",
                "Abajo",
                "Izquierda",
                "Derecha",
                "Back",
            ]

        case .airConditioner:
            return [
                "Power",
                "Temp +",
                "Temp -",
                "Mode",
                "Fan",
                "Swing",
                "Cool",
                "Heat",
                "Auto",
            ]

        case .projector:
            return [
                "Power",
                "Source",
                "Menu",
                "OK",
                "Arriba",
                "Abajo",
                "Izquierda",
                "Derecha",
                "Back",
                "Mute",
                "Freeze",
            ]
        }
    }

    private func advanceGuide() {
        guard guidedMode else {
            signalName = "Power"
            return
        }

        let buttons =
            guidedButtons

        guard !buttons.isEmpty else {
            return
        }

        if guidedIndex + 1
            < buttons.count
        {
            guidedIndex += 1
            signalName =
                buttons[guidedIndex]
        } else {
            guidedMode = false
            guidedIndex = 0
            signalName = "Power"
        }
    }

    private func importIRFile(
        _ result:
            Result<[URL], Error>
    ) {
        do {
            guard let url =
                try result.get().first
            else {
                return
            }

            let accessed =
                url.startAccessingSecurityScopedResource()

            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data =
                try Data(
                    contentsOf: url
                )

            guard
                let text =
                    String(
                        data: data,
                        encoding: .utf8
                    )
            else {
                importMessage =
                    "El archivo no es texto UTF-8."
                return
            }

            let imported =
                FlipperIRCodec.parse(
                    text: text
                )

            guard !imported.isEmpty else {
                importMessage =
                    "No he encontrado señales RAW o protocolos compatibles en ese .ir."
                return
            }

            for signal in imported {
                learnedSignals.addImported(
                    name: signal.name,
                    category: category,
                    code: signal.code
                )
            }

            importMessage =
                "Importadas \(imported.count) señal(es)."
        } catch {
            importMessage =
                "No se pudo importar: \(error.localizedDescription)"
        }
    }
}
