# Fuzzing Targets

This directory contains specialized JavaScript fuzzing targets designed to find vulnerabilities in JavaScript engines.

## Available Fuzzers

### 1. **regexp_fuzzer.js**
Targets regular expression engine vulnerabilities.

**Focus Areas:**
- ReDoS (Regular Expression Denial of Service)
- Regex engine memory corruption
- Nested quantifier handling
- Backreference processing
- Unicode in patterns

**Usage:**
```bash
./jsfuzzer --js=fuzz_targets/regexp_fuzzer.js -max_len=200 -timeout=5
```

**Common Vulnerabilities Found:**
- Catastrophic backtracking (ReDoS)
- Buffer overflows in regex compilation
- Incorrect Unicode handling
- Stack overflow from deep recursion

---

### 2. **json_fuzzer.js**
Targets JSON parsing and stringification.

**Focus Areas:**
- Deep nesting (stack overflow)
- Large numbers (integer overflow)
- Unicode escape sequences
- Circular reference handling
- Objects with many keys

**Usage:**
```bash
./jsfuzzer --js=fuzz_targets/json_fuzzer.js -max_len=10000
```

**Common Vulnerabilities Found:**
- Stack overflow from deeply nested structures
- Integer overflow in length calculations
- Memory exhaustion
- Incorrect escape sequence handling

---

### 3. **array_fuzzer.js**
Targets array and TypedArray operations.

**Focus Areas:**
- Array bounds checking
- TypedArray buffer operations
- Integer overflow in array length
- Buffer sharing between TypedArrays
- Array method edge cases

**Usage:**
```bash
./jsfuzzer --js=fuzz_targets/array_fuzzer.js -max_len=1000
```

**Common Vulnerabilities Found:**
- Out-of-bounds access
- Integer overflow in array operations
- Use-after-free in buffer operations
- Type confusion in TypedArrays

---

### 4. **type_confusion_fuzzer.js**
Targets type coercion and conversion bugs.

**Focus Areas:**
- toString/valueOf manipulation
- Prototype pollution
- Type coercion edge cases
- Proxy object handling
- Symbol.toPrimitive

**Usage:**
```bash
./jsfuzzer --js=fuzz_targets/type_confusion_fuzzer.js -max_len=500
```

**Common Vulnerabilities Found:**
- Type confusion leading to arbitrary code execution
- Prototype pollution
- Incorrect type handling in operators
- Proxy handler bugs

---

### 5. **string_fuzzer.js**
Targets string operations and Unicode handling.

**Focus Areas:**
- Unicode and surrogate pairs
- String normalization
- Large string operations
- String method edge cases
- Locale-specific operations

**Usage:**
```bash
./jsfuzzer --js=fuzz_targets/string_fuzzer.js -max_len=2000
```

**Common Vulnerabilities Found:**
- Buffer overflows in string operations
- Incorrect Unicode handling
- Integer overflow in length calculations
- Normalization bugs

---

### 6. **comprehensive_fuzzer.js**
Combines multiple fuzzing strategies in a single session.

**Focus Areas:**
- All of the above
- Multiple subsystems tested together
- Cross-feature interactions
- Complex execution patterns

**Usage:**
```bash
./jsfuzzer --js=fuzz_targets/comprehensive_fuzzer.js -max_len=1000
```

**Use Case:**
Best for long-running fuzzing campaigns where you want broad coverage across all JavaScript features.

---

## General Usage Tips

### Basic Fuzzing

```bash
# Simple fuzzing run
./jsfuzzer --js=fuzz_targets/TARGET.js

# With timeout (prevent hangs)
./jsfuzzer --js=fuzz_targets/TARGET.js -timeout=10

# Limit input length
./jsfuzzer --js=fuzz_targets/TARGET.js -max_len=1000

# Run for specific duration
./jsfuzzer --js=fuzz_targets/TARGET.js -max_total_time=3600

# Limit number of runs
./jsfuzzer --js=fuzz_targets/TARGET.js -runs=1000000
```

### Advanced Fuzzing

```bash
# Use corpus directory (saves interesting inputs)
./jsfuzzer --js=fuzz_targets/TARGET.js corpus/

# Use dictionary (improves mutation quality)
./jsfuzzer --js=fuzz_targets/TARGET.js -dict=fuzzer.dict

# Minimize corpus
./jsfuzzer --js=fuzz_targets/TARGET.js -merge=1 corpus_min/ corpus/

# Reproduce crash
./jsfuzzer --js=fuzz_targets/TARGET.js crash-FILE

# Minimize crashing input
./jsfuzzer --js=fuzz_targets/TARGET.js -minimize_crash=1 crash-FILE
```

### Parallel Fuzzing

Run multiple fuzzer instances for better coverage:

```bash
# Terminal 1
./jsfuzzer --js=fuzz_targets/regexp_fuzzer.js corpus/

# Terminal 2
./jsfuzzer --js=fuzz_targets/json_fuzzer.js corpus/

# Terminal 3
./jsfuzzer --js=fuzz_targets/array_fuzzer.js corpus/
```

