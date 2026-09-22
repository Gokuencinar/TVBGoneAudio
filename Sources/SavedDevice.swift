import Foundation

struct SavedIRDevice: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let category: IRDeviceCategory
    let codeID: String
    let codeLabel: String
    let createdAt: Date

    // Optional embedded waveform keeps learned/custom codes usable even
    // when they do not exist in a generated database. These are optional
    // for backward compatibility with devices saved by v6.
    let embeddedCarrierHz: Int?
    let embeddedDurationsMicros: [UInt32]?

    init(
        id: UUID = UUID(),
        name: String,
        category: IRDeviceCategory,
        code: IRCode,
        codeLabel: String? = nil,
        createdAt: Date = Date(),
        embedCode: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.codeID = code.id
        self.codeLabel =
            codeLabel ?? code.displayName
        self.createdAt = createdAt

        if embedCode
            || code.id.hasPrefix("learned:")
        {
            embeddedCarrierHz =
                code.carrierHz
            embeddedDurationsMicros =
                code.durationsMicros
        } else {
            embeddedCarrierHz = nil
            embeddedDurationsMicros = nil
        }
    }
}

@MainActor
final class SavedDeviceStore: ObservableObject {
    @Published private(set)
    var devices: [SavedIRDevice] = []

    private let defaultsKey =
        "savedIRDevices.v1"

    init() {
        load()
    }

    func devices(
        for category: IRDeviceCategory
    ) -> [SavedIRDevice] {
        devices.filter {
            $0.category == category
        }
    }

    func add(
        name: String,
        category: IRDeviceCategory,
        code: IRCode,
        codeLabel: String? = nil,
        embedCode: Bool = false
    ) {
        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let finalName =
            cleanName.isEmpty
            ? category.defaultDeviceName
            : cleanName

        let replacement =
            SavedIRDevice(
                name: finalName,
                category: category,
                code: code,
                codeLabel: codeLabel,
                embedCode: embedCode
            )

        if
            let existingIndex =
                devices.firstIndex(
                    where: {
                        $0.category
                            == category
                        && $0.codeID
                            == code.id
                    }
                )
        {
            devices[existingIndex] =
                replacement
        } else {
            devices.append(replacement)
        }

        save()
        IRHaptics.success()
    }

    func replaceAll(
        _ newDevices: [SavedIRDevice]
    ) {
        devices = newDevices
        save()
    }

    func remove(
        _ device: SavedIRDevice
    ) {
        devices.removeAll {
            $0.id == device.id
        }

        save()
    }

    func code(
        for device: SavedIRDevice
    ) -> IRCode? {
        if
            let carrier =
                device.embeddedCarrierHz,
            let durations =
                device.embeddedDurationsMicros
        {
            return IRCode(
                id: device.codeID,
                carrierHz: carrier,
                durationsMicros: durations
            )
        }

        return IRCodeCatalog.code(
            id: device.codeID,
            category: device.category
        )
    }

    private func load() {
        guard
            let data =
                UserDefaults.standard.data(
                    forKey: defaultsKey
                ),
            let decoded =
                try? JSONDecoder().decode(
                    [SavedIRDevice].self,
                    from: data
                )
        else {
            devices = []
            return
        }

        devices = decoded
    }

    private func save() {
        guard
            let data =
                try? JSONEncoder().encode(
                    devices
                )
        else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: defaultsKey
        )
    }
}
