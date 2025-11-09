// Regular Expression Fuzzer
// Targets: ReDoS vulnerabilities, regex engine memory corruption
// Common vulnerability sources: nested quantifiers, backreferences, catastrophic backtracking

function fuzzRegExp(input) {
    if (!input || input.length < 3) return;

    try {
        // Extract pattern length from first byte
        const patternLen = Math.min(input[0] % 100, input.length - 2);

        // Build pattern from input bytes
        const patternBytes = input.slice(1, 1 + patternLen);
        let pattern = '';

        // Common regex metacharacters that can cause issues
        const metachars = ['.', '*', '+', '?', '^', '$', '\\', '|', '[', ']', '(', ')', '{', '}'];

        for (let i = 0; i < patternBytes.length; i++) {
            const byte = patternBytes[i];

            if (byte < 32) {
                // Use metacharacters
                pattern += metachars[byte % metachars.length];
            } else if (byte < 128) {
                // Use printable ASCII
                pattern += String.fromCharCode(byte);
            } else {
                // Use quantifiers with specific values
                const quantifiers = ['*', '+', '?', '{0,10}', '{1,5}', '{2,}'];
                pattern += quantifiers[byte % quantifiers.length];
            }
        }

        // Extract flags
        const flagByte = input[1 + patternLen] || 0;
        let flags = '';
        if (flagByte & 1) flags += 'g';   // global
        if (flagByte & 2) flags += 'i';   // case-insensitive
        if (flagByte & 4) flags += 'm';   // multiline
        if (flagByte & 8) flags += 's';   // dotAll
        if (flagByte & 16) flags += 'u';  // unicode

        // Try to create and use the regex
        try {
            const re = new RegExp(pattern, flags);

            // Test string from remaining input
            const testStr = String.fromCharCode.apply(null, input.slice(2 + patternLen));

            // Test various regex methods
            re.test(testStr);
            re.exec(testStr);

            if (flags.includes('g')) {
                // Test global matching
                const matches = testStr.match(re);
                if (matches) {
                    matches.forEach(m => m.toString());
                }
            }

            // Test string methods that use regex
            testStr.search(re);
            testStr.split(re);
            testStr.replace(re, 'x');

        } catch (e) {
            // Invalid regex or runtime error - continue fuzzing
        }

        // Test nested quantifiers (common ReDoS source)
        if (patternLen > 5) {
            try {
                const nestedPattern = '(a+)+$';
                const nestedRe = new RegExp(nestedPattern);
                const attackStr = 'a'.repeat(Math.min(20, input[0] % 30));
                nestedRe.test(attackStr);
            } catch (e) {}
        }

    } catch (e) {
        // Catch any unhandled errors
    }
}

// Fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    fuzzRegExp(FuzzerInput);
}
