import AVFoundation
import SwiftUI
import UIKit

@MainActor
enum IRHaptics {
    static func tap() {
        UIImpactFeedbackGenerator(
            style: .light
        ).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(
            style: .medium
        ).impactOccurred()
    }

    static func transmit() {
        UIImpactFeedbackGenerator(
            style: .rigid
        ).impactOccurred(
            intensity: 0.75
        )
    }

    static func success() {
        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator()
            .notificationOccurred(.error)
    }
}

struct IRTransmissionHalo: View {
    let trigger: Int

    @State private var phase:
        CGFloat = 1

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) {
                index in

                Circle()
                    .stroke(
                        Color.red.opacity(
                            0.34
                            - Double(index) * 0.07
                        ),
                        lineWidth: 2
                    )
                    .scaleEffect(
                        0.55
                        + phase
                        * (
                            0.55
                            + CGFloat(index) * 0.17
                        )
                    )
                    .opacity(
                        Double(1 - phase)
                    )
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _ in
            phase = 0

            withAnimation(
                .easeOut(duration: 0.72)
            ) {
                phase = 1
            }
        }
    }
}

struct AccessoryStatusCard: View {
    @ObservedObject var transmitter:
        IRTransmitter

    private var ready: Bool {
        transmitter
            .outputRouteSuitableForIR
    }

    private var volumeReady: Bool {
        transmitter.outputVolume >= 0.90
    }

    private var title: String {
        if ready && volumeReady {
            return "Listo para transmitir"
        }

        if ready {
            return "Emisor detectado"
        }

        return "Comprueba el accesorio"
    }

    private var tint: Color {
        if ready && volumeReady {
            return .green
        }

        return .orange
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            tint.opacity(0.15)
                        )
                        .frame(
                            width: 42,
                            height: 42
                        )

                    Image(
                        systemName:
                            ready
                            ? "checkmark.circle.fill"
                            : "cable.connector"
                    )
                    .foregroundStyle(tint)
                    .font(.title3)
                }

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(title)
                        .font(.headline)

                    Text(
                        transmitter.routeDescription
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }

                Spacer()

                Circle()
                    .fill(tint)
                    .frame(
                        width: 9,
                        height: 9
                    )
                    .shadow(
                        color: tint.opacity(0.45),
                        radius: 5
                    )
            }

            if transmitter.sampleRate > 0 {
                HStack(spacing: 8) {
                    StatusChip(
                        text:
                            "\(transmitter.outputChannels) canales",
                        systemImage:
                            "speaker.wave.2.fill"
                    )

                    StatusChip(
                        text:
                            "\(Int(transmitter.sampleRate / 1000)) kHz",
                        systemImage:
                            "waveform"
                    )

                    StatusChip(
                        text:
                            "\(Int((transmitter.outputVolume * 100).rounded())) %",
                        systemImage:
                            "speaker.wave.3.fill"
                    )
                }
            }

            Text(
                "Recomendado: volumen 100 %, Audio mono desactivado y balance centrado."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if let warning =
                transmitter.warning
            {
                Label(
                    warning,
                    systemImage:
                        "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            LinearGradient(
                colors: [
                    tint.opacity(0.13),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20
            )
            .stroke(
                tint.opacity(0.20),
                lineWidth: 1
            )
        )
    }
}

private struct StatusChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(
            text,
            systemImage: systemImage
        )
        .font(.caption2.bold())
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            .thinMaterial,
            in: Capsule()
        )
    }
}

struct LibraryMetricCard: View {
    let value: Int
    let label: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 5) {
            Image(
                systemName: systemImage
            )
            .foregroundStyle(.red)

            Text("\(value)")
                .font(
                    .title3.bold()
                        .monospacedDigit()
                )

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 82
        )
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 17
            )
        )
    }
}

struct PremiumRemoteTile: View {
    let remote: CustomRemote

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 14
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.22),
                            Color.orange.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: 52,
                    height: 52
                )

                Image(
                    systemName: "remote.fill"
                )
                .font(.title2)
                .foregroundStyle(.red)
            }

            Spacer(minLength: 2)

            Text(remote.name)
                .font(.headline)
                .lineLimit(2)

            Text(
                "\(remote.buttons.count) botones"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(remote.category.title)
                .font(.caption2.bold())
                .foregroundStyle(.red)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 154,
            alignment: .leading
        )
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
    }
}

struct PremiumSavedDeviceCard: View {
    let device: SavedIRDevice

