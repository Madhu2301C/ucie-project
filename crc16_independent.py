def ucie_crc16(data: bytes) -> int:
    if len(data) > 128:
        raise ValueError("Input must not exceed 128 bytes")
    data = data + bytes(128 - len(data))
    crc = 0
    for byte in data:
        for bit in range(8):
            feedback = ((crc >> 15) & 1) ^ ((byte >> bit) & 1)
            crc = (crc << 1) & 0xFFFF
            if feedback:
                crc ^= 0x8005
    return crc
vectors = {
    "all zeros": bytes(128),
    "first bit set": bytes([1]) + bytes(127),
    "all FF": bytes([0xFF]) * 128,
    "incrementing bytes": bytes(range(128)),
}
for name, data in vectors.items():
    print(f"{name:20s}: {ucie_crc16(data):04X}")
