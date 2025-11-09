// String Operations Fuzzer
// Targets: String handling bugs, Unicode issues, buffer overflows
// Common issues: incorrect length calculations, Unicode normalization, escape sequence handling

function fuzzStrings(input) {
    if (!input || input.length === 0) return;

    try {
        // Test 1: String construction from bytes
        const str1 = String.fromCharCode.apply(null, input);
        const str2 = String.fromCharCode(...input.slice(0, 100));

        // Test string operations
        try {
            str1.charAt(input[0]);
            str1.charCodeAt(input[1]);
            str1.concat(str2);
            str1.indexOf(str2);
            str1.lastIndexOf(str2);
            str1.slice(input[2], input[3]);
            str1.substring(input[4], input[5]);
            str1.substr(input[6], input[7]);

            // Test case conversions
            str1.toLowerCase();
            str1.toUpperCase();
            str1.toLocaleLowerCase();
            str1.toLocaleUpperCase();

            // Test trim operations
            str1.trim();
            str1.trimStart();
            str1.trimEnd();

        } catch (e) {}

        // Test 2: Unicode and surrogate pairs
        try {
            // Create string with surrogate pairs
            const highSurrogate = 0xD800 + (input[0] % 0x400);
            const lowSurrogate = 0xDC00 + (input[1] % 0x400);

            const unicodeStr = String.fromCharCode(highSurrogate, lowSurrogate);

            // Test operations on Unicode strings
            unicodeStr.length;
            unicodeStr.charCodeAt(0);
            unicodeStr.codePointAt(0);

            // String.fromCodePoint with various values
            String.fromCodePoint(input[2] << 16 | input[3] << 8 | input[4]);

        } catch (e) {}

        // Test 3: String.prototype methods with edge cases
        try {
            const testStr = String.fromCharCode(...input.slice(0, 50));

            // split with various separators
            testStr.split('');
            testStr.split(testStr[0]);
            testStr.split(/./);

            // match, search, replace with regex
            testStr.match(/./g);
            testStr.search(/./);
            testStr.replace(/./, 'x');
            testStr.replaceAll(testStr[0], 'y');

            // padStart and padEnd
            testStr.padStart(input[10], testStr);
            testStr.padEnd(input[11], testStr);

            // repeat
            testStr.repeat(input[12] % 100);

        } catch (e) {}

        // Test 4: Template literals and escaping
        try {
            const dynamicStr = String.fromCharCode(...input.slice(0, 20));

            // Create template string
            const template = `Value: ${dynamicStr}`;

            // Test escape sequences
            const escaped = JSON.stringify(dynamicStr);
            JSON.parse(escaped);

        } catch (e) {}

        // Test 5: String normalization
        try {
            const normalizeStr = String.fromCharCode(...input.slice(0, 30));

            // Different normalization forms
            normalizeStr.normalize('NFC');
            normalizeStr.normalize('NFD');
            normalizeStr.normalize('NFKC');
            normalizeStr.normalize('NFKD');

        } catch (e) {}

        // Test 6: String iteration and codepoints
        try {
            const iterStr = String.fromCharCode(...input.slice(0, 40));

            // Iterate over string
            for (const char of iterStr) {
                char.codePointAt(0);
            }

            // Spread operator
            const chars = [...iterStr];
            chars.length;

        } catch (e) {}

        // Test 7: String comparison and localeCompare
        try {
            const str_a = String.fromCharCode(...input.slice(0, 15));
            const str_b = String.fromCharCode(...input.slice(15, 30));

            str_a.localeCompare(str_b);
            str_a === str_b;
            str_a == str_b;

            // Locale-specific operations
            str_a.toLocaleLowerCase('tr-TR');
            str_a.toLocaleUpperCase('tr-TR');

        } catch (e) {}

        // Test 8: Large strings and concatenation
        try {
            let largeStr = String.fromCharCode(...input);

            // Build large string through concatenation
            for (let i = 0; i < Math.min(input[0] % 10, 5); i++) {
                largeStr += largeStr;
            }

            // Test operations on large string
            largeStr.length;
            largeStr.slice(0, 100);
            largeStr.indexOf('test');

        } catch (e) {}

        // Test 9: String includes, startsWith, endsWith
        try {
            const searchStr = String.fromCharCode(...input.slice(0, 25));
            const pattern = String.fromCharCode(...input.slice(25, 30));

            searchStr.includes(pattern);
            searchStr.startsWith(pattern);
            searchStr.endsWith(pattern);
            searchStr.includes(pattern, input[30]);

        } catch (e) {}

        // Test 10: Conversion to string from other types
        try {
            // Number to string
            const num = (input[0] << 24) | (input[1] << 16) | (input[2] << 8) | input[3];
            num.toString();
            num.toString(2);   // binary
            num.toString(8);   // octal
            num.toString(16);  // hex
            num.toString(36);  // max radix

            // Object to string
            const obj = { toString: () => String.fromCharCode(...input.slice(4, 10)) };
            String(obj);
            '' + obj;

        } catch (e) {}

    } catch (e) {
        // Catch any unhandled errors
    }
}

// Fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    fuzzStrings(FuzzerInput);
}
