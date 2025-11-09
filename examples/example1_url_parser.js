// Example 1: URL Parser - A Real-World Fuzzing Example
// This demonstrates how to fuzz a URL parsing library

// ============================================
// YOUR CODE (the target to fuzz)
// ============================================

function parseURL(url) {
    if (typeof url !== 'string') {
        throw new TypeError('URL must be a string');
    }

    const result = {
        protocol: null,
        host: null,
        port: null,
        path: null,
        query: null,
        fragment: null
    };

    let remaining = url;

    // Extract protocol
    const protocolMatch = remaining.match(/^([a-z][a-z0-9+.-]*):\/\//i);
    if (protocolMatch) {
        result.protocol = protocolMatch[1].toLowerCase();
        remaining = remaining.substring(protocolMatch[0].length);
    }

    // Extract fragment
    const fragmentIndex = remaining.indexOf('#');
    if (fragmentIndex !== -1) {
        result.fragment = remaining.substring(fragmentIndex + 1);
        remaining = remaining.substring(0, fragmentIndex);
    }

    // Extract query string
    const queryIndex = remaining.indexOf('?');
    if (queryIndex !== -1) {
        result.query = remaining.substring(queryIndex + 1);
        remaining = remaining.substring(0, queryIndex);
    }

    // Extract path
    const pathIndex = remaining.indexOf('/');
    if (pathIndex !== -1) {
        result.path = remaining.substring(pathIndex);
        remaining = remaining.substring(0, pathIndex);
    } else {
        result.path = '/';
    }

    // Extract port
    const portIndex = remaining.lastIndexOf(':');
    if (portIndex !== -1) {
        const portStr = remaining.substring(portIndex + 1);
        const port = parseInt(portStr, 10);

        // BUG: No validation of port range!
        // This could cause issues if port is negative or > 65535
        result.port = port;
        remaining = remaining.substring(0, portIndex);
    }

    // What's left is the host
    result.host = remaining;

    return result;
}

function normalizeURL(url) {
    const parsed = parseURL(url);

    // Reconstruct normalized URL
    let normalized = '';

    if (parsed.protocol) {
        normalized += parsed.protocol + '://';
    }

    if (parsed.host) {
        normalized += parsed.host;
    }

    if (parsed.port) {
        normalized += ':' + parsed.port;
    }

    normalized += parsed.path || '/';

    if (parsed.query) {
        normalized += '?' + parsed.query;
    }

    if (parsed.fragment) {
        normalized += '#' + parsed.fragment;
    }

    return normalized;
}

// ============================================
// FUZZING HARNESS
// ============================================

function fuzzURLParser(input) {
    if (!input || input.length === 0) return;

    try {
        // Convert fuzzer input to string URL
        const url = String.fromCharCode.apply(null, input);

        // Test parsing
        const parsed = parseURL(url);

        // Validate parsed components
        if (parsed.port !== null) {
            // Check for port overflow (this will catch the bug!)
            if (parsed.port < 0 || parsed.port > 65535 || isNaN(parsed.port)) {
                // Found a bug! Port should always be valid
                throw new Error(`Invalid port: ${parsed.port}`);
            }
        }

        // Test URL normalization
        const normalized = normalizeURL(url);

        // Test that normalized URL is parseable
        const reparsed = parseURL(normalized);

    } catch (e) {
        // Expected errors for malformed URLs
        // But type errors or assertion failures might indicate bugs
    }
}

// Fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    fuzzURLParser(FuzzerInput);
}

/*
 * HOW TO RUN THIS EXAMPLE:
 *
 * 1. Save this file as example1_url_parser.js
 *
 * 2. Run the fuzzer:
 *    ./jsfuzzer --js=examples/example1_url_parser.js -max_len=500 -timeout=5
 *
 * 3. The fuzzer should find the port validation bug quickly!
 *
 * EXPECTED BUG:
 * When fuzzer generates input like "http://example.com:99999999999"
 * the parseInt will create an invalid port number that exceeds 65535.
 *
 * The harness will detect this and report it as a potential security issue.
 */
