#!/usr/bin/env python3
"""Independent CRC-16 reference using polynomial long division."""
WIDTH = 16
POLY = (1 << 16) | (1 << 15) | (1 << 2) | 1
MESSAGE_BITS = 1024
def crc16_polynomial_division(data: bytes) -> int:
    if len(data) > MESSAGE_BITS // 8:
        raise ValueError("Input exceeds 128 bytes")
    # Zero-pad shorter messages at the MSB (prepend zero bytes).
    data = bytes(128 - len(data)) + data
    # The first processed bit becomes the highest message coefficient.
    message_poly = 0
    for byte in data:
        for bit in range(8):  # bit 0 first, through bit 7
            message_poly = (message_poly << 1) | ((byte >> bit) & 1)
    # Append 16 zero coefficients before polynomial division.
    remainder = message_poly << WIDTH
    while remainder.bit_length() > WIDTH:
        shift = remainder.bit_length() - (WIDTH + 1)
        remainder ^= POLY << shift
    return remainder
def main():
    vectors = [
        ("all zeros", bytes(128), 0x0000),
        ("first bit set", bytes([1]) + bytes(127), 0x8039),
        ("second-byte bit 0", bytes([0, 1]) + bytes(126), 0x0B00),
        ("all FF", bytes([0xFF]) * 128, 0x002E),
        ("incrementing bytes", bytes(range(128)), 0x249F),
    ]
    failed = False
    for name, data, expected in vectors:
        actual = crc16_polynomial_division(data)
        status = "PASS" if actual == expected else "FAIL"
        print(f"{name:22s}: {actual:04X}  expected={expected:04X}  {status}")
        if actual != expected:
            failed = True
    if failed:
        raise SystemExit("CRC reference vector validation FAILED")
    print("\nALL INDEPENDENT POLYNOMIAL-DIVISION VECTORS PASSED")
if __name__ == "__main__":
    main()
