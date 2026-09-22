import Foundation

struct LearnedIRSignal: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var category: IRDeviceCategory
    var carrierHz: Int
    var durationsMicros: [UInt32]
    var sampleRate: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: IRDeviceCategory,
        carrierHz: Int,
        durationsMicros: [UInt32],
        sampleRate: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.carrierHz = carrierHz
        self.durationsMicros = durationsMicros
        self.sampleRate = sampleRate
        self.createdAt = createdAt
    }

    var code: IRCode {
        IRCode(
            id: "learned:\(id.uuidString)",
            carrierHz: carrierHz,
            durationsMicros: durationsMicros
        )
    }
}

@MainActor
final class LearnedIRStore: ObservableObject {
    @Published private(set)
    var signals: [LearnedIRSignal] = []

    private let defaultsKey =
        "learnedIRSignals.v1"

    init() {
        load()
    }

    func add(
        name: String,
        category: IRDeviceCategory,
        carrierHz: Int,
        result: IRCaptureResult
    ) {
        let clean =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let signal =
            LearnedIRSignal(
                name:
                    clean.isEmpty
                    ? "Botón aprendido"
                    : clean,
                category: category,
                carrierHz: carrierHz,
                durationsMicros:
                    result.durationsMicros,
                sampleRate:
                    result.sampleRate
            )

        signals.insert(
            signal,
            at: 0
        )

        save()
        IRHaptics.success()
    }


    func addImported(
        name: String,
        category: IRDeviceCategory,
        code: IRCode
    ) {
        let signal =
            LearnedIRSignal(
                name:
                    name.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                    ? "Importado"
                    : name,
                category: category,
                carrierHz:
                    code.carrierHz,
                durationsMicros:
                    code.durationsMicros,
                sampleRate: 0
            )

        signals.insert(
            signal,
            at: 0
        )

        save()
        IRHaptics.success()
    }

    func replaceAll(
        _ newSignals: [LearnedIRSignal]
    ) {
        signals = newSignals
        save()
    }

    func remove(
        _ signal: LearnedIRSignal
    ) {
        signals.removeAll {
            $0.id == signal.id
        }

        save()
    }

    func rename(
        _ signal: LearnedIRSignal,
        to newName: String
    ) {
        guard
            let index =
                signals.firstIndex(
                    where: {
                        $0.id == signal.id
                    }
                )
        else {
            return
        }

        let clean =
            newName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !clean.isEmpty else {
            return
        }

        signals[index].name = clean
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
                    [LearnedIRSignal].self,
                    from: data
                )
        else {
            signals = []
            return
        }

        signals = decoded
    }

    private func save() {
        guard
            let data =
                try? JSONEncoder().encode(
                    signals
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