---

## Creating Custom Fuzzers

### Template

```javascript
function fuzzMyFeature(input) {
    if (!input || input.length < MIN_SIZE) return;

    try {
        // 1. Extract parameters from fuzzer input
        const param1 = input[0];
        const param2 = input[1];

        // 2. Create test data
        const testData = convertInputToTestData(input);

        // 3. Exercise the feature
        someJavaScriptFeature(testData);

        // 4. Test edge cases
        edgeCaseFunction(param1, param2);

    } catch (e) {
        // Catch exceptions to continue fuzzing
        // Only crash on actual bugs (ASAN will catch memory errors)
    }
}

// Fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    fuzzMyFeature(FuzzerInput);
}
```

### Best Practices

1. **Handle exceptions gracefully** - Don't let expected exceptions stop fuzzing
2. **Use input efficiently** - Extract multiple parameters from fuzzer input
3. **Limit resource usage** - Bound loop counts, string lengths, etc.
4. **Test edge cases** - Empty inputs, max values, null, undefined
5. **Focus on security-critical code** - Parsers, type conversions, memory operations

---

## Interpreting Results

### Crashes

When libFuzzer finds a crash, it saves the input to a file:

```
crash-da39a3ee5e6b4b0d3255bfef95601890afd80709
```

**Next Steps:**
1. Reproduce: `./jsfuzzer --js=TARGET.js crash-FILE`
2. Minimize: `./jsfuzzer --js=TARGET.js -minimize_crash=1 crash-FILE`
3. Analyze with sanitizer output
4. Create minimal test case
5. Report via responsible disclosure

### Sanitizer Output

**AddressSanitizer (heap-buffer-overflow):**
```
==12345==ERROR: AddressSanitizer: heap-buffer-overflow
READ of size 4 at 0x... thread T0
    #0 in function_name at file.c:123
```
→ **High severity** - Memory corruption

**UndefinedBehaviorSanitizer:**
```
runtime error: signed integer overflow
```
→ **Medium severity** - May lead to memory corruption

### Coverage Statistics

libFuzzer reports coverage:
```
#12345  NEW    cov: 1234 bits: 5678 corp: 42
```

- **cov**: Coverage (number of edges hit)
- **bits**: More granular coverage metric
- **corp**: Corpus size (interesting inputs)

**Goal:** Maximize coverage to find more bugs

---

## Fuzzer Dictionary

Create a dictionary file to improve fuzzing quality:

```
# fuzzer.dict
# Common JavaScript keywords
"function"
"return"
"typeof"
"instanceof"
"undefined"
"null"

# Regex patterns
".*"
".+"
".?"
"(a+)+"

# JSON
'{"'
'":'
'}'
'['
']'

# Numbers
"0"
"1"
"-1"
"Infinity"
"NaN"
```

Use with: `./jsfuzzer --js=TARGET.js -dict=fuzzer.dict`

---

## Corpus Management

### Building a Corpus

```bash
# Create corpus directory
mkdir -p corpus/regexp

# Add seed inputs
echo '{"type":"regex","pattern":".*"}' > corpus/regexp/seed1
echo '{"type":"regex","pattern":"(a+)+"}' > corpus/regexp/seed2

# Fuzz with corpus
./jsfuzzer --js=fuzz_targets/regexp_fuzzer.js corpus/regexp/
```

### Merging Corpora

```bash
# Minimize corpus (remove redundant inputs)
./jsfuzzer --js=TARGET.js -merge=1 corpus_min/ corpus/

# Merge multiple corpora
./jsfuzzer --js=TARGET.js -merge=1 merged/ corpus1/ corpus2/ corpus3/
```

---

## Performance Tips

### Speed Up Fuzzing

1. **Reduce timeout**: `-timeout=1` (if no infinite loops expected)
2. **Limit input length**: `-max_len=500`
3. **Use multiple workers**: `-workers=8 -jobs=8`
4. **Build with optimizations**: `-O2` or `-O3`

### Increase Bug Detection

1. **Enable sanitizers**: `-fsanitize=address,undefined`
2. **Increase timeout**: `-timeout=25` (for ReDoS detection)
3. **Longer fuzzing runs**: `-max_total_time=86400` (24 hours)
4. **Use corpus**: Improves coverage-guided fuzzing

---

## Continuous Fuzzing

For production use, consider:

- **OSS-Fuzz**: Google's continuous fuzzing service
- **ClusterFuzz**: Scalable fuzzing infrastructure
- **OneFuzz**: Microsoft's fuzzing platform

---

## Questions?

See the main [VULNERABILITY_RESEARCH_GUIDE.md](../VULNERABILITY_RESEARCH_GUIDE.md) for:
- Adapting fuzzers for other JavaScript engines
- Responsible disclosure procedures
- Bug bounty programs
- Legal and ethical considerations

**Happy fuzzing! 🐛**
