import SwiftUI
import UIKit

enum IRBrowserPresentation:
    String,
    CaseIterable,
    Identifiable
{
    case list
    case wheel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list:
            return "Lista"
        case .wheel:
            return "Ruleta"
        }
    }

    var systemImage: String {
        switch self {
        case .list:
            return "list.bullet"
        case .wheel:
            return "circle.grid.cross"
        }
    }
}

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

    func irOLEDControlSurface(
        cornerRadius: CGFloat = 10
    ) -> some View {
        modifier(
            IROLEDControlModifier(
                cornerRadius:
                    cornerRadius
            )
        )
    }

    func irOLEDInput(
        cornerRadius: CGFloat = 12
    ) -> some View {
        modifier(
            IROLEDInputModifier(
                cornerRadius:
                    cornerRadius
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

    @AppStorage(
        "irUniversal.cyberpunkMode"
    )
    private var cyberpunkMode = true

    @Environment(
        \.accessibilityReduceTransparency
    )
    private var reduceTransparency

    @Environment(
        \.colorSchemeContrast
    )
    private var contrast

    let cornerRadius: CGFloat

    func body(
        content: Content
    ) -> some View {
        if oledMode && cyberpunkMode {
            content
                .background(
                    LinearGradient(
                        colors: [
                            IRCyberPalette
                                .panelRaised,
                            IRCyberPalette
                                .panel,
                        ],
                        startPoint:
                            .topLeading,
                        endPoint:
                            .bottomTrailing
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
                        LinearGradient(
                            colors: [
                                IRCyberPalette
                                    .cyan
                                    .opacity(
                                        contrast
                                            == .increased
                                        ? 0.66
                                        : 0.34
                                    ),
                                IRCyberPalette
                                    .magenta
                                    .opacity(
                                        contrast
                                            == .increased
                                        ? 0.52
                                        : 0.24
                                    ),
                            ],
                            startPoint:
                                .topLeading,
                            endPoint:
                                .bottomTrailing
                        ),
                        lineWidth:
                            contrast
                                == .increased
                            ? 1.2
                            : 0.75
                    )
                )
                .shadow(
                    color:
                        reduceTransparency
                        ? Color.clear
                        : IRCyberPalette
                            .cyan
                            .opacity(0.10),
                    radius: 12
                )
        } else if oledMode {
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

    @AppStorage(
        "irUniversal.cyberpunkMode"
    )
    private var cyberpunkMode = true

    func body(
        content: Content
    ) -> some View {
        content.background(
            Group {
                if oledMode
                    && cyberpunkMode
                {
                    IRCyberGridBackground()
                } else {
                    (
                        oledMode
                        ? Color.black
                        : Color(
                            .systemBackground
                        )
                    )
                    .ignoresSafeArea()
                }
            }
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
            .toolbarBackground(
                enabled
                    ? Color.black
                    : Color(
                        .systemBackground
                    ),
                for: .navigationBar
            )
            .toolbarBackground(
                .visible,
                for: .navigationBar
            )
    }
}

private struct IROLEDControlModifier:
    ViewModifier
{
    @AppStorage(
        "irUniversal.oledMode"
    )
    private var oledMode = true

    @AppStorage(
        "irUniversal.cyberpunkMode"
    )
    private var cyberpunkMode = true

    let cornerRadius: CGFloat

    func body(
        content: Content
    ) -> some View {
        content
            .tint(
                cyberpunkMode
                ? IRCyberPalette.cyan
                : .red
            )
            .padding(oledMode ? 2 : 0)
            .background(
                oledMode
                    ? Color.white
                        .opacity(
                            cyberpunkMode
                            ? 0.035
                            : 0.045
                        )
                    : Color.clear,
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
                    oledMode
                        ? (
                            cyberpunkMode
                            ? IRCyberPalette
                                .cyan
                                .opacity(0.26)
                            : Color.white
                                .opacity(0.07)
                        )
                        : Color.clear,
                    lineWidth: 0.6
                )
            )
    }
}

private struct IROLEDInputModifier:
    ViewModifier
{
    @AppStorage(
        "irUniversal.oledMode"
    )
    private var oledMode = true

    @AppStorage(
        "irUniversal.cyberpunkMode"
    )
    private var cyberpunkMode = true

    let cornerRadius: CGFloat

    func body(
        content: Content
    ) -> some View {
        content
            .padding(
                .horizontal,
                oledMode ? 12 : 0
            )
            .padding(
                .vertical,
                oledMode ? 11 : 0
            )
            .background(
                oledMode
                    ? Color.white
                        .opacity(
                            cyberpunkMode
                            ? 0.040
                            : 0.055
                        )
                    : Color.clear,
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
                    oledMode
                        ? (
                            cyberpunkMode
                            ? IRCyberPalette
                                .cyan
                                .opacity(0.24)
                            : Color.white
                                .opacity(0.085)
                        )
                        : Color.clear,
                    lineWidth: 0.7
                )
            )
    }
}

struct OLEDSettingsCard: View {
    @AppStorage(
        "irUniversal.oledMode"
    )
    private var oledMode = true

    @AppStorage(
        "irUniversal.cyberpunkMode"
    )
    private var cyberpunkMode = true

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
                    "Pantalla OLED",
                    isOn: $oledMode
                )
                .labelsHidden()
                .accessibilityLabel(
                    "Pantalla OLED"
                )
                .onChange(
                    of: oledMode
                ) { enabled in
                    if !enabled {
                        cyberpunkMode = false
                    }
                }
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
