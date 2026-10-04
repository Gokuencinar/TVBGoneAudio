import Foundation
import SwiftUI

struct UniversalRemoteHubView: View {
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var savedDevices: SavedDeviceStore
    @ObservedObject var learnedSignals: LearnedIRStore
    @ObservedObject var customRemotes: CustomRemoteStore
    @ObservedObject var history: WorkedCodeHistoryStore

    @Binding var category: IRDeviceCategory

    @AppStorage("irUniversal.remote.selectedTarget")
    private var selectedTargetKey = ""

    @State private var showLibrary = false
    @State private var showAddRemote = false
    @State private var knownRemoteCount = 0

    private var activeTargetKey: String {
        if targetExists(selectedTargetKey) {
            return selectedTargetKey
        }

        if let remote = customRemotes.remotes.first {
            return targetKey(for: remote)
        }

        if let device = savedDevices.devices.first {
            return targetKey(for: device)
        }

        return ""
    }

    private var selectedDevice: SavedIRDevice? {
        guard activeTargetKey.hasPrefix("device:") else {
            return nil
        }

        let id = String(
            activeTargetKey.dropFirst("device:".count)
        )

        return savedDevices.devices.first {
            $0.id.uuidString == id
        }
    }

    private var selectedRemote: CustomRemote? {
        guard activeTargetKey.hasPrefix("remote:") else {
            return nil
        }

        let id = String(
            activeTargetKey.dropFirst("remote:".count)
        )

        return customRemotes.remotes.first {
            $0.id.uuidString == id
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    remoteShelfCard

                    if let remote = selectedRemote {
                        targetSelector

                        UniversalRemoteSurface(
                            remote: remote,
                            transmitter: transmitter
                        )

                        if !savedDevices.devices.isEmpty {
                            quickPowerDevices
                        }
                    } else if let device = selectedDevice {
                        targetSelector
                        powerOnlySurface(device)
                    } else {
                        emptyState
                    }

                    managementCard
                }
                .padding()
            }
            .irOLEDScreen()
            .navigationTitle("Mando")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddRemote = true
                        IRHaptics.tap()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Añadir mando")
                }
            }
            .onAppear {
                knownRemoteCount = customRemotes.remotes.count
                normalizeSelection()
            }
            .onChange(of: customRemotes.remotes) { newRemotes in
                if
                    newRemotes.count > knownRemoteCount,
                    let newest = newRemotes.last
                {
                    selectedTargetKey = targetKey(for: newest)
                    category = newest.category
                }
                knownRemoteCount = newRemotes.count
                normalizeSelection()
            }
            .onChange(of: savedDevices.devices) { _ in
                normalizeSelection()
            }
            .onChange(of: transmitter.transmissionPulse) { _ in
                guard
                    transmitter.currentCodeID?.hasPrefix("remote:") == true,
                    let remote = remoteForCurrentTransmission()
                else {
                    return
                }

                customRemotes.recordUse(remote)
            }
            .sheet(isPresented: $showLibrary) {
                SavedDevicesView(
                    transmitter: transmitter,
                    savedDevices: savedDevices,
                    customRemotes: customRemotes,
                    history: history
                )
            }
            .sheet(isPresented: $showAddRemote) {
                RemoteAddDeviceSheet(
                    transmitter: transmitter,
                    learnedSignals: learnedSignals,
                    customRemotes: customRemotes
                )
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            IRCyberPalette.cyan.opacity(0.18),
                            IRCyberPalette.magenta.opacity(0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)

                Image(systemName: IRAppSymbols.remote)
                    .font(.title2.bold())
                    .foregroundStyle(IRCyberPalette.cyan)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Mando universal")
                    .font(.title3.bold())

                Text(
                    "Control tipo Mi Remote con distribución automática de botones."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .irCard(cornerRadius: 20)
    }

    private var remoteShelfCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    customRemotes.remotes.contains(where: { $0.isFavorite || $0.lastUsedAt != nil })
                    ? "Favoritos y recientes"
                    : "Mis mandos",
                    systemImage: IRAppSymbols.remote
                )
                    .font(.headline)

                Spacer()

                Text("\(customRemotes.remotes.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(shelfRemotes) { remote in
                        Button {
                            select(
                                targetKey(for: remote),
                                category: remote.category
                            )
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(
                                        cornerRadius: 14,
                                        style: .continuous
                                    )
                                    .fill(
                                        activeTargetKey == targetKey(for: remote)
                                        ? IRCyberPalette.cyan.opacity(0.20)
                                        : Color.white.opacity(0.035)
                                    )
                                    .frame(width: 58, height: 58)

                                    Image(systemName: remote.category.systemImage)
                                        .font(.title2)

                                    if remote.isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                            .offset(x: 20, y: -20)
                                    }
                                }

                                Text(remote.name)
                                    .font(.caption.bold())
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 100)
                            }
                            .frame(minHeight: 98)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(
                            activeTargetKey == targetKey(for: remote)
                            ? IRCyberPalette.cyan
                            : .primary
                        )
                        .accessibilityLabel("Usar mando \(remote.name)")
                    }

                    Button {
                        showAddRemote = true
                        IRHaptics.tap()
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                                .stroke(
                                    IRCyberPalette.cyan.opacity(0.55),
                                    style: StrokeStyle(
                                        lineWidth: 1.2,
                                        dash: [5, 4]
                                    )
                                )
                                .frame(width: 58, height: 58)

                                Image(systemName: "plus")
                                    .font(.title2.bold())
                            }

                            Text("Añadir")
                                .font(.caption.bold())
                                .frame(width: 100)
                        }
                        .frame(minHeight: 98)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(IRCyberPalette.cyan)
                    .accessibilityLabel("Añadir mando")
                }
            }

            if customRemotes.remotes.isEmpty {
                Text(
                    "Añade un dispositivo, elige marca/modelo, prueba su POWER y guarda el mando completo."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .irCard(cornerRadius: 18)
    }

    @ViewBuilder
    private var targetSelector: some View {
        if selectedRemote != nil || selectedDevice != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        "Control activo",
                        systemImage:
                            selectedRemote?.category.systemImage
                            ?? selectedDevice?.category.systemImage
                            ?? IRAppSymbols.remote
                    )
                    .font(.headline)

                    Spacer()

                    IRCyberBadge(
                        text:
                            selectedRemote.map {
                                "\($0.buttons.count) BOTONES"
                            }
                            ?? "POWER",
                        systemImage:
                            selectedRemote == nil
                            ? "power"
                            : "circle.grid.3x3.fill"
                    )

                    if let selectedRemote {
                        Button {
                            customRemotes.toggleFavorite(selectedRemote)
                        } label: {
                            Image(
                                systemName:
                                    selectedRemote.isFavorite
                                    ? "star.fill"
                                    : "star"
                            )
                            .font(.headline)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(
                            selectedRemote.isFavorite
                            ? Color.yellow
                            : IRCyberPalette.cyan
                        )
                        .accessibilityLabel(
                            selectedRemote.isFavorite
                            ? "Quitar de favoritos"
                            : "Añadir a favoritos"
                        )
                    }
                }

                Menu {
                    if !customRemotes.remotes.isEmpty {
                        Section("Mandos completos") {
                            ForEach(customRemotes.remotes) { item in
                                Button {
                                    select(
                                        targetKey(for: item),
                                        category: item.category
                                    )
                                } label: {
                                    Label(
                                        item.name,
                                        systemImage:
                                            activeTargetKey
                                                == targetKey(for: item)
                                            ? "checkmark.circle.fill"
                                            : item.category.systemImage
                                    )
                                }
                            }
                        }
                    }

                    if !savedDevices.devices.isEmpty {
                        Section("Equipos POWER") {
                            ForEach(savedDevices.devices) { item in
                                Button {
                                    select(
                                        targetKey(for: item),
                                        category: item.category
                                    )
                                } label: {
                                    Label(
                                        item.name,
                                        systemImage:
                                            activeTargetKey
                                                == targetKey(for: item)
                                            ? "checkmark.circle.fill"
                                            : item.category.systemImage
                                    )
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(
                            selectedRemote?.name
                            ?? selectedDevice?.name
                            ?? "Seleccionar"
                        )
                        .font(.subheadline.bold())
                        .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.bold())
                    }
                    .frame(minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(
                        IRCyberPalette.cyan.opacity(0.06),
                        in: RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                        .stroke(
                            IRCyberPalette.cyan.opacity(0.24),
                            lineWidth: 0.8
                        )
                    )
                }
                .tint(IRCyberPalette.cyan)

                Text(
                    selectedRemote == nil
                    ? "Este equipo solo tiene POWER guardado. Selecciona un mando completo para disponer de todas las funciones."
                    : "Los botones se colocan automáticamente según su nombre. Los no reconocidos siguen disponibles en «Más controles»."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .irCard(cornerRadius: 18)
        }
    }

    private func powerOnlySurface(
        _ device: SavedIRDevice
    ) -> some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
                        .font(.title3.bold())

                    Text("Código POWER guardado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            }

            RemotePowerButton {
                guard let code = savedDevices.code(for: device) else {
                    IRHaptics.error()
                    return
                }

                transmitter.send(code: code)
            }

            VStack(spacing: 6) {
                Text("Este equipo solo tiene POWER guardado")
                    .font(.headline)

                Text(
                    "Para disponer de volumen, canales, navegación y el resto de funciones, descarga o importa un mando completo."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button {
                showAddRemote = true
                IRHaptics.tap()
            } label: {
                Label(
                    "BUSCAR MANDO COMPLETO",
                    systemImage: "globe"
                )
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(
                IRCyberActionButtonStyle(
                    tint: IRCyberPalette.cyan
                )
            )
        }
        .padding()
        .irCard(cornerRadius: 22)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: IRAppSymbols.remoteOutline)
                .font(.system(size: 44))
                .foregroundStyle(IRCyberPalette.cyan)

            Text("Añade tu primer mando")
                .font(.title3.bold())

            Text(
                "Busca un mando completo por marca/modelo o importa un .ir. Después aparecerá aquí con controles organizados automáticamente."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button {
                showAddRemote = true
                IRHaptics.tap()
            } label: {
                Label(
                    "BUSCAR MANDO ONLINE",
                    systemImage: "magnifyingglass"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(
                IRCyberActionButtonStyle(
                    tint: IRCyberPalette.cyan
                )
            )
        }
        .padding(22)
        .irCard(cornerRadius: 22)
    }

    private var managementCard: some View {
        VStack(spacing: 10) {
            Button {
                showLibrary = true
            } label: {
                HStack {
                    Label(
                        "Mis equipos y mandos",
                        systemImage: "rectangle.stack.fill"
                    )

                    Spacer()

                    Text(
                        "\(savedDevices.devices.count + customRemotes.remotes.count)"
                    )
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !customRemotes.remotes.isEmpty {
                Button {
                    showAddRemote = true
                    IRHaptics.tap()
                } label: {
                    HStack {
                        Label(
                            "Añadir otro mando",
                            systemImage: "plus.circle.fill"
                        )

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .irCard(cornerRadius: 18)
    }

    private var quickPowerDevices: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "POWER rápido",
                systemImage: "bolt.fill"
            )
            .font(.headline)

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                LazyHStack(spacing: 10) {
                    ForEach(savedDevices.devices) { device in
                        Button {
                            guard let code = savedDevices.code(
                                for: device
                            ) else {
                                IRHaptics.error()
                                return
                            }

                            transmitter.send(code: code)
                        } label: {
                            VStack(spacing: 7) {
                                Image(
                                    systemName:
                                        device.category
                                        .systemImage
                                )
                                .font(.title3)

                                Text(device.name)
                                    .font(.caption.bold())
                                    .lineLimit(1)

                                Image(systemName: "power")
                                    .font(.caption.bold())
                            }
                            .frame(width: 104)
                            .frame(minHeight: 88)
                        }
                        .buttonStyle(.bordered)
                        .tint(
                            IRCyberPalette.signalRed
                        )
                        .accessibilityLabel(
                            "Encender o apagar \(device.name)"
                        )
                    }
                }
            }
        }
        .padding()
        .irCard(cornerRadius: 18)
    }

    private func select(
        _ key: String,
        category: IRDeviceCategory
    ) {
        selectedTargetKey = key
        self.category = category

        IRHaptics.tap()
    }

    private var shelfRemotes: [CustomRemote] {
        customRemotes.remotes.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite && !rhs.isFavorite
            }

            let lhsDate = lhs.lastUsedAt ?? lhs.createdAt
            let rhsDate = rhs.lastUsedAt ?? rhs.createdAt
            return lhsDate > rhsDate
        }
    }

    private func remoteForCurrentTransmission() -> CustomRemote? {
        guard
            let codeID = transmitter.currentCodeID,
            codeID.hasPrefix("remote:"),
            let buttonID = UUID(
                uuidString: String(codeID.dropFirst("remote:".count))
            )
        else {
            return nil
        }

        return customRemotes.remotes.first { remote in
            remote.buttons.contains { $0.id == buttonID }
        }
    }

    private func targetKey(
        for remote: CustomRemote
    ) -> String {
        "remote:\(remote.id.uuidString)"
    }

    private func targetKey(
        for device: SavedIRDevice
    ) -> String {
        "device:\(device.id.uuidString)"
    }

    private func targetExists(
        _ key: String
    ) -> Bool {
        if key.hasPrefix("remote:") {
            let id = String(
                key.dropFirst("remote:".count)
            )

            return customRemotes.remotes.contains {
                $0.id.uuidString == id
            }
        }

        if key.hasPrefix("device:") {
            let id = String(
                key.dropFirst("device:".count)
            )

            return savedDevices.devices.contains {
                $0.id.uuidString == id
            }
        }

        return false
    }

    private func normalizeSelection() {
        selectedTargetKey = activeTargetKey

        if let remote = selectedRemote {
            category = remote.category
        } else if let device = selectedDevice {
            category = device.category
        }
    }
}

private struct RemoteAddDeviceSheet: View {
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var learnedSignals: LearnedIRStore
    @ObservedObject var customRemotes: CustomRemoteStore

    @Environment(\.dismiss)
    private var dismiss

    @State private var initialRemoteCount = -1

    private let columns = [
        GridItem(.adaptive(minimum: 128), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Añadir dispositivo")
                            .font(.title2.bold())

                        Text(
                            "Elige el tipo de aparato. Después podrás seleccionar marca, buscar el modelo, probar sus señales y guardar el mando completo."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(IRDeviceCategory.remoteCategories) { item in
                            NavigationLink {
                                RemoteCategoryBrowser(
                                    initialCategory: item,
                                    transmitter: transmitter,
                                    learnedSignals: learnedSignals,
                                    customRemotes: customRemotes
                                )
                            } label: {
                                VStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(
                                            cornerRadius: 16,
                                            style: .continuous
                                        )
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    IRCyberPalette.cyan.opacity(0.16),
                                                    IRCyberPalette.magenta.opacity(0.06),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(height: 74)

                                        Image(systemName: item.systemImage)
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(IRCyberPalette.cyan)
                                    }

                                    Text(item.shortTitle)
                                        .font(.subheadline.bold())
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(minHeight: 36)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .irCard(cornerRadius: 18)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(
                        "Fuentes: Flipper-IRDB, Flipper IRDB oficial e IRDB Web. La disponibilidad exacta depende de los mandos publicados para cada marca/modelo."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .irOLEDScreen()
            .navigationTitle("Añadir mando")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if initialRemoteCount < 0 {
                    initialRemoteCount = customRemotes.remotes.count
                }
            }
            .onChange(of: customRemotes.remotes) { remotes in
                guard initialRemoteCount >= 0 else {
                    initialRemoteCount = remotes.count
                    return
                }

                if remotes.count > initialRemoteCount {
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RemoteCategoryBrowser: View {
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var learnedSignals: LearnedIRStore
    @ObservedObject var customRemotes: CustomRemoteStore

    @State private var category: IRDeviceCategory

    init(
        initialCategory: IRDeviceCategory,
        transmitter: IRTransmitter,
        learnedSignals: LearnedIRStore,
        customRemotes: CustomRemoteStore
    ) {
        _category = State(initialValue: initialCategory)
        self.transmitter = transmitter
        self.learnedSignals = learnedSignals
        self.customRemotes = customRemotes
    }

    var body: some View {
        OnlineIRLibraryView(
            transmitter: transmitter,
            learnedSignals: learnedSignals,
            customRemotes: customRemotes,
            category: $category
        )
    }
}

private struct UniversalRemoteSurface: View {
    let remote: CustomRemote
    @ObservedObject var transmitter: IRTransmitter

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }

        return [
            GridItem(.adaptive(minimum: 94), spacing: 10),
        ]
    }

    private var matcher: RemoteButtonMatcher {
        RemoteButtonMatcher(buttons: remote.buttons)
    }

    private var usedButtonIDs: Set<UUID> {
        Set(
            standardSemantics
                .compactMap {
                    matcher.button(for: $0)?.id
                }
        )
    }

    private var extraButtons: [CustomRemoteButton] {
        remote.buttons.filter {
            !usedButtonIDs.contains($0.id)
        }
    }

    private var standardSemantics: [RemoteSemantic] {
        switch remote.category {
        case .television:
            return RemoteSemantic.televisionStandard
        case .airConditioner:
            return RemoteSemantic.airConditionerStandard
        case .setTopBox, .streamingBox:
            return RemoteSemantic.setTopBoxStandard
        case .fan:
            return RemoteSemantic.fanStandard
        case .dvdPlayer:
            return RemoteSemantic.discPlayerStandard
        case .projector:
            return RemoteSemantic.projectorStandard
        case .avReceiver, .soundbar:
            return RemoteSemantic.audioStandard
        case .camera:
            return RemoteSemantic.cameraStandard
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            remoteStatusHeader

            switch remote.category {
            case .television:
                televisionControls
            case .airConditioner:
                airConditionerControls
            case .setTopBox, .streamingBox:
                setTopBoxControls
            case .fan:
                fanControls
            case .dvdPlayer:
                discPlayerControls
            case .projector:
                projectorControls
            case .avReceiver, .soundbar:
                audioControls
            case .camera:
                cameraControls
            }

            if !extraButtons.isEmpty {
                extraControls
            }
        }
    }

    private var remoteStatusHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(remote.name)
                    .font(.title2.bold())
                    .lineLimit(2)

                Text(remoteSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            IRCyberBadge(
                text:
                    "\(usedButtonIDs.count)/\(remote.buttons.count) MAP",
                systemImage: "point.3.connected.trianglepath.dotted"
            )
        }
        .padding(.horizontal, 4)
    }

    private var remoteSubtitle: String {
        let brand = remote.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let model = remote.model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !brand.isEmpty && !model.isEmpty
            && brand.caseInsensitiveCompare(model) != .orderedSame
        {
            return "\(brand) · \(model) · \(remote.category.shortTitle)"
        }

        if !brand.isEmpty {
            return "\(brand) · \(remote.category.shortTitle)"
        }

        return remote.category.title
    }

    private var televisionControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                RemoteFunctionButton(
                    title: "Input",
                    systemImage: "rectangle.on.rectangle",
                    button: matcher.button(for: .input),
                    transmitter: transmitter
                )

                Spacer()

                RemotePowerButton(
                    button: matcher.primaryPowerButton(),
                    transmitter: transmitter
                )

                Spacer()

                RemoteFunctionButton(
                    title: "Mute",
                    systemImage: "speaker.slash.fill",
                    button: matcher.button(for: .mute),
                    transmitter: transmitter
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    volumeRocker

                    Spacer(minLength: 0)

                    RemoteDPad(
                        matcher: matcher,
                        transmitter: transmitter
                    )

                    Spacer(minLength: 0)

                    channelRocker
                }

                VStack(spacing: 12) {
                    RemoteDPad(
                        matcher: matcher,
                        transmitter: transmitter
                    )

                    HStack(spacing: 48) {
                        volumeRocker
                        channelRocker
                    }
                }
            }

            HStack(spacing: 10) {
                remoteSemanticButton(
                    .back,
                    title: "Atrás",
                    icon: "arrow.uturn.backward"
                )

                remoteSemanticButton(
                    .home,
                    title: "Inicio",
                    icon: "house.fill"
                )

                remoteSemanticButton(
                    .menu,
                    title: "Menú",
                    icon: "list.bullet"
                )
            }

            if matcher.button(for: .guide) != nil
                || matcher.button(for: .info) != nil
            {
                HStack(spacing: 10) {
                    remoteSemanticButton(
                        .guide,
                        title: "Guía",
                        icon: "list.bullet.rectangle"
                    )
                    remoteSemanticButton(
                        .info,
                        title: "Info",
                        icon: "info.circle"
                    )
                }
            }

            if hasPlaybackControls {
                HStack(spacing: 8) {
                    compactSemanticButton(
                        .rewind,
                        title: "Retroceder",
                        icon: "backward.fill"
                    )

                    if matcher.button(for: .playPause) != nil {
                        compactSemanticButton(
                            .playPause,
                            title: "Reproducir o pausar",
                            icon: "playpause.fill"
                        )
                    } else {
                        compactSemanticButton(
                            .play,
                            title: "Reproducir",
                            icon: "play.fill"
                        )
                        compactSemanticButton(
                            .pause,
                            title: "Pausar",
                            icon: "pause.fill"
                        )
                    }

                    compactSemanticButton(
                        .stop,
                        title: "Detener",
                        icon: "stop.fill"
                    )
                    compactSemanticButton(
                        .fastForward,
                        title: "Avanzar",
                        icon: "forward.fill"
                    )
                }
            }

            if hasNumberPad {
                numberPad
            }
        }
        .padding()
        .irCard(cornerRadius: 26)
    }

    private var airConditionerControls: some View {
        VStack(spacing: 18) {
            HStack {
                RemoteFunctionButton(
                    title: "Mode",
                    systemImage: "arrow.triangle.2.circlepath",
                    button: matcher.button(for: .mode),
                    transmitter: transmitter
                )

                Spacer()

                RemotePowerButton(
                    button: matcher.primaryPowerButton(),
                    transmitter: transmitter
                )

                Spacer()

                RemoteFunctionButton(
                    title: "Fan",
                    systemImage: "fanblades.fill",
                    button: matcher.button(for: .fan),
                    transmitter: transmitter
                )
            }

            HStack(spacing: 12) {
                RemoteTemperatureButton(
                    title: "TEMP −",
                    systemImage: "minus",
                    button: matcher.button(for: .temperatureDown),
                    transmitter: transmitter
                )

                VStack(spacing: 3) {
                    Image(systemName: "thermometer.medium")
                        .font(.title)
                        .foregroundStyle(IRCyberPalette.cyan)

                    Text("TEMP")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 64)

                RemoteTemperatureButton(
                    title: "TEMP +",
                    systemImage: "plus",
                    button: matcher.button(for: .temperatureUp),
                    transmitter: transmitter
                )
            }

            LazyVGrid(columns: columns, spacing: 10) {
                remoteSemanticButton(
                    .swing,
                    title: "Swing",
                    icon: "wind"
                )
                remoteSemanticButton(
                    .cool,
                    title: "Cool",
                    icon: "snowflake"
                )
                remoteSemanticButton(
                    .heat,
                    title: "Heat",
                    icon: "sun.max.fill"
                )
                remoteSemanticButton(
                    .dry,
                    title: "Dry",
                    icon: "drop.fill"
                )
                remoteSemanticButton(
                    .sleep,
                    title: "Sleep",
                    icon: "moon.fill"
                )
                remoteSemanticButton(
                    .timer,
                    title: "Timer",
                    icon: "timer"
                )
                remoteSemanticButton(
                    .auto,
                    title: "Auto",
                    icon: "a.circle.fill"
                )
            }
        }
        .padding()
        .irCard(cornerRadius: 26)
    }

    private var projectorControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                RemoteFunctionButton(
                    title: "Source",
                    systemImage: "rectangle.on.rectangle",
                    button: matcher.button(for: .input),
                    transmitter: transmitter
                )

                Spacer()

                RemotePowerButton(
                    button: matcher.primaryPowerButton(),
                    transmitter: transmitter
                )

                Spacer()

                RemoteFunctionButton(
                    title: "Mute",
                    systemImage: "speaker.slash.fill",
                    button: matcher.button(for: .mute),
                    transmitter: transmitter
                )
            }

            RemoteDPad(
                matcher: matcher,
                transmitter: transmitter
            )

            HStack(spacing: 10) {
                remoteSemanticButton(
                    .back,
                    title: "Atrás",
                    icon: "arrow.uturn.backward"
                )
                remoteSemanticButton(
                    .menu,
                    title: "Menú",
                    icon: "list.bullet"
                )
                remoteSemanticButton(
                    .freeze,
                    title: "Freeze",
                    icon: "pause.rectangle.fill"
                )
            }
        }
        .padding()
        .irCard(cornerRadius: 26)
    }

    private var setTopBoxControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                RemoteFunctionButton(
                    title: "Input",
                    systemImage: "rectangle.on.rectangle",
                    button: matcher.button(for: .input),
                    transmitter: transmitter
                )

                Spacer()

                RemotePowerButton(
                    button: matcher.primaryPowerButton(),
                    transmitter: transmitter
                )

                Spacer()

                RemoteFunctionButton(
                    title: "Mute",
                    systemImage: "speaker.slash.fill",
                    button: matcher.button(for: .mute),
                    transmitter: transmitter
                )
            }

            RemoteDPad(
                matcher: matcher,
                transmitter: transmitter
            )

            HStack(spacing: 10) {
                remoteSemanticButton(
                    .back,
                    title: "Atrás",
                    icon: "arrow.uturn.backward"
                )
                remoteSemanticButton(
                    .home,
                    title: "Inicio",
                    icon: "house.fill"
                )
                remoteSemanticButton(
                    .menu,
                    title: "Menú",
                    icon: "list.bullet"
                )
            }

            HStack(spacing: 10) {
                remoteSemanticButton(
                    .guide,
                    title: "Guía",
                    icon: "list.bullet.rectangle"
                )
                remoteSemanticButton(
                    .info,
                    title: "Info",
                    icon: "info.circle"
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 48) {
                    volumeRocker
                    channelRocker
                }

                VStack(spacing: 12) {
                    volumeRocker
                    channelRocker
                }
            }

            if hasPlaybackControls {
                playbackControls
            }

            if hasNumberPad {
                numberPad
            }
        }
        .padding()
        .irCard(cornerRadius: 26)
    }

    private var fanControls: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                RemoteFunctionButton(
                    title: "Mode",
                    systemImage: "arrow.triangle.2.circlepath",
                    button: matcher.button(for: .mode),
                    transmitter: transmitter
                )

                Spacer()

                RemotePowerButton(
                    button: matcher.primaryPowerButton(),
                    transmitter: transmitter
                )

                Spacer()

                RemoteFunctionButton(
                    title: "Luz",
                    systemImage: "lightbulb.fill",
                    button: matcher.button(for: .light),
                    transmitter: transmitter
                )
            }

            HStack(spacing: 12) {
                RemoteTemperatureButton(
                    title: "VEL −",
                    systemImage: "minus",
                    button: matcher.button(for: .speedDown),
                    transmitter: transmitter
                )

                Image(systemName: "wind")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(IRCyberPalette.cyan)
                    .frame(minWidth: 64)

                RemoteTemperatureButton(
                    title: "VEL +",
                    systemImage: "plus",
                    button: matcher.button(for: .speedUp),
                    transmitter: transmitter
                )
            }

            LazyVGrid(columns: columns, spacing: 10) {
                remoteSemanticButton(
                    .swing,
                    title: "Oscilar",
                    icon: "arrow.left.and.right"
                )
                remoteSemanticButton(
                    .timer,
                    title: "Timer",
                    icon: "timer"
                )
            }
        }
        .padding()
        .irCard(cornerRadius: 26)
    }

    private var discPlayerControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                RemoteFunctionButton(
                    title: "Eject",
                    systemImage: "eject.fill",
                    button: matcher.button(for: .eject),
                    transmitter: transmitter
                )

                Spacer()

                RemotePowerButton(
                    button: matcher.primaryPowerButton(),
                    transmitter: transmitter
                )

                Spacer()

                RemoteFunctionButton(
                    title: "Menú",
                    systemImage: "list.bullet",
                    button: matcher.button(for: .menu),
                    transmitter: transmitter
                )
            }

            RemoteDPad(
                matcher: matcher,
                transmitter: transmitter
            )

            HStack(spacing: 10) {
                remoteSemanticButton(
                    .back,
                    title: "Atrás",
                    icon: "arrow.uturn.backward"
                )
                remoteSemanticButton(
                    .info,
                    title: "Info",
                    icon: "info.circle"
                )
            }

            if hasPlaybackControls {
                playbackControls
            }

            if hasNumberPad {
                numberPad
            }
        }
        .padding()
        .irCard(cornerRadius: 26)
    }

    private var audioControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                RemoteFunctionButton(
                    title: "Input",
                    systemImage: "rectangle.on.rectangle",
                    button: matcher.button(for: .input),
                    transmitter: transmitter
                )

                Spacer()

                RemotePowerButton(
                    button: matcher.primaryPowerButton(),
                    transmitter: transmitter
                )

                Spacer()

                RemoteFunctionButton(
                    title: "Mute",
                    systemImage: "speaker.slash.fill",
                    button: matcher.button(for: .mute),
                    transmitter: transmitter
                )
            }

            HStack(spacing: 28) {
                volumeRocker

                VStack(spacing: 10) {
                    remoteSemanticButton(
                        .mode,
                        title: "Mode",
                        icon: "waveform"
                    )
                    remoteSemanticButton(
                        .menu,
                        title: "Menú",
                        icon: "list.bullet"
                    )
                }
            }

            if [
                RemoteSemantic.up,
                .down,
                .left,
                .right,
                .ok,
            ].contains(where: { matcher.button(for: $0) != nil }) {
                RemoteDPad(
                    matcher: matcher,
                    transmitter: transmitter
                )
            }

            if matcher.button(for: .back) != nil {
                remoteSemanticButton(
                    .back,
                    title: "Atrás",
                    icon: "arrow.uturn.backward"
                )
            }

            if hasPlaybackControls {
                playbackControls
            }
        }
        .padding()
        .irCard(cornerRadius: 26)
    }

    private var cameraControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                RemoteFunctionButton(
                    title: "Zoom −",
                    systemImage: "minus.magnifyingglass",
                    button: matcher.button(for: .zoomOut),
                    transmitter: transmitter
                )

                RemotePowerButton(
                    button: matcher.primaryPowerButton(),
                    transmitter: transmitter
                )

                RemoteFunctionButton(
                    title: "Zoom +",
                    systemImage: "plus.magnifyingglass",
                    button: matcher.button(for: .zoomIn),
                    transmitter: transmitter
                )
            }

            Button {
                send(.shutter)
            } label: {
                Label("DISPARAR", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(IRCyberPalette.magenta)
            .disabled(matcher.button(for: .shutter) == nil)
            .accessibilityLabel("Disparar cámara")

            if [
                RemoteSemantic.up,
                .down,
                .left,
                .right,
                .ok,
            ].contains(where: { matcher.button(for: $0) != nil }) {
                RemoteDPad(
                    matcher: matcher,
                    transmitter: transmitter
                )
            }

            HStack(spacing: 10) {
                remoteSemanticButton(
                    .back,
                    title: "Atrás",
                    icon: "arrow.uturn.backward"
                )
                remoteSemanticButton(
                    .menu,
                    title: "Menú",
                    icon: "list.bullet"
                )
            }
        }
        .padding()
        .irCard(cornerRadius: 26)
    }

    private var playbackControls: some View {
        HStack(spacing: 8) {
            compactSemanticButton(
                .rewind,
                title: "Retroceder",
                icon: "backward.fill"
            )

            if matcher.button(for: .playPause) != nil {
                compactSemanticButton(
                    .playPause,
                    title: "Reproducir o pausar",
                    icon: "playpause.fill"
                )
            } else {
                compactSemanticButton(
                    .play,
                    title: "Reproducir",
                    icon: "play.fill"
                )
                compactSemanticButton(
                    .pause,
                    title: "Pausar",
                    icon: "pause.fill"
                )
            }

            compactSemanticButton(
                .stop,
                title: "Detener",
                icon: "stop.fill"
            )
            compactSemanticButton(
                .fastForward,
                title: "Avanzar",
                icon: "forward.fill"
            )
        }
    }

    private var extraControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    "Más controles",
                    systemImage: "square.grid.2x2.fill"
                )
                .font(.headline)

                Spacer()

                Text("\(extraButtons.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(extraButtons) { button in
                    Button {
                        transmitter.send(code: button.code)
                    } label: {
                        VStack(spacing: 6) {
                            Image(
                                systemName:
                                    RemoteButtonIcon
                                    .systemImage(
                                        for: button.name
                                    )
                            )
                            .font(.title3)

                            Text(button.name)
                                .font(.caption.bold())
                                .lineLimit(
                                    dynamicTypeSize.isAccessibilitySize
                                    ? nil
                                    : 2
                                )
                                .multilineTextAlignment(.center)
                        }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 72
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(IRCyberPalette.cyan)
                }
            }
        }
        .padding()
        .irCard(cornerRadius: 20)
    }

    private var hasPlaybackControls: Bool {
        [
            RemoteSemantic.rewind,
            .play,
            .pause,
            .playPause,
            .stop,
            .fastForward,
        ].contains {
            matcher.button(for: $0) != nil
        }
    }

    private var volumeRocker: some View {
        RemoteVerticalRocker(
            title: "VOL",
            up: matcher.button(for: .volumeUp),
            down: matcher.button(for: .volumeDown),
            transmitter: transmitter,
            upLabel: "Subir volumen",
            downLabel: "Bajar volumen"
        )
    }

    private var channelRocker: some View {
        RemoteVerticalRocker(
            title: "CH",
            up: matcher.button(for: .channelUp),
            down: matcher.button(for: .channelDown),
            transmitter: transmitter,
            upLabel: "Canal siguiente",
            downLabel: "Canal anterior"
        )
    }

    private var hasNumberPad: Bool {
        RemoteSemantic.numberSemantics.contains {
            matcher.button(for: $0) != nil
        }
    }

    private var numberPad: some View {
        VStack(spacing: 8) {
            Text("TECLADO")
                .font(.caption.monospaced().bold())
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(
                    repeating:
                        GridItem(.flexible(), spacing: 8),
                    count: 3
                ),
                spacing: 8
            ) {
                ForEach(RemoteSemantic.numberSemantics) { semantic in
                    let number = semantic.numberLabel ?? ""

                    Button {
                        send(semantic)
                    } label: {
                        Text(number)
                            .font(.title3.monospacedDigit().bold())
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 48
                            )
                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        matcher.button(for: semantic)
                            == nil
                    )
                    .accessibilityLabel(
                        "Número \(number)"
                    )
                }
            }
        }
    }

    private func remoteSemanticButton(
        _ semantic: RemoteSemantic,
        title: String,
        icon: String
    ) -> some View {
        RemoteFunctionButton(
            title: title,
            systemImage: icon,
            button: matcher.button(for: semantic),
            transmitter: transmitter
        )
    }

    private func compactSemanticButton(
        _ semantic: RemoteSemantic,
        title: String,
        icon: String
    ) -> some View {
        Button {
            send(semantic)
        } label: {
            Image(systemName: icon)
                .font(.headline)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 44
                )
        }
        .buttonStyle(.bordered)
        .disabled(matcher.button(for: semantic) == nil)
        .accessibilityLabel(title)
    }

    private func send(
        _ semantic: RemoteSemantic
    ) {
        guard let button = matcher.button(for: semantic) else {
            IRHaptics.error()
            return
        }

        transmitter.send(code: button.code)
    }
}

