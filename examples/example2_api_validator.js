// Example 2: API Request Validator - Fuzzing Data Validation
// This shows how to fuzz validation and sanitization code

// ============================================
// YOUR CODE (the target to fuzz)
// ============================================

class APIRequestValidator {
    constructor() {
        this.rules = {};
    }

    addRule(field, validator) {
        this.rules[field] = validator;
    }

    validate(request) {
        const errors = [];

        // Check required fields
        for (const field in this.rules) {
            if (!(field in request)) {
                errors.push(`Missing required field: ${field}`);
                continue;
            }

            // Run validator
            const validator = this.rules[field];
            try {
                const isValid = validator(request[field]);
                if (!isValid) {
                    errors.push(`Invalid value for field: ${field}`);
                }
            } catch (e) {
                errors.push(`Validation error for ${field}: ${e.message}`);
            }
        }

        return {
            valid: errors.length === 0,
            errors: errors
        };
    }

    sanitize(request) {
        const sanitized = {};

        for (const field in request) {
            const value = request[field];

            // Sanitize strings
            if (typeof value === 'string') {
                // Remove HTML tags
                sanitized[field] = value.replace(/<[^>]*>/g, '');

                // Remove SQL injection attempts
                sanitized[field] = sanitized[field]
                    .replace(/['";]/g, '')
                    .replace(/--/g, '')
                    .replace(/\/\*/g, '');

                // BUG: Doesn't handle Unicode normalization attacks!
                // Different Unicode representations could bypass filters
            } else {
                sanitized[field] = value;
            }
        }

        return sanitized;
    }
}

// Create validator instance
const validator = new APIRequestValidator();

// Add validation rules
validator.addRule('username', (val) => {
    return typeof val === 'string' &&
           val.length >= 3 &&
           val.length <= 20 &&
           /^[a-zA-Z0-9_]+$/.test(val);
});

validator.addRule('email', (val) => {
    return typeof val === 'string' &&
           /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val);
});

validator.addRule('age', (val) => {
    // BUG: Doesn't properly validate number type!
    // Could accept strings that look like numbers
    return val >= 0 && val <= 150;
});

validator.addRule('role', (val) => {
    const validRoles = ['user', 'admin', 'moderator'];
    return validRoles.includes(val);
});

// ============================================
// FUZZING HARNESS
// ============================================

function fuzzAPIValidator(input) {
    if (!input || input.length < 20) return;

    try {
        // Generate API request from fuzzer input
        const request = {
            username: String.fromCharCode.apply(null, input.slice(0, 20)),
            email: String.fromCharCode.apply(null, input.slice(20, 50)),
            age: (input[50] << 8) | input[51],  // Can be > 255
            role: String.fromCharCode.apply(null, input.slice(52, 60))
        };

        // Test validation
        const validationResult = validator.validate(request);

        // Test sanitization
        const sanitized = validator.sanitize(request);

        // Test edge cases
        if (input.length > 60) {
            // Test with missing fields
            const partial = {
                username: request.username
            };
            validator.validate(partial);

            // Test with extra fields
            const extra = {
                ...request,
                extraField: 'unexpected',
                __proto__: 'prototype pollution attempt'
            };
            validator.validate(extra);

            // Test sanitization with special characters
            const malicious = {
                username: '<script>alert("xss")</script>',
                email: 'test@test.com\'; DROP TABLE users;--',
                age: '25',  // String instead of number (will expose bug!)
                role: 'admin'
            };
            validator.validate(malicious);
            validator.sanitize(malicious);
        }

    } catch (e) {
        // Expected errors for invalid input
    }
}

// Fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    fuzzAPIValidator(FuzzerInput);
}

/*
 * HOW TO RUN THIS EXAMPLE:
 *
 * 1. Save this file as example2_api_validator.js
 *
 * 2. Run the fuzzer:
 *    ./jsfuzzer --js=examples/example2_api_validator.js -max_len=200 -timeout=5
 *
 * 3. The fuzzer will find validation bypasses!
 *
 * EXPECTED BUGS:
 * - Age validator accepts strings like "25" instead of numbers
 * - Sanitizer doesn't handle Unicode normalization
 * - No prototype pollution protection
 */
