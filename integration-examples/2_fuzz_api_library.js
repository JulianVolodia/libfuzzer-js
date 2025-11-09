// Example: Fuzzing an API Library
// This shows how to fuzz a library with multiple API functions

// ===== YOUR API LIBRARY (the code you want to fuzz) =====

const MyMathLib = {
    // Calculate factorial
    factorial: function(n) {
        if (n < 0) throw new Error('Negative number');
        if (n > 20) throw new Error('Number too large');
        if (n === 0 || n === 1) return 1;

        let result = 1;
        for (let i = 2; i <= n; i++) {
            result *= i;
        }
        return result;
    },

    // Calculate Fibonacci number
    fibonacci: function(n) {
        if (n < 0) throw new Error('Negative number');
        if (n > 40) throw new Error('Number too large');
        if (n <= 1) return n;

        let a = 0, b = 1;
        for (let i = 2; i <= n; i++) {
            const temp = a + b;
            a = b;
            b = temp;
        }
        return b;
    },

    // Check if number is prime
    isPrime: function(n) {
        if (n < 2) return false;
        if (n === 2) return true;
        if (n % 2 === 0) return false;

        for (let i = 3; i <= Math.sqrt(n); i += 2) {
            if (n % i === 0) return false;
        }
        return true;
    },

    // Greatest common divisor
    gcd: function(a, b) {
        a = Math.abs(a);
        b = Math.abs(b);

        while (b !== 0) {
            const temp = b;
            b = a % b;
            a = temp;
        }
        return a;
    },

    // Parse and evaluate expression
    evaluate: function(expr) {
        // Simple expression evaluator
        // Supports: +, -, *, /, numbers
        const tokens = expr.match(/\d+|[+\-*/]/g);
        if (!tokens) throw new Error('Invalid expression');

        let result = parseInt(tokens[0]);
        for (let i = 1; i < tokens.length; i += 2) {
            const op = tokens[i];
            const num = parseInt(tokens[i + 1]);

            if (isNaN(num)) throw new Error('Invalid number');

            switch (op) {
                case '+': result += num; break;
                case '-': result -= num; break;
                case '*': result *= num; break;
                case '/':
                    if (num === 0) throw new Error('Division by zero');
                    result /= num;
                    break;
                default:
                    throw new Error('Unknown operator');
            }
        }
        return result;
    }
};

// ===== FUZZER CODE =====

// Helper to extract numbers from fuzzer input
function extractInt32(offset) {
    return (FuzzerInput[offset] || 0) |
           ((FuzzerInput[offset + 1] || 0) << 8) |
           ((FuzzerInput[offset + 2] || 0) << 16) |
           ((FuzzerInput[offset + 3] || 0) << 24);
}

function extractByte(offset) {
    return FuzzerInput[offset] || 0;
}

try {
    if (FuzzerInput.length >= 5) {
        // Use first byte to select which API to fuzz
        const apiChoice = extractByte(0) % 5;

        switch (apiChoice) {
            case 0: {
                // Fuzz factorial
                const n = extractInt32(1) % 100;
                MyMathLib.factorial(n);
                break;
            }

            case 1: {
                // Fuzz fibonacci
                const n = extractInt32(1) % 100;
                MyMathLib.fibonacci(n);
                break;
            }

            case 2: {
                // Fuzz isPrime
                const n = extractInt32(1);
                MyMathLib.isPrime(n);
                break;
            }

            case 3: {
                // Fuzz gcd
                if (FuzzerInput.length >= 9) {
                    const a = extractInt32(1);
                    const b = extractInt32(5);
                    MyMathLib.gcd(a, b);
                }
                break;
            }

            case 4: {
                // Fuzz expression evaluator
                const expr = String.fromCharCode.apply(null, FuzzerInput.slice(1));
                MyMathLib.evaluate(expr);
                break;
            }
        }
    }
} catch (e) {
    // Expected errors for invalid input
}

// Run this fuzzer with:
// ./jsfuzzer --js=integration-examples/2_fuzz_api_library.js corpus -max_total_time=60
