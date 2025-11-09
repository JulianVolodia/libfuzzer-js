// JSON parsing fuzzer
// This fuzzer tests JavaScript's JSON.parse function
// FuzzerInput is a Uint8Array containing random data

// Convert fuzzer input to string
const inputStr = String.fromCharCode.apply(null, FuzzerInput);

try {
    // Try to parse as JSON
    const obj = JSON.parse(inputStr);

    // If parsing succeeded, perform operations on the parsed object
    if (obj !== null && typeof obj === 'object') {
        // Test property access
        for (let key in obj) {
            if (obj.hasOwnProperty(key)) {
                const value = obj[key];
                // Access the value
            }
        }

        // Test JSON.stringify on the parsed object
        JSON.stringify(obj);
    }

} catch (e) {
    // Most random inputs won't be valid JSON
    // This is expected behavior, not a bug
}
