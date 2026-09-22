import Foundation

enum UniversalPowerCodes {
    /// Small front-loaded set of common TV power commands.
    /// These run before the larger TV-B-Gone database.
    static let codes: [IRCode] = [
        samsung32(id: "universal-samsung-power", address: 0x07, command: 0x02),
        rc5(id: "universal-vestel-tdsystems-power", address: 0x00, command: 0x0C, toggle: false, repeats: 3),
        rc5(id: "universal-telefunken-power", address: 0x01, command: 0x0C, toggle: false, repeats: 3),
        sony12(id: "universal-sony-power", address: 0x01, command: 0x15),
        nec(id: "universal-nec-04-08", address: 0x04, command: 0x08),
        rc6Mode0(id: "universal-philips-power", address: 0x00, command: 0x0C, toggle: false),
        nec(id: "universal-medion-power", address: 0x19, command: 0x18),
        nec(id: "universal-oppo-power", address: 0x49, command: 0x1A),
        necExtended(id: "universal-denver-power", bytes: [0x00, 0x7F, 0x0A, 0xF5]),
        necExtended(id: "universal-hisense-power", bytes: [0x00, 0xBF, 0x0D, 0xF2]),
        necExtended(id: "universal-elitelux-power", bytes: [0x00, 0x7F, 0x15, 0xEA]),
    ]

    /// Vestel's classic TV power command is RC5 0x100C.
    /// This is useful as a focused TD Systems/Vestel hardware test.
    static let vestelTDSystemsTest: IRCode =
        rc5(id: "tdsystems-vestel-rc5-100c", address: 0x00, command: 0x0C, toggle: false, repeats: 4)

    private static func samsung32(id: String, address: UInt8, command: UInt8) -> IRCode {
        let bytes: [UInt8] = [address, address, command, ~command]
        return IRCode(id: id, carrierHz: 38_000, durationsMicros: pulseDistance(
            headerMark: 4500,
            headerSpace: 4500,
            bytes: bytes,
            bitMark: 550,
            zeroSpace: 550,
            oneSpace: 1650,
            trailingMark: 550
        ))
    }

    private static func nec(id: String, address: UInt8, command: UInt8) -> IRCode {
        let bytes: [UInt8] = [address, ~address, command, ~command]
        return IRCode(id: id, carrierHz: 38_222, durationsMicros: pulseDistance(
            headerMark: 9000,
            headerSpace: 4500,
            bytes: bytes,
            bitMark: 562,
            zeroSpace: 562,
            oneSpace: 1687,
            trailingMark: 562
        ))
    }

    private static func necExtended(id: String, bytes: [UInt8]) -> IRCode {
        return IRCode(id: id, carrierHz: 38_400, durationsMicros: pulseDistance(
            headerMark: 9000,
            headerSpace: 4500,
            bytes: bytes,
            bitMark: 562,
            zeroSpace: 562,
            oneSpace: 1687,
            trailingMark: 562
        ))
    }

    private static func pulseDistance(
        headerMark: UInt32,
        headerSpace: UInt32,
        bytes: [UInt8],
        bitMark: UInt32,
        zeroSpace: UInt32,
        oneSpace: UInt32,
        trailingMark: UInt32
    ) -> [UInt32] {
        var out: [UInt32] = [headerMark, headerSpace]

        // NEC-family and Samsung32 are transmitted least-significant-bit first.
        for byte in bytes {
            for bit in 0..<8 {
                out.append(bitMark)
                out.append(((byte >> bit) & 1) == 0 ? zeroSpace : oneSpace)
            }
        }

        out.append(trailingMark)
        return out
    }

