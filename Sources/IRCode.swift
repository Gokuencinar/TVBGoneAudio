import Foundation

struct IRCode: Identifiable, Hashable {
    let id: String
    let carrierHz: Int
    let durationsMicros: [UInt32]

    var sourceLabel: String {
        if id.hasPrefix("flipper:") { return "Flipper-IRDB" }
        if id.hasPrefix("universal-") { return "Universal" }
        if id.lowercased().contains("eu") || id.lowercased().contains("na") {
            return "TV-B-Gone"
        }
        return "Base IR"
    }

    var brandHint: String {
        if id.hasPrefix("flipper:") {
            let body = String(id.dropFirst("flipper:".count))
            let path = body.components(separatedBy: "#").first ?? body
            let parts = path.split(separator: "/").map(String.init)
            if parts.count >= 2 {
                return prettify(parts[1])
            }
        }

        if id.hasPrefix("universal-") {
            var parts = id
                .replacingOccurrences(of: "universal-", with: "")
                .replacingOccurrences(of: "-power", with: "")
                .split(separator: "-")
                .map(String.init)

            let ignored = Set(["nec", "rc5", "rc6", "tdsystems"])
            parts.removeAll { ignored.contains($0.lowercased()) }
            if let first = parts.first {
                return prettify(first)
            }
        }

        return sourceLabel
    }

    var displayName: String {
        if id.hasPrefix("flipper:") {
            let body = String(id.dropFirst("flipper:".count))
            let components = body.components(separatedBy: "#")
            let signal = components.count > 1 ? components[1] : "Power"
            let filename = (components.first ?? body)
                .split(separator: "/")
                .last
                .map(String.init)?
                .replacingOccurrences(of: ".ir", with: "") ?? ""
            let model = prettify(filename)

            if model.isEmpty {
                return "\(brandHint) · \(prettify(signal))"
            }
            return "\(brandHint) · \(model) · \(prettify(signal))"
        }

        if id.hasPrefix("universal-") {
            let clean = id
                .replacingOccurrences(of: "universal-", with: "")
                .replacingOccurrences(of: "-power", with: "")
            return prettify(clean)
        }

        if id.hasPrefix("code_") {
            return "TV-B-Gone · \(id)"
        }

        return prettify(id)
    }

    var durationMillis: Int {
        Int(durationsMicros.reduce(UInt64(0)) { $0 + UInt64($1) } / 1000)
    }

    private func prettify(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                let w = String(word)
                guard let first = w.first else { return w }
                return String(first).uppercased() + w.dropFirst()
            }
            .joined(separator: " ")
    }
}

enum IRDeviceCategory: String, CaseIterable, Identifiable, Codable {
    case television
    case airConditioner
    case projector

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .television: return "TV"
        case .airConditioner: return "Aire"
        case .projector: return "Proyector"
        }
    }

    var title: String {
        switch self {
        case .television: return "Televisores"
        case .airConditioner: return "Aires acondicionados"
        case .projector: return "Proyectores"
        }
    }

    var defaultDeviceName: String {
        switch self {
        case .television: return "Mi TV"
        case .airConditioner: return "Mi aire"
        case .projector: return "Mi proyector"
        }
    }

    var buttonTitle: String {
        switch self {
        case .television: return "APAGAR TELEVISORES"
        case .airConditioner: return "APAGAR AIRES"
        case .projector: return "APAGAR PROYECTORES"
        }
    }

    var systemImage: String {
        switch self {
        case .television: return "tv.fill"
        case .airConditioner: return "snowflake"
        case .projector: return "video.fill"
        }
    }

    var explanation: String {
        switch self {
        case .television:
            return "Prueba primero los códigos universales y TV-B-Gone que ya sabemos que funcionan, y después la base ampliada."
        case .airConditioner:
            return "Recorre señales POWER/OFF de mandos de aire acondicionado, priorizando capturas RAW."
        case .projector:
            return "Recorre señales POWER/OFF de proyectores de distintas marcas y modelos."
        }
    }
}

enum TVRegion: String, CaseIterable, Identifiable, Codable {
    case europe
    case northAmerica

    var id: String { rawValue }

    var title: String {
        switch self {
        case .europe: return "Europa"
        case .northAmerica: return "Norteamérica / Asia"
        }
    }

    var codes: [IRCode] {
        switch self {
        case .europe:
            return GeneratedTVBGoneDatabase.europe
        case .northAmerica:
            return GeneratedTVBGoneDatabase.northAmerica
        }
    }
}

enum ScanPace: String, CaseIterable, Identifiable {
    case fast
    case identify

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast: return "Rápido"
        case .identify: return "Identificar"
        }
    }

    var gapSeconds: Double {
        switch self {
        case .fast: return 0.205
        case .identify: return 0.80
        }
    }

    var help: String {
        switch self {
        case .fast:
            return "Barrido rápido para apagar el equipo cuanto antes."
        case .identify:
            return "Deja más tiempo entre códigos para poder pulsar «FUNCIONÓ»."
        }
    }
}

enum IRSourceFilter: String, CaseIterable, Identifiable {
    case all
    case universal
    case tvBGone
    case flipper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todos"
        case .universal: return "Universal"
        case .tvBGone: return "TV-B-Gone"
        case .flipper: return "IRDB"
        }
    }

    func matches(_ code: IRCode) -> Bool {
        switch self {
        case .all: return true
        case .universal: return code.sourceLabel == "Universal"
        case .tvBGone: return code.sourceLabel == "TV-B-Gone"
        case .flipper: return code.sourceLabel == "Flipper-IRDB"
        }
    }
}
