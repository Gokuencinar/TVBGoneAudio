import Foundation

struct IRProtocolGuess: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let confidence: Double
    let summary: String
    let dataHex: String?
}

struct IRDatabaseMatch: Identifiable, Equatable {
    let id: String
    let name: String
    let source: String
    let score: Double
    let carrierHz: Int
}

enum IRSignalAnalyzer {
    static func analyze(
        code: IRCode
    ) -> [IRProtocolGuess] {
        let d = code.durationsMicros
        guard d.count >= 4 else { return [] }

        var guesses: [IRProtocolGuess] = []

        if let guess = decodePulseDistance(
            durations: d,
            protocolName: "NEC / NEC Extended",
            headerMark: 9000,
            headerSpace: 4500,
            bitMark: 562,
            zeroSpace: 562,
            oneSpace: 1687,
            bitCount: 32,
            carrier: code.carrierHz,
            expectedCarrier: 38_000
        ) {
            let bytes = guess.bytes
            let classic =
                bytes.count >= 4
                && bytes[1] == ~bytes[0]
                && bytes[3] == ~bytes[2]

            let name =
                classic
                ? "NEC"
                : "NEC Extended"

            guesses.append(
                IRProtocolGuess(
                    name: name,
                    confidence: guess.confidence,
                    summary:
                        classic
                        ? "Dirección \(hex(bytes[0])) · comando \(hex(bytes[2]))"
                        : "32 bits LSB-first",
                    dataHex: bytesHex(bytes)
                )
            )
        }

        if let guess = decodePulseDistance(
            durations: d,
            protocolName: "Samsung32",
            headerMark: 4500,
            headerSpace: 4500,
            bitMark: 550,
            zeroSpace: 550,
            oneSpace: 1650,
            bitCount: 32,
            carrier: code.carrierHz,
            expectedCarrier: 38_000
        ) {
            guesses.append(
                IRProtocolGuess(
                    name: "Samsung32",
                    confidence: guess.confidence,
                    summary: "32 bits LSB-first",
                    dataHex: bytesHex(guess.bytes)
                )
            )
        }

        if let guess = decodePulseDistance(
            durations: d,
            protocolName: "JVC",
            headerMark: 8400,
            headerSpace: 4200,
            bitMark: 525,
            zeroSpace: 525,
            oneSpace: 1575,
            bitCount: 16,
            carrier: code.carrierHz,
            expectedCarrier: 38_000
        ) {
            guesses.append(
                IRProtocolGuess(
                    name: "JVC",
                    confidence: guess.confidence,
                    summary: "16 bits LSB-first",
                    dataHex: bytesHex(guess.bytes)
                )
            )
        }

        if let guess = decodePulseDistance(
            durations: d,
            protocolName: "RCA",
            headerMark: 4000,
            headerSpace: 4000,
            bitMark: 500,
            zeroSpace: 1000,
            oneSpace: 2000,
            bitCount: 24,
            carrier: code.carrierHz,
            expectedCarrier: 38_000
        ) {
            guesses.append(
                IRProtocolGuess(
                    name: "RCA",
                    confidence: guess.confidence,
                    summary: "24 bits LSB-first",
                    dataHex: bytesHex(guess.bytes)
                )
            )
        }

        if let guess = decodePulseDistance(
            durations: d,
            protocolName: "Kaseikyo",
            headerMark: 3456,
            headerSpace: 1728,
            bitMark: 432,
            zeroSpace: 432,
            oneSpace: 1296,
            bitCount: 48,
            carrier: code.carrierHz,
            expectedCarrier: 38_000
        ) {
            guesses.append(
                IRProtocolGuess(
                    name: "Kaseikyo / Panasonic",
                    confidence: guess.confidence,
                    summary: "48 bits LSB-first",
                    dataHex: bytesHex(guess.bytes)
                )
            )
        }

        if let guess = decodePulseDistance(
            durations: d,
            protocolName: "Pioneer",
            headerMark: 8500,
            headerSpace: 4225,
            bitMark: 500,
            zeroSpace: 500,
            oneSpace: 1500,
            bitCount: 33,
            carrier: code.carrierHz,
            expectedCarrier: 40_000
        ) {
            guesses.append(
                IRProtocolGuess(
                    name: "Pioneer",
                    confidence: guess.confidence,
                    summary: "32 bits LSB-first",
                    dataHex: bytesHex(guess.bytes)
                )
            )
        }

        if let sony = decodeSony(
            durations: d,
            carrier: code.carrierHz
        ) {
            guesses.append(sony)
        }

        if let manchester = detectManchester(
            durations: d,
            carrier: code.carrierHz
        ) {
            guesses.append(manchester)
        }

        return guesses
            .filter { $0.confidence >= 0.45 }
            .sorted { $0.confidence > $1.confidence }
    }

