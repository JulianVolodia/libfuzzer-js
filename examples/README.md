# Fuzzing Examples - Learn by Doing

This directory contains practical, real-world examples showing how to fuzz different types of JavaScript code.

---

## Quick Start

```bash
# Run any example directly
./jsfuzzer --js=examples/example1_url_parser.js -timeout=5

# Or use the deployment script for interactive setup
./deploy_fuzzer.sh
```

---

## Available Examples

### 1. **URL Parser** (`example1_url_parser.js`)

**What it demonstrates:**
- Fuzzing a string parsing function
- Finding validation bugs
- Testing edge cases in URL handling

**The Bug:**
The URL parser doesn't validate port numbers properly. When fuzzer generates `http://example.com:999999999`, the `parseInt` creates an invalid port that exceeds 65535.

**Run it:**
```bash
./jsfuzzer --js=examples/example1_url_parser.js -max_len=500 -timeout=5
```

**Expected Result:**
The fuzzer should quickly find inputs that create invalid port numbers.

**Learning Points:**
- How to convert fuzzer bytes to strings
- How to validate parsed data
- How to catch logic errors with assertions

---

### 2. **API Request Validator** (`example2_api_validator.js`)

**What it demonstrates:**
- Fuzzing validation and sanitization code
- Finding type confusion bugs
- Testing security filters

**The Bugs:**
1. Age validator accepts strings like `"25"` instead of requiring numbers
2. Sanitizer doesn't handle Unicode normalization
3. No protection against prototype pollution

**Run it:**
```bash
./jsfuzzer --js=examples/example2_api_validator.js -max_len=200 -timeout=5
```

**Expected Result:**
Fuzzer will generate inputs that bypass validation rules.

**Learning Points:**
- How to generate structured data from fuzzer input
- How to test multiple functions in one harness
- How to find validation bypasses

---

### 3. **Template Engine** (`example3_template_engine.js`)

**What it demonstrates:**
- Fuzzing template processing
- Finding performance issues (ReDoS-like bugs)
- Testing complex string operations

**The Bugs:**
1. No limit on loop iterations (can cause hangs)
2. No limit on repeat helper (memory exhaustion)
3. Prototype pollution via `getNestedValue`
4. Potential ReDoS in regex patterns

**Run it:**
```bash
# Normal timeout
./jsfuzzer --js=examples/example3_template_engine.js -max_len=500 -timeout=10

# Longer timeout to catch performance issues
./jsfuzzer --js=examples/example3_template_engine.js -max_len=500 -timeout=25
```

**Expected Result:**
Fuzzer will find inputs that cause hangs or excessive processing.

**Learning Points:**
- How to use different fuzzing strategies
- How to detect performance issues
- How to test template engines and interpreters

---

## How These Examples Work

### Anatomy of a Fuzzing Example

Each example follows this structure:

```javascript
// 1. YOUR CODE
// The actual code you want to fuzz (with intentional bugs)

function yourFunction(input) {
    // Your implementation
    // Contains bugs for demonstration
}

// 2. FUZZING HARNESS
// Converts fuzzer input to format your code expects

function fuzzYourCode(input) {
    try {
        // Convert fuzzer bytes to appropriate format
        const formatted = formatInput(input);

        // Call your function
        yourFunction(formatted);

        // Add assertions to catch logic errors
        validateOutput(formatted);

    } catch (e) {
        // Handle expected errors
    }
}

// 3. FUZZER ENTRY POINT
// libFuzzer calls this with random input

if (typeof FuzzerInput !== 'undefined') {
    fuzzYourCode(FuzzerInput);
}
```

### The Fuzzing Cycle

```
1. libFuzzer generates random bytes
         ↓
2. Harness converts bytes to test data
         ↓
3. Your code processes the test data
         ↓
4. Sanitizers detect crashes/bugs
         ↓
5. libFuzzer mutates input based on coverage
         ↓
   (repeat)
```

---

## Creating Your Own Examples

### Template for New Examples

```javascript
// Your code to fuzz
function myFunction(input) {
    // TODO: Add your code here
    return input.toUpperCase();
}

// Fuzzing harness
function fuzzMyFunction(input) {
    if (!input || input.length === 0) return;

    try {
        // Convert fuzzer input
        const testInput = String.fromCharCode.apply(null, input);

        // Call your function
        const result = myFunction(testInput);

        // Add validation
        if (typeof result !== 'string') {
            throw new Error('Result should be string');
        }

    } catch (e) {
        // Expected errors
    }
}

// Fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    fuzzMyFunction(FuzzerInput);
}
```

### Tips for Good Examples

1. **Start Simple**
   - Focus on one function at a time
   - Add complexity gradually

2. **Add Assertions**
   - Validate outputs
   - Check invariants
   - Detect logic errors

