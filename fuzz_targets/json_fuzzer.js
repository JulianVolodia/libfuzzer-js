// JSON Parsing Fuzzer
// Targets: JSON parser vulnerabilities, stack overflow, integer overflow
// Common issues: deeply nested objects, large numbers, Unicode handling

function fuzzJSON(input) {
    if (!input || input.length === 0) return;

    try {
        // Strategy 1: Direct parsing of fuzzer input as string
        let jsonStr = String.fromCharCode.apply(null, input);

        // Limit length to prevent excessive memory usage in fuzzer
        if (jsonStr.length > 100000) {
            jsonStr = jsonStr.slice(0, 100000);
        }

        try {
            const obj = JSON.parse(jsonStr);

            // Test JSON.stringify on parsed object
            if (obj !== null && typeof obj === 'object') {
                JSON.stringify(obj);

                // Test with different replacer functions
                JSON.stringify(obj, null, 2);
                JSON.stringify(obj, (key, value) => value);

                // Test circular reference detection
                if (Array.isArray(obj)) {
                    obj.push(obj);
                } else {
                    obj.self = obj;
                }

                try {
                    JSON.stringify(obj);
                } catch (e) {
                    // Expected: circular reference error
                }
            }
        } catch (e) {
            // Invalid JSON - continue with other strategies
        }

        // Strategy 2: Generate JSON with specific vulnerability patterns
        if (input.length > 10) {
            // Test deeply nested objects
            const depth = Math.min(input[0] % 100, 500);
            let nested = '{"a":';
            for (let i = 0; i < depth; i++) {
                nested += '{"b":';
            }
            nested += '1';
            for (let i = 0; i < depth; i++) {
                nested += '}';
            }
            nested += '}';

            try {
                JSON.parse(nested);
            } catch (e) {}

            // Test deeply nested arrays
            let nestedArray = '[';
            for (let i = 0; i < depth; i++) {
                nestedArray += '[';
            }
            nestedArray += '1';
            for (let i = 0; i < depth; i++) {
                nestedArray += ']';
            }

            try {
                JSON.parse(nestedArray);
            } catch (e) {}
        }

        // Strategy 3: Test large numbers
        if (input.length > 5) {
            const numStr = Array.from(input.slice(0, 300))
                .map(b => (b % 10).toString())
                .join('');

            try {
                JSON.parse(numStr);
                JSON.parse('-' + numStr);
                JSON.parse(numStr + '.' + numStr);
                JSON.parse(numStr + 'e' + input[0]);
            } catch (e) {}
        }

        // Strategy 4: Test Unicode and escape sequences
        if (input.length > 8) {
            let unicodeStr = '"';
            for (let i = 0; i < Math.min(input.length, 100); i++) {
                const byte = input[i];
                if (byte % 3 === 0) {
                    unicodeStr += '\\u' + byte.toString(16).padStart(4, '0');
                } else if (byte % 3 === 1) {
                    unicodeStr += '\\x' + byte.toString(16).padStart(2, '0');
                } else {
                    unicodeStr += String.fromCharCode(byte);
                }
            }
            unicodeStr += '"';

            try {
                JSON.parse(unicodeStr);
            } catch (e) {}
        }

        // Strategy 5: Test object with many keys
        if (input.length > 20) {
            const keyCount = Math.min(input[0] % 100, 1000);
            let manyKeys = '{';
            for (let i = 0; i < keyCount; i++) {
                manyKeys += `"key${i}":${input[i % input.length]},`;
            }
            manyKeys = manyKeys.slice(0, -1) + '}';

            try {
                JSON.parse(manyKeys);
            } catch (e) {}
        }

    } catch (e) {
        // Catch any unhandled errors
    }
}

// Fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    fuzzJSON(FuzzerInput);
}
