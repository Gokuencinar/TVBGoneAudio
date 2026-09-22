import SwiftUI
import UIKit

extension View {
    func irCard(
        cornerRadius: CGFloat = 18
    ) -> some View {
        modifier(
            IRCardModifier(
                cornerRadius:
                    cornerRadius
            )
        )
    }

    func irOLEDScreen() -> some View {
        modifier(
            IROLEDScreenModifier()
        )
    }

    func irOLEDRoot(
        enabled: Bool
    ) -> some View {
        modifier(
            IROLEDRootModifier(
                enabled: enabled
            )
        )
    }
}

private struct IRCardModifier:
    ViewModifier
{
    @AppStorage(
        "irUniversal.oledMode"
    )
    private var oledMode = true

    let cornerRadius: CGFloat

    func body(
        content: Content
    ) -> some View {
        if oledMode {
            content
                .background(
                    Color.white.opacity(
                        0.055
                    ),
                    in:
                        RoundedRectangle(
                            cornerRadius:
                                cornerRadius,
                            style:
                                .continuous
                        )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius:
                            cornerRadius,
                        style:
                            .continuous
                    )
                    .stroke(
                        Color.white
                            .opacity(
                                0.075
                            ),
                        lineWidth: 0.7
                    )
                )
        } else {
            content.background(
                .thinMaterial,
                in:
                    RoundedRectangle(
                        cornerRadius:
                            cornerRadius,
                        style:
                            .continuous
                    )
            )
        }
    }
}

private struct IROLEDScreenModifier:
    ViewModifier
{
    @AppStorage(
        "irUniversal.oledMode"
    )
    private var oledMode = true

    func body(
        content: Content
    ) -> some View {
        content
            .background(
                (
                    oledMode
                    ? Color.black
                    : Color(
                        .systemBackground
                    )
                )
                .ignoresSafeArea()
            )
    }
}

private struct IROLEDRootModifier:
    ViewModifier
{
    let enabled: Bool

    func body(
        content: Content
    ) -> some View {
        content
            .background(
                (
                    enabled
                    ? Color.black
                    : Color(
                        .systemBackground
                    )
                )
                .ignoresSafeArea()
            )
            .toolbarBackground(
                enabled
                    ? Color.black
                    : Color(
                        .systemBackground
                    ),
                for: .tabBar
            )
            .toolbarBackground(
                .visible,
                for: .tabBar
            )
    }
}

struct OLEDSettingsCard: View {
    @AppStorage(
        "irUniversal.oledMode"
    )
    private var oledMode = true

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Label(
                    "Pantalla OLED",
                    systemImage:
                        "circle.lefthalf.filled"
                )
                .font(.headline)

                Spacer()

                Toggle(
                    "",
                    isOn: $oledMode
                )
                .labelsHidden()
            }

            Text(
                oledMode
                ? "Negro puro activado. Reduce los píxeles iluminados y aumenta el contraste en pantallas OLED."
                : "Usando la apariencia estándar de iOS."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.black)
                    .frame(
                        width: 26,
                        height: 26
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                Color.white
                                    .opacity(
                                        0.18
                                    )
                            )
                    )

                Circle()
                    .fill(
                        Color.white
                            .opacity(0.08)
                    )
                    .frame(
                        width: 26,
                        height: 26
                    )

                Circle()
                    .fill(Color.red)
                    .frame(
                        width: 26,
                        height: 26
                    )

                Text(
                    "Negro real · superficies mínimas · acento rojo"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .irCard(cornerRadius: 18)
    }
}
