import Foundation

struct OnlineIRRemote: Identifiable, Hashable {
    let id: String
    let source: OnlineIRSource
    let path: String
    let brand: String
    let model: String
    let categoryLabel: String
    let downloadURL: URL
    let score: Int

    var displayName: String {
        model.isEmpty || model.caseInsensitiveCompare(brand) == .orderedSame
            ? brand
            : "\(brand) · \(model)"
    }
}

enum OnlineIRSource: String, CaseIterable, Identifiable, Hashable {
    case flipperCommunity
    case flipperOfficial
    case legacyIRDB

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flipperCommunity: return "Flipper-IRDB"
        case .flipperOfficial: return "Flipper IRDB oficial"
        case .legacyIRDB: return "IRDB Web"
        }
    }
}

enum OnlineIRSourceFilter: String, CaseIterable, Identifiable {
    case all, flipper, official, irdb
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todas"
        case .flipper: return "Flipper"
        case .official: return "Oficial"
        case .irdb: return "IRDB"
        }
    }

    var sources: [OnlineIRSource] {
        switch self {
        case .all: return OnlineIRSource.allCases
        case .flipper: return [.flipperCommunity]
        case .official: return [.flipperOfficial]
        case .irdb: return [.legacyIRDB]
        }
    }
}

struct OnlineIRLoadedRemote: Identifiable {
    let id = UUID()
    let name: String
    let sourceDescription: String
    let signals: [ImportedIRSignal]
}

private struct GitHubIRTree: Decodable {
    struct Entry: Decodable {
        let path: String
        let type: String
    }
    let tree: [Entry]
    let truncated: Bool
}

@MainActor
final class OnlineIRLibrary: ObservableObject {
    @Published private(set) var results: [OnlineIRRemote] = []
    @Published private(set) var status = "Busca por marca y, si lo conoces, por modelo."
    @Published private(set) var isSearching = false
    @Published private(set) var brands: [String] = []
    @Published private(set) var isLoadingBrands = false
    @Published private(set) var brandStatus = "Cargando índice de marcas…"

    private var memoryCache: [String: Data] = [:]