private struct RemotePowerButton: View {
    var button: CustomRemoteButton?
    var transmitter: IRTransmitter?
    var customAction: (() -> Void)?

    init(
        button: CustomRemoteButton? = nil,
        transmitter: IRTransmitter? = nil
    ) {
        self.button = button
        self.transmitter = transmitter
        customAction = nil
    }

    init(action: @escaping () -> Void) {
        button = nil
        transmitter = nil
        customAction = action
    }

    var body: some View {
        Button {
            if let customAction {
                customAction()
            } else if
                let button,
                let transmitter
            {
                transmitter.send(code: button.code)
            }
        } label: {
            Image(systemName: "power")
                .font(.system(size: 28, weight: .bold))
                .frame(width: 68, height: 68)
        }
        .buttonStyle(
            IRCyberActionButtonStyle(
                tint: IRCyberPalette.signalRed
            )
        )
        .clipShape(Circle())
        .disabled(
            customAction == nil
            && button == nil
        )
        .accessibilityLabel("Encender o apagar")
    }
}

private struct RemoteFunctionButton: View {
    let title: String
    let systemImage: String
    let button: CustomRemoteButton?
    @ObservedObject var transmitter: IRTransmitter

    var body: some View {
        Button {
            guard let button else {
                return
            }

            transmitter.send(code: button.code)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.headline)

                Text(title)
                    .font(.caption2.bold())
                    .lineLimit(1)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 48
            )
        }
        .buttonStyle(.bordered)
        .tint(IRCyberPalette.cyan)
        .disabled(button == nil)
        .accessibilityLabel(title)
        .accessibilityHint(
            button == nil
            ? "No disponible en este mando"
            : "Envía la señal infrarroja"
        )
    }
}