    static func recommendedCarrierHz(
        for code: IRCode
    ) -> Int {
        guard
            let best =
                analyze(code: code).first
        else {
            return 38_000
        }

        let name =
            best.name.lowercased()

        if name.contains("rc5")
            || name.contains("rc6")
        {
            return 36_000
        }

        if name.contains("sony")
            || name.contains("sirc")
            || name.contains("pioneer")
        {
            return 40_000
        }

        // NEC, NEC Extended, Samsung32, JVC, RCA and
        // Kaseikyo/Panasonic are normally around 38 kHz.
        return 38_000
    }

    static func bestDatabaseMatches(
        for code: IRCode,
        category: IRDeviceCategory,
        limit: Int = 5
    ) -> [IRDatabaseMatch] {
        let candidates =
            IRCodeCatalog.allCodes(
                for: category
            )

        return candidates
            .compactMap { candidate -> IRDatabaseMatch? in
                let score =
                    similarity(
                        code,
                        candidate
                    )

                guard score >= 0.35 else {
                    return nil
                }

                return IRDatabaseMatch(
                    id: candidate.id,
                    name: candidate.displayName,
                    source: candidate.sourceLabel,
                    score: score,
                    carrierHz:
                        candidate.carrierHz
                )
            }
            .sorted { $0.score > $1.score }
            .prefix(max(1, limit))
            .map { $0 }
    }

    static func similarity(
        _ first: IRCode,
        _ second: IRCode
    ) -> Double {
        let a = first.durationsMicros
        let b = second.durationsMicros

        guard
            a.count >= 4,
            b.count >= 4
        else {
            return 0
        }

        let lengthRatio =
            Double(min(a.count, b.count))
            / Double(max(a.count, b.count))

        guard lengthRatio >= 0.72 else {
            return 0
        }

        let compareCount =
            min(a.count, b.count)

        var error = 0.0

        for index in 0..<compareCount {
            let av = Double(a[index])
            let bv = Double(b[index])
            let denom =
                max(200.0, max(av, bv))

            error +=
                min(
                    1.0,
                    abs(av - bv) / denom
                )
        }

        error /= Double(compareCount)

        let firstCarrier =
            first.carrierHz == 0
            ? 38_000
            : first.carrierHz

        let secondCarrier =
            second.carrierHz == 0
            ? 38_000
            : second.carrierHz

        let carrierError =
            min(
                1.0,
                Double(
                    abs(
                        firstCarrier
                        - secondCarrier
                    )
                ) / 12_000.0
            )

        let score =
            (1.0 - error)
            * lengthRatio
            * (1.0 - 0.18 * carrierError)

        return max(
            0,
            min(1, score)
        )
    }

    static func captureConsistency(
        _ captures: [IRCaptureResult]
    ) -> Double? {
        guard captures.count >= 2 else {
            return nil
        }

        var scores: [Double] = []

        for index in 0..<(captures.count - 1) {
            for second in (index + 1)..<captures.count {
                let firstCode = IRCode(
                    id: "capture-a",
                    carrierHz: 38_000,
                    durationsMicros:
                        captures[index].durationsMicros
                )
                let secondCode = IRCode(
                    id: "capture-b",
                    carrierHz: 38_000,
                    durationsMicros:
                        captures[second].durationsMicros
                )

                scores.append(
                    similarity(
                        firstCode,
                        secondCode
                    )
                )
            }
        }

        guard !scores.isEmpty else {
            return nil
        }

        return scores.reduce(0, +)
            / Double(scores.count)
    }

