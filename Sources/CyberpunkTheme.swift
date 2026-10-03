import SwiftUI

enum IRCyberPalette {
    static let cyan = Color(
        red: 0.05,
        green: 0.92,
        blue: 1.00
    )

    static let magenta = Color(
        red: 1.00,
        green: 0.12,
        blue: 0.72
    )

    static let signalRed = Color(
        red: 1.00,
        green: 0.18,
        blue: 0.26
    )

    static let success = Color(
        red: 0.22,
        green: 1.00,
        blue: 0.55
    )

    static let warning = Color(
        red: 1.00,
        green: 0.72,
        blue: 0.12
    )

    static let panel = Color(
        red: 0.018,
        green: 0.025,
        blue: 0.035
    )

    static let panelRaised = Color(
        red: 0.035,
        green: 0.045,
        blue: 0.060
    )
}

struct IRCyberGridBackground: View {
    @AppStorage(
        "irUniversal.cyberpunkMode"
    )
    private var cyberpunkMode = true

    @Environment(
        \.accessibilityReduceTransparency
    )
    private var reduceTransparency

    var body: some View {
        ZStack {
            Color.black

            if cyberpunkMode {
                LinearGradient(
                    colors: [
                        IRCyberPalette.cyan
                            .opacity(
                                reduceTransparency
                                ? 0.025
                                : 0.075
                            ),
                        Color.clear,
                        IRCyberPalette.magenta
                            .opacity(
                                reduceTransparency
                                ? 0.020
                                : 0.060
                            ),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if !reduceTransparency {
                    Canvas { context, size in
                        let spacing: CGFloat = 34

                        var minor = Path()
                        var x: CGFloat = 0

                        while x <= size.width {
                            minor.move(
                                to: CGPoint(
                                    x: x,
                                    y: 0
                                )
                            )
                            minor.addLine(
                                to: CGPoint(
                                    x: x,
                                    y: size.height
                                )
                            )
                            x += spacing
                        }

                        var y: CGFloat = 0

                        while y <= size.height {
                            minor.move(
                                to: CGPoint(
                                    x: 0,
                                    y: y
                                )
                            )
                            minor.addLine(
                                to: CGPoint(
                                    x: size.width,
                                    y: y
                                )
                            )
                            y += spacing
                        }

                        context.stroke(
                            minor,
                            with: .color(
                                IRCyberPalette.cyan
                                    .opacity(0.035)
                            ),
                            lineWidth: 0.45
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct IRCyberBadge: View {
    let text: String
    let systemImage: String
    var tint: Color = IRCyberPalette.cyan

    var body: some View {
        Label(
            text,
            systemImage: systemImage
        )
        .font(
            .caption2
                .monospaced()
                .bold()
        )
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            tint.opacity(0.09),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(
                    tint.opacity(0.34),
                    lineWidth: 0.7
                )
        )
    }
}

struct IRCyberProgressBar: View {
    let value: Double
    var tint: Color = IRCyberPalette.cyan

    private var clamped: Double {
        min(
            1,
            max(0, value)
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        Color.white
                            .opacity(0.055)
                    )

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint,
                                IRCyberPalette.magenta,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width:
                            proxy.size.width
                            * clamped
                    )
                    .shadow(
                        color:
                            tint.opacity(0.34),
                        radius: 6
                    )
            }
        }
        .frame(height: 7)
        .accessibilityElement()
        .accessibilityLabel(
            "Progreso"
        )
        .accessibilityValue(
            "\(Int((clamped * 100).rounded())) por ciento"
        )
    }
}

struct IRCyberActionButtonStyle: ButtonStyle {
    let tint: Color

    @Environment(\.isEnabled)
    private var isEnabled

    @Environment(
        \.accessibilityReduceMotion
    )
    private var reduceMotion

    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .foregroundStyle(
                isEnabled
                ? Color.white
                : Color.secondary
            )
            .background(
                LinearGradient(
                    colors: [
                        tint.opacity(
                            isEnabled
                            ? 0.92
                            : 0.20
                        ),
                        IRCyberPalette.magenta
                            .opacity(
                                isEnabled
                                ? 0.62
                                : 0.12
                            ),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    tint.opacity(
                        isEnabled
                        ? 0.78
                        : 0.18
                    ),
                    lineWidth: 0.9
                )
            )
            .shadow(
                color:
                    tint.opacity(
                        isEnabled
                        ? 0.24
                        : 0
                    ),
                radius: 10
            )
            .scaleEffect(
                configuration.isPressed
                ? 0.985
                : 1
            )
            .opacity(
                configuration.isPressed
                ? 0.88
                : 1
            )
            .animation(
                reduceMotion
                ? nil
                : .easeOut(
                    duration: 0.12
                ),
                value:
                    configuration.isPressed
            )
    }
}

struct IRCyberSettingsCard: View {
    @AppStorage(
        "irUniversal.cyberpunkMode"
    )
    private var cyberpunkMode = true

    @AppStorage(
        "irUniversal.keepAwakeDuringActivity"
    )
    private var keepAwake = true

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Label(
                    "Interfaz Cyberpunk",
                    systemImage:
                        "cpu.fill"
                )
                .font(.headline)

                Spacer()

                Toggle(
                    "",
                    isOn:
                        $cyberpunkMode
                )
                .labelsHidden()
                .tint(
                    IRCyberPalette.cyan
                )
            }

            Text(
                cyberpunkMode
                ? "HUD neon, rejilla OLED, bordes luminosos y telemetría estilo terminal."
                : "Usando el tema OLED clásico."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()
                .overlay(
                    IRCyberPalette.cyan
                        .opacity(0.14)
                )

            Toggle(
                isOn: $keepAwake
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(
                        "Mantener pantalla activa"
                    )
                    .font(.subheadline.bold())

                    Text(
                        "Evita que el iPhone se bloquee durante barridos y capturas IR."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .tint(
                IRCyberPalette.cyan
            )

            HStack(spacing: 8) {
                IRCyberBadge(
                    text: "OLED",
                    systemImage:
                        "circle.fill"
                )

                IRCyberBadge(
                    text: "NEON HUD",
                    systemImage:
                        "waveform.path.ecg",
                    tint:
                        IRCyberPalette.magenta
                )

                IRCyberBadge(
                    text: "IR LINK",
                    systemImage:
                        "dot.radiowaves.right",
                    tint:
                        IRCyberPalette.signalRed
                )
            }
        }
        .padding()
        .irCard(
            cornerRadius: 18
        )
    }
}
