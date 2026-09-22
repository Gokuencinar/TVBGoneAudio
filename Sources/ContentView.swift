import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var transmitter = IRTransmitter()
    @StateObject private var savedDevices = SavedDeviceStore()
    @StateObject private var learnedSignals = LearnedIRStore()
    @StateObject private var learner = IRLearner()
    @StateObject private var customRemotes = CustomRemoteStore()
    @StateObject private var updater = AppUpdater()
    @StateObject private var workedHistory = WorkedCodeHistoryStore()

    @AppStorage("irUniversal.onboardingVersion")
    private var onboardingVersion = 0

    @State private var category: IRDeviceCategory = .television
    @State private var region: TVRegion = .europe
    @State private var pace: ScanPace = .fast
    @State private var showUpdateAlert = false
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            ControlView(
                transmitter: transmitter,
                savedDevices: savedDevices,
                history: workedHistory,
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
                learnedSignals: learnedSignals,
                customRemotes: customRemotes,
                category: $category,
                region: $region
            )
            .tabItem {
                Label("Códigos", systemImage: "dial.medium.fill")
            }

            SavedDevicesView(
                transmitter: transmitter,
                savedDevices: savedDevices,
                customRemotes: customRemotes,
                history: workedHistory
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
                Label("Aprender", systemImage: "mic.fill")
            }

            DiagnosticsView(
                transmitter: transmitter,
                learner: learner,
                updater: updater,
                savedDevices: savedDevices,
                learnedSignals: learnedSignals,
                customRemotes: customRemotes,
                history: workedHistory
            )
            .tabItem {
                Label("Diagnóstico", systemImage: "waveform.path.ecg")
            }
        }
        .tint(.red)
        .task {
            await updater.checkForUpdates(silent: true)
        }
        .onChange(of: updater.updateAvailable) { available in
            if available {
                showUpdateAlert = true
            }
        }
        .alert(
            "Actualización disponible",
            isPresented: $showUpdateAlert
        ) {
            Button("Actualizar con TrollStore") {
                updater.installWithTrollStore()
            }

            Button("Más tarde", role: .cancel) {}
        } message: {
            Text(
                "Está disponible IR Universal \(updater.availableVersionText). TrollStore descargará e instalará la nueva IPA."
            )
        }
        .onAppear {
            transmitter.inspectOutputRoute()

            if onboardingVersion < 5 {
                showOnboarding = true
            }
        }
        .fullScreenCover(
            isPresented: $showOnboarding
        ) {
            IRWelcomeView {
                onboardingVersion = 5
                showOnboarding = false
            }
        }
    }
}

private struct ControlView: View {
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var savedDevices: SavedDeviceStore
    @ObservedObject var history: WorkedCodeHistoryStore

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
                    statusCard
                    quickDevices
                    recentWorkedCard

                    DeviceCategoryPicker(
                        category: $category,
                        disabled: transmitter.isScanning
                    )

                    if category == .television {
                        regionPicker
                    }

                    scanCard

