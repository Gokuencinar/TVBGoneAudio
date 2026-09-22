import Foundation

struct IRCode: Identifiable {
    let id: String
    let carrierHz: Int
    let durationsMicros: [UInt32]
}

enum IRDeviceCategory: String, CaseIterable, Identifiable {
    case television = "TV"
    case airConditioner = "Aire"
    case projector = "Proyector"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .television: return "Televisores"
        case .airConditioner: return "Aires acondicionados"
        case .projector: return "Proyectores"
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
        case .television: return "tv"
        case .airConditioner: return "snowflake"
        case .projector: return "video"
        }
    }

    var explanation: String {
        switch self {
        case .television:
            return "Primero usa la base que ya funciona en tu TV y después añade cientos de perfiles modernos."
        case .airConditioner:
            return "Recorre señales POWER/OFF de mandos de aire acondicionado. Las señales RAW se conservan exactamente."
        case .projector:
            return "Recorre señales POWER/OFF de mandos de proyectores de distintas marcas."
        }
    }
}

enum TVRegion: String, CaseIterable, Identifiable {
    case europe = "Europa"
    case northAmerica = "Norteamérica / Asia"

    var id: String { rawValue }

    var codes: [IRCode] {
        switch self {
        case .europe:
            return GeneratedTVBGoneDatabase.europe
        case .northAmerica:
            return GeneratedTVBGoneDatabase.northAmerica
        }
    }
}
