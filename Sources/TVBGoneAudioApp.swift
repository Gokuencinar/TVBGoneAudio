import SwiftUI

@main
struct TVBGoneAudioApp: App {
    @AppStorage(
        "irUniversal.oledMode"
    )
    private var oledMode = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(
                    oledMode
                    ? .dark
                    : nil
                )
                .irOLEDRoot(
                    enabled: oledMode
                )
        }
    }
}