private struct RemoteVerticalRocker: View {
    let title: String
    let up: CustomRemoteButton?
    let down: CustomRemoteButton?
    @ObservedObject var transmitter: IRTransmitter
    let upLabel: String
    let downLabel: String

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.caption2.monospaced().bold())
                .foregroundStyle(.secondary)
                .padding(.bottom, 5)

            Button {
                if let up {
                    transmitter.send(code: up.code)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.headline.bold())
                    .frame(width: 48, height: 52)
            }
            .buttonStyle(.bordered)
            .disabled(up == nil)
            .accessibilityLabel(upLabel)

            Button {
                if let down {
                    transmitter.send(code: down.code)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.headline.bold())
                    .frame(width: 48, height: 52)
            }
            .buttonStyle(.bordered)
            .disabled(down == nil)
            .accessibilityLabel(downLabel)
        }
    }
}

private struct RemoteTemperatureButton: View {
    let title: String
    let systemImage: String
    let button: CustomRemoteButton?
    @ObservedObject var transmitter: IRTransmitter

    var body: some View {
        Button {
            if let button {
                transmitter.send(code: button.code)
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2.bold())

                Text(title)
                    .font(.caption.monospaced().bold())
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 72
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(IRCyberPalette.cyan.opacity(0.75))
        .disabled(button == nil)
        .accessibilityLabel(title)
    }
}

private struct RemoteDPad: View {
    let matcher: RemoteButtonMatcher
    @ObservedObject var transmitter: IRTransmitter

