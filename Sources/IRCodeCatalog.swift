import Foundation

enum IRCodeCatalog {
    static func codes(
        for category: IRDeviceCategory,
        region: TVRegion
    ) -> [IRCode] {
        switch category {
        case .television:
            return deduplicated(
                UniversalPowerCodes.codes
                + region.codes
                + GeneratedFlipperPowerDatabase.televisions
            )

        case .airConditioner:
            return GeneratedFlipperPowerDatabase.airConditioners

        case .projector:
            return GeneratedFlipperPowerDatabase.projectors
        }
    }

    static func allCodes(
        for category: IRDeviceCategory
    ) -> [IRCode] {
        switch category {
        case .television:
            return deduplicated(
                UniversalPowerCodes.codes
                + GeneratedTVBGoneDatabase.europe
                + GeneratedTVBGoneDatabase.northAmerica
                + GeneratedFlipperPowerDatabase.televisions
            )
        case .airConditioner:
            return GeneratedFlipperPowerDatabase.airConditioners
        case .projector:
            return GeneratedFlipperPowerDatabase.projectors
        }
    }

    static func code(
        id: String,
        category: IRDeviceCategory
    ) -> IRCode? {
        allCodes(for: category).first { $0.id == id }
    }

    static func filtered(
        category: IRDeviceCategory,
        region: TVRegion,
        source: IRSourceFilter,
        searchText: String
    ) -> [IRCode] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return codes(for: category, region: region).filter { code in
            guard source.matches(code) else { return false }
            guard !query.isEmpty else { return true }

            return code.displayName.lowercased().contains(query)
                || code.id.lowercased().contains(query)
                || code.brandHint.lowercased().contains(query)
                || code.sourceLabel.lowercased().contains(query)
        }
    }

    private static func deduplicated(
        _ input: [IRCode]
    ) -> [IRCode] {
        var seen = Set<String>()
        return input.filter { seen.insert($0.id).inserted }
    }
}
