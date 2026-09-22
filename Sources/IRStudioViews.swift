import SwiftUI
import UniformTypeIdentifiers

struct IRWaveformView: View {
    let durations: [UInt32]

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !durations.isEmpty else {
                    return
                }

                let shown =
                    Array(
                        durations.prefix(160)
                    )

                let total =
                    max(
                        1.0,
                        shown.reduce(0.0) {
                            $0 + Double($1)
                        }
                    )

                var x = 0.0
                let highY =
                    size.height * 0.25
                let lowY =
                    size.height * 0.75

                var path = Path()
                path.move(
                    to: CGPoint(
                        x: 0,
                        y: highY
                    )
                )

                for (
                    index,
                    duration
                ) in shown.enumerated()
                {
                    let width =
                        size.width
                        * Double(duration)
                        / total

                    let y =
                        index % 2 == 0
                        ? highY
                        : lowY

                    path.addLine(
                        to: CGPoint(
                            x: x,
                            y: y
                        )
                    )

                    x += width

                    path.addLine(
                        to: CGPoint(
                            x: x,
                            y: y
                        )
                    )

                    if index + 1
                        < shown.count
                    {
                        let nextY =
                            (index + 1) % 2 == 0
                            ? highY
                            : lowY

                        path.addLine(
                            to: CGPoint(
                                x: x,
                                y: nextY
                            )
                        )
                    }
                }

                context.stroke(
                    path,
                    with: .color(.primary),
                    lineWidth: 2
                )
            }
        }
        .frame(height: 110)
        .padding(8)
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 14
            )
        )
        .accessibilityLabel(
            "Gráfica de la señal infrarroja"
        )
    }
}

struct IRAnalysisCard: View {
    let code: IRCode
    let category: IRDeviceCategory

    private var guesses:
        [IRProtocolGuess] {
        IRSignalAnalyzer.analyze(
            code: code
        )
    }

