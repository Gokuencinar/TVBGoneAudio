import Foundation

struct WorkedCodeRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let codeID: String
    let codeLabel: String
    let sourceLabel: String
    let category: IRDeviceCategory
    let carrierHz: Int
    let durationsMicros: [UInt32]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        code: IRCode,
        category: IRDeviceCategory,
        createdAt: Date = Date()
    ) {
        self.id = id
        codeID = code.id
        codeLabel = code.displayName
        sourceLabel = code.sourceLabel
        self.category = category
        carrierHz =
            code.carrierHz == 0
            ? 38_000
            : code.carrierHz
        durationsMicros =
            code.durationsMicros
        self.createdAt = createdAt
    }

    var code: IRCode {
        IRCode(
            id: codeID,
            carrierHz: carrierHz,
            durationsMicros: durationsMicros
        )
    }
}

@MainActor
final class WorkedCodeHistoryStore: ObservableObject {
    @Published private(set)
    var records: [WorkedCodeRecord] = []

    private let defaultsKey =
        "workedIRCodes.v1"

    init() {
        load()
    }

    func add(
        code: IRCode,
        category: IRDeviceCategory
    ) {
        records.removeAll {
            $0.codeID == code.id
                && $0.category == category
        }

        records.insert(
            WorkedCodeRecord(
                code: code,
                category: category
            ),
            at: 0
        )

        if records.count > 100 {
            records.removeLast(
                records.count - 100
            )
        }

        save()
    }

    func remove(
        _ record: WorkedCodeRecord
    ) {
        records.removeAll {
            $0.id == record.id
        }

        save()
        IRHaptics.tap()
    }

    func clear() {
        records = []
        save()
        IRHaptics.tap()
    }

    func replaceAll(
        _ newRecords: [WorkedCodeRecord]
    ) {
        records = Array(
            newRecords
                .sorted {
                    $0.createdAt
                        > $1.createdAt
                }
                .prefix(100)
        )

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
                    [WorkedCodeRecord].self,
                    from: data
                )
        else {
            records = []
            return
        }

        records = decoded
    }

    private func save() {
        guard
            let data =
                try? JSONEncoder().encode(
                    records
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
