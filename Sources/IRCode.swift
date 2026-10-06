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
    case setTopBox
    case fan
    case streamingBox
    case dvdPlayer
    case projector
    case avReceiver
    case camera
    case soundbar

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .television: return "TV"
        case .airConditioner: return "Aire"
        case .setTopBox: return "Decodif."
        case .fan: return "Ventilador"
        case .streamingBox: return "Smart box"
        case .dvdPlayer: return "DVD/Blu-ray"
        case .projector: return "Proyector"
        case .avReceiver: return "A/V"
        case .camera: return "Cámara"
        case .soundbar: return "Soundbar"
        }
    }

    var title: String {
        switch self {
        case .television: return "Televisores"
        case .airConditioner: return "Aires acondicionados"
        case .setTopBox: return "Decodificadores / TV Box"
        case .fan: return "Ventiladores"
        case .streamingBox: return "Streaming / Smart Box"
        case .dvdPlayer: return "DVD / Blu-ray"
        case .projector: return "Proyectores"
        case .avReceiver: return "Receptores A/V"
        case .camera: return "Cámaras"
        case .soundbar: return "Barras de sonido"
        }
    }

    var defaultDeviceName: String {
        switch self {
        case .television: return "Mi TV"
        case .airConditioner: return "Mi aire"
        case .setTopBox: return "Mi decodificador"
        case .fan: return "Mi ventilador"
        case .streamingBox: return "Mi Smart Box"
        case .dvdPlayer: return "Mi reproductor"
        case .projector: return "Mi proyector"
        case .avReceiver: return "Mi receptor A/V"
        case .camera: return "Mi cámara"
        case .soundbar: return "Mi barra de sonido"
        }
    }

    var buttonTitle: String {
        switch self {
        case .television: return "APAGAR TELEVISORES"
        case .airConditioner: return "APAGAR AIRES"
        case .setTopBox: return "APAGAR DECODIFICADORES"
        case .fan: return "APAGAR VENTILADORES"
        case .streamingBox: return "APAGAR SMART BOX"
        case .dvdPlayer: return "APAGAR DVD / BLU-RAY"
        case .projector: return "APAGAR PROYECTORES"
        case .avReceiver: return "APAGAR RECEPTORES A/V"
        case .camera: return "APAGAR CÁMARAS"
        case .soundbar: return "APAGAR BARRAS DE SONIDO"
        }
    }

    var scanRepeatCount: Int {
        self == .projector ? 2 : 1
    }

    var systemImage: String {
        switch self {
        case .television: return "tv.fill"
        case .airConditioner: return "snowflake"
        case .setTopBox: return "shippingbox.fill"
        case .fan: return "wind"
        case .streamingBox: return "play.rectangle.fill"
        case .dvdPlayer: return "opticaldisc"
        case .projector: return "video.fill"
        case .avReceiver: return "speaker.wave.3.fill"
        case .camera: return "camera.fill"
        case .soundbar: return "speaker.wave.2.fill"
        }
    }

    var explanation: String {
        switch self {
        case .television:
            return "Prueba primero los códigos universales y TV-B-Gone que ya sabemos que funcionan, y después la base ampliada."
        case .airConditioner:
            return "Recorre señales POWER/OFF de mandos de aire acondicionado, priorizando capturas RAW."
        case .projector:
            return "Recorre señales POWER/OFF de proyectores de distintas marcas y modelos. Cada candidato se envía dos veces para confirmar el apagado."
        case .setTopBox:
            return "Recorre señales POWER/OFF de decodificadores, receptores de TV y convertidores."
        case .fan:
            return "Recorre señales POWER/OFF de ventiladores con mando infrarrojo."
        case .streamingBox:
            return "Recorre señales POWER/OFF de TV Box y dispositivos de streaming."
        case .dvdPlayer:
            return "Recorre señales POWER/OFF de DVD, Blu-ray, LaserDisc y VCR."
        case .avReceiver:
            return "Recorre señales POWER/OFF de receptores y amplificadores A/V."
        case .camera:
            return "Recorre las señales POWER/OFF disponibles para cámaras y equipos CCTV compatibles."
        case .soundbar:
            return "Recorre señales POWER/OFF de barras de sonido de distintas marcas."
        }
    }
}

enum IRAppSymbols {
    // SF Symbols 4 / iOS 16 compatible. `remote.fill` can render blank on iOS 16.
    static let remote = "av.remote.fill"
    static let remoteOutline = "av.remote"
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