    private var matches:
        [IRDatabaseMatch] {
        IRSignalAnalyzer.bestDatabaseMatches(
            for: code,
            category: category,
            limit: 5
        )
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Label(
                "Analizador IR",
                systemImage: "waveform.path.ecg"
            )
            .font(.headline)

            if let best = guesses.first {
                LabeledContent(
                    "Protocolo probable",
                    value: best.name
                )

                LabeledContent(
                    "Confianza",
                    value:
                        "\(Int(best.confidence * 100)) %"
                )

                Text(best.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let data =
                    best.dataHex
                {
                    Text(data)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            } else {
                Text(
                    "No coincide con suficiente claridad con los protocolos conocidos. Se conservará como RAW, que sigue siendo totalmente reproducible."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Divider()

            Text("Coincidencias en la base")
                .font(.subheadline.bold())

            if matches.isEmpty {
                Text(
                    "No hay coincidencias fuertes entre los códigos POWER/OFF de la base."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ForEach(matches) { match in
                    HStack {
                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {
                            Text(match.name)
                                .font(.caption)

                            Text(match.source)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(
                            "\(Int(match.score * 100)) %"
                        )
                        .font(.caption.monospacedDigit())
                    }
                }
            }
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

struct LearnedSignalDetailView: View {
    let signal: LearnedIRSignal

    @ObservedObject var transmitter:
        IRTransmitter

    @State private var showExporter =
        false

    private var exportDocument:
        FlipperIRDocument {
        FlipperIRDocument(
            text:
                FlipperIRCodec.exportRaw(
                    name: signal.name,
                    code: signal.code
                )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    Text(signal.name)
                        .font(.title2.bold())

                    LabeledContent(
                        "Categoría",
                        value:
                            signal.category.title
                    )

                    LabeledContent(
                        "Portadora",
                        value:
                            "\(signal.carrierHz) Hz"
                    )

                    LabeledContent(
                        "Tiempos",
                        value:
                            "\(signal.durationsMicros.count)"
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

                IRWaveformView(
                    durations:
                        signal.durationsMicros
                )

                IRAnalysisCard(
                    code: signal.code,
                    category: signal.category
                )

                Button {
                    transmitter.send(
                        code: signal.code
                    )
                } label: {
                    Label(
                        "PROBAR",
                        systemImage: "wave.3.right"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(
                    .borderedProminent
                )
                .tint(.red)

                Button {
                    showExporter = true
                } label: {
                    Label(
                        "Exportar como Flipper .ir",
                        systemImage:
                            "square.and.arrow.up"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("Señal IR")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .flipperIR,
            defaultFilename:
                "\(safeFilename(signal.name)).ir"
        ) { _ in }
    }

    private func safeFilename(
        _ value: String
    ) -> String {
        let allowed =
            CharacterSet
            .alphanumerics
            .union(
                CharacterSet(
                    charactersIn:
                        "-_"
                )
            )

        return value
            .unicodeScalars
            .map {
                allowed.contains($0)
                ? String($0)
                : "_"
            }
            .joined()
    }
}

struct RemoteBuilderView: View {
    @ObservedObject var learnedSignals:
        LearnedIRStore

    @ObservedObject var remoteStore:
        CustomRemoteStore

    @Environment(\.dismiss)
    private var dismiss

    @State private var name =
        "Mi mando"

    @State private var category:
        IRDeviceCategory = .television

    @State private var selected =
        Set<UUID>()

    private var available:
        [LearnedIRSignal] {
        learnedSignals.signals
            .filter {
                $0.category == category
            }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mando") {
                    TextField(
                        "Nombre",
                        text: $name
                    )

                    Picker(
                        "Tipo",
                        selection: $category
                    ) {
                        ForEach(
                            IRDeviceCategory
                                .allCases
                        ) { item in
                            Text(item.title)
                                .tag(item)
                        }
                    }
                }

                Section(
                    "Botones (\(selected.count))"
                ) {
                    if available.isEmpty {
                        Text(
                            "Primero aprende o importa algún botón de esta categoría."
                        )
                        .foregroundStyle(.secondary)
                    }

                    ForEach(available) {
                        signal in

                        Button {
                            if selected.contains(
                                signal.id
                            ) {
                                selected.remove(
                                    signal.id
                                )
                            } else {
                                selected.insert(
                                    signal.id
                                )
                            }
                        } label: {
                            HStack {
                                Text(signal.name)

                                Spacer()

                                Image(
                                    systemName:
                                        selected.contains(
                                            signal.id
                                        )
                                        ? "checkmark.circle.fill"
                                        : "circle"
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Button {
                        let signals =
                            available.filter {
                                selected.contains(
                                    $0.id
                                )
                            }

                        remoteStore.create(
                            name: name,
                            category: category,
                            signals: signals
                        )

                        dismiss()
                    } label: {
                        Label(
                            "Crear mando",
                            systemImage: "remote.fill"
                        )
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .navigationTitle("Nuevo mando")
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CustomRemoteView: View {
    let remote: CustomRemote

    @ObservedObject var transmitter:
        IRTransmitter

    @State private var showExporter = false

    private var exportDocument: FlipperIRDocument {
        FlipperIRDocument(
            text: FlipperIRCodec.exportRemote(remote)
        )
    }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(
                        .flexible()
                    ),
                    GridItem(
                        .flexible()
                    ),
                ],
                spacing: 12
            ) {
                ForEach(remote.buttons) {
                    button in

                    Button {
                        transmitter.send(
                            code: button.code
                        )
                    } label: {
                        VStack(spacing: 8) {
                            Image(
                                systemName:
                                    iconName(
                                        for:
                                            button.name
                                    )
                            )
                            .font(.title2)

                            Text(button.name)
                                .font(.headline)
                                .lineLimit(2)
                                .minimumScaleFactor(
                                    0.75
                                )
                        }
                        .frame(
                            maxWidth:
                                .infinity,
                            minHeight: 88
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .tint(
                        button.name
                            .lowercased()
                            .contains("power")
                        ? .red
                        : .accentColor
                    )
                }
            }
            .padding()
        }
        .navigationTitle(remote.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showExporter = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .flipperIR,
            defaultFilename: "\(safeFilename(remote.name)).ir"
        ) { _ in }
    }

    private func safeFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map {
            allowed.contains($0) ? String($0) : "_"
        }.joined()
    }

    private func iconName(
        for name: String
    ) -> String {
        let n =
            name.lowercased()

        if n.contains("power")
            || n.contains("encend")
            || n.contains("apag")
        {
            return "power"
        }

        if n.contains("vol")
            && (
                n.contains("+")
                || n.contains("up")
            )
        {
            return "speaker.plus.fill"
        }

        if n.contains("vol")
            && (
                n.contains("-")
                || n.contains("down")
            )
        {
            return "speaker.minus.fill"
        }

        if n.contains("mute") {
            return "speaker.slash.fill"
        }

        if n.contains("input")
            || n.contains("source")
        {
            return "rectangle.on.rectangle"
        }

        if n.contains("menu") {
            return "list.bullet"
        }

        if n.contains("ok")
            || n.contains("enter")
        {
            return "checkmark.circle.fill"
        }

        return "dot.radiowaves.left.and.right"
    }
}
