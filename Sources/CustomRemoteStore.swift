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

    init(
        id: UUID = UUID(),
        name: String,
        category: IRDeviceCategory,
        buttons: [CustomRemoteButton],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.buttons = buttons
        self.createdAt = createdAt
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
    }

    func createImported(
        name: String,
        category: IRDeviceCategory,
        signals: [ImportedIRSignal]
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
                buttons: buttons
            )
        )

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
