import SwiftUI

struct OnlineIRLibraryView: View {
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var learnedSignals: LearnedIRStore
    @ObservedObject var customRemotes: CustomRemoteStore
    @Binding var category: IRDeviceCategory

    @StateObject private var library = OnlineIRLibrary()
    @State private var brand = ""
    @State private var model = ""
    @State private var source: OnlineIRSourceFilter = .all
    @State private var deepSearch = false
    @State private var importURL = ""
    @State private var imported: OnlineIRLoadedRemote?
    @State private var importError: String?
    @State private var importing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Biblioteca IR online", systemImage: "globe")
                        .font(.title2.bold())

                    Text("Busca mandos publicados por la comunidad, pruébalos y guarda los que funcionen para usarlos después sin Internet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DeviceCategoryPicker(category: $category, disabled: library.isSearching)

                    TextField("Marca (ej. TD Systems)", text: $brand)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)

                    TextField("Modelo (opcional)", text: $model)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)

                    Picker("Fuente", selection: $source) {
                        ForEach(OnlineIRSourceFilter.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Búsqueda profunda", isOn: $deepSearch)

                    Button {
                        Task {
                            await library.search(
                                brand: brand,
                                model: model,
                                category: category,
                                filter: source,
                                deep: deepSearch
                            )
                        }
                    } label: {
                        HStack {
                            if library.isSearching {
                                ProgressView()
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text(library.isSearching ? "BUSCANDO…" : "BUSCAR CÓDIGOS")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(library.isSearching)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 10) {
                    Label("Importar desde Internet", systemImage: "link")
                        .font(.headline)

                    Text("También puedes pegar directamente un enlace HTTPS a un archivo .ir o CSV IRDB.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("https://…", text: $importURL)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        importing = true
                        importError = nil
                        Task {
                            do {
                                imported = try await library.importURL(importURL)
                            } catch {
                                importError = error.localizedDescription
                            }
                            importing = false
                        }
                    } label: {
                        Label(importing ? "DESCARGANDO…" : "IMPORTAR URL", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(importing || importURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let importError {
                        Text(importError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Resultados")
                            .font(.headline)
                        Spacer()
                        Text("\(library.results.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Text(library.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if library.results.isEmpty && !library.isSearching {
                        OnlineIREmptyView()
                    } else {
                        ForEach(library.results) { remote in
                            NavigationLink {
                                OnlineIRRemoteDetailView(
                                    remote: remote,
                                    library: library,
                                    transmitter: transmitter,
                                    learnedSignals: learnedSignals,
                                    customRemotes: customRemotes,
                                    category: category
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "remote.fill")
                                        .font(.title2)
                                        .foregroundStyle(.red)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(remote.displayName)
                                            .font(.headline)
                                            .lineLimit(2)
                                        Text("\(remote.source.title) · \(remote.categoryLabel)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(remote.path)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                            }
                            .buttonStyle(.plain)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle("IR online")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $imported) { loaded in
            NavigationStack {
                OnlineIRLoadedRemoteView(
                    loaded: loaded,
                    transmitter: transmitter,
                    learnedSignals: learnedSignals,
                    customRemotes: customRemotes,
                    category: category
                )
            }
        }
    }
}

private struct OnlineIRRemoteDetailView: View {
    let remote: OnlineIRRemote
    @ObservedObject var library: OnlineIRLibrary
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var learnedSignals: LearnedIRStore
    @ObservedObject var customRemotes: CustomRemoteStore
    let category: IRDeviceCategory

    @State private var loaded: OnlineIRLoadedRemote?
    @State private var errorMessage: String?
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(remote.displayName)
                        .font(.title2.bold())
                    Text(remote.source.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(remote.path)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if loading {
                    ProgressView("Descargando mando…")
                        .padding(.vertical, 40)
                } else if let errorMessage {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        Button("Reintentar") { load() }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                } else if let loaded {
                    OnlineIRLoadedRemoteContent(
                        loaded: loaded,
                        transmitter: transmitter,
                        learnedSignals: learnedSignals,
                        customRemotes: customRemotes,
                        category: category
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Mando online")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if loaded == nil { await performLoad() }
        }
    }

    private func load() {
        Task { await performLoad() }
    }

    @MainActor
    private func performLoad() async {
        loading = true
        errorMessage = nil
        do {
            loaded = try await library.download(remote)
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}

private struct OnlineIRLoadedRemoteView: View {
    let loaded: OnlineIRLoadedRemote
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var learnedSignals: LearnedIRStore
    @ObservedObject var customRemotes: CustomRemoteStore
    let category: IRDeviceCategory
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            OnlineIRLoadedRemoteContent(
                loaded: loaded,
                transmitter: transmitter,
                learnedSignals: learnedSignals,
                customRemotes: customRemotes,
                category: category
            )
            .padding()
        }
        .navigationTitle(loaded.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
    }
}

private struct OnlineIRLoadedRemoteContent: View {
    let loaded: OnlineIRLoadedRemote
    @ObservedObject var transmitter: IRTransmitter
    @ObservedObject var learnedSignals: LearnedIRStore
    @ObservedObject var customRemotes: CustomRemoteStore
    let category: IRDeviceCategory

    @State private var message: String?

    private var powerSignals: [ImportedIRSignal] {
        let p = loaded.signals.filter {
            let n = $0.name.lowercased()
            return n.contains("power") || n.contains("on/off") || n == "off"
        }
        return p.isEmpty ? Array(loaded.signals.prefix(3)) : p
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loaded.name)
                    .font(.title3.bold())
                Text(loaded.sourceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(loaded.signals.count) botones compatibles")
                    .font(.caption.monospacedDigit())
            }

            if !powerSignals.isEmpty {
                Text("Prueba rápida")
                    .font(.headline)

                ForEach(powerSignals.prefix(4)) { signal in
                    Button {
                        transmitter.send(code: signal.code)
                    } label: {
                        Label("Probar \(signal.name)", systemImage: "power")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }

            Button {
                customRemotes.createImported(
                    name: loaded.name,
                    category: category,
                    signals: loaded.signals
                )
                message = "Mando guardado en «Mis equipos»."
            } label: {
                Label("GUARDAR MANDO COMPLETO", systemImage: "remote.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Divider()

            Text("Todos los botones")
                .font(.headline)

            ForEach(loaded.signals) { signal in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(signal.name)
                            .font(.subheadline.bold())
                        Text("\(signal.code.carrierHz / 1000) kHz · \(signal.sourceDescription)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        transmitter.send(code: signal.code)
                    } label: {
                        Image(systemName: "wave.3.right")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        learnedSignals.addImported(
                            name: signal.name,
                            category: category,
                            code: signal.code
                        )
                        message = "«\(signal.name)» guardado en la biblioteca local."
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OnlineIREmptyView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("Busca una marca o modelo")
                .font(.headline)
            Text("Para marcas poco comunes, activa «Búsqueda profunda» o prueba sin indicar el modelo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}
