import Foundation

struct CustomRemoteButton: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let carrierHz: Int
    let durationsMicros: [UInt32]

    init(
        id: UUID = UUID(),
        name: String,
        code: IRCode
    ) {
        self.id = id
        self.name = name
        carrierHz = code.carrierHz
        durationsMicros =
            code.durationsMicros
    }

    var code: IRCode {
        IRCode(
            id: "remote:\(id.uuidString)",
            carrierHz: carrierHz,
            durationsMicros:
                durationsMicros
        )
    }
}

struct CustomRemote: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var category: IRDeviceCategory
    var buttons: [CustomRemoteButton]
    var createdAt: Date
    var brand: String?
    var model: String?
    var sourceDescription: String?
    var sourcePath: String?
    var isFavorite: Bool
    var lastUsedAt: Date?
    var useCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        category: IRDeviceCategory,
        buttons: [CustomRemoteButton],
        createdAt: Date = Date(),
        brand: String? = nil,
        model: String? = nil,
        sourceDescription: String? = nil,
        sourcePath: String? = nil,
        isFavorite: Bool = false,
        lastUsedAt: Date? = nil,
        useCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.buttons = buttons
        self.createdAt = createdAt
        self.brand = brand
        self.model = model
        self.sourceDescription = sourceDescription
        self.sourcePath = sourcePath
        self.isFavorite = isFavorite
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case buttons
        case createdAt
        case brand
        case model
        case sourceDescription
        case sourcePath
        case isFavorite
        case lastUsedAt
        case useCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(IRDeviceCategory.self, forKey: .category)
        buttons = try container.decode([CustomRemoteButton].self, forKey: .buttons)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        sourceDescription = try container.decodeIfPresent(String.self, forKey: .sourceDescription)
        sourcePath = try container.decodeIfPresent(String.self, forKey: .sourcePath)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        useCount = try container.decodeIfPresent(Int.self, forKey: .useCount) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(buttons, forKey: .buttons)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(brand, forKey: .brand)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(sourceDescription, forKey: .sourceDescription)
        try container.encodeIfPresent(sourcePath, forKey: .sourcePath)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try container.encode(useCount, forKey: .useCount)
    }
}

@MainActor
final class CustomRemoteStore: ObservableObject {
    @Published private(set)
    var remotes: [CustomRemote] = []

    private let defaultsKey =
        "customIRRemotes.v1"

    init() {
        load()
    }

    func create(
        name: String,
        category: IRDeviceCategory,
        signals: [LearnedIRSignal]
    ) {
        let clean =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !signals.isEmpty else {
            return
        }

        let buttons =
            signals.map {
                CustomRemoteButton(
                    name: $0.name,
                    code: $0.code
                )
            }

        remotes.append(
            CustomRemote(
                name:
                    clean.isEmpty
                    ? "Mi mando"
                    : clean,
                category: category,
                buttons: buttons
            )
        )

        save()
        IRHaptics.success()
    }

    func createImported(
        name: String,
        category: IRDeviceCategory,
        signals: [ImportedIRSignal],
        brand: String? = nil,
        model: String? = nil,
        sourceDescription: String? = nil,
        sourcePath: String? = nil
    ) {
        let clean =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !signals.isEmpty else {
            return
        }

        let buttons =
            signals.map {
                CustomRemoteButton(
                    name: $0.name,
                    code: $0.code
                )
            }

        remotes.append(
            CustomRemote(
                name:
                    clean.isEmpty
                    ? "Mando online"
                    : clean,
                category: category,
                buttons: buttons,
                brand: brand,
                model: model,
                sourceDescription: sourceDescription,
                sourcePath: sourcePath
            )
        )

        save()
        IRHaptics.success()
    }

    func replaceAll(
        _ newRemotes: [CustomRemote]
    ) {
        remotes = newRemotes
        save()
    }

    func remove(
        _ remote: CustomRemote
    ) {
        remotes.removeAll {
            $0.id == remote.id
        }

        save()
    }

    func toggleFavorite(
        _ remote: CustomRemote
    ) {
        guard
            let index = remotes.firstIndex(
                where: { $0.id == remote.id }
            )
        else {
            return
        }

        remotes[index].isFavorite.toggle()
        save()
        IRHaptics.tap()
    }

    func recordUse(
        _ remote: CustomRemote
    ) {
        guard
            let index = remotes.firstIndex(
                where: { $0.id == remote.id }
            )
        else {
            return
        }

        remotes[index].lastUsedAt = Date()
        remotes[index].useCount += 1
        save()
    }

    func add(
        signal: LearnedIRSignal,
        to remote: CustomRemote
    ) {
        guard
            let index =
                remotes.firstIndex(
                    where: {
                        $0.id == remote.id
                    }
                )
        else {
            return
        }

        let alreadyExists =
            remotes[index].buttons
            .contains {
                $0.name
                    .caseInsensitiveCompare(
                        signal.name
                    ) == .orderedSame
            }

        if !alreadyExists {
            remotes[index].buttons.append(
                CustomRemoteButton(
                    name: signal.name,
                    code: signal.code
                )
            )

            save()
        }
    }

    func removeButton(
        _ button: CustomRemoteButton,
        from remote: CustomRemote
    ) {
        guard
            let index =
                remotes.firstIndex(
                    where: {
                        $0.id == remote.id
                    }
                )
        else {
            return
        }

        remotes[index].buttons
            .removeAll {
                $0.id == button.id
            }

        save()
    }

    private func load() {
        guard
            let data =
                UserDefaults.standard.data(
                    forKey: defaultsKey
                ),
            let decoded =
                try? JSONDecoder().decode(
                    [CustomRemote].self,
                    from: data
                )
        else {
            remotes = []
            return
        }

        remotes = decoded
    }

    private func save() {
        guard
            let data =
                try? JSONEncoder().encode(
                    remotes
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