    var body: some View {
        Grid(
            horizontalSpacing: 4,
            verticalSpacing: 4
        ) {
            GridRow {
                Color.clear
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)

                dPadButton(
                    .up,
                    icon: "chevron.up",
                    label: "Arriba"
                )

                Color.clear
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
            }

            GridRow {
                dPadButton(
                    .left,
                    icon: "chevron.left",
                    label: "Izquierda"
                )

                dPadButton(
                    .ok,
                    icon: nil,
                    label: "OK"
                )

                dPadButton(
                    .right,
                    icon: "chevron.right",
                    label: "Derecha"
                )
            }

            GridRow {
                Color.clear
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)

                dPadButton(
                    .down,
                    icon: "chevron.down",
                    label: "Abajo"
                )

                Color.clear
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
            }
        }
        .padding(8)
        .background(
            Color.white.opacity(0.025),
            in: Circle()
        )
        .overlay(
            Circle()
                .stroke(
                    IRCyberPalette.cyan.opacity(0.18),
                    lineWidth: 0.8
                )
        )
    }

    private func dPadButton(
        _ semantic: RemoteSemantic,
        icon: String?,
        label: String
    ) -> some View {
        let button = matcher.button(for: semantic)

        return Button {
            if let button {
                transmitter.send(code: button.code)
            }
        } label: {
            Group {
                if let icon {
                    Image(systemName: icon)
                        .font(.headline.bold())
                } else {
                    Text("OK")
                        .font(.caption.bold())
                }
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(.bordered)
        .tint(
            semantic == .ok
            ? IRCyberPalette.magenta
            : IRCyberPalette.cyan
        )
        .disabled(button == nil)
        .accessibilityLabel(label)
    }
}

private struct RemoteButtonMatcher {
    let buttons: [CustomRemoteButton]

    func primaryPowerButton() -> CustomRemoteButton? {
        if let toggle = button(for: .power) {
            return toggle
        }

        let fallbackAliases: Set<String> = [
            "power on", "power off", "on", "off",
            "encender solo", "apagar solo",
        ]

        return buttons.first {
            fallbackAliases.contains(normalize($0.name))
        }
    }

    func button(
        for semantic: RemoteSemantic
    ) -> CustomRemoteButton? {
        let candidates = buttons.map {
            ($0, normalize($0.name))
        }

        if let exact = candidates.first(
            where: {
                semantic.exactAliases.contains($0.1)
            }
        ) {
            return exact.0
        }

        if let partial = candidates.first(
            where: { candidate in
                semantic.containsAliases.contains {
                    candidate.1.contains($0)
                }
            }
        ) {
            return partial.0
        }

        return nil
    }

    private func normalize(
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

private enum RemoteSemantic: String, Identifiable {
    case power
    case input
    case mute
    case volumeUp
    case volumeDown
    case channelUp
    case channelDown
    case up
    case down
    case left
    case right
    case ok
    case back
    case home
    case menu
    case rewind
    case play
    case pause
    case playPause
    case stop
    case fastForward
    case zero
    case one
    case two
    case three
    case four
    case five
    case six
    case seven
    case eight
    case nine
    case temperatureUp
    case temperatureDown
    case mode
    case fan
    case swing
    case cool
    case heat
    case dry
    case sleep
    case timer
    case auto
    case freeze
    case eject
    case speedUp
    case speedDown
    case light
    case shutter
    case zoomIn
    case zoomOut
    case guide
    case info

    var id: String { rawValue }

    static let televisionStandard: [RemoteSemantic] = [
        .power, .input, .mute,
        .volumeUp, .volumeDown,
        .channelUp, .channelDown,
        .up, .down, .left, .right, .ok,
        .back, .home, .menu, .guide, .info,
        .rewind, .play, .pause, .playPause, .stop, .fastForward,
    ] + numberSemantics

    static let airConditionerStandard: [RemoteSemantic] = [
        .power, .temperatureUp, .temperatureDown,
        .mode, .fan, .swing, .cool, .heat,
        .dry, .sleep, .timer, .auto,
    ]

    static let projectorStandard: [RemoteSemantic] = [
        .power, .input, .mute,
        .up, .down, .left, .right, .ok,
        .back, .menu, .freeze,
    ]

    static let setTopBoxStandard: [RemoteSemantic] = [
        .power, .input, .mute,
        .volumeUp, .volumeDown,
        .channelUp, .channelDown,
        .up, .down, .left, .right, .ok,
        .back, .home, .menu, .guide, .info,
        .rewind, .play, .pause, .playPause, .stop, .fastForward,
    ] + numberSemantics

    static let fanStandard: [RemoteSemantic] = [
        .power, .mode, .speedUp, .speedDown,
        .swing, .timer, .light,
    ]

    static let discPlayerStandard: [RemoteSemantic] = [
        .power, .eject,
        .up, .down, .left, .right, .ok,
        .back, .menu, .info,
        .rewind, .play, .pause, .playPause, .stop, .fastForward,
    ] + numberSemantics

    static let audioStandard: [RemoteSemantic] = [
        .power, .input, .mute,
        .volumeUp, .volumeDown,
        .mode, .menu,
        .up, .down, .left, .right, .ok, .back,
        .rewind, .play, .pause, .playPause, .stop, .fastForward,
    ]

    static let cameraStandard: [RemoteSemantic] = [
        .power, .shutter, .zoomIn, .zoomOut,
        .up, .down, .left, .right, .ok,
        .back, .menu,
    ]

    static let numberSemantics: [RemoteSemantic] = [
        .one, .two, .three,
        .four, .five, .six,
        .seven, .eight, .nine,
        .zero,
    ]

    var numberLabel: String? {
        switch self {
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        default: return nil
        }
    }

    var exactAliases: Set<String> {
        switch self {
        case .power:
            return [
                "power", "power toggle", "power on off", "pwr", "on off",
                "standby", "encender", "apagar",
            ]
        case .input:
            return [
                "input", "input select", "source", "source select",
                "av", "tv av", "entrada",
            ]
        case .mute:
            return ["mute", "silence", "silencio"]
        case .volumeUp:
            return [
                "vol plus", "volume plus", "volume up", "vol up",
                "subir volumen", "vup",
            ]
        case .volumeDown:
            return [
                "vol minus", "volume minus", "volume down",
                "vol down", "bajar volumen", "vdown",
            ]
        case .channelUp:
            return [
                "ch plus", "channel plus", "channel up", "ch up",
                "program plus", "prog plus", "canal plus",
            ]
        case .channelDown:
            return [
                "ch minus", "channel minus", "channel down",
                "ch down", "program minus", "prog minus", "canal menos",
            ]
        case .up:
            return ["up", "arrow up", "cursor up", "arriba"]
        case .down:
            return ["down", "arrow down", "cursor down", "abajo"]
        case .left:
            return ["left", "arrow left", "cursor left", "izquierda"]
        case .right:
            return ["right", "arrow right", "cursor right", "derecha"]
        case .ok:
            return ["ok", "enter", "select", "confirm", "center"]
        case .back:
            return ["back", "return", "atras", "exit"]
        case .home:
            return ["home", "smart home", "portal", "inicio"]
        case .menu:
            return ["menu", "settings", "options", "ajustes"]
        case .rewind:
            return ["rewind", "rev", "media rewind"]
        case .play:
            return ["play", "media play"]
        case .pause:
            return ["pause", "media pause"]
        case .playPause:
            return ["play pause", "playpause", "play pause toggle"]
        case .stop:
            return ["stop", "media stop"]
        case .fastForward:
            return ["fast forward", "forward", "ff", "media forward"]
        case .zero:
            return ["0", "num 0", "digit 0", "number 0"]
        case .one:
            return ["1", "num 1", "digit 1", "number 1"]
        case .two:
            return ["2", "num 2", "digit 2", "number 2"]
        case .three:
            return ["3", "num 3", "digit 3", "number 3"]
        case .four:
            return ["4", "num 4", "digit 4", "number 4"]
        case .five:
            return ["5", "num 5", "digit 5", "number 5"]
        case .six:
            return ["6", "num 6", "digit 6", "number 6"]
        case .seven:
            return ["7", "num 7", "digit 7", "number 7"]
        case .eight:
            return ["8", "num 8", "digit 8", "number 8"]
        case .nine:
            return ["9", "num 9", "digit 9", "number 9"]
        case .temperatureUp:
            return [
                "temp plus", "temperature plus", "temp up",
                "temperature up", "subir temperatura",
            ]
        case .temperatureDown:
            return [
                "temp minus", "temperature minus", "temp down",
                "temperature down", "bajar temperatura",
            ]
        case .mode:
            return ["mode", "modo"]
        case .fan:
            return ["fan", "fan speed", "ventilador"]
        case .swing:
            return ["swing", "oscillate", "oscilacion"]
        case .cool:
            return ["cool", "cold", "frio"]
        case .heat:
            return ["heat", "hot", "calor"]
        case .dry:
            return ["dry", "dehumidify", "deshumidificar"]
        case .sleep:
            return ["sleep", "night", "noche"]
        case .timer:
            return ["timer", "clock", "temporizador"]
        case .auto:
            return ["auto", "automatic", "automatico"]
        case .freeze:
            return ["freeze", "still", "congelar"]
        case .eject:
            return ["eject", "open close", "open", "close", "expulsar"]
        case .speedUp:
            return [
                "speed plus", "speed up", "fan speed plus", "fan speed up",
                "velocidad plus", "subir velocidad",
            ]
        case .speedDown:
            return [
                "speed minus", "speed down", "fan speed minus", "fan speed down",
                "velocidad menos", "bajar velocidad",
            ]
        case .light:
            return ["light", "lamp", "led", "luz"]
        case .shutter:
            return ["shutter", "shoot", "capture", "photo", "foto", "disparar"]
        case .zoomIn:
            return ["zoom plus", "zoom in", "tele", "acercar"]
        case .zoomOut:
            return ["zoom minus", "zoom out", "wide", "alejar"]
        case .guide:
            return ["guide", "epg", "tv guide", "guia"]
        case .info:
            return ["info", "information", "display", "informacion"]
        }
    }

    var containsAliases: [String] {
        switch self {
        case .power:
            return []
        case .input:
            return []
        case .mute:
            return []
        case .volumeUp:
            return ["volume up", "vol up", "vol plus", "volume plus"]
        case .volumeDown:
            return ["volume down", "vol down", "vol minus", "volume minus"]
        case .channelUp:
            return ["channel up", "ch up", "ch plus", "channel plus"]
        case .channelDown:
            return ["channel down", "ch down", "ch minus", "channel minus"]
        case .home:
            return []
        case .menu:
            return []
        case .back:
            return []
        case .rewind:
            return []
        case .play:
            return []
        case .pause:
            return []
        case .playPause:
            return ["play pause", "playpause"]
        case .fastForward:
            return ["fast forward"]
        case .temperatureUp:
            return ["temp up", "temp plus", "temperature up"]
        case .temperatureDown:
            return ["temp down", "temp minus", "temperature down"]
        case .fan:
            return []
        case .swing:
            return []
        case .freeze:
            return []
        default:
            return []
        }
    }
}

enum RemoteButtonIcon {
    static func isPowerName(
        _ name: String
    ) -> Bool {
        let value = name
            .folding(
                options: [
                    .diacriticInsensitive,
                    .caseInsensitive,
                ],
                locale: .current
            )
            .lowercased()

        return value.contains("power")
            || value.contains("standby")
            || value.contains("encend")
            || value.contains("apag")
    }

    static func systemImage(
        for name: String
    ) -> String {
        let value = name.lowercased()

        if isPowerName(name) {
            return "power"
        }

        if value.contains("vol") {
            if value.contains("+")
                || value.contains("up")
            {
                return "speaker.plus.fill"
            }

            if value.contains("-")
                || value.contains("down")
            {
                return "speaker.minus.fill"
            }
        }

        if value.contains("mute") {
            return "speaker.slash.fill"
        }

        if value.contains("home") {
            return "house.fill"
        }

        if value.contains("channel")
            || value.contains("ch+")
            || value.contains("ch-")
        {
            return "chevron.up.chevron.down"
        }

        if value == "up"
            || value.contains("arriba")
        {
            return "chevron.up"
        }

        if value == "down"
            || value.contains("abajo")
        {
            return "chevron.down"
        }

        if value == "left"
            || value.contains("izquierda")
        {
            return "chevron.left"
        }

        if value == "right"
            || value.contains("derecha")
        {
            return "chevron.right"
        }

        if value == "ok"
            || value.contains("enter")
            || value.contains("select")
        {
            return "checkmark.circle.fill"
        }

        if value.contains("back")
            || value.contains("return")
        {
            return "arrow.uturn.backward"
        }

        if value.contains("menu") {
            return "list.bullet"
        }

        if value.contains("input")
            || value.contains("source")
        {
            return "rectangle.on.rectangle"
        }

        if value.contains("temp") {
            return "thermometer.medium"
        }

        if value.contains("eject")
            || value.contains("open close")
        {
            return "eject.fill"
        }

        if value.contains("zoom") {
            if value.contains("+")
                || value.contains("in")
            {
                return "plus.magnifyingglass"
            }

            if value.contains("-")
                || value.contains("out")
            {
                return "minus.magnifyingglass"
            }
        }

        if value.contains("shutter")
            || value.contains("capture")
            || value.contains("photo")
            || value.contains("foto")
        {
            return "camera.fill"
        }

        if value.contains("light")
            || value.contains("lamp")
            || value == "led"
            || value.contains("luz")
        {
            return "lightbulb.fill"
        }

        if value.contains("guide")
            || value == "epg"
        {
            return "list.bullet.rectangle"
        }

        if value == "info"
            || value.contains("information")
        {
            return "info.circle"
        }

        if value.contains("speed")
            || value.contains("velocidad")
        {
            return "wind"
        }

        if value.contains("fan") {
            return "fanblades.fill"
        }

        if value.contains("play")
            || value.contains("pause")
        {
            return "playpause.fill"
        }

        if value.contains("rewind") {
            return "backward.fill"
        }

        if value.contains("forward") {
            return "forward.fill"
        }

        if value.contains("stop") {
            return "stop.fill"
        }

        if value.contains("freeze") {
            return "pause.rectangle.fill"
        }

        return "dot.radiowaves.left.and.right"
    }
}