    func loadBrands(
        category: IRDeviceCategory,
        filter: OnlineIRSourceFilter
    ) async {
        isLoadingBrands = true
        brandStatus = "Actualizando marcas…"

        var found: [String] = []
        var failures = 0

        for source in filter.sources {
            do {
                switch source {
                case .flipperCommunity:
                    found += try await brandsFromGitHubTree(
                        url: "https://api.github.com/repos/Lucaslhm/Flipper-IRDB/git/trees/main?recursive=1",
                        source: source,
                        category: category
                    )

                case .flipperOfficial:
                    found += try await brandsFromGitHubTree(
                        url: "https://api.github.com/repos/flipperdevices/IRDB/git/trees/dev?recursive=1",
                        source: source,
                        category: category
                    )

                case .legacyIRDB:
                    found += try await brandsFromLegacy(
                        category: category
                    )
                }
            } catch {
                failures += 1
            }
        }

        var unique: [String: String] = [:]

        for value in found {
            let display =
                value
                .replacingOccurrences(
                    of: "_",
                    with: " "
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            let key = clean(display)

            guard
                !key.isEmpty,
                key != "unknown",
                key != "desconocida"
            else {
                continue
            }

            if unique[key] == nil {
                unique[key] = display
            }
        }

        brands =
            unique.values.sorted {
                $0.localizedCaseInsensitiveCompare(
                    $1
                ) == .orderedAscending
            }

        isLoadingBrands = false

        if brands.isEmpty {
            brandStatus =
                failures > 0
                ? "No se pudo cargar el índice de marcas."
                : "No hay marcas para esta categoría."
        } else {
            brandStatus =
                "\(brands.count) marcas disponibles"
        }
    }

    func search(
        brand: String,
        model: String,
        category: IRDeviceCategory,
        filter: OnlineIRSourceFilter,
        deep: Bool
    ) async {
        let b = clean(brand)
        let m = clean(model)
        guard !b.isEmpty || !m.isEmpty else {
            results = []
            status = "Escribe al menos una marca o un modelo."
            return
        }

        isSearching = true
        status = "Consultando bibliotecas IR…"
        results = []

        var found: [OnlineIRRemote] = []
        var failures: [String] = []

        for source in filter.sources {
            do {
                switch source {
                case .flipperCommunity:
                    found += try await searchGitHubTree(
                        url: "https://api.github.com/repos/Lucaslhm/Flipper-IRDB/git/trees/main?recursive=1",
                        rawPrefix: "https://raw.githubusercontent.com/Lucaslhm/Flipper-IRDB/main/",
                        source: source,
                        brand: b,
                        model: m,
                        category: category,
                        deep: deep
                    )
                case .flipperOfficial:
                    found += try await searchGitHubTree(
                        url: "https://api.github.com/repos/flipperdevices/IRDB/git/trees/dev?recursive=1",
                        rawPrefix: "https://raw.githubusercontent.com/flipperdevices/IRDB/dev/",
                        source: source,
                        brand: b,
                        model: m,
                        category: category,
                        deep: deep
                    )
                case .legacyIRDB:
                    found += try await searchLegacy(
                        brand: b,
                        model: m,
                        category: category,
                        deep: deep
                    )
                }
            } catch {
                failures.append("\(source.title): \(error.localizedDescription)")
            }
        }

        var seen = Set<String>()
        results = found
            .sorted {
                $0.score == $1.score
                    ? $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    : $0.score > $1.score
            }
            .filter { seen.insert($0.id).inserted }
            .prefix(120)
            .map { $0 }

        isSearching = false
        if results.isEmpty {
            status = failures.isEmpty
                ? "Sin resultados. Prueba «Búsqueda profunda» o deja el modelo vacío."
                : "Sin resultados. Algunas fuentes fallaron: \(failures.joined(separator: " · "))"
        } else {
            status = "Encontrados \(results.count) mandos/códigos. Se descargan solo cuando los abres."
        }
    }

    func download(_ remote: OnlineIRRemote) async throws -> OnlineIRLoadedRemote {
        let data = try await fetch(remote.downloadURL, maxBytes: 2_000_000)
        guard let text = String(data: data, encoding: .utf8) else {
            throw error("El archivo descargado no es texto UTF-8.")
        }

        let signals: [ImportedIRSignal]
        if remote.source == .legacyIRDB {
            signals = IRDBCSVCodec.parse(text: text, idPrefix: "online-irdb")
        } else {
            signals = FlipperIRCodec.parse(text: text)
        }

        guard !signals.isEmpty else {
            throw error("El archivo existe, pero no contiene señales compatibles.")
        }

        return OnlineIRLoadedRemote(
            name: remote.displayName,
            sourceDescription: "\(remote.source.title) · \(remote.path)",
            signals: signals
        )
    }

    func importURL(_ value: String) async throws -> OnlineIRLoadedRemote {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = normalizedURL(value), url.scheme?.lowercased() == "https" else {
            throw error("Solo se admiten URLs HTTPS válidas.")
        }

        let data = try await fetch(url, maxBytes: 2_000_000)
        guard let text = String(data: data, encoding: .utf8) else {
            throw error("El contenido descargado no es texto UTF-8.")
        }

        var signals = FlipperIRCodec.parse(text: text)
        if signals.isEmpty {
            signals = IRDBCSVCodec.parse(text: text, idPrefix: "url-irdb")
        }
        guard !signals.isEmpty else {
            throw error("No se encontraron señales .ir o IRDB compatibles en esa URL.")
        }

        let base = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
        return OnlineIRLoadedRemote(
            name: base.isEmpty ? "Mando importado" : base,
            sourceDescription: "URL · \(url.host ?? "HTTPS")",
            signals: signals
        )
    }

    private func brandsFromGitHubTree(
        url: String,
        source: OnlineIRSource,
        category: IRDeviceCategory
    ) async throws -> [String] {
        let data =
            try await cached(
                url,
                maxBytes: 20_000_000
            )

        let tree =
            try JSONDecoder().decode(
                GitHubIRTree.self,
                from: data
            )

        guard !tree.truncated else {
            throw error(
                "El índice de GitHub llegó incompleto."
            )
        }

        return tree.tree.compactMap {
            entry in

            guard
                entry.type == "blob",
                entry.path
                    .lowercased()
                    .hasSuffix(".ir"),
                categoryMatches(
                    entry.path,
                    category: category,
                    source: source
                )
            else {
                return nil
            }

            let pieces =
                entry.path
                    .split(separator: "/")
                    .map(String.init)

            let candidate =
                guessBrand(
                    pieces: pieces,
                    source: source
                )

            return candidate.isEmpty
                ? nil
                : candidate
        }
    }

    private func brandsFromLegacy(
        category: IRDeviceCategory
    ) async throws -> [String] {
        let indexURL =
            "https://cdn.jsdelivr.net/gh/probonopd/irdb@master/codes/index"

        let data =
            try await cached(
                indexURL,
                maxBytes: 8_000_000
            )

        guard
            let text =
                String(
                    data: data,
                    encoding: .utf8
                )
        else {
            return []
        }

        return text
            .components(
                separatedBy: .newlines
            )
            .compactMap { line in
                let path =
                    line.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

                guard
                    path.lowercased()
                        .hasSuffix(".csv")
                else {
                    return nil
                }

                let parts =
                    path
                        .split(separator: "/")
                        .map(String.init)

                guard parts.count >= 3 else {
                    return nil
                }

                let candidateBrand =
                    parts[0]
                let candidateModel =
                    parts[1]

                guard
                    legacyCategoryMatches(
                        candidateModel,
                        category: category
                    )
                else {
                    return nil
                }

                return candidateBrand
            }
    }

    private func searchGitHubTree(
        url: String,
        rawPrefix: String,
        source: OnlineIRSource,
        brand: String,
        model: String,
        category: IRDeviceCategory,
        deep: Bool
    ) async throws -> [OnlineIRRemote] {
        let data = try await cached(url, maxBytes: 20_000_000)
        let tree = try JSONDecoder().decode(GitHubIRTree.self, from: data)
        guard !tree.truncated else { throw error("El índice de GitHub llegó incompleto.") }

        return tree.tree.compactMap { entry in
            guard entry.type == "blob", entry.path.lowercased().hasSuffix(".ir") else { return nil }
            guard categoryMatches(entry.path, category: category, source: source) else { return nil }

            let pieces = entry.path.split(separator: "/").map(String.init)
            let file = pieces.last.map { String($0.dropLast(3)) } ?? "Mando"
            let guessedBrand = guessBrand(pieces: pieces, source: source)
            let score = matchScore(
                brand: brand,
                model: model,
                candidateBrand: guessedBrand,
                candidateModel: file,
                full: entry.path,
                deep: deep
            )
            guard score > 0 else { return nil }

            let encoded = entry.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? entry.path
            guard let downloadURL = URL(string: rawPrefix + encoded) else { return nil }

            return OnlineIRRemote(
                id: "\(source.rawValue):\(entry.path)",
                source: source,
                path: entry.path,
                brand: guessedBrand.isEmpty ? "Desconocida" : guessedBrand,
                model: file.replacingOccurrences(of: "_", with: " "),
                categoryLabel: category.shortTitle,
                downloadURL: downloadURL,
                score: score
            )
        }
    }

    private func searchLegacy(
        brand: String,
        model: String,
        category: IRDeviceCategory,
        deep: Bool
    ) async throws -> [OnlineIRRemote] {
        let indexURL = "https://cdn.jsdelivr.net/gh/probonopd/irdb@master/codes/index"
        let data = try await cached(indexURL, maxBytes: 8_000_000)
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        return text.components(separatedBy: .newlines).compactMap { line in
            let path = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard path.lowercased().hasSuffix(".csv") else { return nil }
            let parts = path.split(separator: "/").map(String.init)
            guard parts.count >= 3 else { return nil }

            let candidateBrand = parts[0]
            let candidateModel = parts[1]
            let full = "\(candidateBrand) \(candidateModel) \(path)"
            if !legacyCategoryMatches(candidateModel, category: category) && !deep { return nil }

            let score = matchScore(
                brand: brand,
                model: model,
                candidateBrand: candidateBrand,
                candidateModel: candidateModel,
                full: full,
                deep: deep
            )
            guard score > 0 else { return nil }

            let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            guard let u = URL(string: "https://cdn.jsdelivr.net/gh/probonopd/irdb@master/codes/" + encoded) else { return nil }

            return OnlineIRRemote(
                id: "legacy:\(path)",
                source: .legacyIRDB,
                path: path,
                brand: candidateBrand,
                model: candidateModel,
                categoryLabel: category.shortTitle,
                downloadURL: u,
                score: score
            )
        }
    }

    private func guessBrand(pieces: [String], source: OnlineIRSource) -> String {
        guard pieces.count >= 2 else { return "" }
        if source == .flipperCommunity {
            return pieces.count >= 3 ? pieces[1].replacingOccurrences(of: "_", with: " ") : pieces[0]
        }
        if let i = pieces.firstIndex(of: "categories"), pieces.count > i + 2 {
            return pieces[i + 2].replacingOccurrences(of: "_", with: " ")
        }
        return pieces.dropLast().last?.replacingOccurrences(of: "_", with: " ") ?? ""
    }

    private func categoryMatches(_ path: String, category: IRDeviceCategory, source: OnlineIRSource) -> Bool {
        let n = clean(path)
        switch category {
        case .television:
            return n.contains("tv") || n.contains("television")
        case .airConditioner:
            return source == .flipperCommunity && (n.contains("ac") || n.contains("air conditioner"))
        case .projector:
            return n.contains("projector")
        }
    }

    private func legacyCategoryMatches(_ value: String, category: IRDeviceCategory) -> Bool {
        let n = clean(value)
        switch category {
        case .television: return n.contains("tv") || n.contains("television")
        case .airConditioner: return n.contains("air") || n.contains("ac")
        case .projector: return n.contains("projector")
        }
    }

    private func matchScore(
        brand: String,
        model: String,
        candidateBrand: String,
        candidateModel: String,
        full: String,
        deep: Bool
    ) -> Int {
        let cb = clean(candidateBrand), cm = clean(candidateModel), all = clean(full)
        var score = 0

        if !brand.isEmpty {
            if cb == brand { score += 35 }
            else if cb.contains(brand) || brand.contains(cb) { score += 24 }
            else if compact(cb).contains(compact(brand)) { score += 18 }
            else if deep && tokens(brand).allSatisfy({ all.contains($0) }) { score += 8 }
            else { return 0 }
        }

        if !model.isEmpty {
            if cm == model { score += 40 }
            else if cm.contains(model) || all.contains(model) { score += 28 }
            else if compact(all).contains(compact(model)) { score += 20 }
            else if deep && tokens(model).allSatisfy({ all.contains($0) }) { score += 10 }
            else { return 0 }
        }
        return score
    }

    private func clean(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func compact(_ value: String) -> String {
        clean(value).filter { $0.isLetter || $0.isNumber }
    }

    private func tokens(_ value: String) -> [String] {
        clean(value).split(separator: " ").map(String.init).filter { $0.count >= 2 }
    }

    private func cached(_ string: String, maxBytes: Int) async throws -> Data {
        if let data = memoryCache[string] { return data }
        guard let url = URL(string: string) else { throw error("URL interna inválida.") }
        let data = try await fetch(url, maxBytes: maxBytes)
        memoryCache[string] = data
        return data
    }

    private func fetch(_ url: URL, maxBytes: Int) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("IR-Universal/5.1 iOS", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw error(http.statusCode == 403 || http.statusCode == 429
                ? "La fuente está limitando temporalmente las consultas."
                : "Servidor HTTP \(http.statusCode).")
        }
        guard data.count <= maxBytes else { throw error("La respuesta es demasiado grande.") }
        return data
    }

    private func normalizedURL(_ value: String) -> URL? {
        guard var c = URLComponents(string: value) else { return nil }
        if c.host?.lowercased() == "github.com" {
            let p = c.path.split(separator: "/").map(String.init)
            if p.count >= 5, p[2] == "blob" {
                let filePath = p.dropFirst(4).joined(separator: "/")
                return URL(string: "https://raw.githubusercontent.com/\(p[0])/\(p[1])/\(p[3])/\(filePath)")
            }
        }
        c.fragment = nil
        return c.url
    }

    private func error(_ message: String) -> NSError {
        NSError(domain: "IRUniversal.Online", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

enum IRDBCSVCodec {
    static func parse(text: String, idPrefix: String) -> [ImportedIRSignal] {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }

        return lines.dropFirst().enumerated().compactMap { index, line in
            let f = csv(line)
            guard f.count >= 5,
                  let device = Int(f[2].trimmingCharacters(in: .whitespaces)),
                  let sub = Int(f[3].trimmingCharacters(in: .whitespaces)),
                  let function = Int(f[4].trimmingCharacters(in: .whitespaces)),
                  (0...255).contains(device), (0...255).contains(function)
            else { return nil }

            let proto = f[1].uppercased().replacingOccurrences(of: "-", with: "")
            let d = UInt8(device), command = UInt8(function)
            let id = "\(idPrefix):\(index):\(UUID().uuidString)"
            let code: IRCode?

            if proto.hasPrefix("NEC") {
                code = sub >= 0 && sub <= 255
                    ? IRProtocolEncoder.encode(protocolName: "NECEXT", address: [d, UInt8(sub)], command: [command, ~command], id: id)
                    : IRProtocolEncoder.encode(protocolName: "NEC", address: [d], command: [command], id: id)
            } else if proto.hasPrefix("RC5") {
                code = IRProtocolEncoder.encode(protocolName: "RC5", address: [d], command: [command], id: id)
            } else if proto.hasPrefix("RC6") {
                code = IRProtocolEncoder.encode(protocolName: "RC6", address: [d], command: [command], id: id)
            } else if proto.contains("SONY") || proto.contains("SIRC") {
                let p = proto.contains("20") ? "SIRC20" : proto.contains("15") ? "SIRC15" : "SIRC"
                code = IRProtocolEncoder.encode(protocolName: p, address: [d], command: [command], id: id)
            } else if proto == "JVC" || proto == "RCA" {
                code = IRProtocolEncoder.encode(protocolName: proto, address: [d], command: [command], id: id)
            } else {
                code = nil
            }

            guard let code else { return nil }
            let name = f[0].trimmingCharacters(in: .whitespacesAndNewlines)
            return ImportedIRSignal(
                name: name.isEmpty ? "BUTTON_\(function)" : name,
                code: code,
                sourceDescription: "IRDB \(proto)"
            )
        }
    }

    private static func csv(_ line: String) -> [String] {
        var out: [String] = [], cur = ""
        var quoted = false
        for ch in line {
            if ch == "\"" { quoted.toggle() }
            else if ch == "," && !quoted { out.append(cur); cur = "" }
            else { cur.append(ch) }
        }
        out.append(cur)
        return out
    }
}