                    if transmitter.isScanning {
                        activeScanCard
                    }
                }
                .padding()
            }
            .irOLEDScreen()
            .navigationTitle("IR Universal")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                transmitter.inspectOutputRoute()
            }
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
        VStack(spacing: 12) {
            ZStack {
                IRTransmissionHalo(
                    trigger: transmitter.transmissionPulse
                )
                .frame(width: 150, height: 150)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .red.opacity(0.20),
                                .orange.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 104, height: 104)

                Image(systemName: category.systemImage)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.red)
            }

            if transmitter.isScanning {
                Label(
                    "BARRIENDO CÓDIGOS",
                    systemImage: "dot.radiowaves.left.and.right"
                )
                .font(.caption.bold())
                .foregroundStyle(.red)
            } else if transmitter.isPreviewing {
                Label(
                    "TRANSMITIENDO",
                    systemImage: "wave.3.right"
                )
                .font(.caption.bold())
                .foregroundStyle(.red)
            } else {
                Text("IR UNIVERSAL")
                    .font(.caption.bold())
                    .tracking(1.8)
                    .foregroundStyle(.secondary)
            }

            Text(category.title)
                .font(.title2.bold())

            Text(category.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
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

    @ViewBuilder
    private var recentWorkedCard: some View {
        if let record = history.records.first {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        "Último código que funcionó",
                        systemImage: "checkmark.seal.fill"
                    )
                    .font(.headline)

                    Spacer()

                    Text(
                        record.createdAt.formatted(
                            date: .omitted,
                            time: .shortened
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.codeLabel)
                            .font(.subheadline.bold())
                            .lineLimit(2)

                        Text(
                            "\(record.sourceLabel) · \(record.carrierHz) Hz"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        transmitter.send(code: record.code)
                    } label: {
                        Image(systemName: "power")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.12),
                        Color.clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        Color.green.opacity(0.22),
                        lineWidth: 1
                    )
            )
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
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Código actual")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if transmitter.currentCarrierHz > 0 {
                            Text(
                                "\(transmitter.currentCarrierHz / 1000) kHz"
                            )
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        }
                    }

                    Text(codeName)
                        .font(.subheadline.monospaced())
                        .lineLimit(2)

                    HStack {
                        Label(
                            "~\(estimatedRemainingText)",
                            systemImage: "clock"
                        )

                        Spacer()

                        Text(
                            "\(Int((transmitter.progress * 100).rounded())) %"
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

                if let best = workedCandidates.first {
                    history.add(
                        code: best,
                        category: category
                    )
                }

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

    private var estimatedRemainingText: String {
        let remaining =
            max(
                0,
                transmitter.totalCount
                    - transmitter.sentCount
            )

        let seconds =
            Int(
                ceil(
                    Double(remaining)
                    * (pace.gapSeconds + 0.12)
                )
            )

        if seconds < 60 {
            return "\(seconds) s"
        }

        let minutes = seconds / 60
        let rest = seconds % 60

        return rest == 0
            ? "\(minutes) min"
            : "\(minutes) min \(rest) s"
    }

    private var statusCard: some View {
        AccessoryStatusCard(
            transmitter: transmitter
        )
    }
}

private struct ManualCodeView: View {
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var savedDevices: SavedDeviceStore
    @ObservedObject var learnedSignals: LearnedIRStore
    @ObservedObject var customRemotes: CustomRemoteStore

    @Binding var category: IRDeviceCategory
    @Binding var region: TVRegion

    @State private var source: IRSourceFilter = .all
    @State private var searchText = ""
    @State private var selectedCodeID = ""
    @State private var showSaveSheet = false
    @State private var selectedBrowseLetter = "A"
    @State private var selectedBrowseName = ""

    private let alphabet =
        Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            .map(String.init)

    private var sourceCodes: [IRCode] {
        IRCodeCatalog.filtered(
            category: category,
            region: region,
            source: source,
            searchText: ""
        )
    }

    private var browserNames: [String] {
        var seen = Set<String>()

        return sourceCodes
            .map { browserName(for: $0) }
            .filter { !$0.isEmpty }
            .sorted {
                $0.localizedCaseInsensitiveCompare($1)
                    == .orderedAscending
            }
            .filter {
                seen.insert(
                    $0.folding(
                        options: [
                            .caseInsensitive,
                            .diacriticInsensitive,
                        ],
                        locale: .current
                    )
                ).inserted
            }
    }

    private var visibleBrowserNames: [String] {
        browserNames.filter {
            firstLetter(of: $0)
                == selectedBrowseLetter
        }
    }

    private var filteredCodes: [IRCode] {
        let base =
            IRCodeCatalog.filtered(
                category: category,
                region: region,
                source: source,
                searchText: searchText
            )

        guard
            !selectedBrowseName.isEmpty
        else {
            return base
        }

        return base.filter {
            browserName(for: $0)
                .caseInsensitiveCompare(
                    selectedBrowseName
                ) == .orderedSame
        }
    }

    private var selectedCode: IRCode? {
        filteredCodes.first {
            $0.id == selectedCodeID
        }
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

                    NavigationLink {
                        OnlineIRLibraryView(
                            transmitter: transmitter,
                            learnedSignals: learnedSignals,
                            customRemotes: customRemotes,
                            category: $category
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.title2)
                                .foregroundStyle(.red)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Biblioteca IR online")
                                    .font(.headline)
                                Text("Busca por marca/modelo, prueba códigos y descarga mandos")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    .buttonStyle(.plain)
                    .irCard(cornerRadius: 18)

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

                    localBrandBrowser

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
                        .irCard(cornerRadius: 20)

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
                    selectedBrowseName = ""
                    normalizeSelection()
                }
                .onChange(of: region) { _ in
                    selectedBrowseName = ""
                    normalizeSelection()
                }
                .onChange(of: source) { _ in
                    selectedBrowseName = ""
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

    private var localBrandBrowser: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Label(
                    "Índice A–Z",
                    systemImage:
                        "textformat.abc"
                )
                .font(.headline)

                Spacer()

                Text(
                    "\(browserNames.count)"
                )
                .font(
                    .caption
                        .monospacedDigit()
                )
                .foregroundStyle(.secondary)
            }

            Text(
                source == .tvBGone
                ? "TV-B-Gone no incluye marca real en todos sus códigos; en esos casos se muestran los nombres disponibles."
                : "Elige una letra y después una marca para filtrar la ruleta."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if !browserNames.isEmpty {
                HStack(
                    alignment: .top,
                    spacing: 10
                ) {
                    ScrollView {
                        LazyVStack(
                            spacing: 4
                        ) {
                            ForEach(
                                alphabet,
                                id: \.self
                            ) { letter in
                                let enabled =
                                    browserNames
                                        .contains {
                                            firstLetter(
                                                of: $0
                                            ) == letter
                                        }

                                Button {
                                    selectedBrowseLetter =
                                        letter
                                    IRHaptics.tap()
                                } label: {
                                    Text(letter)
                                        .font(
                                            .caption.bold()
                                        )
                                        .frame(
                                            width: 34,
                                            height: 30
                                        )
                                        .foregroundStyle(
                                            selectedBrowseLetter
                                                == letter
                                            ? Color.white
                                            : enabled
                                                ? Color.red
                                                : Color.secondary
                                                    .opacity(
                                                        0.35
                                                    )
                                        )
                                        .background(
                                            selectedBrowseLetter
                                                == letter
                                            ? Color.red
                                            : Color.clear,
                                            in:
                                                RoundedRectangle(
                                                    cornerRadius:
                                                        8
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(!enabled)
                            }
                        }
                    }
                    .frame(
                        width: 42,
                        height: 250
                    )

                    Divider()

                    ScrollView {
                        LazyVStack(
                            alignment: .leading,
                            spacing: 4
                        ) {
                            ForEach(
                                visibleBrowserNames,
                                id: \.self
                            ) { name in
                                Button {
                                    selectedBrowseName =
                                        selectedBrowseName
                                            == name
                                        ? ""
                                        : name

                                    searchText = ""
                                    normalizeSelection()
                                    IRHaptics.tap()
                                } label: {
                                    HStack {
                                        Text(name)
                                            .font(
                                                .subheadline
                                            )
                                            .foregroundStyle(
                                                .primary
                                            )
                                            .multilineTextAlignment(
                                                .leading
                                            )

                                        Spacer()

                                        if selectedBrowseName
                                            == name
                                        {
                                            Image(
                                                systemName:
                                                    "checkmark.circle.fill"
                                            )
                                            .foregroundStyle(
                                                .red
                                            )
                                        } else {
                                            Image(
                                                systemName:
                                                    "chevron.right"
                                            )
                                            .font(
                                                .caption2
                                            )
                                            .foregroundStyle(
                                                .secondary
                                            )
                                        }
                                    }
                                    .padding(
                                        .horizontal,
                                        10
                                    )
                                    .padding(
                                        .vertical,
                                        9
                                    )
                                    .background(
                                        selectedBrowseName
                                            == name
                                        ? Color.red
                                            .opacity(
                                                0.12
                                            )
                                        : Color.clear,
                                        in:
                                            RoundedRectangle(
                                                cornerRadius:
                                                    10
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(height: 250)
                }

                if !selectedBrowseName.isEmpty {
                    HStack {
                        Label(
                            selectedBrowseName,
                            systemImage:
                                "line.3.horizontal.decrease.circle.fill"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.red)

                        Spacer()

                        Button(
                            "Quitar filtro"
                        ) {
                            selectedBrowseName =
                                ""
                            normalizeSelection()
                            IRHaptics.tap()
                        }
                        .font(.caption)
                    }
                    .padding(.top, 2)
                }
            } else {
                Text(
                    "No hay nombres disponibles para este filtro."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(
                    maxWidth: .infinity
                )
                .padding(.vertical, 24)
            }
        }
        .padding()
        .irCard(cornerRadius: 20)
    }

    private func browserName(
        for code: IRCode
    ) -> String {
        let brand =
            code.brandHint
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if
            !brand.isEmpty,
            brand
                .caseInsensitiveCompare(
                    code.sourceLabel
                ) != .orderedSame
        {
            return brand
        }

        var fallback =
            code.displayName

        if
            fallback
                .lowercased()
                .hasPrefix(
                    "tv-b-gone · "
                )
        {
            fallback =
                String(
                    fallback.dropFirst(
                        "TV-B-Gone · ".count
                    )
                )
        }

        return fallback
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private func firstLetter(
        of value: String
    ) -> String {
        let folded =
            value.folding(
                options: [
                    .diacriticInsensitive,
                    .caseInsensitive,
                ],
                locale: .current
            )
            .uppercased()

        guard
            let first =
                folded.first
        else {
            return "#"
        }

        let letter =
            String(first)

        return alphabet.contains(letter)
            ? letter
            : "#"
    }

    private func normalizeBrowser() {
        if
            !selectedBrowseName.isEmpty,
            !browserNames.contains(
                where: {
                    $0.caseInsensitiveCompare(
                        selectedBrowseName
                    ) == .orderedSame
                }
            )
        {
            selectedBrowseName = ""
        }

        if
            !browserNames.contains(
                where: {
                    firstLetter(of: $0)
                        == selectedBrowseLetter
                }
            ),
            let first =
                browserNames.first
        {
            selectedBrowseLetter =
                firstLetter(of: first)
        }
    }

    private func normalizeSelection() {
        normalizeBrowser()

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
    @ObservedObject var history: WorkedCodeHistoryStore

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    HStack(spacing: 10) {
                        LibraryMetricCard(
                            value: savedDevices.devices.count,
                            label: "Equipos",
                            systemImage: "tv"
                        )

                        LibraryMetricCard(
                            value: customRemotes.remotes.count,
                            label: "Mandos",
                            systemImage: "remote.fill"
                        )

                        LibraryMetricCard(
                            value: history.records.count,
                            label: "Funcionaron",
                            systemImage: "checkmark.seal.fill"
                        )
                    }

                    if !customRemotes.remotes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(
                                "Mis mandos",
                                systemImage: "remote.fill"
                            )
                            .font(.title3.bold())

                            LazyVGrid(
                                columns: columns,
                                spacing: 12
                            ) {
                                ForEach(customRemotes.remotes) { remote in
                                    NavigationLink {
                                        CustomRemoteView(
                                            remote: remote,
                                            transmitter: transmitter
                                        )
                                    } label: {
                                        PremiumRemoteTile(
                                            remote: remote
                                        )
                                    }
                                    .buttonStyle(.plain)
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
                                                systemImage: "trash"
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                    }

                    if !savedDevices.devices.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(
                                "Acceso rápido",
                                systemImage: "bolt.fill"
                            )
                            .font(.title3.bold())

                            ForEach(savedDevices.devices) { device in
                                PremiumSavedDeviceCard(
                                    device: device,
                                    transmitter: transmitter,
                                    savedDevices: savedDevices
                                )
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                    }

                    if !history.records.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(
                                    "Historial de aciertos",
                                    systemImage: "clock.arrow.circlepath"
                                )
                                .font(.title3.bold())

                                Spacer()

                                Button("Borrar") {
                                    history.clear()
                                }
                                .font(.caption)
                                .foregroundStyle(.red)
                            }

                            ForEach(
                                Array(history.records.prefix(8))
                            ) { record in
                                WorkedCodeRow(
                                    record: record,
                                    transmitter: transmitter,
                                    history: history
                                )
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                    }

                    if
                        savedDevices.devices.isEmpty
                        && customRemotes.remotes.isEmpty
                        && history.records.isEmpty
                    {
                        EmptyStateView(
                            title: "Tu biblioteca está vacía",
                            systemImage: "remote",
                            message:
                                "Cuando encuentres un código que funcione, aparecerá aquí para que puedas volver a usarlo en segundos."
                        )
                        .padding(.top, 60)
                    }
                }
                .padding()
            }
            .irOLEDScreen()
            .navigationTitle("Mis equipos")
        }
    }
}

private struct DiagnosticsView: View {
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var learner: IRLearner
    @ObservedObject var updater: AppUpdater
    @ObservedObject var savedDevices: SavedDeviceStore
    @ObservedObject var learnedSignals: LearnedIRStore
    @ObservedObject var customRemotes: CustomRemoteStore
    @ObservedObject var history: WorkedCodeHistoryStore

    private var compatibilityConclusion: String {
        if transmitter.outputRouteSuitableForIR && learner.isExternalInput {
            return "Compatible a nivel de audio para transmitir y aprender. La app todavía no puede garantizar que el dispositivo externo sea físicamente un receptor IR hasta recibir una trama válida."
        }

        if transmitter.outputRouteSuitableForIR && !learner.isExternalInput {
            return "Compatible para transmitir. No se detecta entrada externa: el aprendizaje IR no es compatible con el accesorio conectado."
        }

        if !transmitter.outputRouteSuitableForIR && learner.isExternalInput {
            return "Se detecta entrada externa para aprendizaje, pero la salida no parece una ruta estéreo cableada apta para este emisor."
        }

        return "Pulsa «Comprobar accesorio». Para transmitir se necesita salida estéreo cableada; para aprender, una entrada externa real."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Compatibilidad del accesorio", systemImage: "checkmark.shield")
                            .font(.headline)

                        HStack {
                            Image(systemName: transmitter.outputRouteSuitableForIR ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(transmitter.outputRouteSuitableForIR ? .green : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Transmisión")
                                    .font(.subheadline.bold())
                                Text(transmitter.routeDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        HStack {
                            Image(systemName: learner.isExternalInput ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(learner.isExternalInput ? .green : .red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Aprendizaje")
                                    .font(.subheadline.bold())
                                Text(learner.inputDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Text(compatibilityConclusion)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            transmitter.inspectOutputRoute()
                            learner.requestPermissionAndCheckInput()
                        } label: {
                            Label("COMPROBAR ACCESORIO", systemImage: "cable.connector")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .irCard(cornerRadius: 18)

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

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Por qué importan los ajustes de audio")
                            .font(.headline)

                        Label(
                            "Volumen: controla la amplitud eléctrica. Si baja demasiado, los LED IR reciben menos corriente y cae mucho el alcance.",
                            systemImage: "speaker.wave.3.fill"
                        )

                        Label(
                            "Balance: debe estar centrado porque el adaptador usa la diferencia entre L y R. Desplazarlo reduce la tensión diferencial y la potencia IR.",
                            systemImage: "slider.horizontal.3"
                        )

                        Label(
                            "Audio mono: debe estar desactivado. La app genera L y R en oposición de fase; al mezclarlos a mono pueden cancelarse casi por completo.",
                            systemImage: "ear.and.waveform"
                        )
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        .thinMaterial,
                        in: RoundedRectangle(cornerRadius: 18)
                    )

                    OLEDSettingsCard()

                    BackupCenterView(
                        savedDevices: savedDevices,
                        learnedSignals: learnedSignals,
                        customRemotes: customRemotes,
                        history: history
                    )

                    UpdateCenterView(updater: updater)
                }
                .padding()
            }
            .irOLEDScreen()
            .navigationTitle("Diagnóstico")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DeviceCategoryPicker: View {
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

    @State private var carrierHz = 0
    @State private var signalName = "Power"

    @State private var showImporter = false
    @State private var showRemoteBuilder = false
    @State private var importMessage: String?

    @State private var guidedMode = false
    @State private var guidedIndex = 0

    private let carriers =
        [0, 36_000, 38_000, 40_000, 56_000]

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
            .irOLEDScreen()
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
                            learner.isExternalInput
                            ? "checkmark.circle.fill"
                            : "xmark.circle.fill"
                    )
                    .foregroundStyle(
                        learner.isExternalInput
                        ? .green
                        : .red
                    )
                }
            }

            Text(
                learner.inputDescription
            )
            .font(.subheadline)

            if learner.inputChannels > 0 && !learner.isExternalInput {
                Label(
                    "Entrada interna: este dispositivo no puede aprender IR",
                    systemImage: "xmark.circle.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(.red)
            } else if learner.isExternalInput {
                Label(
                    "Entrada externa detectada",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(.green)
            }

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
                        hz == 0
                        ? "Auto"
                        : "\(hz / 1000)"
                    )
                    .tag(hz)
                }
            }
            .pickerStyle(.segmented)

            Text(
                carrierHz == 0
                ? "Auto analiza la trama capturada, intenta reconocer el protocolo y elige su portadora habitual. Con un receptor IR demodulado no es posible medir directamente la portadora óptica porque el propio receptor ya la ha eliminado."
                : "Selección manual: \(carrierHz / 1000) kHz. Úsala si conoces la frecuencia del mando o la del receptor."
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
                .disabled(learner.isRecording || !learner.isExternalInput)

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
                .disabled(!learner.isExternalInput && !learner.isRecording)
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
        let resolvedCarrier =
            effectiveCarrier(
                for: result
            )

        let code =
            IRCode(
                id:
                    "learn-preview",
                carrierHz:
                    resolvedCarrier,
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

            LabeledContent(
                "Portadora",
                value:
                    carrierHz == 0
                    ? "Auto → \(resolvedCarrier / 1000) kHz"
                    : "\(resolvedCarrier / 1000) kHz"
            )

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
                        carrierHz: resolvedCarrier,
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

    private func effectiveCarrier(
        for result: IRCaptureResult
    ) -> Int {
        if carrierHz > 0 {
            return carrierHz
        }

        let probe =
            IRCode(
                id: "auto-carrier-probe",
                carrierHz: 0,
                durationsMicros:
                    result.durationsMicros
            )

        return IRSignalAnalyzer
            .recommendedCarrierHz(
                for: probe
            )
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
