// Comprehensive JavaScript Fuzzer
// Targets: Multiple subsystems in a single fuzzing session
// Combines various vulnerability patterns for maximum coverage

function comprehensiveFuzz(input) {
    if (!input || input.length < 10) return;

    // Use different strategies based on first byte
    const strategy = input[0] % 8;

    try {
        switch (strategy) {
            case 0:
                fuzzArithmetic(input.slice(1));
                break;
            case 1:
                fuzzObjects(input.slice(1));
                break;
            case 2:
                fuzzFunctions(input.slice(1));
                break;
            case 3:
                fuzzExceptions(input.slice(1));
                break;
            case 4:
                fuzzEval(input.slice(1));
                break;
            case 5:
                fuzzPrototypes(input.slice(1));
                break;
            case 6:
                fuzzAsyncOperations(input.slice(1));
                break;
            case 7:
                fuzzMixedOperations(input.slice(1));
                break;
        }
    } catch (e) {
        // Continue fuzzing even on errors
    }
}

// Arithmetic and number operations
function fuzzArithmetic(input) {
    try {
        const a = (input[0] << 24) | (input[1] << 16) | (input[2] << 8) | input[3];
        const b = (input[4] << 24) | (input[5] << 16) | (input[6] << 8) | input[7];

        // Basic arithmetic
        const sum = a + b;
        const diff = a - b;
        const product = a * b;
        const quotient = a / b;
        const remainder = a % b;
        const power = a ** (b % 10);

        // Bitwise operations
        const and = a & b;
        const or = a | b;
        const xor = a ^ b;
        const leftShift = a << (b % 32);
        const rightShift = a >> (b % 32);
        const unsignedShift = a >>> (b % 32);

        // Math operations
        Math.abs(a);
        Math.sqrt(a);
        Math.pow(a, b % 10);
        Math.min(a, b);
        Math.max(a, b);
        Math.floor(a / b);
        Math.ceil(a / b);
        Math.round(a / b);

        // Special number values
        const inf = 1 / 0;
        const negInf = -1 / 0;
        const nan = 0 / 0;

        inf + a;
        negInf * b;
        nan + sum;

        // Number conversions
        Number.isNaN(nan);
        Number.isFinite(inf);
        Number.isInteger(a);
        Number.isSafeInteger(product);

    } catch (e) {}
}

// Object operations and property access
function fuzzObjects(input) {
    try {
        const obj = {};

        // Add properties
        for (let i = 0; i < Math.min(input.length, 100); i++) {
            const key = `key${input[i]}`;
            obj[key] = input[i];
        }

        // Property operations
        Object.keys(obj);
        Object.values(obj);
        Object.entries(obj);
        Object.getOwnPropertyNames(obj);
        Object.getOwnPropertyDescriptors(obj);

        // Property definition
        Object.defineProperty(obj, 'special', {
            value: input[0],
            writable: input[1] % 2 === 0,
            enumerable: input[2] % 2 === 0,
            configurable: input[3] % 2 === 0
        });

        // Object manipulation
        Object.freeze(obj);
        Object.isFrozen(obj);
        Object.seal(obj);
        Object.isSealed(obj);
        Object.preventExtensions(obj);
        Object.isExtensible(obj);

        // Property access patterns
        obj[input[4]];
        obj[String.fromCharCode(...input.slice(5, 10))];

        // Getters and setters
        const objWithAccessors = {
            _value: input[5],
            get value() { return this._value; },
            set value(v) { this._value = v; }
        };

        objWithAccessors.value;
        objWithAccessors.value = input[6];

    } catch (e) {}
}

// Function operations
function fuzzFunctions(input) {
    try {
        // Function constructor
        const funcBody = String.fromCharCode(...input.slice(0, 50));

        try {
            const dynamicFunc = new Function('x', funcBody);
            dynamicFunc(input[50]);
        } catch (e) {}

        // Function methods
        const testFunc = function(a, b) { return a + b; };

        testFunc.call(null, input[0], input[1]);
        testFunc.apply(null, [input[2], input[3]]);
        const boundFunc = testFunc.bind(null, input[4]);
        boundFunc(input[5]);

        // Arrow functions
        const arrow = (x) => x * 2;
        arrow(input[6]);

        // Generator functions
        function* generator() {
            for (let i = 0; i < input.length && i < 10; i++) {
                yield input[i];
            }
        }

        const gen = generator();
        gen.next();
        gen.next();

        // Function properties
        testFunc.length;
        testFunc.name;
        testFunc.toString();

    } catch (e) {}
}

