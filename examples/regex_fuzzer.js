// Regular expression fuzzer
// This fuzzer tests JavaScript's RegExp implementation
// FuzzerInput is a Uint8Array containing random data

// Convert fuzzer input to string
const inputStr = String.fromCharCode.apply(null, FuzzerInput);

// Split input into pattern and test string
const midpoint = Math.floor(FuzzerInput.length / 2);
const pattern = String.fromCharCode.apply(null, FuzzerInput.slice(0, midpoint));
const testStr = String.fromCharCode.apply(null, FuzzerInput.slice(midpoint));

try {
    // Try to create a regular expression from the pattern
    const regex = new RegExp(pattern);

    // Test various regex operations
    regex.test(testStr);
    regex.exec(testStr);

    // Test with flags
    if (pattern.length > 0) {
        try {
            const regexWithFlags = new RegExp(pattern, 'gi');
            regexWithFlags.test(testStr);
        } catch (e) {
            // Invalid flags or pattern
        }
    }

    // Test string methods that use regex
    testStr.match(regex);
    testStr.search(regex);
    testStr.replace(regex, 'replaced');

} catch (e) {
    // Most random inputs won't be valid regex patterns
    // This is expected behavior
}
