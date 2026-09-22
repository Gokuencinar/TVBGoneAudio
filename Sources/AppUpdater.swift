import Foundation
import SwiftUI
import UIKit

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case assets
    }
}

struct IRAppRelease: Equatable {
    let version: String
    let build: Int
    let ipaURL: URL
    let notes: String
}

@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var isChecking = false
    @Published private(set) var updateAvailable = false
    @Published private(set) var release: IRAppRelease?
    @Published private(set) var status: String?

    private let latestReleaseURL = URL(
        string:
            "https://api.github.com/repos/Gokuencinar/TVBGoneAudio/releases/latest"
    )!

    var currentVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey:
                "CFBundleShortVersionString"
        ) as? String ?? "0"
    }

    var currentBuild: Int {
        Int(
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleVersion"
            ) as? String ?? "0"
        ) ?? 0
    }

    var availableVersionText: String {
        guard let release else {
            return ""
        }

        return "\(release.version) (\(release.build))"
    }

    func checkForUpdates(
        silent: Bool = false
    ) async {
        guard !isChecking else {
            return
        }

        isChecking = true

        if !silent {
            status = "Buscando actualizaciones…"
        }

        defer {
            isChecking = false
        }

        do {
            var request =
                URLRequest(
                    url: latestReleaseURL,
                    cachePolicy:
                        .reloadIgnoringLocalCacheData,
                    timeoutInterval: 15
                )

            request.setValue(
                "application/vnd.github+json",
                forHTTPHeaderField: "Accept"
            )

            request.setValue(
                "IR-Universal-Updater",
                forHTTPHeaderField:
                    "User-Agent"
            )

            let (data, response) =
                try await URLSession.shared.data(
                    for: request
                )

            guard
                let http =
                    response as? HTTPURLResponse,
                (200..<300).contains(
                    http.statusCode
                )
            else {
                throw URLError(
                    .badServerResponse
                )
            }

            let githubRelease =
                try JSONDecoder().decode(
                    GitHubRelease.self,
                    from: data
                )

            guard
                let parsed =
                    parseVersionTag(
                        githubRelease.tagName
                    ),
                let ipa =
                    githubRelease.assets.first(
                        where: {
                            $0.name
                                .lowercased()
                                .hasSuffix(".ipa")
                        }
                    )
            else {
                throw UpdateError
                    .invalidRelease
            }

            let candidate =
                IRAppRelease(
                    version:
                        parsed.version,
                    build:
                        parsed.build,
                    ipaURL:
                        ipa.browserDownloadURL,
                    notes:
                        githubRelease.body ?? ""
                )

            release = candidate

            if isNewer(candidate) {
                updateAvailable = true
                status =
                    "Nueva versión disponible: \(candidate.version) (\(candidate.build))."
            } else {
                updateAvailable = false

                if !silent {
                    status =
                        "IR Universal está actualizado."
                }
            }
        } catch {
            updateAvailable = false

            if !silent {
                status =
                    "No se pudo comprobar la actualización: \(error.localizedDescription)"
            }
        }
    }

    func installWithTrollStore() {
        guard
            let release,
            updateAvailable
        else {
            status =
                "No hay ninguna actualización pendiente."
            return
        }

        var components =
            URLComponents()

        components.scheme =
            "apple-magnifier"
        components.host = "install"
        components.queryItems = [
            URLQueryItem(
                name: "url",
                value:
                    release.ipaURL
                        .absoluteString
            ),
        ]

        guard let url =
            components.url
        else {
            status =
                "No se pudo preparar la URL para TrollStore."
            return
        }

        UIApplication.shared.open(
            url,
            options: [:]
        ) { [weak self] success in
            Task { @MainActor in
                self?.status =
                    success
                    ? "Enviado a TrollStore. Confirma la instalación allí."
                    : "No se pudo abrir TrollStore."
            }
        }
    }

    private func isNewer(
        _ candidate: IRAppRelease
    ) -> Bool {
        let comparison =
            candidate.version.compare(
                currentVersion,
                options: .numeric
            )

        if comparison
            == .orderedDescending
        {
            return true
        }

        if comparison
            == .orderedAscending
        {
            return false
        }

        return candidate.build
            > currentBuild
    }

    private func parseVersionTag(
        _ tag: String
    ) -> (
        version: String,
        build: Int
    )? {
        var value = tag

        if value.hasPrefix("v") {
            value.removeFirst()
        }

        guard
            let range =
                value.range(
                    of: "-b",
                    options: .backwards
                )
        else {
            return nil
        }

        let version =
            String(
                value[
                    ..<range.lowerBound
                ]
            )

        let buildText =
            String(
                value[
                    range.upperBound...
                ]
            )

        guard let build =
            Int(buildText)
        else {
            return nil
        }

        return (
            version,
            build
        )
    }

    private enum UpdateError:
        LocalizedError
    {
        case invalidRelease

        var errorDescription: String? {
            switch self {
            case .invalidRelease:
                return
                    "La release no contiene una IPA válida."
            }
        }
    }
}

struct UpdateCenterView: View {
    @ObservedObject var updater:
        AppUpdater

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Label(
                "Actualizaciones",
                systemImage:
                    "arrow.down.circle.fill"
            )
            .font(.headline)

            LabeledContent(
                "Instalada",
                value:
                    "\(updater.currentVersion) (\(updater.currentBuild))"
            )

            if updater.updateAvailable,
               let release =
                updater.release
            {
                LabeledContent(
                    "Disponible",
                    value:
                        "\(release.version) (\(release.build))"
                )

                Button {
                    updater
                        .installWithTrollStore()
                } label: {
                    Label(
                        "ACTUALIZAR CON TROLLSTORE",
                        systemImage:
                            "arrow.down.app.fill"
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .tint(.red)
            }

            Button {
                Task {
                    await updater
                        .checkForUpdates()
                }
            } label: {
                HStack {
                    if updater.isChecking {
                        ProgressView()
                    } else {
                        Image(
                            systemName:
                                "arrow.clockwise"
                        )
                    }

                    Text(
                        updater.isChecking
                        ? "Comprobando…"
                        : "Buscar actualización"
                    )
                }
                .frame(
                    maxWidth: .infinity
                )
            }
            .buttonStyle(.bordered)
            .disabled(updater.isChecking)

            if let status =
                updater.status
            {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Text(
                "La instalación se entrega a TrollStore mediante su URL Scheme. Si se abre la app Lupa en lugar de TrollStore, activa «URL Scheme» en los ajustes de TrollStore."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
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
    }
}