// Exception handling
function fuzzExceptions(input) {
    try {
        // Throw different error types
        const errorType = input[0] % 7;

        try {
            switch (errorType) {
                case 0:
                    throw new Error(String.fromCharCode(...input.slice(1, 10)));
                case 1:
                    throw new TypeError(String.fromCharCode(...input.slice(1, 10)));
                case 2:
                    throw new RangeError(String.fromCharCode(...input.slice(1, 10)));
                case 3:
                    throw new ReferenceError(String.fromCharCode(...input.slice(1, 10)));
                case 4:
                    throw new SyntaxError(String.fromCharCode(...input.slice(1, 10)));
                case 5:
                    throw new URIError(String.fromCharCode(...input.slice(1, 10)));
                case 6:
                    throw input[1];  // Throw primitive value
            }
        } catch (e) {
            // Inspect error
            e.message;
            e.name;
            e.stack;
            e.toString();
        }

        // Finally blocks
        try {
            if (input[2] % 2 === 0) throw new Error('test');
        } finally {
            // Cleanup code
            const x = input[3];
        }

    } catch (e) {}
}

// Eval and code generation
function fuzzEval(input) {
    try {
        const code = String.fromCharCode(...input.slice(0, Math.min(input.length, 200)));

        // Try to evaluate as JavaScript
        try {
            eval(code);
        } catch (e) {
            // Invalid JavaScript or runtime error
        }

        // Indirect eval
        try {
            (0, eval)(code);
        } catch (e) {}

    } catch (e) {}
}

// Prototype chain manipulation
function fuzzPrototypes(input) {
    try {
        // Create object with custom prototype
        const proto = {
            customMethod: function() { return input[0]; }
        };

        const obj = Object.create(proto);
        obj.ownProperty = input[1];

        // Prototype operations
        Object.getPrototypeOf(obj);
        Object.setPrototypeOf(obj, { newMethod: () => input[2] });

        // Constructor manipulation
        function CustomConstructor() {
            this.value = input[3];
        }

        CustomConstructor.prototype.method = function() { return this.value; };

        const instance = new CustomConstructor();
        instance.method();

        // Instanceof checks
        instance instanceof CustomConstructor;
        instance instanceof Object;

        // hasOwnProperty
        instance.hasOwnProperty('value');
        instance.hasOwnProperty('method');

    } catch (e) {}
}

// Async operations (if supported)
function fuzzAsyncOperations(input) {
    try {
        // Promise operations
        const promise1 = Promise.resolve(input[0]);
        const promise2 = Promise.reject(input[1]);

        promise1.then(v => v * 2).catch(e => e);
        promise2.then(v => v).catch(e => e);

        // Promise combinators
        Promise.all([promise1, promise2]).catch(e => e);
        Promise.race([promise1, promise2]).catch(e => e);
        Promise.allSettled([promise1, promise2]).catch(e => e);

        // Create promise chain
        Promise.resolve(input[2])
            .then(v => v + input[3])
            .then(v => v * input[4])
            .catch(e => e);

    } catch (e) {}
}

// Mixed operations combining multiple features
function fuzzMixedOperations(input) {
    try {
        // Combine arrays, objects, and functions
        const arr = Array.from(input.slice(0, 20));
        const obj = { data: arr };

        const processor = function(item) {
            return {
                original: item,
                doubled: item * 2,
                string: String.fromCharCode(item)
            };
        };

        const processed = arr.map(processor);

        // Complex property access
        processed.forEach((item, index) => {
            obj[`item_${index}`] = item;
        });

        // JSON round-trip
        try {
            const json = JSON.stringify(obj);
            const parsed = JSON.parse(json);

            // Access nested properties
            for (const key in parsed) {
                if (parsed.hasOwnProperty(key)) {
                    const value = parsed[key];
                    typeof value;
                }
            }
        } catch (e) {}

        // Regex on generated strings
        try {
            const str = String.fromCharCode(...input.slice(20, 40));
            const pattern = String.fromCharCode(...input.slice(40, 45));
            const re = new RegExp(pattern, 'gi');
            str.match(re);
        } catch (e) {}

    } catch (e) {}
}

// Fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    comprehensiveFuzz(FuzzerInput);
}
