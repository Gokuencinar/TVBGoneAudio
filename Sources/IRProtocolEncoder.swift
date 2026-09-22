import Foundation

enum IRProtocolEncoder {
    static func encode(
        protocolName: String,
        address: [UInt8],
        command: [UInt8],
        id: String
    ) -> IRCode? {
        let p =
            protocolName
            .uppercased()
            .filter {
                $0.isLetter
                || $0.isNumber
            }

        switch p {
        case "NEC":
            return nec(
                address: address,
                command: command,
                id: id
            )

        case "NECEXT",
             "NECEXTENDED":
            return necExtended(
                address: address,
                command: command,
                id: id
            )

        case "SAMSUNG32":
            return samsung32(
                address: address,
                command: command,
                id: id
            )

        case "SIRC",
             "SONY12":
            return sirc(
                address: address,
                command: command,
                bits: 12,
                id: id
            )

        case "SIRC15",
             "SONY15":
            return sirc(
                address: address,
                command: command,
                bits: 15,
                id: id
            )

        case "SIRC20",
             "SONY20":
            return sirc(
                address: address,
                command: command,
                bits: 20,
                id: id
            )

        case "RC5",
             "RC5X":
            return rc5(
                address: address,
                command: command,
                id: id
            )

        case "RC6",
             "RC6MODE0":
            return rc6(
                address: address,
                command: command,
                id: id
            )

        case "JVC":
            return jvc(
                address: address,
                command: command,
                id: id
            )

        case "KASEIKYO":
            return kaseikyo(
                address: address,
                command: command,
                id: id
            )

        case "RCA":
            return rca(
                address: address,
                command: command,
                id: id
            )

        case "PIONEER":
            return pioneer(
                address: address,
                command: command,
                id: id
            )

        default:
            return nil
        }
    }

    private static func pulseDistance(
        headerMark: UInt32,
        headerSpace: UInt32,
        value: UInt64,
        bits: Int,
        bitMark: UInt32,
        zeroSpace: UInt32,
        oneSpace: UInt32,
        trailingMark: UInt32? = nil
    ) -> [UInt32] {
        var output: [UInt32] = [
            headerMark,
            headerSpace,
        ]

        for bit in 0..<bits {
            output.append(bitMark)

            output.append(
                ((value >> UInt64(bit)) & 1) == 1
                ? oneSpace
                : zeroSpace
            )
        }

        if let trailingMark {
            output.append(trailingMark)
        }

        return output
    }

    private static func littleEndianValue(
        _ bytes: [UInt8]
    ) -> UInt64 {
        var value: UInt64 = 0

        for (index, byte) in bytes.enumerated() {
            guard index < 8 else { break }

            value |=
                UInt64(byte)
                << UInt64(index * 8)
        }

        return value
    }

    private static func nec(
        address: [UInt8],
        command: [UInt8],
        id: String
    ) -> IRCode? {
        guard
            let a = address.first,
            let c = command.first
        else {
            return nil
        }

        let bytes: [UInt8] = [
            a,
            ~a,
            c,
            ~c,
        ]

        return IRCode(
            id: id,
            carrierHz: 38_222,
            durationsMicros:
                pulseDistance(
                    headerMark: 9000,
                    headerSpace: 4500,
                    value:
                        littleEndianValue(
                            bytes
                        ),
                    bits: 32,
                    bitMark: 562,
                    zeroSpace: 562,
                    oneSpace: 1687,
                    trailingMark: 562
                )
        )
    }

    private static func necExtended(
        address: [UInt8],
        command: [UInt8],
        id: String
    ) -> IRCode? {
        guard
            address.count >= 2,
            command.count >= 2
        else {
            return nil
        }

        let bytes =
            Array(address.prefix(2))
            + Array(command.prefix(2))

        return IRCode(
            id: id,
            carrierHz: 38_400,
            durationsMicros:
                pulseDistance(
                    headerMark: 9000,
                    headerSpace: 4500,
                    value:
                        littleEndianValue(
                            bytes
                        ),
                    bits: 32,
                    bitMark: 562,
                    zeroSpace: 562,
                    oneSpace: 1687,
                    trailingMark: 562
                )
        )
    }

    private static func samsung32(
        address: [UInt8],
        command: [UInt8],
        id: String
    ) -> IRCode? {
        guard
            let a = address.first,
            let c = command.first
        else {
            return nil
        }

        let bytes: [UInt8] = [
            a,
            a,
            c,
            ~c,
        ]

        return IRCode(
            id: id,
            carrierHz: 38_000,
            durationsMicros:
                pulseDistance(
                    headerMark: 4500,
                    headerSpace: 4500,
                    value:
                        littleEndianValue(
                            bytes
                        ),
                    bits: 32,
                    bitMark: 550,
                    zeroSpace: 550,
                    oneSpace: 1650,
                    trailingMark: 550
                )
        )
    }

