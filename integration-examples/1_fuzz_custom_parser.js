// Example: Fuzzing a Custom Parser
// This shows how to fuzz your own parsing logic

// ===== YOUR CUSTOM PARSER (the code you want to fuzz) =====

function parseCustomFormat(input) {
    // Example: Simple key-value parser
    // Format: "KEY:VALUE\nKEY:VALUE\n"

    const lines = input.split('\n');
    const result = {};

    for (const line of lines) {
        if (line.trim() === '') continue;

        const colonPos = line.indexOf(':');
        if (colonPos === -1) {
            throw new Error('Invalid format: missing colon');
        }

        const key = line.substring(0, colonPos).trim();
        const value = line.substring(colonPos + 1).trim();

        if (key.length === 0) {
            throw new Error('Invalid format: empty key');
        }

        // Check for duplicate keys
        if (result.hasOwnProperty(key)) {
            throw new Error('Duplicate key: ' + key);
        }

        result[key] = value;
    }

    return result;
}

function processData(data) {
    // Process the parsed data
    for (const key in data) {
        const value = data[key];

        // Example: Perform operations on values
        if (value.length > 100) {
            throw new Error('Value too long');
        }

        // More processing...
        value.toUpperCase();
    }
}

// ===== FUZZER CODE =====

const inputStr = String.fromCharCode.apply(null, FuzzerInput);

try {
    // Parse the input
    const data = parseCustomFormat(inputStr);

    // Process the parsed data
    processData(data);

    // The fuzzer will find inputs that:
    // - Crash the parser
    // - Trigger edge cases
    // - Cause unexpected behavior

} catch (e) {
    // Expected errors for invalid input
    // These are normal and handled gracefully
}

// Run this fuzzer with:
// ./jsfuzzer --js=integration-examples/1_fuzz_custom_parser.js corpus -max_total_time=60