    static func consensus(
        captures: [IRCaptureResult]
    ) -> IRCaptureResult? {
        guard !captures.isEmpty else {
            return nil
        }

        let reference =
            captures.max {
                $0.durationsMicros.count
                    < $1.durationsMicros.count
            }!

        let compatible =
            captures.filter {
                let a =
                    Double(
                        min(
                            $0.durationsMicros.count,
                            reference.durationsMicros.count
                        )
                    )
                let b =
                    Double(
                        max(
                            $0.durationsMicros.count,
                            reference.durationsMicros.count
                        )
                    )

                return b > 0
                    && a / b >= 0.90
            }

        guard compatible.count >= 2 else {
            return reference
        }

        let count =
            compatible.map {
                $0.durationsMicros.count
            }.min() ?? reference.durationsMicros.count

        var output: [UInt32] = []
        output.reserveCapacity(count)

        for index in 0..<count {
            let values =
                compatible.map {
                    $0.durationsMicros[index]
                }
                .sorted()

            output.append(
                values[values.count / 2]
            )
        }

        return IRCaptureResult(
            durationsMicros: output,
            sampleRate:
                compatible.map {
                    $0.sampleRate
                }.reduce(0, +)
                / Double(compatible.count),
            edgeCount:
                compatible.map {
                    $0.edgeCount
                }.max() ?? 0,
            peakLevel:
                compatible.map {
                    $0.peakLevel
                }.max() ?? 0
        )
    }

    private struct PulseDecode {
        let bytes: [UInt8]
        let confidence: Double
    }

    private static func decodePulseDistance(
        durations: [UInt32],
        protocolName: String,
        headerMark: Double,
        headerSpace: Double,
        bitMark: Double,
        zeroSpace: Double,
        oneSpace: Double,
        bitCount: Int,
        carrier: Int,
        expectedCarrier: Int
    ) -> PulseDecode? {
        let needed =
            2 + bitCount * 2

        guard durations.count >= needed else {
            return nil
        }

        // Avoid mistaking the prefix of a substantially longer protocol
        // for a shorter pulse-distance protocol (for example NEC as JVC).
        if durations.count > needed + 6 {
            let end = min(
                durations.count,
                needed + 5
            )
            let hasFrameGap =
                durations[needed..<end]
                .contains { $0 >= 20_000 }

            if !hasFrameGap {
                return nil
            }
        }

        guard
            close(
                durations[0],
                headerMark,
                tolerance: 0.30
            ),
            close(
                durations[1],
                headerSpace,
                tolerance: 0.30
            )
        else {
            return nil
        }

        var bytes =
            [UInt8](
                repeating: 0,
                count: (bitCount + 7) / 8
            )

        var accumulatedError = 0.0
        var measurements = 2

        accumulatedError +=
            relativeError(
                durations[0],
                headerMark
            )
        accumulatedError +=
            relativeError(
                durations[1],
                headerSpace
            )

        for bit in 0..<bitCount {
            let markIndex =
                2 + bit * 2
            let spaceIndex =
                markIndex + 1

            let mark =
                durations[markIndex]
            let space =
                durations[spaceIndex]

            guard
                close(
                    mark,
                    bitMark,
                    tolerance: 0.42
                )
            else {
                return nil
            }

            accumulatedError +=
                relativeError(
                    mark,
                    bitMark
                )
            measurements += 1

            let zeroError =
                relativeError(
                    space,
                    zeroSpace
                )
            let oneError =
                relativeError(
                    space,
                    oneSpace
                )

            let isOne =
                oneError < zeroError

            let bestError =
                min(
                    zeroError,
                    oneError
                )

            guard bestError <= 0.42 else {
                return nil
            }

            accumulatedError +=
                bestError
            measurements += 1

            if isOne {
                bytes[bit / 8] |=
                    UInt8(
                        1 << (bit % 8)
                    )
            }
        }

        var confidence =
            1.0
            - min(
                1.0,
                accumulatedError
                    / Double(measurements)
            )

        if carrier > 0 {
            let carrierPenalty =
                min(
                    0.20,
                    Double(
                        abs(
                            carrier
                            - expectedCarrier
                        )
                    ) / 50_000.0
                )

            confidence -= carrierPenalty
        }

        return PulseDecode(
            bytes: bytes,
            confidence:
                max(
                    0,
                    min(1, confidence)
                )
        )
    }

