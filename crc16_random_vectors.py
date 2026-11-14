
import random
from pathlib import Path

WIDTH = 16
POLY = (1 << 16) | (1 << 15) | (1 << 2) | 1
VECTOR_COUNT = 1000
SEED = 20261018
VECTOR_FILE = Path("crc_random_vectors.txt")


def crc16_polynomial_division(data: bytes) -> int:
    if len(data) != 128:
        raise ValueError("Each message must contain exactly 128 bytes")

    message_poly = 0

    # Process byte 0 bit 0 through bit 7, then subsequent bytes.
    for byte in data:
        for bit in range(8):
            message_poly = (message_poly << 1) | ((byte >> bit) & 1)

    remainder = message_poly << WIDTH

    while remainder.bit_length() > WIDTH:
        shift = remainder.bit_length() - 17
        remainder ^= POLY << shift

    return remainder


def main():
    rng = random.Random(SEED)

    with VECTOR_FILE.open("x", encoding="ascii") as output:
        for index in range(VECTOR_COUNT):
            data = bytes(rng.getrandbits(8) for _ in range(128))
            expected_crc = crc16_polynomial_division(data)

            # Reverse bytes so packed SystemVerilog vectors preserve
            # message[7:0] as byte 0.
            message_hex = data[::-1].hex()

            output.write(f"{message_hex} {expected_crc:04X}\n")

    print(f"PASS: Generated {VECTOR_COUNT} deterministic vectors.")
    print(f"Seed: {SEED}")
    print(f"Output: {VECTOR_FILE}")


if __name__ == "__main__":
    main()
