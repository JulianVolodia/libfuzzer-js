// Arithmetic operations fuzzer
// This fuzzer tests JavaScript arithmetic and numeric operations
// FuzzerInput is a Uint8Array containing random data

if (FuzzerInput.length >= 16) {
    // Extract four 32-bit integers from fuzzer input
    const a = FuzzerInput[0] | (FuzzerInput[1] << 8) | (FuzzerInput[2] << 16) | (FuzzerInput[3] << 24);
    const b = FuzzerInput[4] | (FuzzerInput[5] << 8) | (FuzzerInput[6] << 16) | (FuzzerInput[7] << 24);
    const c = FuzzerInput[8] | (FuzzerInput[9] << 8) | (FuzzerInput[10] << 16) | (FuzzerInput[11] << 24);
    const d = FuzzerInput[12] | (FuzzerInput[13] << 8) | (FuzzerInput[14] << 16) | (FuzzerInput[15] << 24);

    // Test basic arithmetic
    const sum = a + b;
    const diff = a - b;
    const prod = a * b;

    // Test division (with zero check)
    if (b !== 0) {
        const quot = a / b;
        const mod = a % b;
    }

    // Test bitwise operations
    const and = a & b;
    const or = a | b;
    const xor = a ^ b;
    const lshift = a << (b & 31); // Limit shift amount
    const rshift = a >> (b & 31);

    // Test floating point operations
    const floatA = a / 1000.0;
    const floatB = b / 1000.0;

    const sqrt = Math.sqrt(Math.abs(floatA));
    const pow = Math.pow(floatA, floatB % 10); // Limit exponent
    const sin = Math.sin(floatA);
    const cos = Math.cos(floatB);

    // Test edge cases
    const max = Math.max(a, b, c, d);
    const min = Math.min(a, b, c, d);

    // Test type conversions
    const str = a.toString();
    const parsed = parseInt(str, 10);

    // Test array operations with numeric indices
    const arr = [a, b, c, d];
    const sorted = arr.sort((x, y) => x - y);
    const filtered = arr.filter(x => x > 0);
    const mapped = arr.map(x => x * 2);
    const reduced = arr.reduce((acc, x) => acc + x, 0);
}
