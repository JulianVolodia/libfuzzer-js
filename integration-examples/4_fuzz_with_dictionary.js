// Example: Fuzzing with Dictionary (Structured Input)
// This shows how to use dictionaries for more effective fuzzing

// ===== CODE TO FUZZ: HTTP Request Parser =====

function parseHTTPRequest(request) {
    const lines = request.split('\r\n');
    if (lines.length === 0) {
        throw new Error('Empty request');
    }

    // Parse request line: METHOD /path HTTP/1.1
    const requestLine = lines[0];
    const parts = requestLine.split(' ');

    if (parts.length !== 3) {
        throw new Error('Invalid request line');
    }

    const method = parts[0];
    const path = parts[1];
    const version = parts[2];

    // Validate method
    const validMethods = ['GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS'];
    if (!validMethods.includes(method)) {
        throw new Error('Invalid HTTP method');
    }

    // Validate version
    if (!version.startsWith('HTTP/')) {
        throw new Error('Invalid HTTP version');
    }

    // Parse headers
    const headers = {};
    let i = 1;
    for (; i < lines.length; i++) {
        const line = lines[i];
        if (line === '') break; // End of headers

        const colonPos = line.indexOf(':');
        if (colonPos === -1) {
            throw new Error('Invalid header format');
        }

        const key = line.substring(0, colonPos).trim();
        const value = line.substring(colonPos + 1).trim();

        headers[key] = value;
    }

    // Parse body (everything after empty line)
    const body = lines.slice(i + 1).join('\r\n');

    return {
        method: method,
        path: path,
        version: version,
        headers: headers,
        body: body
    };
}

function validateRequest(request) {
    // Additional validation
    if (request.method === 'POST' || request.method === 'PUT') {
        if (!request.headers['Content-Length']) {
            throw new Error('Content-Length required for POST/PUT');
        }

        const contentLength = parseInt(request.headers['Content-Length']);
        if (contentLength !== request.body.length) {
            throw new Error('Content-Length mismatch');
        }
    }

    // Validate path
    if (!request.path.startsWith('/')) {
        throw new Error('Path must start with /');
    }

    // Check for common headers
    if (request.headers['Host']) {
        const host = request.headers['Host'];
        if (host.length > 255) {
            throw new Error('Host header too long');
        }
    }

    return true;
}

// ===== FUZZER CODE =====

const inputStr = String.fromCharCode.apply(null, FuzzerInput);

try {
    const request = parseHTTPRequest(inputStr);
    validateRequest(request);

    // Additional processing could go here
} catch (e) {
    // Expected errors for malformed requests
}

// ===== DICTIONARY FILE =====
// Create a file named 'http.dict' with these entries:
//
// # HTTP Methods
// "GET"
// "POST"
// "PUT"
// "DELETE"
// "HEAD"
// "OPTIONS"
//
// # HTTP Versions
// "HTTP/1.0"
// "HTTP/1.1"
// "HTTP/2.0"
//
// # Common Headers
// "Host:"
// "Content-Length:"
// "Content-Type:"
// "User-Agent:"
// "Accept:"
//
// # Common Paths
// "/"
// "/index.html"
// "/api/"
//
// # Special Characters
// "\r\n"
// "\r\n\r\n"
// ": "
// " "
//
// Run this fuzzer with dictionary:
// ./jsfuzzer --js=integration-examples/4_fuzz_with_dictionary.js \
//            -dict=http.dict \
//            corpus -max_total_time=60
//
// The dictionary helps the fuzzer generate more valid-looking HTTP requests,
// which increases the chance of finding deeper bugs in the parsing logic.
