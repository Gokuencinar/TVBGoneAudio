import Foundation

struct IRCode: Identifiable {
    let id: String
    let carrierHz: Int
    let durationsMicros: [UInt32]
}

enum TVRegion: String, CaseIterable, Identifiable {
    case europe = "Europa"
    case northAmerica = "Norteamérica / Asia"

    var id: String { rawValue }

    var codes: [IRCode] {
        switch self {
        case .europe: return GeneratedTVBGoneDatabase.europe
        case .northAmerica: return GeneratedTVBGoneDatabase.northAmerica
        }
    }
}
