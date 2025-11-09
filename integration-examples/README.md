# Integration Examples

This directory contains practical examples showing how to fuzz different types of JavaScript code with libfuzzer-js.

## Examples

### 1. Custom Parser (`1_fuzz_custom_parser.js`)

Shows how to fuzz a custom text parser (key-value format).

**What it demonstrates:**
- Basic parser fuzzing
- Error handling
- Finding parse errors and edge cases

**Run it:**
```bash
../scripts/fuzz.sh 1_fuzz_custom_parser.js -t 60
```

### 2. API Library (`2_fuzz_api_library.js`)

Shows how to fuzz a library with multiple API functions.

**What it demonstrates:**
- Testing multiple APIs
- Using fuzzer input to select which API to test
- Extracting structured data from fuzzer input
- Testing mathematical functions

**Run it:**
```bash
../scripts/fuzz.sh 2_fuzz_api_library.js -t 60 -w 4
```

### 3. State Machine (`3_fuzz_state_machine.js`)

Shows how to fuzz stateful code with command sequences.

**What it demonstrates:**
- State machine fuzzing
- Command sequence generation
- Finding invalid state transitions
- Testing connection lifecycles

**Run it:**
```bash
../scripts/fuzz.sh 3_fuzz_state_machine.js -t 120
```

### 4. Dictionary-Based Fuzzing (`4_fuzz_with_dictionary.js`)

Shows how to use dictionaries for structured format fuzzing (HTTP parser).

**What it demonstrates:**
- Dictionary-based fuzzing
- Protocol/format parsing
- Structured input generation
- HTTP request validation

**Create dictionary first:**
```bash
cat > http.dict << 'EOF'
# HTTP Methods
"GET"
"POST"
"PUT"
"DELETE"

# HTTP Versions
"HTTP/1.0"
"HTTP/1.1"

# Common Headers
"Host:"
"Content-Length:"

# Special sequences
"\r\n"
"\r\n\r\n"
": "
" "
EOF
```

**Run it:**
```bash
../scripts/fuzz.sh 4_fuzz_with_dictionary.js -d http.dict -t 60
```

## How to Use These Examples

### 1. Run as-is

Each example can be run directly to see how fuzzing works:

```bash
cd integration-examples
../scripts/fuzz.sh 1_fuzz_custom_parser.js -t 60
```

### 2. Modify for Your Code

Copy an example and modify it to test your own code:

```bash
# Copy the most relevant example
cp 2_fuzz_api_library.js my_project_fuzzer.js

# Edit to include your code
vim my_project_fuzzer.js

# Run fuzzing
../scripts/fuzz.sh my_project_fuzzer.js -t 300
```

### 3. Learn Patterns

Study the examples to learn different fuzzing patterns:

- **Parser fuzzing**: Example 1
- **API fuzzing**: Example 2
- **Stateful fuzzing**: Example 3
- **Structured fuzzing**: Example 4

## Creating Your Own Fuzzer

Use the fuzzer creation script:

```bash
# Create from template
../scripts/create-fuzzer.sh my_fuzzer api

# Import existing code
../scripts/create-fuzzer.sh my_lib import -f ../mylib.js
```

## Tips for Effective Fuzzing

### 1. Start with Simple Examples

Run examples 1 and 2 first to understand basic fuzzing.

### 2. Use Appropriate Templates

Choose the template that matches your code:
- Text parsing → Example 1
- API testing → Example 2
- Stateful code → Example 3
- Protocols → Example 4

### 3. Increase Fuzzing Time

The examples use short fuzzing times (60s) for demonstration. For real testing, use longer times:

```bash
# Fuzz for 1 hour
../scripts/fuzz.sh my_fuzzer.js -t 3600

# Fuzz overnight
../scripts/fuzz.sh my_fuzzer.js -t 28800 -w 8
```

### 4. Use Multiple Workers

Utilize all CPU cores:

```bash
../scripts/fuzz.sh my_fuzzer.js -w $(nproc) -t 3600
```

### 5. Check Results

After fuzzing, check for crashes:

```bash
# List crashes
ls -la crash-* leak-* timeout-*

# Analyze
../scripts/analyze-crash.sh crash-abc123 my_fuzzer.js -r
```

## Integration Patterns

### Pattern 1: Inline Your Code

```javascript
// Your code
function myFunction(input) {
    // ...
}

// Fuzzer
const input = String.fromCharCode.apply(null, FuzzerInput);
try {
    myFunction(input);
} catch (e) {}
```

### Pattern 2: Concatenate Files

```bash
cat mylib.js fuzzer_harness.js > combined.js
../scripts/fuzz.sh combined.js
```

### Pattern 3: Import Template

```bash
../scripts/create-fuzzer.sh mycode import -f ../src/mycode.js
# Edit to call your functions
vim mycode.js
../scripts/fuzz.sh mycode.js
```

## Common Issues

### No Crashes Found

This is good! It means no obvious bugs were found. To be thorough:

1. Run longer (hours instead of minutes)
2. Use more workers
3. Review fuzzer code to ensure it exercises your code
4. Try different input sizes (`-l` option)
5. Use dictionaries for structured input

### Fuzzer Too Slow

1. Reduce input size: `-l 1024`
2. Optimize your code
3. Remove logging/debugging code
4. Use more workers: `-w 8`

### Memory Issues

1. Limit input size: `-l 2048`
2. Reduce workers: `-w 2`
3. Check for memory leaks in your code

## Next Steps

1. Run all examples to see different fuzzing patterns
2. Choose the pattern that matches your code
3. Create your own fuzzer based on the examples
4. Run long fuzzing campaigns
5. Analyze and fix any crashes found

For more information, see:
- `../INTEGRATION_GUIDE.md` - Comprehensive integration guide
- `../README.md` - Main project README
- `../MCP_SETUP.md` - Claude Code integration

Happy Fuzzing! 🐛🔍
