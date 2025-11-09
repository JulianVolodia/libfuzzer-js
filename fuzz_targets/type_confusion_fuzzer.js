// Type Confusion and Coercion Fuzzer
// Targets: Type coercion bugs, unexpected type conversions, prototype pollution
// Common issues: toString/valueOf manipulation, prototype chain issues

function fuzzTypeCoercion(input) {
    if (!input || input.length < 8) return;

    try {
        // Test 1: Custom toString and valueOf
        const customObj = {
            toString: function() {
                // Return different types based on fuzzer input
                if (input[0] % 3 === 0) return String.fromCharCode(...input.slice(0, 10));
                if (input[0] % 3 === 1) return input[0];
                return { nested: 'object' };
            },
            valueOf: function() {
                if (input[1] % 3 === 0) return input[1];
                if (input[1] % 3 === 1) return String.fromCharCode(...input.slice(1, 5));
                return [1, 2, 3];
            }
        };

        // Trigger various coercions
        try {
            const str = '' + customObj;  // Calls toString
            const num = +customObj;      // Calls valueOf
            const bool = !!customObj;
            const neg = -customObj;

            // Arithmetic operations
            customObj + customObj;
            customObj - input[2];
            customObj * input[3];
            customObj / input[4];
            customObj % input[5];

            // Comparison operations
            customObj == input[6];
            customObj < input[7];
            customObj > input[8];

            // Use as property key
            const testObj = {};
            testObj[customObj] = 'test';
            testObj[customObj];

            // Use as array index
            const testArr = [1, 2, 3, 4, 5];
            testArr[customObj] = 'fuzz';
            testArr[customObj];

        } catch (e) {}

        // Test 2: Proxy objects with custom handlers
        try {
            const target = { value: input[0] };
            const handler = {
                get: function(obj, prop) {
                    // Return different types based on fuzzer input
                    if (input[2] % 4 === 0) return input[3];
                    if (input[2] % 4 === 1) return 'string';
                    if (input[2] % 4 === 2) return { nested: true };
                    return function() { return input[4]; };
                },
                set: function(obj, prop, value) {
                    // Trigger type conversions
                    obj[prop] = String(value) + Number(value);
                    return true;
                }
            };

            const proxy = new Proxy(target, handler);
            proxy.value;
            proxy.value = input[5];
            proxy.newProp = input[6];

        } catch (e) {}

        // Test 3: Prototype pollution attempts
        try {
            const obj = {};
            const key = String.fromCharCode(...input.slice(0, 10));
            const value = input[10];

            // Try various property access patterns
            obj[key] = value;
            obj['__proto__'] = { polluted: value };
            obj['constructor'] = { polluted: value };
            obj['prototype'] = { polluted: value };

            // Check if pollution occurred
            const check = {};
            check.polluted;

        } catch (e) {}

        // Test 4: Symbol toPrimitive
        try {
            const objWithToPrimitive = {
                [Symbol.toPrimitive]: function(hint) {
                    if (hint === 'number') return input[0];
                    if (hint === 'string') return String.fromCharCode(...input.slice(0, 5));
                    return input[1];
                }
            };

            // Trigger with different hints
            +objWithToPrimitive;      // number hint
            `${objWithToPrimitive}`;  // string hint
            objWithToPrimitive + '';  // default hint

        } catch (e) {}

        // Test 5: Class and constructor manipulation
        try {
            class CustomClass {
                constructor(value) {
                    this.value = value;
                }

                valueOf() { return input[2]; }
                toString() { return String.fromCharCode(...input.slice(3, 8)); }
            }

            const instance = new CustomClass(input[0]);

            // Trigger conversions
            +instance;
            '' + instance;
            instance + input[4];

            // Modify constructor
            instance.constructor = function() { return input[5]; };

        } catch (e) {}

        // Test 6: Type-specific operations
        try {
            // Number operations
            const numStr = String.fromCharCode(...input.slice(0, 20));
            Number(numStr);
            parseInt(numStr, input[0] % 37);
            parseFloat(numStr);

            // Boolean coercion
            Boolean(input[1]);
            Boolean('');
            Boolean(0);
            Boolean(null);
            Boolean(undefined);

            // String coercion with objects
            String({ toString: () => input[2] });
            String({ valueOf: () => input[3] });

        } catch (e) {}

        // Test 7: Date object coercion
        try {
            const dateStr = String.fromCharCode(...input.slice(0, 30));
            const date = new Date(dateStr);

            +date;              // valueOf
            '' + date;          // toString
            date.toJSON();
            date.toString();
            date.valueOf();

        } catch (e) {}

        // Test 8: Mixed type arrays
        try {
            const mixedArray = [
                input[0],                                      // number
                String.fromCharCode(...input.slice(1, 5)),   // string
                { value: input[5] },                          // object
                [input[6], input[7]],                         // array
                null,
                undefined,
                true,
                Symbol('test')
            ];

            // Operations that involve type conversions
            mixedArray.join('');
            mixedArray.toString();
            JSON.stringify(mixedArray);
            mixedArray.sort();

        } catch (e) {}

    } catch (e) {
        // Catch any unhandled errors
    }
}

// Fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    fuzzTypeCoercion(FuzzerInput);
}
