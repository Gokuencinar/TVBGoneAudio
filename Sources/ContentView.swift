import SwiftUI

struct ContentView: View {
    @StateObject private var transmitter = IRTransmitter()
    @State private var category: IRDeviceCategory = .television
    @State private var region: TVRegion = .europe

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: category.systemImage)
                        .font(.system(size: 68))
                        .symbolRenderingMode(.hierarchical)

                    Text("IR Universal Audio")
                        .font(.largeTitle.bold())

                    Picker(
                        "Tipo de dispositivo",
                        selection: $category
                    ) {
                        ForEach(
                            IRDeviceCategory.allCases
                        ) { item in
                            Text(item.rawValue)
                                .tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(transmitter.isSending)

                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {
                        Text(category.title)
                            .font(.title2.bold())

                        Text(category.explanation)
                            .foregroundStyle(.secondary)

                        Text(
                            "\(transmitter.codeCount(for: category, region: region)) códigos disponibles"
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )

                    if category == .television {
                        Picker(
                            "Región TV-B-Gone",
                            selection: $region
                        ) {
                            ForEach(
                                TVRegion.allCases
                            ) { item in
                                Text(item.rawValue)
                                    .tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(transmitter.isSending)
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        Label(
                            transmitter.routeDescription,
                            systemImage: "cable.connector"
                        )

                        if transmitter.sampleRate > 0 {
                            Label(
                                "\(Int(transmitter.sampleRate)) Hz",
                                systemImage: "waveform"
                            )
                        }

                        Label(
                            "Audio mono: DESACTIVADO",
                            systemImage: "ear.and.waveform"
                        )

                        Label(
                            "Balance centrado · volumen multimedia 100 %",
                            systemImage: "speaker.wave.3.fill"
                        )
                    }
                    .font(.subheadline)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding()
                    .background(
                        .thinMaterial,
                        in: RoundedRectangle(
                            cornerRadius: 16
                        )
                    )

                    if transmitter.isSending {
                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ProgressView(
                                value: transmitter.progress
                            )

                            Text(
                                "\(transmitter.sentCount) / \(transmitter.totalCount)"
                            )
                            .font(.caption.monospacedDigit())

                            if let codeID =
                                transmitter.currentCodeID
                            {
                                Text("Código actual")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(codeID)
                                    .font(
                                        .system(
                                            size: 11,
                                            design: .monospaced
                                        )
                                    )
                                    .lineLimit(3)
                                    .textSelection(.enabled)
                            }

                            if transmitter.skippedCount > 0 {
                                Text(
                                    "\(transmitter.skippedCount) omitidos porque la portadora supera lo reproducible por esta salida de audio."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                    }

                    Button {
                        if transmitter.isSending {
                            transmitter.stop()
                        } else {
                            transmitter.start(
                                category: category,
                                region: region
                            )
                        }
                    } label: {
                        Label(
                            transmitter.isSending
                                ? "DETENER"
                                : category.buttonTitle,
                            systemImage:
                                transmitter.isSending
                                ? "stop.fill"
                                : "power"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Divider()

                    DisclosureGroup("Diagnóstico") {
                        VStack(
                            alignment: .leading,
                            spacing: 12
                        ) {
                            Button(
                                "Probar portadora 38 kHz durante 1 s"
                            ) {
                                transmitter.testCarrier()
                            }
                            .buttonStyle(.bordered)
                            .disabled(transmitter.isSending)

                            Text(
                                "Si el LED emite pero ningún aparato responde, revisa primero Audio mono, balance y volumen."
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }

                    if let warning =
                        transmitter.warning
                    {
                        Text(warning)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                    }

                    Text(
                        "Usa el emisor únicamente con equipos que tengas permiso para controlar. En aires acondicionados algunos mandos codifican el estado completo; esta base prioriza señales OFF/POWER conocidas y omite protocolos que no puede reconstruir con seguridad."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