    private static func sony12(id: String, address: UInt8, command: UInt8) -> IRCode {
        let payload = UInt16(command & 0x7F) | (UInt16(address & 0x1F) << 7)
        var all: [UInt32] = []

        for _ in 0..<3 {
            var frame: [UInt32] = [2400, 600]
            for bit in 0..<12 {
                let one = ((payload >> bit) & 1) != 0
                frame.append(one ? 1200 : 600)
                frame.append(600)
            }

            // Replace the final nominal 600us space with the remainder of a 45ms frame.
            if !frame.isEmpty {
                frame.removeLast()
            }
            let used = frame.reduce(UInt32(0), +)
            frame.append(used < 45_000 ? 45_000 - used : 1)
            all.append(contentsOf: frame)
        }

        return IRCode(id: id, carrierHz: 40_000, durationsMicros: all)
    }

    private static func rc5(
        id: String,
        address: UInt8,
        command: UInt8,
        toggle: Bool,
        repeats: Int
    ) -> IRCode {
        let fieldBit = command < 0x40
        let command6 = command & 0x3F

        var bits: [Bool] = []
        bits.append(true)                // Start bit
        bits.append(fieldBit)            // Field/start bit
        bits.append(toggle)              // Toggle

        for shift in stride(from: 4, through: 0, by: -1) {
            bits.append(((address >> shift) & 1) != 0)
        }
        for shift in stride(from: 5, through: 0, by: -1) {
            bits.append(((command6 >> shift) & 1) != 0)
        }

        // Manchester: logical 1 = space/mark, logical 0 = mark/space.
        var halfLevels: [Bool] = []
        for bit in bits {
            halfLevels.append(!bit) // false = space, true = mark
            halfLevels.append(bit)
        }

        // The first start bit begins with an implicit idle half-space.
        // Skip it so the returned raw IR pattern begins with a MARK.
        var frame: [UInt32] = []
        if halfLevels.count > 1 {
            var current = halfLevels[1]
            var duration: UInt32 = 889

            if halfLevels.count > 2 {
                for i in 2..<halfLevels.count {
                    if halfLevels[i] == current {
                        duration += 889
                    } else {
                        frame.append(duration)
                        current = halfLevels[i]
                        duration = 889
                    }
                }
            }
            frame.append(duration)
        }

        // RC5 nominal repeat period ~114ms.
        let used = frame.reduce(UInt32(0), +)
        if used < 114_000 {
            let gap = 114_000 - used
            if frame.count % 2 == 0 {
                // Starts on mark, so even count means the last segment is a space.
                frame[frame.count - 1] += gap
            } else {
                frame.append(gap)
            }
        }

        var all: [UInt32] = []
        for _ in 0..<max(1, repeats) {
            all.append(contentsOf: frame)
        }

        return IRCode(id: id, carrierHz: 36_000, durationsMicros: all)
    }

    private static func rc6Mode0(
        id: String,
        address: UInt8,
        command: UInt8,
        toggle: Bool
    ) -> IRCode {
        let t: UInt32 = 444
        let payload = (UInt16(address) << 8) | UInt16(command)

        var bits: [Bool] = [
            true,   // start
            false, false, false, // mode 0
            toggle
        ]
        for shift in stride(from: 15, through: 0, by: -1) {
            bits.append(((payload >> shift) & 1) != 0)
        }

        var pattern: [UInt32] = []
        var lastWasMark: Bool? = nil

        func add(_ mark: Bool, _ duration: UInt32, to array: inout [UInt32], last: inout Bool?) {
            if let previous = last, previous == mark {
                array[array.count - 1] += duration
            } else {
                array.append(duration)
                last = mark
            }
        }

        add(true, 2664, to: &pattern, last: &lastWasMark)
        add(false, 888, to: &pattern, last: &lastWasMark)

        for (index, bit) in bits.enumerated() {
            let half = index == 4 ? 2 * t : t
            add(bit, half, to: &pattern, last: &lastWasMark)
            add(!bit, half, to: &pattern, last: &lastWasMark)
        }

        add(false, 2664, to: &pattern, last: &lastWasMark)
        return IRCode(id: id, carrierHz: 36_000, durationsMicros: pattern)
    }
}