    private static func sirc(
        address: [UInt8],
        command: [UInt8],
        bits: Int,
        id: String
    ) -> IRCode? {
        guard
            let c = command.first
        else {
            return nil
        }

        let addressBits: Int

        switch bits {
        case 12: addressBits = 5
        case 15: addressBits = 8
        case 20: addressBits = 13
        default: return nil
        }

        let addressValue =
            littleEndianValue(address)

        let payload =
            UInt64(c & 0x7F)
            | (
                addressValue
                & (
                    (UInt64(1)
                        << UInt64(addressBits))
                    - 1
                )
            ) << 7

        var all: [UInt32] = []

        for _ in 0..<3 {
            var frame: [UInt32] = [
                2400,
                600,
            ]

            for bit in 0..<bits {
                frame.append(
                    (
                        (
                            payload
                            >> UInt64(bit)
                        ) & 1
                    ) == 1
                    ? 1200
                    : 600
                )

                frame.append(600)
            }

            if !frame.isEmpty {
                frame.removeLast()
            }

            let used =
                frame.reduce(
                    UInt32(0),
                    +
                )

            frame.append(
                used < 45_000
                ? 45_000 - used
                : 1
            )

            all.append(
                contentsOf: frame
            )
        }

        return IRCode(
            id: id,
            carrierHz: 40_000,
            durationsMicros: all
        )
    }

    private static func rc5(
        address: [UInt8],
        command: [UInt8],
        id: String
    ) -> IRCode? {
        guard
            let addressByte =
                address.first,
            let commandByte =
                command.first
        else {
            return nil
        }

        let addr =
            addressByte & 0x1F
        let cmd =
            commandByte & 0x7F
        let fieldBit =
            cmd < 0x40
        let cmd6 =
            cmd & 0x3F

        var bits: [Bool] = [
            true,
            fieldBit,
            false,
        ]

        for shift in stride(
            from: 4,
            through: 0,
            by: -1
        ) {
            bits.append(
                (
                    (
                        addr
                        >> UInt8(shift)
                    ) & 1
                ) != 0
            )
        }

        for shift in stride(
            from: 5,
            through: 0,
            by: -1
        ) {
            bits.append(
                (
                    (
                        cmd6
                        >> UInt8(shift)
                    ) & 1
                ) != 0
            )
        }

        var halfLevels: [Bool] = []

        for bit in bits {
            halfLevels.append(!bit)
            halfLevels.append(bit)
        }

        guard halfLevels.count > 1 else {
            return nil
        }

        var frame: [UInt32] = []
        var current =
            halfLevels[1]
        var duration: UInt32 =
            889

        if halfLevels.count > 2 {
            for index in 2..<halfLevels.count {
                if halfLevels[index]
                    == current
                {
                    duration += 889
                } else {
                    frame.append(duration)
                    current =
                        halfLevels[index]
                    duration = 889
                }
            }
        }

        frame.append(duration)

        let used =
            frame.reduce(
                UInt32(0),
                +
            )

        if used < 114_000 {
            let gap =
                114_000 - used

            if frame.count % 2 == 0 {
                frame[frame.count - 1] +=
                    gap
            } else {
                frame.append(gap)
            }
        }

        var all: [UInt32] = []

        for _ in 0..<3 {
            all.append(
                contentsOf: frame
            )
        }

        return IRCode(
            id: id,
            carrierHz: 36_000,
            durationsMicros: all
        )
    }

    private static func rc6(
        address: [UInt8],
        command: [UInt8],
        id: String
    ) -> IRCode? {
        guard
            let addressByte =
                address.first,
            let commandByte =
                command.first
        else {
            return nil
        }

        let payload =
            (
                UInt16(addressByte)
                << 8
            )
            | UInt16(commandByte)

        var bits: [Bool] = [
            true,
            false,
            false,
            false,
            false,
        ]

        for shift in stride(
            from: 15,
            through: 0,
            by: -1
        ) {
            bits.append(
                (
                    (
                        payload
                        >> UInt16(shift)
                    ) & 1
                ) != 0
            )
        }

        var pattern: [UInt32] = []
        var lastWasMark: Bool?

        func add(
            _ mark: Bool,
            _ duration: UInt32
        ) {
            if
                let previous =
                    lastWasMark,
                previous == mark,
                !pattern.isEmpty
            {
                pattern[
                    pattern.count - 1
                ] += duration
            } else {
                pattern.append(duration)
                lastWasMark = mark
            }
        }

        add(true, 2664)
        add(false, 888)

        for (index, bit)
            in bits.enumerated()
        {
            let half: UInt32 =
                index == 4
                ? 888
                : 444

            add(bit, half)
            add(!bit, half)
        }

        add(false, 2664)

        return IRCode(
            id: id,
            carrierHz: 36_000,
            durationsMicros: pattern
        )
    }

