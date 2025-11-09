
# Integration Guide: Fuzzing Your JavaScript Code

This guide shows you how to integrate libfuzzer-js into your project to find bugs through fuzzing.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Deployment](#deployment)
3. [Creating Fuzzers](#creating-fuzzers)
4. [Running Fuzzing Campaigns](#running-fuzzing-campaigns)
5. [Analyzing Results](#analyzing-results)
6. [Integration Patterns](#integration-patterns)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

## Quick Start

### 1. Deploy libfuzzer-js

```bash
# Clone the repository
git clone https://github.com/yourusername/libfuzzer-js.git
cd libfuzzer-js

# Run deployment script (sets up everything)
./scripts/deploy.sh

# Load environment
source ~/fuzzing/fuzzer-env.sh
```

### 2. Create Your First Fuzzer

```bash
# Create a fuzzer for your code
./scripts/create-fuzzer.sh my_app api -o ~/fuzzing/fuzzers/

# Edit the fuzzer to include your code
vim ~/fuzzing/fuzzers/my_app.js
```

### 3. Run Fuzzing

```bash
# Fuzz for 5 minutes with 4 parallel workers
./scripts/fuzz.sh ~/fuzzing/fuzzers/my_app.js -t 300 -w 4
```

### 4. Analyze Crashes

```bash
# List any crashes
ls -la crash-* leak-* timeout-*

# Analyze a crash
./scripts/analyze-crash.sh crash-abc123 ~/fuzzing/fuzzers/my_app.js
```

## Deployment

The deployment script automates the entire setup process.

### Basic Deployment

```bash
./scripts/deploy.sh
```

This will:
- Check prerequisites (clang++, svn, make)
- Download and build libFuzzer
- Build libfuzzer-js
- Create a fuzzing workspace at `~/fuzzing/`
- Set up the MCP server for Claude Code

### Custom Deployment

```bash
# Use custom workspace directory
./scripts/deploy.sh --fuzzer-dir /my/custom/path

# Skip libFuzzer if already installed
LIBFUZZER_A_PATH=/path/to/libFuzzer.a ./scripts/deploy.sh --skip-libfuzzer

# Skip MCP server setup
./scripts/deploy.sh --skip-mcp
```

### Environment Setup

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
source ~/fuzzing/fuzzer-env.sh
```

Or run manually each session:

```bash
source ~/fuzzing/fuzzer-env.sh
```

## Creating Fuzzers

### Using Templates

The `create-fuzzer.sh` script provides templates for common fuzzing scenarios:

```bash
# JSON fuzzer
./scripts/create-fuzzer.sh my_json json

# Regex fuzzer
./scripts/create-fuzzer.sh my_regex regex

# Arithmetic fuzzer
./scripts/create-fuzzer.sh my_math arithmetic

# String operations
./scripts/create-fuzzer.sh my_string string

# API testing
./scripts/create-fuzzer.sh my_api api

# Protocol/parser testing
./scripts/create-fuzzer.sh my_protocol protocol

# Import existing code
./scripts/create-fuzzer.sh my_lib import -f ./mylib.js
```

### Manual Fuzzer Creation

Basic fuzzer structure:

```javascript
// Your code to test
function myFunction(input) {
    // Your implementation
}

// Fuzzer code
const inputStr = String.fromCharCode.apply(null, FuzzerInput);

try {
    myFunction(inputStr);
} catch (e) {
    // Expected errors
}
```

### Extracting Structured Data

```javascript
// Helper functions for binary data
const readByte = (offset) => FuzzerInput[offset] || 0;

const readInt16 = (offset) => {
    return (FuzzerInput[offset] || 0) |
           ((FuzzerInput[offset+1] || 0) << 8);
};

const readInt32 = (offset) => {
    return (FuzzerInput[offset] || 0) |
           ((FuzzerInput[offset+1] || 0) << 8) |
           ((FuzzerInput[offset+2] || 0) << 16) |
           ((FuzzerInput[offset+3] || 0) << 24);
};

// Use them in your fuzzer
if (FuzzerInput.length >= 8) {
    const cmd = readByte(0);
    const value = readInt32(1);
    myAPI(cmd, value);
}
```

## Running Fuzzing Campaigns

### Basic Usage

```bash
# Fuzz for 60 seconds
./scripts/fuzz.sh my_fuzzer.js -t 60

# Fuzz with 4 parallel workers
./scripts/fuzz.sh my_fuzzer.js -w 4 -t 300

# Custom corpus directory
./scripts/fuzz.sh my_fuzzer.js -c ./my_corpus

# Use a dictionary
./scripts/fuzz.sh my_fuzzer.js -d ./my.dict
```

### Advanced Options

```bash
# Maximum input length
./scripts/fuzz.sh my_fuzzer.js -l 8192

# Enable leak detection
./scripts/fuzz.sh my_fuzzer.js --detect-leaks

# Verbose output
./scripts/fuzz.sh my_fuzzer.js -v

# Merge corpora
./scripts/fuzz.sh my_fuzzer.js -M corpus1 corpus2 -merge=1
```

### Continuous Fuzzing

For long-running fuzzing campaigns:

```bash
# Run in background
nohup ./scripts/fuzz.sh my_fuzzer.js -t 86400 > fuzz.log 2>&1 &

# Or use screen/tmux
screen -S fuzzing
./scripts/fuzz.sh my_fuzzer.js -w 8
# Ctrl+A, D to detach
```

## Analyzing Results

### Listing Crashes

```bash
# Find all crashes in current directory
ls -la crash-* leak-* timeout-*

# Find crashes in corpus directory
./scripts/analyze-crash.sh
```

### Analyzing a Crash

```bash
# Basic analysis
./scripts/analyze-crash.sh crash-abc123

# Analyze with fuzzer for reproduction
./scripts/analyze-crash.sh crash-abc123 my_fuzzer.js

# Reproduce the crash
./scripts/analyze-crash.sh crash-abc123 my_fuzzer.js -r

# Minimize crash input
./scripts/analyze-crash.sh crash-abc123 my_fuzzer.js -m

# Full hex dump
./scripts/analyze-crash.sh crash-abc123 -x

# Extract strings
./scripts/analyze-crash.sh crash-abc123 -s
```

### Corpus Statistics

```bash
# View corpus statistics
./scripts/corpus-stats.sh corpus

# Check coverage (approximate)
./scripts/corpus-stats.sh my_corpus
```

## Integration Patterns

### Pattern 1: Parser Fuzzing

See: `integration-examples/1_fuzz_custom_parser.js`

```javascript
function myParser(input) {
    // Your parsing logic
}

const inputStr = String.fromCharCode.apply(null, FuzzerInput);
try {
    const result = myParser(inputStr);
    // Use result
} catch (e) {
    // Expected parse errors
}
```

### Pattern 2: API Library Fuzzing

See: `integration-examples/2_fuzz_api_library.js`

```javascript
// Select which API to test
const apiChoice = FuzzerInput[0] % apiCount;

switch (apiChoice) {
    case 0: api1(extractData(1)); break;
    case 1: api2(extractData(1)); break;
    // ...
}
```

### Pattern 3: State Machine Fuzzing

See: `integration-examples/3_fuzz_state_machine.js`

```javascript
const machine = new StateMachine();

// Execute command sequence
for (let i = 0; i < FuzzerInput.length; i++) {
    const cmd = FuzzerInput[i] % commandCount;
    executeCommand(machine, cmd);
}
```

### Pattern 4: Dictionary-Based Fuzzing

See: `integration-examples/4_fuzz_with_dictionary.js`

Create a dictionary file:

```
# my.dict
"keyword1"
"keyword2"
"special_token"
```

Run with dictionary:

```bash
./scripts/fuzz.sh my_fuzzer.js -d my.dict
```

## Best Practices

### 1. Start Simple

Begin with simple inputs and gradually increase complexity:

```javascript
// Start with this
try {
    myFunction(String.fromCharCode.apply(null, FuzzerInput));
} catch (e) {}

// Then add structure
if (FuzzerInput.length >= 4) {
    const type = FuzzerInput[0];
    const data = FuzzerInput.slice(1);
    myFunction(type, data);
}
```

### 2. Use Appropriate Input Sizes

```bash
# For text parsers
./scripts/fuzz.sh parser.js -l 4096

# For binary protocols
./scripts/fuzz.sh protocol.js -l 1024

# For large documents
./scripts/fuzz.sh document.js -l 65536
```

### 3. Handle Expected Errors

```javascript
try {
    riskyOperation();
} catch (e) {
    // GOOD: Caught expected errors
    // Only crashes outside catch blocks are bugs
}

// BAD: No error handling
riskyOperation(); // Will crash on any error
```

### 4. Test All Code Paths

Use the first fuzzer byte to select code paths:

```javascript
const choice = FuzzerInput[0] % 4;

switch (choice) {
    case 0: testFeatureA(); break;
    case 1: testFeatureB(); break;
    case 2: testFeatureC(); break;
    case 3: testFeatureD(); break;
}
```

### 5. Use Dictionaries for Structured Formats

For formats with keywords (JSON, XML, protocols):

```bash
./scripts/fuzz.sh structured_parser.js -d keywords.dict
```

### 6. Run Parallel Campaigns

```bash
# CPU cores = workers for maximum speed
./scripts/fuzz.sh my_fuzzer.js -w $(nproc) -t 3600
```

### 7. Minimize Crashes Before Reporting

```bash
# Minimize to smallest reproducing input
./scripts/analyze-crash.sh crash-abc my_fuzzer.js -m
```

## Integrating Your Own Code

### Method 1: Inline Code

```javascript
// Put your code directly in the fuzzer
function myCode() {
    // Your implementation
}

// Fuzzer code
const input = String.fromCharCode.apply(null, FuzzerInput);
try {
    myCode(input);
} catch (e) {}
```

### Method 2: Concatenate Files

```bash
# Combine your code with fuzzer harness
cat mylib.js fuzzer_harness.js > combined_fuzzer.js
./scripts/fuzz.sh combined_fuzzer.js
```

### Method 3: Use Import Template

```bash
./scripts/create-fuzzer.sh my_lib import -f ./mylib.js
# Edit the generated fuzzer to call your functions
./scripts/fuzz.sh my_lib.js
```

## Troubleshooting

### Fuzzer Not Building

```bash
# Check environment variable
echo $LIBFUZZER_A_PATH

# Re-run deployment
./scripts/deploy.sh

# Check dependencies
clang++ --version
```

### No Crashes Found

This is good! But to ensure thorough testing:

- Run longer: `-t 3600` (1 hour) or more
- Use more workers: `-w $(nproc)`
- Add dictionaries for structured input
- Try different input sizes: `-l 8192`
- Review fuzzer code to ensure it tests target

### Out of Memory

```bash
# Limit input size
./scripts/fuzz.sh fuzzer.js -l 1024

# Reduce workers
./scripts/fuzz.sh fuzzer.js -w 2
```

### Slow Fuzzing

```bash
# Use multiple workers
./scripts/fuzz.sh fuzzer.js -w 8

# Reduce input size
./scripts/fuzz.sh fuzzer.js -l 2048

# Optimize fuzzer code (remove logging, etc.)
```

### Reproducing Crashes

```bash
# Make sure fuzzer hasn't changed
git diff my_fuzzer.js

# Run with exact crash input
./jsfuzzer --js=my_fuzzer.js crash-abc123

# Check memory limits
ulimit -a
```

## Example Workflows

### Workflow 1: New Project

```bash
# 1. Deploy
./scripts/deploy.sh
source ~/fuzzing/fuzzer-env.sh

# 2. Create fuzzer
./scripts/create-fuzzer.sh myproject api -o ~/fuzzing/fuzzers/

# 3. Edit fuzzer to include your code
vim ~/fuzzing/fuzzers/myproject.js

# 4. Quick test (5 min)
./scripts/fuzz.sh ~/fuzzing/fuzzers/myproject.js -t 300

# 5. Overnight fuzz
nohup ./scripts/fuzz.sh ~/fuzzing/fuzzers/myproject.js -w 8 -t 28800 > fuzz.log 2>&1 &

# 6. Check results next day
./scripts/analyze-crash.sh crash-*
```

### Workflow 2: CI/CD Integration

```bash
#!/bin/bash
# ci-fuzz.sh - Run in CI pipeline

set -e

# Build fuzzer
./scripts/deploy.sh --skip-mcp

# Run short campaign
timeout 300 ./scripts/fuzz.sh test/fuzzer.js -t 280 || true

# Check for crashes
if ls crash-* leak-* timeout-* 2>/dev/null; then
    echo "Fuzzing found crashes!"
    ./scripts/analyze-crash.sh crash-* || true
    exit 1
fi

echo "No crashes found"
exit 0
```

### Workflow 3: Regression Testing

```bash
# Save corpus for regression tests
./scripts/fuzz.sh my_fuzzer.js -c regression_corpus -t 3600

# Later, run regression tests
./scripts/fuzz.sh my_fuzzer.js -c regression_corpus -runs=1000
```

## Additional Resources

- **Examples**: See `integration-examples/` directory
- **MCP Server**: See `MCP_SETUP.md` for Claude Code integration
- **LibFuzzer Docs**: https://llvm.org/docs/LibFuzzer.html
- **QuickJS**: https://bellard.org/quickjs/

## Support

For issues or questions:
- Check examples in `integration-examples/`
- Review troubleshooting section
- Open an issue on GitHub

Happy Fuzzing! 🐛🔍