3. **Handle Exceptions**
   - Wrap in try-catch
   - Let memory errors crash (ASAN will catch them)
   - Continue fuzzing on expected errors

4. **Test Edge Cases**
   - Empty input
   - Very large input
   - Special characters
   - Type confusion

---

## Advanced Examples

### Example: Fuzzing with Multiple Strategies

```javascript
function comprehensiveFuzz(input) {
    if (input.length < 2) return;

    // Use first byte to select strategy
    const strategy = input[0] % 4;

    switch (strategy) {
        case 0:
            // Test string operations
            testStrings(input.slice(1));
            break;

        case 1:
            // Test numeric operations
            testNumbers(input.slice(1));
            break;

        case 2:
            // Test edge cases
            testEdgeCases(input.slice(1));
            break;

        case 3:
            // Test combinations
            testCombinations(input.slice(1));
            break;
    }
}
```

### Example: Stateful Fuzzing

```javascript
let globalState = { initialized: false, data: [] };

function statefulFuzz(input) {
    if (!globalState.initialized) {
        globalState.initialized = true;
        initialize();
    }

    const operation = input[0] % 3;

    switch (operation) {
        case 0: addData(input.slice(1)); break;
        case 1: processData(); break;
        case 2: resetState(); break;
    }
}
```

---

## Debugging Tips

### When Fuzzer Finds a Crash

```bash
# 1. Reproduce the crash
./jsfuzzer --js=examples/example1_url_parser.js crash-abc123

# 2. Examine the input
hexdump -C crash-abc123

# 3. Minimize the crash
./jsfuzzer --js=examples/example1_url_parser.js -minimize_crash=1 crash-abc123

# 4. Convert to readable format (if text)
cat crash-abc123 | tr -cd '\11\12\15\40-\176'
```

### Understanding the Output

```
#12345 NEW    cov: 234 bits: 567 corp: 12 exec/s: 100
```

- **#12345**: Iteration number
- **NEW**: Found new coverage
- **cov: 234**: Coverage edges hit
- **corp: 12**: Corpus size (interesting inputs)
- **exec/s: 100**: Executions per second

---

## Performance Tips

### Speed Up Fuzzing

```bash
# Reduce input length
./jsfuzzer --js=example.js -max_len=100

# Reduce timeout
./jsfuzzer --js=example.js -timeout=1

# Use multiple workers (if supported)
./jsfuzzer --js=example.js -workers=4
```

### Improve Bug Detection

```bash
# Increase timeout (for ReDoS)
./jsfuzzer --js=example.js -timeout=25

# Build with sanitizers
clang++ -fsanitize=address,undefined ...

# Run longer
./jsfuzzer --js=example.js -max_total_time=3600
```

---

## Next Steps

1. **Try the examples**
   ```bash
   ./jsfuzzer --js=examples/example1_url_parser.js
   ```

2. **Modify an example**
   - Add your own functions
   - Add more test cases
   - Fix the bugs and verify

3. **Create your own**
   - Use the template above
   - Start with one function
   - Gradually expand coverage

4. **Use the deployment script**
   ```bash
   ./deploy_fuzzer.sh
   ```

5. **Read the integration guide**
   - `FUZZING_INTEGRATION_GUIDE.md`
   - Learn advanced techniques
   - CI/CD integration

---

## Common Patterns

### Pattern 1: String Parsing

```javascript
function fuzzStringParser(input) {
    const str = String.fromCharCode.apply(null, input);
    parseString(str);
}
```

### Pattern 2: Binary Data

```javascript
function fuzzBinaryParser(input) {
    // input is already Uint8Array
    parseBinary(input);
}
```

### Pattern 3: Structured Data

```javascript
function fuzzStructured(input) {
    const obj = {
        id: (input[0] << 8) | input[1],
        type: input[2] % 4,
        data: String.fromCharCode.apply(null, input.slice(3))
    };
    processObject(obj);
}
```

### Pattern 4: Multiple Functions

```javascript
function fuzzMultiple(input) {
    const selector = input[0] % 3;

    switch (selector) {
        case 0: testFunction1(input.slice(1)); break;
        case 1: testFunction2(input.slice(1)); break;
        case 2: testFunction3(input.slice(1)); break;
    }
}
```

---

## Resources

- **Main Guide**: `../FUZZING_INTEGRATION_GUIDE.md`
- **Vulnerability Research**: `../VULNERABILITY_RESEARCH_GUIDE.md`
- **Quick Start**: `../QUICK_START_GUIDE.md`
- **Deployment**: `../deploy_fuzzer.sh`

---

## Contributing

Found an interesting bug pattern? Create an example and share it!

1. Create `exampleN_description.js`
2. Include comments explaining the bugs
3. Add running instructions
4. Submit a pull request

---

**Happy Learning and Fuzzing! 🐛**
