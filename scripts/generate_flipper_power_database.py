#!/usr/bin/env python3
"""
Generate a compact Swift POWER/OFF database from Lucaslhm/Flipper-IRDB.

Only signals suitable for a TV-B-Gone-style "turn devices off" scan are kept:
  - explicit OFF / POWER_OFF commands
  - generic POWER / POWER_TOGGLE / STANDBY commands

POWER_ON commands are intentionally excluded so the off scan does not
deliberately turn devices on.

RAW Flipper signals are preserved exactly. A small set of common parsed
protocols is converted to raw timings. Unknown parsed protocols are skipped
rather than guessed.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path


GENERIC_POWER_NAMES = {
    "power",
    "pwr",
    "power_toggle",
    "powertoggle",
    "toggle_power",
    "togglepower",
    "standby",
}
OFF_NAMES = {
    "off",
    "power_off",
    "poweroff",
    "turn_off",
    "turnoff",
    "shutdown",
    "power_down",
    "powerdown",
}

CATEGORY_DIRS = {
    "televisions": "TVs",
    "airConditioners": "ACs",
    "projectors": "Projectors",
}


def normalize_name(value: str) -> str:
    value = value.lower().strip()
    value = re.sub(r"[^a-z0-9]+", "_", value)
    return re.sub(r"_+", "_", value).strip("_")


def power_priority(name: str):
    """Return priority (lower = earlier) or None if this is not an OFF scan command."""
    n = normalize_name(name)

    if (
        n in OFF_NAMES
        or n.startswith("power_off_")
        or n.endswith("_power_off")
        or n.startswith("off_")
    ):
        return 0

    if (
        n in GENERIC_POWER_NAMES
        or n == "power"
        or n.startswith("power_toggle_")
        or n.endswith("_power")
    ):
        # Do not accidentally accept names such as "low_power".
        if n.startswith("low_power") or n.startswith("power_saving"):
            return None
        return 1

    return None


def parse_ir_records(text: str):
    records = []
    current = {}
    last_key = None

    def finish():
        nonlocal current, last_key
        if current.get("name") and current.get("type"):
            records.append(current)
        current = {}
        last_key = None

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        if line.startswith("#"):
            finish()
            continue

        if ":" in line:
            key, value = line.split(":", 1)
            key = key.strip().lower()
            value = value.strip()

            if key == "name" and current.get("name"):
                finish()

            current[key] = value
            last_key = key
            continue

        # Be tolerant of wrapped RAW data lines.
        if last_key == "data" and re.fullmatch(r"[0-9 ]+", line):
            current["data"] = current.get("data", "") + " " + line

    finish()
    return records


def parse_hex_bytes(value: str):
    out = []
    for token in value.split():
        try:
            out.append(int(token, 16) & 0xFF)
        except ValueError:
            pass
    return out


def pulse_distance_bytes(
    header_mark,
    header_space,
    data_bytes,
    bit_mark,
    zero_space,
    one_space,
    *,
    lsb_first=True,
    trailing_mark=None,
):
    out = [header_mark, header_space]

    for byte in data_bytes:
        shifts = range(8) if lsb_first else range(7, -1, -1)
        for shift in shifts:
            out.append(bit_mark)
            out.append(one_space if ((byte >> shift) & 1) else zero_space)

    if trailing_mark is not None:
        out.append(trailing_mark)

    return out


def encode_nec(address, command):
    if not address or not command:
        return None

    a = address[0]
    c = command[0]
    data = [a, (~a) & 0xFF, c, (~c) & 0xFF]

    return (
        38222,
        pulse_distance_bytes(
            9000, 4500, data,
            562, 562, 1687,
            trailing_mark=562,
        ),
    )


def encode_nec_extended(address, command):
    # Flipper NECext stores the two transmitted address bytes and the two
    # transmitted command bytes explicitly (e.g. 40 40 / 0A F5).
    if len(address) < 2 or len(command) < 2:
        return None

    data = address[:2] + command[:2]
    return (
        38400,
        pulse_distance_bytes(
            9000, 4500, data,
            562, 562, 1687,
            trailing_mark=562,
        ),
    )


def encode_samsung32(address, command):
    if not address or not command:
        return None

    a = address[0]
    c = command[0]
    data = [a, a, c, (~c) & 0xFF]

    return (
        38000,
        pulse_distance_bytes(
            4500, 4500, data,
            550, 550, 1650,
            trailing_mark=550,
        ),
    )


def encode_sirc(address, command, bits):
    if not address or not command:
        return None

    address_bits = {12: 5, 15: 8, 20: 13}.get(bits)
    if address_bits is None:
        return None

    address_value = sum(v << (8 * i) for i, v in enumerate(address))
    command_value = command[0] & 0x7F
    payload = command_value | (
        (address_value & ((1 << address_bits) - 1)) << 7
    )

    all_frames = []

    # Sony remotes normally repeat the frame. Three frames improves compatibility.
    for _ in range(3):
        frame = [2400, 600]

        for bit in range(bits):
            frame.append(1200 if ((payload >> bit) & 1) else 600)
            frame.append(600)

        # Replace final 600us space with the remainder of a 45ms frame period.
        frame.pop()
        used = sum(frame)
        frame.append(max(1, 45000 - used))
        all_frames.extend(frame)

    return 40000, all_frames


def encode_rc5(address, command):
    if not address or not command:
        return None

    addr = address[0] & 0x1F
    cmd = command[0] & 0x7F
    field_bit = cmd < 0x40
    cmd6 = cmd & 0x3F

    # Start, field, toggle(false), address(5), command(6), MSB-first.
    bits = [True, field_bit, False]
    bits += [bool((addr >> shift) & 1) for shift in range(4, -1, -1)]
    bits += [bool((cmd6 >> shift) & 1) for shift in range(5, -1, -1)]

    # Manchester: 1 = space/mark, 0 = mark/space. True means MARK.
    half_levels = []
    for bit in bits:
        half_levels.extend([not bit, bit])

    # The first half-space of the start bit is implicit idle. Start at MARK.
    levels = half_levels[1:]
    if not levels:
        return None

    frame = []
    current = levels[0]
    duration = 889

    for level in levels[1:]:
        if level == current:
            duration += 889
        else:
            frame.append(duration)
            current = level
            duration = 889

    frame.append(duration)

    # Nominal RC5 repeat period ~114 ms.
    used = sum(frame)
    if used < 114000:
        gap = 114000 - used
        if len(frame) % 2 == 0:
            frame[-1] += gap
        else:
            frame.append(gap)

    # Repeat a few times to behave like a normal held POWER key.
    return 36000, frame * 3


def encode_rc6(address, command):
    if not address or not command:
        return None

    payload = ((address[0] & 0xFF) << 8) | (command[0] & 0xFF)

    # RC6 mode 0: start(1), mode(000), toggle(false), 16-bit payload.
    bits = [True, False, False, False, False]
    bits += [bool((payload >> shift) & 1) for shift in range(15, -1, -1)]

    pattern = []
    last_was_mark = None

    def add(mark, duration):
        nonlocal last_was_mark
        if pattern and last_was_mark == mark:
            pattern[-1] += duration
        else:
            pattern.append(duration)
            last_was_mark = mark

    add(True, 2664)
    add(False, 888)

    for index, bit in enumerate(bits):
        half = 888 if index == 4 else 444
        add(bit, half)
        add(not bit, half)

    add(False, 2664)
    return 36000, pattern


def encode_jvc(address, command):
    if not address or not command:
        return None

    # JVC 16-bit: address byte then command byte, LSB-first.
    data = [address[0], command[0]]
    return (
        38000,
        pulse_distance_bytes(
            8400, 4200, data,
            525, 525, 1575,
            trailing_mark=525,
        ),
    )


def parsed_to_raw(record):
    protocol = re.sub(r"[^A-Z0-9]", "", record.get("protocol", "").upper())
    address = parse_hex_bytes(record.get("address", ""))
    command = parse_hex_bytes(record.get("command", ""))

    if protocol == "NEC":
        return encode_nec(address, command)
    if protocol in {"NECEXT", "NECEXTENDED"}:
        return encode_nec_extended(address, command)
    if protocol == "SAMSUNG32":
        return encode_samsung32(address, command)
    if protocol in {"SIRC", "SONY12"}:
        return encode_sirc(address, command, 12)
    if protocol in {"SIRC15", "SONY15"}:
        return encode_sirc(address, command, 15)
    if protocol in {"SIRC20", "SONY20"}:
        return encode_sirc(address, command, 20)
    if protocol == "RC5":
        return encode_rc5(address, command)
    if protocol in {"RC6", "RC6MODE0"}:
        return encode_rc6(address, command)
    if protocol == "JVC":
        return encode_jvc(address, command)

    return None


def record_to_raw(record):
    record_type = record.get("type", "").strip().lower()

    if record_type == "raw":
        try:
            frequency = int(record.get("frequency", "0"))
            durations = [
                int(x)
                for x in record.get("data", "").split()
                if x.isdigit()
            ]
        except ValueError:
            return None

        if frequency <= 0 or not durations:
            return None

        return frequency, durations

    if record_type == "parsed":
        return parsed_to_raw(record)

    return None


def swift_escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", " ")
        .replace("\r", " ")
    )


def collect_category(root: Path, dirname: str):
    base = root / dirname
    candidates = []
    unsupported = Counter()

    if not base.exists():
        raise RuntimeError(f"Missing Flipper-IRDB folder: {base}")

    for path in sorted(base.rglob("*.ir")):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        rel = path.relative_to(root).as_posix()

        for record in parse_ir_records(text):
            priority = power_priority(record.get("name", ""))
            if priority is None:
                continue

            raw = record_to_raw(record)
            if raw is None:
                if record.get("type", "").strip().lower() == "parsed":
                    unsupported[record.get("protocol", "UNKNOWN")] += 1
                continue

            frequency, durations = raw

            # Protect the generated source from corrupt / absurd captures.
            if not (15000 <= frequency <= 60000):
                continue
            if len(durations) < 2 or len(durations) > 10000:
                continue
            if any(d < 0 or d > 5_000_000 for d in durations):
                continue

            signal_name = record.get("name", "Power")
            signal_id = f"flipper:{rel}#{signal_name}"

            candidates.append(
                (priority, rel.lower(), signal_name.lower(), signal_id, frequency, durations)
            )

    candidates.sort(key=lambda x: (x[0], x[1], x[2]))

    # Exact-waveform deduplication. Many model files contain identical OEM codes.
    seen = set()
    unique = []

    for _, _, _, signal_id, frequency, durations in candidates:
        key = (frequency, tuple(durations))
        if key in seen:
            continue
        seen.add(key)
        unique.append((signal_id, frequency, durations))

    return unique, unsupported


def render_swift(category_data):
    lines = [
        "// AUTO-GENERATED by scripts/generate_flipper_power_database.py",
        "// Source: Lucaslhm/Flipper-IRDB (CC0 1.0)",
        "// Only POWER/OFF-style signals are included.",
        "",
        "import Foundation",
        "",
        "enum GeneratedFlipperPowerDatabase {",
    ]

    for swift_name in ("televisions", "airConditioners", "projectors"):
        entries = category_data[swift_name]
        lines.append(f"    static let {swift_name}: [IRCode] = [")

        for signal_id, frequency, durations in entries:
            nums = ",".join(str(x) for x in durations)
            lines.append(
                f'        IRCode(id: "{swift_escape(signal_id)}", '
                f'carrierHz: {frequency}, durationsMicros: [{nums}]),'
            )

        lines.append("    ]")
        lines.append("")

    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: generate_flipper_power_database.py <Flipper-IRDB root> <output.swift>"
        )

    root = Path(sys.argv[1])
    output = Path(sys.argv[2])

    category_data = {}
    all_unsupported = Counter()

    for swift_name, dirname in CATEGORY_DIRS.items():
        entries, unsupported = collect_category(root, dirname)
        category_data[swift_name] = entries
        all_unsupported.update(unsupported)
        print(f"{dirname}: {len(entries)} unique POWER/OFF signals")

    if any(len(category_data[name]) == 0 for name in CATEGORY_DIRS):
        raise RuntimeError("One or more generated device categories are empty")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render_swift(category_data), encoding="utf-8")

    if all_unsupported:
        summary = ", ".join(
            f"{name}={count}"
            for name, count in all_unsupported.most_common()
        )
        print("Skipped unsupported parsed protocols:", summary)

    print("Generated:", output)


if __name__ == "__main__":
    main()
