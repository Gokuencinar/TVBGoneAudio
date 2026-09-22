import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let flipperIR =
        UTType(filenameExtension: "ir")
        ?? .plainText
}

struct ImportedIRSignal: Identifiable {
    let id = UUID()
    let name: String
    let code: IRCode
    let sourceDescription: String
}

enum FlipperIRCodec {
    static func parse(
        text: String
    ) -> [ImportedIRSignal] {
        let records =
            parseRecords(text)

        var output: [ImportedIRSignal] = []

        for record in records {
            guard
                let name =
                    record["name"],
                let type =
                    record["type"]?
                    .lowercased()
            else {
                continue
            }

            let id =
                "imported:\(UUID().uuidString)"

            if type == "raw" {
                guard
                    let frequencyText =
                        record["frequency"],
                    let frequency =
                        Int(frequencyText)
                else {
                    continue
                }

                let durations =
                    (record["data"] ?? "")
                    .split {
                        $0 == " "
                        || $0 == "\t"
                        || $0 == "\n"
                    }
                    .compactMap {
                        UInt32($0)
                    }

                guard durations.count >= 2 else {
                    continue
                }

                output.append(
                    ImportedIRSignal(
                        name: name,
                        code: IRCode(
                            id: id,
                            carrierHz: frequency,
                            durationsMicros:
                                durations
                        ),
                        sourceDescription:
                            "Flipper RAW"
                    )
                )

                continue
            }

            if type == "parsed" {
                let protocolName =
                    record["protocol"] ?? ""

                let address =
                    parseHexBytes(
                        record["address"] ?? ""
                    )

                let command =
                    parseHexBytes(
                        record["command"] ?? ""
                    )

                if let code =
                    IRProtocolEncoder.encode(
                        protocolName:
                            protocolName,
                        address: address,
                        command: command,
                        id: id
                    )
                {
                    output.append(
                        ImportedIRSignal(
                            name: name,
                            code: code,
                            sourceDescription:
                                "Flipper \(protocolName)"
                        )
                    )
                }
            }
        }

        return output
    }

    static func exportRaw(
        name: String,
        code: IRCode
    ) -> String {
        exportRawRecords(
            [(name, code)]
        )
    }

    static func exportRemote(
        _ remote: CustomRemote
    ) -> String {
        exportRawRecords(
            remote.buttons.map {
                ($0.name, $0.code)
            }
        )
    }

    private static func exportRawRecords(
        _ records: [(String, IRCode)]
    ) -> String {
        var lines = [
            "Filetype: IR signals file",
            "Version: 1",
        ]

        for (name, code) in records {
            let safeName =
                name
                .replacingOccurrences(
                    of: "\n",
                    with: " "
                )
                .replacingOccurrences(
                    of: "\r",
                    with: " "
                )

            let data =
                code.durationsMicros
                .map(String.init)
                .joined(separator: " ")

            lines.append("#")
            lines.append("name: \(safeName)")
            lines.append("type: raw")
            lines.append(
                "frequency: \(code.carrierHz == 0 ? 38000 : code.carrierHz)"
            )
            lines.append("duty_cycle: 0.330000")
            lines.append("data: \(data)")
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func parseRecords(
        _ text: String
    ) -> [[String: String]] {
        var records:
            [[String: String]] = []

        var current:
            [String: String] = [:]

        var lastKey: String?

        func finish() {
            if
                current["name"] != nil,
                current["type"] != nil
            {
                records.append(current)
            }

            current = [:]
            lastKey = nil
        }

        for rawLine
            in text.components(
                separatedBy: .newlines
            )
        {
            let line =
                rawLine.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            if line.isEmpty {
                continue
            }

            if line.hasPrefix("#") {
                finish()
                continue
            }

            if let colon =
                line.firstIndex(of: ":")
            {
                let key =
                    String(
                        line[..<colon]
                    )
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .lowercased()

                let value =
                    String(
                        line[
                            line.index(
                                after: colon
                            )...
                        ]
                    )
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                if
                    key == "name",
                    current["name"] != nil
                {
                    finish()
                }

                current[key] = value
                lastKey = key
                continue
            }

            if
                lastKey == "data",
                line.allSatisfy({
                    $0.isNumber
                    || $0 == " "
                    || $0 == "\t"
                })
            {
                current["data"] =
                    (
                        current["data"]
                        ?? ""
                    )
                    + " "
                    + line
            }
        }

        finish()

        return records
    }

    private static func parseHexBytes(
        _ value: String
    ) -> [UInt8] {
        value
            .split {
                $0 == " "
                || $0 == "\t"
            }
            .compactMap {
                UInt8(
                    $0,
                    radix: 16
                )
            }
    }
}

struct FlipperIRDocument: FileDocument {
    static var readableContentTypes:
        [UTType] {
        [
            .flipperIR,
            .plainText,
            .data,
        ]
    }

    var text: String

    init(
        text: String = ""
    ) {
        self.text = text
    }

    init(
        configuration:
            ReadConfiguration
    ) throws {
        if
            let data =
                configuration.file
                .regularFileContents,
            let value =
                String(
                    data: data,
                    encoding: .utf8
                )
        {
            text = value
        } else {
            text = ""
        }
    }

    func fileWrapper(
        configuration:
            WriteConfiguration
    ) throws -> FileWrapper {
        FileWrapper(
            regularFileWithContents:
                text.data(
                    using: .utf8
                ) ?? Data()
        )
    }
}