    private static func jvc(
        address: [UInt8],
        command: [UInt8],
        id: String
    ) -> IRCode? {
        guard
            let a = address.first,
            let c = command.first
        else {
            return nil
        }

        return IRCode(
            id: id,
            carrierHz: 38_000,
            durationsMicros:
                pulseDistance(
                    headerMark: 8400,
                    headerSpace: 4200,
                    value:
                        littleEndianValue(
                            [a, c]
                        ),
                    bits: 16,
                    bitMark: 525,
                    zeroSpace: 525,
                    oneSpace: 1575,
                    trailingMark: 525
                )
        )
    }

    private static func kaseikyo(
        address: [UInt8],
        command: [UInt8],
        id: String
    ) -> IRCode? {
        guard
            address.count >= 4,
            command.count >= 2
        else {
            return nil
        }

        let addressValue =
            UInt32(
                littleEndianValue(
                    Array(
                        address.prefix(4)
                    )
                )
            )

        let commandValue =
            UInt16(
                littleEndianValue(
                    Array(
                        command.prefix(2)
                    )
                )
            )

        let deviceID =
            UInt8(
                (
                    addressValue
                    >> 24
                ) & 0x03
            )

        let vendorID =
            UInt16(
                (
                    addressValue
                    >> 8
                ) & 0xFFFF
            )

        let genre1 =
            UInt8(
                (
                    addressValue
                    >> 4
                ) & 0x0F
            )

        let genre2 =
            UInt8(
                addressValue
                    & 0x0F
            )

        let data0 =
            UInt8(
                vendorID
                    & 0xFF
            )

        let data1 =
            UInt8(
                vendorID >> 8
            )

        var vendorParity =
            data0 ^ data1

        vendorParity =
            (
                vendorParity
                & 0x0F
            )
            ^ (
                vendorParity
                >> 4
            )

        let data2 =
            (
                vendorParity
                & 0x0F
            )
            | (
                genre1
                << 4
            )

        let data3 =
            (
                genre2
                & 0x0F
            )
            | (
                UInt8(
                    commandValue
                        & 0x0F
                )
                << 4
            )

        let data4 =
            (
                deviceID
                << 6
            )
            | UInt8(
                (
                    commandValue
                    >> 4
                ) & 0x3F
            )

        let data5 =
            data2
            ^ data3
            ^ data4

        let bytes = [
            data0,
            data1,
            data2,
            data3,
            data4,
            data5,
        ]

        return IRCode(
            id: id,
            carrierHz: 38_000,
            durationsMicros:
                pulseDistance(
                    headerMark: 3456,
                    headerSpace: 1728,
                    value:
                        littleEndianValue(
                            bytes
                        ),
                    bits: 48,
                    bitMark: 432,
                    zeroSpace: 432,
                    oneSpace: 1296,
                    trailingMark: 432
                )
        )
    }

    private static func rca(
        address: [UInt8],
        command: [UInt8],
        id: String
    ) -> IRCode? {
        guard
            let addressByte =
                address.first,
            let commandByte =
                command.first
        else {
            return nil
        }

        let addr =
            addressByte & 0x0F
        let cmd =
            commandByte

        var payload =
            UInt64(addr)

        payload |=
            UInt64(cmd)
            << 4

        payload |=
            UInt64(
                (~addr) & 0x0F
            ) << 12

        payload |=
            UInt64(~cmd)
            << 16

        return IRCode(
            id: id,
            carrierHz: 38_000,
            durationsMicros:
                pulseDistance(
                    headerMark: 4000,
                    headerSpace: 4000,
                    value: payload,
                    bits: 24,
                    bitMark: 500,
                    zeroSpace: 1000,
                    oneSpace: 2000,
                    trailingMark: 500
                )
        )
    }

    private static func pioneer(
        address: [UInt8],
        command: [UInt8],
        id: String
    ) -> IRCode? {
        guard
            let a = address.first,
            let c = command.first
        else {
            return nil
        }

        let bytes: [UInt8] = [
            a,
            ~a,
            c,
            ~c,
            0,
        ]

        var frame =
            pulseDistance(
                headerMark: 8500,
                headerSpace: 4225,
                value:
                    littleEndianValue(
                        bytes
                    ),
                bits: 33,
                bitMark: 500,
                zeroSpace: 500,
                oneSpace: 1500,
                trailingMark: 500
            )

        if frame.count % 2 == 1 {
            frame.append(26_000)
        } else if !frame.isEmpty {
            frame[
                frame.count - 1
            ] += 26_000
        }

        return IRCode(
            id: id,
            carrierHz: 40_000,
            durationsMicros:
                frame + frame
        )
    }
}
