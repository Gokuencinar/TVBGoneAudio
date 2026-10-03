import SwiftUI

@main
struct TVBGoneAudioApp: App {
    @AppStorage(
        "irUniversal.oledMode"
    )
    private var oledMode = true

    @AppStorage(
        "irUniversal.cyberpunkMode"
    )
    private var cyberpunkMode = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(
                    oledMode
                    || cyberpunkMode
                    ? .dark
                    : nil
                )
                .irOLEDRoot(
                    enabled:
                        oledMode
                        || cyberpunkMode
                )
        }
    }
}
