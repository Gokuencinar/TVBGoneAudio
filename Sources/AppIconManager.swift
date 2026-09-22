import SwiftUI
import UIKit

struct AppIconChoice: Identifiable, Hashable {
    let id: String
    let title: String
    let assetName: String
    let alternateName: String?
}

@MainActor
final class AppIconManager: ObservableObject {
    static let choices: [AppIconChoice] = [
        AppIconChoice(
            id: "power",
            title: "Power IR",
            assetName: "IconPreviewPower",
            alternateName: nil
        ),
        AppIconChoice(
            id: "remote",
            title: "Mando azul",
            assetName: "IconPreviewRemote",
            alternateName: "AppIconRemote"
        ),
        AppIconChoice(
            id: "led",
            title: "LED IR",
            assetName: "IconPreviewLED",
            alternateName: "AppIconLED"
        ),
        AppIconChoice(
            id: "gradient",
            title: "Power degradado",
            assetName: "IconPreviewGradient",
            alternateName: "AppIconGradient"
        ),
    ]

    @Published private(set) var selectedID = "power"
    @Published private(set) var status: String?

    init() {
        refresh()
    }

    func refresh() {
        let current = UIApplication.shared.alternateIconName
        selectedID = Self.choices.first(where: { $0.alternateName == current })?.id ?? "power"
    }

    func select(_ choice: AppIconChoice) {
        guard UIApplication.shared.supportsAlternateIcons else {
            status = "Esta instalación de iOS no permite cambiar el icono dinámicamente."
            return
        }

        UIApplication.shared.setAlternateIconName(choice.alternateName) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.status = "No se pudo cambiar el icono: \(error.localizedDescription)"
                } else {
                    self?.selectedID = choice.id
                    self?.status = "Icono cambiado a «\(choice.title)»."
                }
            }
        }
    }
}

struct AppIconPickerView: View {
    @StateObject private var manager = AppIconManager()

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Icono de la app", systemImage: "app.badge")
                .font(.headline)

            Text("Puedes cambiarlo cuando quieras. iOS mostrará una confirmación del sistema.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AppIconManager.choices) { choice in
                    Button {
                        manager.select(choice)
                    } label: {
                        VStack(spacing: 8) {
                            Image(choice.assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            Text(choice.title)
                                .font(.caption.bold())
                                .multilineTextAlignment(.center)

                            Image(systemName: manager.selectedID == choice.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(manager.selectedID == choice.id ? .green : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                    }
                    .buttonStyle(.plain)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }

            if let status = manager.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .onAppear { manager.refresh() }
    }
}