    private static func decodeSony(
        durations: [UInt32],
        carrier: Int
    ) -> IRProtocolGuess? {
        guard
            durations.count >= 2 + 12 * 2,
            close(
                durations[0],
                2400,
                tolerance: 0.35
            ),
            close(
                durations[1],
                600,
                tolerance: 0.35
            )
        else {
            return nil
        }

        for bitCount in [20, 15, 12] {
            let needed =
                2 + bitCount * 2

            guard durations.count >= needed else {
                continue
            }

            var value: UInt32 = 0
            var error = 0.0
            var valid = true

            for bit in 0..<bitCount {
                let mark =
                    durations[2 + bit * 2]
                let space =
                    durations[3 + bit * 2]

                // Sony replaces the final nominal space with the
                // remainder of the frame period, so only validate
                // ordinary inter-bit spaces.
                if bit < bitCount - 1 {
                    guard
                        close(
                            space,
                            600,
                            tolerance: 0.45
                        )
                    else {
                        valid = false
                        break
                    }
                }

                let zeroError =
                    relativeError(
                        mark,
                        600
                    )
                let oneError =
                    relativeError(
                        mark,
                        1200
                    )

                let isOne =
                    oneError < zeroError

                guard
                    min(
                        zeroError,
                        oneError
                    ) <= 0.45
                else {
                    valid = false
                    break
                }

                if isOne {
                    value |=
                        UInt32(
                            1 << bit
                        )
                }

                error +=
                    min(
                        zeroError,
                        oneError
                    )
            }

            if valid {
                let command =
                    UInt8(
                        value & 0x7F
                    )

                let address =
                    value >> 7

                let confidence =
                    max(
                        0,
                        1.0
                        - error
                            / Double(bitCount)
                    )

                return IRProtocolGuess(
                    name:
                        "Sony SIRC\(bitCount)",
                    confidence:
                        confidence,
                    summary:
                        "Dirección 0x\(String(address, radix: 16).uppercased()) · comando \(hex(command))",
                    dataHex:
                        String(
                            format:
                                "0x%X",
                            value
                        )
                )
            }
        }

        return nil
    }

    private static func detectManchester(
        durations: [UInt32],
        carrier: Int
    ) -> IRProtocolGuess? {
        let sample =
            Array(
                durations.prefix(60)
            )

        guard sample.count >= 12 else {
            return nil
        }

        let rc5Matches =
            sample.filter {
                close(
                    $0,
                    889,
                    tolerance: 0.30
                )
                || close(
                    $0,
                    1778,
                    tolerance: 0.30
                )
            }.count

        let rc5Ratio =
            Double(rc5Matches)
            / Double(sample.count)

        if rc5Ratio > 0.72 {
            return IRProtocolGuess(
                name: "RC5 probable",
                confidence:
                    min(
                        0.90,
                        0.50 + rc5Ratio * 0.45
                    ),
                summary:
                    "Patrón Manchester de ~889 µs",
                dataHex: nil
            )
        }

        if
            durations.count >= 2,
            close(
                durations[0],
                2664,
                tolerance: 0.25
            ),
            close(
                durations[1],
                888,
                tolerance: 0.25
            )
        {
            return IRProtocolGuess(
                name: "RC6 probable",
                confidence: 0.78,
                summary:
                    "Cabecera RC6 detectada; señal Manchester",
                dataHex: nil
            )
        }

        return nil
    }

    private static func close(
        _ actual: UInt32,
        _ expected: Double,
        tolerance: Double
    ) -> Bool {
        relativeError(
            actual,
            expected
        ) <= tolerance
    }

    private static func relativeError(
        _ actual: UInt32,
        _ expected: Double
    ) -> Double {
        abs(
            Double(actual)
            - expected
        ) / max(1, expected)
    }

    private static func hex(
        _ value: UInt8
    ) -> String {
        String(
            format: "0x%02X",
            value
        )
    }

    private static func bytesHex(
        _ bytes: [UInt8]
    ) -> String {
        bytes
            .map {
                String(
                    format: "%02X",
                    $0
                )
            }
            .joined(separator: " ")
    }
}
