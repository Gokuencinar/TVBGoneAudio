import SwiftUI

struct ContentView: View {
    @StateObject private var transmitter = IRTransmitter()
    @State private var region: TVRegion = .europe

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: 80))
                        .symbolRenderingMode(.hierarchical)

                    Text("TV-B-Gone Audio")
                        .font(.largeTitle.bold())

                    Text("Compatibilidad ampliada: prueba primero códigos universales comunes y después la base TV-B-Gone.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Picker("Región", selection: $region) {
                        ForEach(TVRegion.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(transmitter.isSending)

                    VStack(alignment: .leading, spacing: 8) {
                        Label(transmitter.routeDescription, systemImage: "cable.connector")
                        if transmitter.sampleRate > 0 {
                            Label("\(Int(transmitter.sampleRate)) Hz", systemImage: "waveform")
                        }
                        Label("Audio mono: DESACTIVADO", systemImage: "ear.and.waveform")
                        Label("Balance: centrado · volumen multimedia: 100 %", systemImage: "speaker.wave.3.fill")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    if transmitter.isSending {
                        VStack(spacing: 8) {
                            ProgressView(value: transmitter.progress)
                            Text("\(transmitter.sentCount) / \(transmitter.totalCount) códigos")
                                .font(.caption.monospacedDigit())
                            if transmitter.skippedCount > 0 {
                                Text("\(transmitter.skippedCount) omitidos por portadora no representable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        if transmitter.isSending {
                            transmitter.stop()
                        } else {
                            transmitter.start(region: region)
                        }
                    } label: {
                        Label(
                            transmitter.isSending ? "DETENER" : "APAGAR TELEVISORES",
                            systemImage: transmitter.isSending ? "stop.fill" : "power"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Divider()

                    Text("Diagnóstico")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Probar TD Systems / Vestel (RC5 0x100C)") {
                        transmitter.testVestelTDSystems()
                    }
                    .buttonStyle(.bordered)
                    .disabled(transmitter.isSending)

                    Button("Probar portadora 38 kHz durante 1 s") {
                        transmitter.testCarrier()
                    }
                    .buttonStyle(.bordered)
                    .disabled(transmitter.isSending)

                    if let warning = transmitter.warning {
                        Text(warning)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Para el emisor estéreo, iOS debe tener Ajustes → Accesibilidad → Audio y visual → Audio mono desactivado. Apunta directamente al receptor IR del televisor durante la prueba.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
