# Fuzzing Integration Guide
## How to Fuzz Your Own Source Code and Binaries

This comprehensive guide teaches you how to integrate fuzzing into your projects, whether you have source code or just binaries.

---

## Table of Contents

1. [Introduction to Fuzzing Integration](#introduction-to-fuzzing-integration)
2. [Fuzzing Your JavaScript Code](#fuzzing-your-javascript-code)
3. [Fuzzing Compiled Binaries](#fuzzing-compiled-binaries)
4. [Creating Effective Harnesses](#creating-effective-harnesses)
5. [Integration Strategies](#integration-strategies)
6. [CI/CD Integration](#cicd-integration)
7. [Real-World Examples](#real-world-examples)

---

## Introduction to Fuzzing Integration

### What is a Fuzzing Harness?

A **fuzzing harness** is a wrapper that:
1. Takes random input from the fuzzer
2. Feeds it to your code
3. Monitors for crashes and errors
4. Allows the fuzzer to explore different code paths

### Basic Fuzzing Workflow

```
┌─────────────┐
│   Fuzzer    │  Generates random/mutated input
│  (libFuzzer)│
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Harness   │  Converts fuzzer input to format your code expects
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Your Code  │  The target being tested
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Result    │  Crash? Success? Coverage?
└─────────────┘
```

---

## Fuzzing Your JavaScript Code

### Scenario 1: Fuzzing a JavaScript Function

**Your Code (mylib.js):**
```javascript
function parseUserInput(input) {
    // Your code that might have bugs
    if (input.length > 1000) {
        throw new Error("Input too long");
    }

    // Parse and process
    const data = JSON.parse(input);
    return processData(data);
}

function processData(data) {
    // Complex processing logic
    return data.value * 2;
}
```

**Fuzzing Harness (fuzz_mylib.js):**
```javascript
// Load your library
load('mylib.js');  // Or use require() if Node.js compatible

// Fuzzing entry point
if (typeof FuzzerInput !== 'undefined') {
    try {
        // Convert fuzzer bytes to string
        const inputStr = String.fromCharCode.apply(null, FuzzerInput);

        // Call your function with fuzzer-generated input
        parseUserInput(inputStr);

    } catch (e) {
        // Expected errors - don't crash the fuzzer
        // Only memory corruption will be caught by sanitizers
    }
}
```

**Run the Fuzzer:**
```bash
# Concatenate your code with the harness
cat mylib.js fuzz_mylib.js > combined_fuzz.js

# Fuzz it
./jsfuzzer --js=combined_fuzz.js -max_len=2000 -timeout=10
```

### Scenario 2: Fuzzing a JavaScript Module/Class

**Your Code (UserValidator.js):**
```javascript
class UserValidator {
    constructor() {
        this.rules = {};
    }

    addRule(field, validator) {
        this.rules[field] = validator;
    }

    validate(userData) {
        for (const field in this.rules) {
            if (!this.rules[field](userData[field])) {
                throw new Error(`Invalid ${field}`);
            }
        }
        return true;
    }
}
```

**Fuzzing Harness:**
```javascript
// Load your code
load('UserValidator.js');

function fuzzValidator(input) {
    if (!input || input.length < 10) return;

    try {
        const validator = new UserValidator();

        // Add some rules
        validator.addRule('email', (val) => val && val.includes('@'));
        validator.addRule('age', (val) => val >= 0 && val < 150);

        // Generate user data from fuzzer input
        const userData = {
            email: String.fromCharCode.apply(null, input.slice(0, 50)),
            age: (input[0] << 8) | input[1],
            name: String.fromCharCode.apply(null, input.slice(2, 30))
        };

        // Validate with fuzzer-generated data
        validator.validate(userData);

    } catch (e) {
        // Expected validation errors
    }
}

if (typeof FuzzerInput !== 'undefined') {
    fuzzValidator(FuzzerInput);
}
```

### Scenario 3: Fuzzing API Parsers

**Your Code (api_parser.js):**
```javascript
function parseAPIRequest(requestBody) {
    // Parse JSON request
    const req = JSON.parse(requestBody);

    // Extract fields
    const action = req.action;
    const params = req.params;

    // Route based on action
    switch (action) {
        case 'create':
            return handleCreate(params);
        case 'update':
            return handleUpdate(params);
        case 'delete':
            return handleDelete(params);
        default:
            throw new Error('Unknown action');
    }
}

function handleCreate(params) {
    // Complex creation logic
    const id = generateID(params.name);
    return { id, status: 'created' };
}
```

**Fuzzing Harness:**
```javascript
load('api_parser.js');

if (typeof FuzzerInput !== 'undefined') {
    try {
        const requestBody = String.fromCharCode.apply(null, FuzzerInput);
        parseAPIRequest(requestBody);
    } catch (e) {
        // Expected errors for invalid requests
    }
}
```

---

## Fuzzing Compiled Binaries

### Scenario 1: Fuzzing a Native Binary with JavaScript Bindings

Many native libraries expose JavaScript APIs. You can fuzz these!

**Example: Fuzzing a Native Crypto Library**

```javascript
// Assuming native crypto module is loaded
// crypto.hash() is implemented in C/C++ but exposed to JS

if (typeof FuzzerInput !== 'undefined') {
    try {
        // Feed fuzzer input to native code
        const result = crypto.hash('sha256', FuzzerInput);

        // Test other functions
        crypto.encrypt(FuzzerInput, 'key123');
        crypto.decrypt(result, 'key123');

    } catch (e) {
        // Expected errors
    }
}
```

### Scenario 2: Fuzzing Embedded JavaScript in Your C++ App

If you embed a JS engine in your C++ application:

**Your C++ Code (app.cpp):**
```cpp
#include <quickjs/quickjs.h>

class MyApp {
public:
    void processScript(const char* script) {
        JSRuntime *rt = JS_NewRuntime();
        JSContext *ctx = JS_NewContext(rt);

        // Execute user-provided script
        JS_Eval(ctx, script, strlen(script), "script.js", 0);

        JS_FreeContext(ctx);
        JS_FreeRuntime(rt);
    }
};
```

**Fuzzing Harness (fuzz_app.cpp):**
```cpp
#include "app.h"
#include <cstdint>
#include <cstddef>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size == 0) return 0;

    // Null-terminate the input to use as string
    char* script = new char[size + 1];
    memcpy(script, data, size);
    script[size] = '\0';

    // Fuzz your application
    MyApp app;
    app.processScript(script);

    delete[] script;
    return 0;
}
```

**Build and Fuzz:**
```bash
clang++ -fsanitize=fuzzer,address app.cpp fuzz_app.cpp -o fuzz_app
./fuzz_app -max_len=1000 -timeout=10
```

---

## Creating Effective Harnesses

### Rule 1: Parse Fuzzer Input Intelligently

**Bad Harness:**
```javascript
// Just converts to string - limited fuzzing effectiveness
const input = String.fromCharCode.apply(null, FuzzerInput);
myFunction(input);
```

**Good Harness:**
```javascript
// Extracts multiple parameters from fuzzer input
if (FuzzerInput.length >= 10) {
    const operation = FuzzerInput[0] % 4;  // 4 different operations
    const param1 = (FuzzerInput[1] << 8) | FuzzerInput[2];
    const param2 = FuzzerInput[3];
    const strParam = String.fromCharCode.apply(null, FuzzerInput.slice(4, 50));

    switch (operation) {
        case 0: myFunction1(param1, strParam); break;
        case 1: myFunction2(param2); break;
        case 2: myFunction3(strParam, param1); break;
        case 3: myFunction4(param1, param2); break;
    }
}
```

### Rule 2: Handle Exceptions Properly

**Bad Harness:**
```javascript
// Crashes on expected errors
myFunction(FuzzerInput);  // Uncaught exception stops fuzzing
```

**Good Harness:**
```javascript
try {
    myFunction(FuzzerInput);
} catch (e) {
    // Expected errors - continue fuzzing
    // Memory corruption will still be caught by ASAN
}
```

### Rule 3: Maximize Code Coverage

**Good Harness - Multiple Code Paths:**
```javascript
function comprehensiveFuzz(input) {
    if (input.length < 5) return;

    // Use first byte to select code path
    const selector = input[0] % 5;

    switch (selector) {
        case 0:
            testFeatureA(input.slice(1));
            break;
        case 1:
            testFeatureB(input.slice(1));
            break;
        case 2:
            testFeatureC(input.slice(1));
            break;
        case 3:
            // Test combination of features
            testFeatureA(input.slice(1, 20));
            testFeatureB(input.slice(20, 40));
            break;
        case 4:
            testEdgeCases(input.slice(1));
            break;
    }
}

if (typeof FuzzerInput !== 'undefined') {
    comprehensiveFuzz(FuzzerInput);
}
```

### Rule 4: Avoid Resource Exhaustion

**Bad Harness:**
```javascript
// Can cause out-of-memory
const huge = new Array(FuzzerInput[0] * 1000000);
```

**Good Harness:**
```javascript
// Bounds-checked
const size = Math.min(FuzzerInput[0] * 100, 10000);
const arr = new Array(size);
```

---

## Integration Strategies

### Strategy 1: Direct Integration (Inline Fuzzing)

Embed fuzzing directly in your codebase:

**Your Project Structure:**
```
myproject/
├── src/
│   ├── parser.js
│   ├── validator.js
│   └── utils.js
├── test/
│   └── unit_tests.js
└── fuzz/
    ├── fuzz_parser.js
    ├── fuzz_validator.js
    └── run_fuzzing.sh
```

**fuzz/run_fuzzing.sh:**
```bash
#!/bin/bash
# Automated fuzzing script

# Combine source files with fuzzer
cat ../src/parser.js fuzz_parser.js > /tmp/fuzz_parser_combined.js

# Run fuzzer
./jsfuzzer --js=/tmp/fuzz_parser_combined.js \
    -max_len=1000 \
    -timeout=10 \
    -max_total_time=3600 \
    -artifact_prefix=crashes/
```

### Strategy 2: Module-Based Integration

If using Node.js or modules:

**fuzz/fuzz_module.js:**
```javascript
// Mock require if not available
if (typeof require === 'undefined') {
    function require(path) {
        load(path);  // Use QuickJS load
        return exports;
    }
}

const myModule = require('../src/myModule.js');

if (typeof FuzzerInput !== 'undefined') {
    try {
        const input = String.fromCharCode.apply(null, FuzzerInput);
        myModule.processInput(input);
    } catch (e) {}
}
```

### Strategy 3: Build System Integration

**Makefile Integration:**
```makefile
.PHONY: fuzz test

# Regular tests
test:
	npm test

# Fuzzing target
fuzz: fuzz-parser fuzz-validator fuzz-api

fuzz-parser:
	cat src/parser.js fuzz/fuzz_parser.js > /tmp/combined.js
	./jsfuzzer --js=/tmp/combined.js -max_total_time=600

fuzz-validator:
	cat src/validator.js fuzz/fuzz_validator.js > /tmp/combined.js
	./jsfuzzer --js=/tmp/combined.js -max_total_time=600

fuzz-all-night:
	./fuzz/continuous_fuzzing.sh 28800  # 8 hours
```

---

## CI/CD Integration

### GitHub Actions Integration

**.github/workflows/fuzzing.yml:**
```yaml
name: Continuous Fuzzing

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    # Run nightly fuzzing
    - cron: '0 2 * * *'

jobs:
  fuzz:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Install Dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y clang subversion make

    - name: Build libFuzzer
      run: |
        svn co https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer Fuzzer
        cd Fuzzer
        ./build.sh
        echo "LIBFUZZER_A_PATH=$(pwd)/libFuzzer.a" >> $GITHUB_ENV

    - name: Build Fuzzer
      run: make

    - name: Run Short Fuzzing Campaign
      run: |
        # Run each fuzzer for 5 minutes
        timeout 300 ./jsfuzzer --js=fuzz/fuzz_parser.js -max_len=1000 || true
        timeout 300 ./jsfuzzer --js=fuzz/fuzz_validator.js -max_len=500 || true

    - name: Upload Crashes
      if: always()
      uses: actions/upload-artifact@v2
      with:
        name: fuzzing-crashes
        path: |
          crash-*
          leak-*
          timeout-*
```

### GitLab CI Integration

**.gitlab-ci.yml:**
```yaml
stages:
  - test
  - fuzz

fuzzing:
  stage: fuzz
  image: ubuntu:latest

  before_script:
    - apt-get update
    - apt-get install -y clang subversion make

  script:
    # Build libFuzzer
    - svn co https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer Fuzzer
    - cd Fuzzer && ./build.sh && cd ..
    - export LIBFUZZER_A_PATH=$(realpath Fuzzer/libFuzzer.a)

    # Build fuzzer
    - make

    # Run fuzzing (limited time for CI)
    - timeout 600 ./jsfuzzer --js=fuzz/fuzz_target.js || true

  artifacts:
    when: always
    paths:
      - crash-*
      - leak-*
    expire_in: 1 week

  only:
    - main
    - develop
```

### Jenkins Integration

**Jenkinsfile:**
```groovy
pipeline {
    agent any

    stages {
        stage('Setup') {
            steps {
                sh 'make setup-fuzzer'
            }
        }

        stage('Fuzz') {
            parallel {
                stage('Fuzz Parser') {
                    steps {
                        sh 'timeout 600 ./jsfuzzer --js=fuzz/parser.js || true'
                    }
                }
                stage('Fuzz Validator') {
                    steps {
                        sh 'timeout 600 ./jsfuzzer --js=fuzz/validator.js || true'
                    }
                }
                stage('Fuzz API') {
                    steps {
                        sh 'timeout 600 ./jsfuzzer --js=fuzz/api.js || true'
                    }
                }
            }
        }

        stage('Analyze') {
            steps {
                sh '''
                    if ls crash-* 1> /dev/null 2>&1; then
                        echo "CRASHES FOUND!"
                        exit 1
                    fi
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'crash-*, leak-*', allowEmptyArchive: true
        }
    }
}
```

---

## Real-World Examples

### Example 1: Fuzzing a URL Parser

**Your Code (url_parser.js):**
```javascript
function parseURL(url) {
    const parts = {};

    // Extract protocol
    const protocolEnd = url.indexOf('://');
    if (protocolEnd !== -1) {
        parts.protocol = url.substring(0, protocolEnd);
        url = url.substring(protocolEnd + 3);
    }

    // Extract host and path
    const pathStart = url.indexOf('/');
    if (pathStart !== -1) {
        parts.host = url.substring(0, pathStart);
        parts.path = url.substring(pathStart);
    } else {
        parts.host = url;
        parts.path = '/';
    }

    // Extract port
    const portStart = parts.host.indexOf(':');
    if (portStart !== -1) {
        parts.port = parseInt(parts.host.substring(portStart + 1));
        parts.host = parts.host.substring(0, portStart);
    }

    return parts;
}
```

**Fuzzing Harness:**
```javascript
load('url_parser.js');

if (typeof FuzzerInput !== 'undefined') {
    try {
        const url = String.fromCharCode.apply(null, FuzzerInput);
        const parsed = parseURL(url);

        // Test that parsed parts are valid
        if (parsed.port) {
            if (parsed.port < 0 || parsed.port > 65535) {
                throw new Error('Invalid port');  // This is a bug!
            }
        }
    } catch (e) {}
}
```

### Example 2: Fuzzing Template Engine

**Your Code (template.js):**
```javascript
function renderTemplate(template, data) {
    return template.replace(/\{\{(\w+)\}\}/g, (match, key) => {
        return data[key] || '';
    });
}
```

**Fuzzing Harness:**
```javascript
load('template.js');

if (typeof FuzzerInput !== 'undefined' && FuzzerInput.length > 10) {
    try {
        // Generate template from fuzzer input
        const templateLen = FuzzerInput[0] % 100;
        const template = String.fromCharCode.apply(null,
            FuzzerInput.slice(1, 1 + templateLen));

        // Generate data object
        const data = {
            name: String.fromCharCode.apply(null, FuzzerInput.slice(101, 120)),
            value: FuzzerInput[121],
            key: String.fromCharCode.apply(null, FuzzerInput.slice(122, 140))
        };

        renderTemplate(template, data);
    } catch (e) {}
}
```

### Example 3: Fuzzing State Machine

**Your Code (state_machine.js):**
```javascript
class StateMachine {
    constructor() {
        this.state = 'INIT';
        this.transitions = {
            'INIT': ['START'],
            'START': ['PROCESS', 'ERROR'],
            'PROCESS': ['COMPLETE', 'ERROR'],
            'COMPLETE': ['INIT'],
            'ERROR': ['INIT']
        };
    }

    transition(newState) {
        const allowed = this.transitions[this.state];
        if (!allowed || !allowed.includes(newState)) {
            throw new Error(`Invalid transition: ${this.state} -> ${newState}`);
        }
        this.state = newState;
    }
}
```

**Fuzzing Harness:**
```javascript
load('state_machine.js');

if (typeof FuzzerInput !== 'undefined' && FuzzerInput.length > 5) {
    try {
        const sm = new StateMachine();
        const states = ['START', 'PROCESS', 'COMPLETE', 'ERROR', 'INIT'];

        // Perform random transitions based on fuzzer input
        for (let i = 0; i < Math.min(FuzzerInput.length, 50); i++) {
            const stateIdx = FuzzerInput[i] % states.length;
            try {
                sm.transition(states[stateIdx]);
            } catch (e) {
                // Expected invalid transition
            }
        }
    } catch (e) {}
}
```

---

## Advanced Techniques

### Technique 1: Structure-Aware Fuzzing

```javascript
// Use fuzzer input to generate structured data
function generateStructuredInput(bytes) {
    if (bytes.length < 20) return null;

    return {
        header: {
            version: bytes[0],
            type: bytes[1] % 4,
            flags: (bytes[2] << 8) | bytes[3]
        },
        payload: {
            length: (bytes[4] << 8) | bytes[5],
            data: Array.from(bytes.slice(6, 6 + Math.min(bytes[4], 100)))
        },
        checksum: (bytes[bytes.length - 2] << 8) | bytes[bytes.length - 1]
    };
}

if (typeof FuzzerInput !== 'undefined') {
    const structured = generateStructuredInput(FuzzerInput);
    if (structured) {
        processMessage(structured);
    }
}
```

### Technique 2: Stateful Fuzzing

```javascript
// Maintain state across fuzzer iterations
let globalState = null;

function statefulFuzz(input) {
    if (!globalState) {
        globalState = { counter: 0, data: [] };
    }

    // Use input to perform stateful operations
    const operation = input[0] % 3;

    switch (operation) {
        case 0:  // Add data
            globalState.data.push(input[1]);
            break;
        case 1:  // Process data
            processData(globalState.data);
            break;
        case 2:  // Reset
            globalState = { counter: 0, data: [] };
            break;
    }

    globalState.counter++;
}

if (typeof FuzzerInput !== 'undefined') {
    statefulFuzz(FuzzerInput);
}
```

---

## Tips for Effective Fuzzing

### 1. Start Small
- Begin with one function or module
- Gradually expand coverage
- Don't try to fuzz everything at once

### 2. Use Corpuses
- Create seed inputs that trigger different code paths
- Fuzzer will mutate these for better coverage
- Example corpus structure:
```
corpus/
├── valid_input_1.bin
├── valid_input_2.bin
├── edge_case_1.bin
└── malformed_input.bin
```

### 3. Monitor Coverage
```bash
# Build with coverage instrumentation
clang++ -fprofile-instr-generate -fcoverage-mapping ...

# Run fuzzer
./fuzzer corpus/

# Generate coverage report
llvm-profdata merge -sparse default.profraw -o default.profdata
llvm-cov show ./fuzzer -instr-profile=default.profdata
```

### 4. Set Appropriate Limits
```bash
# Memory limit (prevents OOM)
./jsfuzzer --js=target.js -rss_limit_mb=2048

# Time limit (for ReDoS detection)
./jsfuzzer --js=target.js -timeout=25

# Input size limit
./jsfuzzer --js=target.js -max_len=10000
```

### 5. Automate Everything
- Use the deployment scripts provided
- Integrate into your build system
- Run fuzzing in CI/CD
- Set up cron jobs for continuous fuzzing

---

## Conclusion

Fuzzing integration is a powerful way to find bugs before they reach production. Key takeaways:

1. **Create targeted harnesses** for each component
2. **Handle exceptions properly** to continue fuzzing
3. **Maximize code coverage** by testing multiple paths
4. **Integrate into CI/CD** for continuous testing
5. **Start simple** and expand gradually

Use the provided deployment scripts to get started quickly!

---

**Next Steps:**
1. Run `./deploy_fuzzer.sh` to set up automated fuzzing for your code
2. Create harnesses using the templates above
3. Integrate into your CI/CD pipeline
4. Monitor for crashes and fix bugs
5. Gradually expand fuzzing coverage

Happy fuzzing! 🐛
