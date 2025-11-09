// Array and TypedArray Fuzzer
// Targets: Array bounds checking, TypedArray conversions, memory corruption
// Common issues: integer overflow in length, buffer overflows, incorrect type handling

function fuzzArrays(input) {
    if (!input || input.length < 4) return;

    try {
        // Test 1: Array constructor with fuzzer-controlled size
        const arraySize = (input[0] << 8) | input[1];
        const boundedSize = Math.min(arraySize, 10000); // Prevent OOM

        try {
            const arr = new Array(boundedSize);

            // Test array operations
            for (let i = 0; i < Math.min(input.length - 2, 100); i++) {
                arr[i] = input[i + 2];
            }

            // Test array methods that can cause issues
            arr.push(...input.slice(0, 10));
            arr.pop();
            arr.shift();
            arr.unshift(input[0]);
            arr.reverse();
            arr.sort();

            // Test splice with fuzzer-controlled parameters
            const spliceStart = input[2] % arr.length;
            const spliceCount = input[3] % 100;
            arr.splice(spliceStart, spliceCount, ...input.slice(0, 5));

            // Test slice
            arr.slice(input[4] % arr.length, input[5] % arr.length);

            // Test fill
            arr.fill(input[6], input[7] % arr.length, input[8] % arr.length);

        } catch (e) {}

        // Test 2: TypedArray operations
        const typedArrayTypes = [
            Uint8Array,
            Uint16Array,
            Uint32Array,
            Int8Array,
            Int16Array,
            Int32Array,
            Float32Array,
            Float64Array
        ];

        for (const TypedArrayConstructor of typedArrayTypes) {
            try {
                // Create from fuzzer input
                const ta1 = new TypedArrayConstructor(input.slice(0, 32));

                // Test various operations
                ta1.reverse();
                ta1.sort();

                // Test set with offset
                const offset = input[0] % (ta1.length - 1);
                ta1.set(input.slice(0, 4), offset);

                // Test subarray
                const start = input[1] % ta1.length;
                const end = input[2] % ta1.length;
                const sub = ta1.subarray(start, end);

                // Test copyWithin
                const target = input[3] % ta1.length;
                const copyStart = input[4] % ta1.length;
                ta1.copyWithin(target, copyStart);

                // Test buffer sharing
                const buffer = ta1.buffer;
                const ta2 = new Uint8Array(buffer);
                ta2[0] = input[10];

            } catch (e) {}
        }

        // Test 3: Array iteration and callbacks
        try {
            const arr = Array.from(input.slice(0, 100));

            // These methods execute callbacks which could have bugs
            arr.forEach((v, i) => arr[i] = v * 2);
            arr.map(v => v + 1);
            arr.filter(v => v > 100);
            arr.reduce((acc, v) => acc + v, 0);
            arr.find(v => v === input[0]);
            arr.findIndex(v => v === input[0]);
            arr.some(v => v > 200);
            arr.every(v => v < 256);

        } catch (e) {}

        // Test 4: Array-like objects and length property manipulation
        try {
            const arrayLike = {
                length: input[0] << 8 | input[1]
            };

            for (let i = 0; i < Math.min(input.length, 100); i++) {
                arrayLike[i] = input[i];
            }

            // Convert to real array
            const converted = Array.from(arrayLike);
            Array.prototype.slice.call(arrayLike);

        } catch (e) {}

        // Test 5: Sparse arrays
        try {
            const sparse = [];
            sparse[input[0] * 100] = input[1];
            sparse[input[2] * 100] = input[3];

            sparse.forEach(v => v);
            sparse.map(v => v);
            JSON.stringify(sparse);

        } catch (e) {}

        // Test 6: Array concat and flat
        try {
            const arr1 = Array.from(input.slice(0, 10));
            const arr2 = Array.from(input.slice(10, 20));

            const concatenated = arr1.concat(arr2);

            // Test flat with different depths
            const nested = [arr1, [arr2, [input.slice(20, 30)]]];
            nested.flat(1);
            nested.flat(2);
            nested.flat(input[0] % 10);

        } catch (e) {}

    } catch (e) {
        // Catch any unhandled errors
    }
}

// Fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    fuzzArrays(FuzzerInput);
}
