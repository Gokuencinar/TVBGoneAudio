import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct IRUniversalBackup: Codable {
    let formatVersion: Int
    let createdAt: Date
    let appVersion: String
    let savedDevices: [SavedIRDevice]
    let learnedSignals: [LearnedIRSignal]
    let customRemotes: [CustomRemote]
    let workedCodes: [WorkedCodeRecord]
}

struct IRBackupDocument: FileDocument {
    static var readableContentTypes:
        [UTType] {
        [.json]
    }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(
        configuration:
            ReadConfiguration
    ) throws {
        guard
            let contents =
                configuration.file
                    .regularFileContents
        else {
            throw CocoaError(
                .fileReadCorruptFile
            )
        }

        data = contents
    }

    func fileWrapper(
        configuration:
            WriteConfiguration
    ) throws -> FileWrapper {
        FileWrapper(
            regularFileWithContents:
                data
        )
    }
}

@MainActor
enum IRBackupCodec {
    static func encode(
        savedDevices: SavedDeviceStore,
        learnedSignals: LearnedIRStore,
        customRemotes: CustomRemoteStore,
        history: WorkedCodeHistoryStore
    ) throws -> Data {
        let backup =
            IRUniversalBackup(
                formatVersion: 1,
                createdAt: Date(),
                appVersion:
                    Bundle.main.object(
                        forInfoDictionaryKey:
                            "CFBundleShortVersionString"
                    ) as? String ?? "0",
                savedDevices:
                    savedDevices.devices,
                learnedSignals:
                    learnedSignals.signals,
                customRemotes:
                    customRemotes.remotes,
                workedCodes:
                    history.records
            )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
        ]

        return try encoder.encode(
            backup
        )
    }

    static func decode(
        _ data: Data
    ) throws -> IRUniversalBackup {
        let backup =
            try JSONDecoder().decode(
                IRUniversalBackup.self,
                from: data
            )

        guard
            backup.formatVersion == 1
        else {
            throw CocoaError(
                .fileReadUnknown
            )
        }

        return backup
    }
}

struct BackupCenterView: View {
    @ObservedObject var savedDevices:
        SavedDeviceStore
    @ObservedObject var learnedSignals:
        LearnedIRStore
    @ObservedObject var customRemotes:
        CustomRemoteStore
    @ObservedObject var history:
        WorkedCodeHistoryStore

    @State private var showExporter =
        false
    @State private var showImporter =
        false
    @State private var exportDocument =
        IRBackupDocument(data: Data())
    @State private var pendingBackup:
        IRUniversalBackup?
    @State private var status: String?

    private var itemCount: Int {
        savedDevices.devices.count
        + learnedSignals.signals.count
        + customRemotes.remotes.count
        + history.records.count
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Label(
                    "Copia de seguridad",
                    systemImage:
                        "externaldrive.fill"
                )
                .font(.headline)

                Spacer()

                Text("\(itemCount) elementos")
                    .font(
                        .caption
                            .monospacedDigit()
                    )
                    .foregroundStyle(.secondary)
            }

            Text(
                "Guarda en un único archivo tus equipos, señales aprendidas, mandos y códigos que funcionaron."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    exportBackup()
                } label: {
                    Label(
                        "Exportar",
                        systemImage:
                            "square.and.arrow.up"
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(.bordered)

                Button {
                    showImporter = true
                } label: {
                    Label(
                        "Restaurar",
                        systemImage:
                            "square.and.arrow.down"
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(.bordered)
            }

            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
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
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename:
                "IR-Universal-Backup"
        ) { result in
            if case .failure(
                let error
            ) = result {
                status =
                    "No se pudo exportar: \(error.localizedDescription)"
                IRHaptics.error()
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [
                .json,
            ],
            allowsMultipleSelection:
                false
        ) { result in
            importBackup(result)
        }
        .alert(
            "Restaurar copia",
            isPresented:
                Binding(
                    get: {
                        pendingBackup != nil
                    },
                    set: {
                        if !$0 {
                            pendingBackup = nil
                        }
                    }
                )
        ) {
            Button(
                "Restaurar",
                role: .destructive
            ) {
                restorePendingBackup()
            }

            Button(
                "Cancelar",
                role: .cancel
            ) {
                pendingBackup = nil
            }
        } message: {
            if let pendingBackup {
                Text(
                    "Se sustituirá la biblioteca actual por \(pendingBackup.savedDevices.count) equipos, \(pendingBackup.customRemotes.count) mandos, \(pendingBackup.learnedSignals.count) señales y \(pendingBackup.workedCodes.count) aciertos."
                )
            }
        }
    }

    private func exportBackup() {
        do {
            let data =
                try IRBackupCodec.encode(
                    savedDevices:
                        savedDevices,
                    learnedSignals:
                        learnedSignals,
                    customRemotes:
                        customRemotes,
                    history:
                        history
                )

            exportDocument =
                IRBackupDocument(
                    data: data
                )
            showExporter = true
            status =
                "Copia preparada."
            IRHaptics.success()
        } catch {
            status =
                "No se pudo crear la copia: \(error.localizedDescription)"
            IRHaptics.error()
        }
    }

    private func importBackup(
        _ result:
            Result<[URL], Error>
    ) {
        do {
            let urls = try result.get()

            guard let url =
                urls.first
            else {
                return
            }

            let scoped =
                url.startAccessingSecurityScopedResource()

            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data =
                try Data(
                    contentsOf: url
                )

            pendingBackup =
                try IRBackupCodec.decode(
                    data
                )

            IRHaptics.tap()
        } catch {
            status =
                "Copia no válida: \(error.localizedDescription)"
            IRHaptics.error()
        }
    }

    private func restorePendingBackup() {
        guard let backup =
            pendingBackup
        else {
            return
        }

        savedDevices.replaceAll(
            backup.savedDevices
        )
        learnedSignals.replaceAll(
            backup.learnedSignals
        )
        customRemotes.replaceAll(
            backup.customRemotes
        )
        history.replaceAll(
            backup.workedCodes
        )

        pendingBackup = nil
        status =
            "Copia restaurada correctamente."
        IRHaptics.success()
    }
}
