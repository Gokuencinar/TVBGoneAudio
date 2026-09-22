import SwiftUI

struct ContentView: View {
    @StateObject private var transmitter = IRTransmitter()
    @State private var region: TVRegion = .europe

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: 86))
                        .symbolRenderingMode(.hierarchical)

                    Text("TV-B-Gone Audio")
                        .font(.largeTitle.bold())

                    Text("Envía secuencialmente códigos POWER mediante audio estéreo diferencial para adaptadores IR.")
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
                        Label("Usa volumen multimedia al máximo y salida estéreo.", systemImage: "speaker.wave.3.fill")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    if transmitter.isSending {
                        VStack(spacing: 10) {
                            ProgressView(value: transmitter.progress)
                            Text("\(transmitter.sentCount) / \(transmitter.totalCount) códigos")
                                .font(.caption.monospacedDigit())
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
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

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

                    Text("Consejo: apunta el emisor al televisor y mantenlo orientado mientras avanza la secuencia. Europa está seleccionada por defecto.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