    @ObservedObject var transmitter:
        IRTransmitter
    @ObservedObject var savedDevices:
        SavedDeviceStore

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 15
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.20),
                            Color.orange.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: 54,
                    height: 54
                )

                Image(
                    systemName:
                        device.category.systemImage
                )
                .font(.title3)
                .foregroundStyle(.red)
            }

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(device.name)
                    .font(.headline)

                Text(device.codeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(device.category.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                guard let code =
                    savedDevices.code(
                        for: device
                    )
                else {
                    IRHaptics.error()
                    return
                }

                transmitter.send(
                    code: code
                )
            } label: {
                Image(systemName: "power")
                    .font(.headline)
                    .frame(
                        width: 44,
                        height: 44
                    )
            }
            .buttonStyle(
                .borderedProminent
            )
            .clipShape(Circle())
            .tint(.red)
        }
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
        .contextMenu {
            Button(
                role: .destructive
            ) {
                savedDevices.remove(
                    device
                )
            } label: {
                Label(
                    "Eliminar equipo",
                    systemImage: "trash"
                )
            }
        }
    }
}

struct WorkedCodeRow: View {
    let record: WorkedCodeRecord

    @ObservedObject var transmitter:
        IRTransmitter
    @ObservedObject var history:
        WorkedCodeHistoryStore

    var body: some View {
        HStack(spacing: 12) {
            Image(
                systemName:
                    "checkmark.seal.fill"
            )
            .foregroundStyle(.green)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(record.codeLabel)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Text(
                    "\(record.sourceLabel) · \(record.carrierHz / 1000) kHz"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                    record.createdAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                transmitter.send(
                    code: record.code
                )
            } label: {
                Image(
                    systemName:
                        "wave.3.right"
                )
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 16
            )
        )
        .contextMenu {
            Button(
                role: .destructive
            ) {
                history.remove(record)
            } label: {
                Label(
                    "Eliminar del historial",
                    systemImage: "trash"
                )
            }
        }
    }
}

struct IRWelcomeView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [
        (
            icon: String,
            title: String,
            subtitle: String
        )
    ] = [
        (
            "remote.fill",
            "Todo tu infrarrojo en un sitio",
            "Controla equipos, encuentra códigos online, guarda mandos y conserva los que ya sabes que funcionan."
        ),
        (
            "cable.connector",
            "Máximo alcance",
            "Para este emisor usa volumen al 100 %, balance centrado y Audio mono desactivado."
        ),
        (
            "waveform.badge.mic",
            "Transmitir y aprender son distintos",
            "El emisor puede enviar IR. Para aprender señales necesitas además un receptor IR con una entrada de audio compatible."
        ),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.red.opacity(0.14),
                    Color(.systemBackground),
                    Color.orange.opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Text("IR UNIVERSAL")
                        .font(.caption.bold())
                        .tracking(2)

                    Spacer()

                    Text("5.0")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                TabView(selection: $page) {
                    ForEach(
                        pages.indices,
                        id: \.self
                    ) { index in
                        let item =
                            pages[index]

                        VStack(spacing: 26) {
                            Spacer()

                            ZStack {
                                Circle()
                                    .fill(
                                        Color.red
                                            .opacity(0.12)
                                    )
                                    .frame(
                                        width: 150,
                                        height: 150
                                    )

                                Image(
                                    systemName:
                                        item.icon
                                )
                                .font(
                                    .system(
                                        size: 58,
                                        weight:
                                            .semibold
                                    )
                                )
                                .foregroundStyle(.red)
                            }

                            VStack(spacing: 12) {
                                Text(item.title)
                                    .font(
                                        .largeTitle
                                            .bold()
                                    )
                                    .multilineTextAlignment(
                                        .center
                                    )

                                Text(item.subtitle)
                                    .font(.body)
                                    .foregroundStyle(
                                        .secondary
                                    )
                                    .multilineTextAlignment(
                                        .center
                                    )
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 26)

                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(
                    .page(
                        indexDisplayMode:
                            .always
                    )
                )

                Button {
                    IRHaptics.medium()

                    if page
                        < pages.count - 1
                    {
                        withAnimation {
                            page += 1
                        }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(
                        page
                            == pages.count - 1
                        ? "EMPEZAR"
                        : "CONTINUAR"
                    )
                    .font(.headline)
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding(.vertical, 14)
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(.large)
                .tint(.red)
                .padding()
            }
        }
    }
}
