# Complete Fuzzing Tutorial
## From Zero to Fuzzing Your Own Code in 30 Minutes

This tutorial teaches you everything you need to know to integrate fuzzing into your own projects.

---

## 📚 Table of Contents

1. [What You'll Learn](#what-youll-learn)
2. [Quick Start (5 minutes)](#quick-start-5-minutes)
3. [Understanding Fuzzing (10 minutes)](#understanding-fuzzing-10-minutes)
4. [Fuzzing Your Code (30 minutes)](#fuzzing-your-code-30-minutes)
5. [Real-World Examples (15 minutes)](#real-world-examples-15-minutes)
6. [Deployment & Automation (20 minutes)](#deployment--automation-20-minutes)
7. [CI/CD Integration (15 minutes)](#cicd-integration-15-minutes)
8. [Advanced Topics](#advanced-topics)

---

## What You'll Learn

By the end of this tutorial, you will:

✅ Understand how fuzzing works
✅ Know how to fuzz your own JavaScript code
✅ Create effective fuzzing harnesses
✅ Find real bugs through fuzzing
✅ Integrate fuzzing into your CI/CD pipeline
✅ Automate fuzzing for continuous testing

---

## Quick Start (5 minutes)

### Step 1: Build the Fuzzer

```bash
# macOS
./setup_macos.sh

# Windows
.\setup_windows.ps1

# Linux/WSL
make
```

### Step 2: Run an Example

```bash
# Try the URL parser example
./jsfuzzer --js=examples/example1_url_parser.js -timeout=5

# Watch it find bugs in seconds!
```

### Step 3: Fuzz Your Own Code

```bash
# Use the interactive deployment script
./deploy_fuzzer.sh

# Follow the prompts to set up fuzzing for your code
```

**That's it!** You're now fuzzing. Continue reading to learn how it works.

---

## Understanding Fuzzing (10 minutes)

### What is Fuzzing?

**Fuzzing** is automated software testing that feeds random/malformed inputs to your code to find bugs, crashes, and security vulnerabilities.

```
┌─────────────┐
│   Fuzzer    │  Generates random inputs
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Your Code  │  Processes the input
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Result    │  Crash? Bug? Success?
└─────────────┘
```

### Why Fuzz?

**Bugs Fuzzing Finds:**
- Buffer overflows
- Use-after-free
- Integer overflows
- Null pointer dereferences
- Assertion failures
- Infinite loops
- Type confusion
- Validation bypasses

**Real-World Impact:**
- Google finds 1000s of bugs through fuzzing
- Apple pays up to $1M for fuzzing discoveries
- Microsoft integrates fuzzing in Windows development

### How This Fuzzer Works

This fuzzer uses **libFuzzer**, a coverage-guided fuzzing engine from LLVM:

1. **Generates** random bytes
2. **Feeds** them to your code via a harness
3. **Monitors** for crashes using sanitizers
4. **Tracks** code coverage
5. **Mutates** inputs to explore more code paths
6. **Saves** interesting inputs that find new coverage
7. **Repeats** millions of times

**Coverage-Guided** means it's smart:
- Not just random testing
- Learns what inputs trigger new code paths
- Evolves inputs to maximize coverage

---

## Fuzzing Your Code (30 minutes)

### The Three Components

Every fuzzing setup needs:

1. **Your Code** - The target to test
2. **Fuzzing Harness** - Converts fuzzer input to format your code expects
3. **Fuzzer** - Generates inputs and monitors for bugs

### Method 1: Automatic Setup (Recommended)

```bash
./deploy_fuzzer.sh
```

This interactive script will:
- ✅ Guide you through setup
- ✅ Analyze your code
- ✅ Generate appropriate harness
- ✅ Create run scripts
- ✅ Set up corpus management

**Follow the prompts and you're done!**

### Method 2: Manual Setup

#### Step 1: Write Your Code

```javascript
// mylib.js - Your library to fuzz

function parseUserInput(input) {
    if (typeof input !== 'string') {
        throw new TypeError('Input must be string');
    }

    // Parse JSON
    const data = JSON.parse(input);

    // BUG: No validation of data structure!
    return data.value * 2;
}
```

#### Step 2: Create Fuzzing Harness

Use the generator:

```bash
./generate_harness.sh mylib.js fuzz_mylib.js
```

Or write manually:

```javascript
// fuzz_mylib.js - Fuzzing harness

if (typeof FuzzerInput !== 'undefined') {
    try {
        // Convert fuzzer bytes to string
        const input = String.fromCharCode.apply(null, FuzzerInput);

        // Call your function
        parseUserInput(input);

    } catch (e) {
        // Expected errors for invalid input
    }
}
```

#### Step 3: Combine and Run

```bash
# Combine your code with harness
cat mylib.js fuzz_mylib.js > combined_fuzz.js

# Run fuzzer
./jsfuzzer --js=combined_fuzz.js -max_len=1000 -timeout=10
```

#### Step 4: Analyze Results

**If crashes are found:**

```bash
# Reproduce crash
./jsfuzzer --js=combined_fuzz.js crash-abc123

# Minimize crash input
./jsfuzzer --js=combined_fuzz.js -minimize_crash=1 crash-abc123

# Examine the input
hexdump -C crash-abc123
cat crash-abc123  # If it's text
```

### Understanding Harnesses

A harness is the bridge between fuzzer and your code:

#### Bad Harness ❌

```javascript
// Just converts to string - limited effectiveness
const input = String.fromCharCode.apply(null, FuzzerInput);
myFunction(input);
```

#### Good Harness ✅

```javascript
function fuzzMyCode(input) {
    if (input.length < 10) return;  // Minimum size

    try {
        // Extract multiple parameters
        const operation = input[0] % 4;
        const value1 = (input[1] << 8) | input[2];
        const value2 = input[3];
        const text = String.fromCharCode.apply(null, input.slice(4, 50));

        // Test different code paths
        switch (operation) {
            case 0: testFeatureA(value1, text); break;
            case 1: testFeatureB(value2); break;
            case 2: testFeatureC(text); break;
            case 3: testCombination(value1, value2, text); break;
        }

    } catch (e) {
        // Expected errors - continue fuzzing
    }
}

if (typeof FuzzerInput !== 'undefined') {
    fuzzMyCode(FuzzerInput);
}
```

### The 4 Golden Rules of Harnesses

**Rule 1: Extract Multiple Parameters**
- Use bytes for different purposes
- Test multiple functions
- Explore different code paths

**Rule 2: Handle Exceptions Properly**
- Wrap in try-catch
- Let memory errors crash (sanitizers catch them)
- Continue on expected errors

**Rule 3: Maximize Code Coverage**
- Test all features
- Use selector bytes to choose code paths
- Combine features in different ways

**Rule 4: Avoid Resource Exhaustion**
- Bound array sizes
- Limit loop iterations
- Cap string lengths
- Prevent OOM

---

## Real-World Examples (15 minutes)

### Example 1: URL Parser

**The Code:**

```javascript
function parseURL(url) {
    const result = { protocol: null, host: null, port: null };

    // Extract protocol
    const protocolEnd = url.indexOf('://');
    if (protocolEnd !== -1) {
        result.protocol = url.substring(0, protocolEnd);
        url = url.substring(protocolEnd + 3);
    }

    // Extract port
    const portStart = url.lastIndexOf(':');
    if (portStart !== -1) {
        result.port = parseInt(url.substring(portStart + 1));
        // BUG: No validation! Port could be > 65535
    }

    return result;
}
```

**The Harness:**

```javascript
function fuzzURLParser(input) {
    try {
        const url = String.fromCharCode.apply(null, input);
        const parsed = parseURL(url);

        // Validate port (catches the bug!)
        if (parsed.port !== null) {
            if (parsed.port < 0 || parsed.port > 65535) {
                throw new Error(`Invalid port: ${parsed.port}`);
            }
        }
    } catch (e) {}
}

if (typeof FuzzerInput !== 'undefined') {
    fuzzURLParser(FuzzerInput);
}
```

**Run It:**

```bash
./jsfuzzer --js=examples/example1_url_parser.js -timeout=5
```

**Expected:** Fuzzer finds `http://x:99999999` and similar inputs that create invalid ports.

### Example 2: API Validator

See `examples/example2_api_validator.js` for:
- Validation bypass testing
- Type confusion bugs
- Security filter testing

### Example 3: Template Engine

See `examples/example3_template_engine.js` for:
- Performance issue detection
- ReDoS-like bugs
- Prototype pollution

**Try them all:**

```bash
# Run all examples
for example in examples/example*.js; do
    echo "Fuzzing: $example"
    timeout 60 ./jsfuzzer --js="$example" -timeout=5 || true
done
```

---

## Deployment & Automation (20 minutes)

### Interactive Deployment

```bash
./deploy_fuzzer.sh
```

This will:
1. ✅ Check fuzzer installation
2. ✅ Help you select your project
3. ✅ Analyze your code
4. ✅ Generate harness automatically
5. ✅ Create run scripts
6. ✅ Set up corpus management
7. ✅ Offer to run a quick test

**Output:**
```
Your fuzzing environment is ready!

Next Steps:

1. Review harness: ~/project/fuzzing_output/fuzz_harness.js
2. Quick test:     bash ~/project/fuzzing_output/quick_test.sh
3. Full fuzzing:   bash ~/project/fuzzing_output/run_fuzzing.sh
4. Continuous:     bash ~/project/fuzzing_output/continuous_fuzzing.sh
```

### Directory Structure Created

```
your_project/
├── src/
│   └── your_code.js
└── fuzzing_output/
    ├── fuzz_harness.js           # Generated harness
    ├── combined_fuzz_target.js   # Your code + harness
    ├── run_fuzzing.sh            # Main fuzzing script
    ├── quick_test.sh             # 60-second test
    ├── continuous_fuzzing.sh     # Run indefinitely
    ├── corpus/                   # Interesting inputs
    │   ├── seed_1.txt
    │   └── seed_2.txt
    └── crashes/                  # Crash artifacts
```

### Running Fuzzing

**Quick Test (60 seconds):**
```bash
bash fuzzing_output/quick_test.sh
```

**Full Campaign:**
```bash
# Run for 1 hour
FUZZ_TIME=3600 bash fuzzing_output/run_fuzzing.sh

# Run with specific parameters
MAX_LEN=5000 TIMEOUT=25 bash fuzzing_output/run_fuzzing.sh
```

**Continuous Fuzzing:**
```bash
# Run indefinitely with 1-hour cycles
bash fuzzing_output/continuous_fuzzing.sh

# Custom cycle time (2 hours)
bash fuzzing_output/continuous_fuzzing.sh 7200
```

### Managing Corpus

**Why Corpus Matters:**
- Seeds fuzzer with valid inputs
- Improves coverage faster
- Finds bugs quicker

**Add Seed Inputs:**
```bash
# Add example JSON
echo '{"name":"test","value":123}' > corpus/seed_json.txt

# Add example URL
echo 'http://example.com/path' > corpus/seed_url.txt

# Add binary data
printf '\x00\x01\x02\x03' > corpus/seed_binary
```

**Corpus Grows Automatically:**
- Fuzzer saves inputs that find new coverage
- Corpus gets better over time
- No manual maintenance needed

---

## CI/CD Integration (15 minutes)

### Why Integrate Fuzzing in CI/CD?

**Benefits:**
- 🔍 Find bugs before they reach production
- 🔄 Continuous testing with every commit
- 📊 Track fuzzing progress over time
- 🚨 Alert on new crashes
- 💾 Build corpus over time

### GitHub Actions

**File:** `.github/workflows/fuzzing.yml`

```yaml
name: Continuous Fuzzing

on:
  pull_request:  # Quick fuzz on PRs
  push:          # Full fuzz on main
  schedule:      # Nightly deep fuzzing
    - cron: '0 2 * * *'

jobs:
  fuzz:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build fuzzer
        run: make
      - name: Run fuzzing
        run: |
          timeout 600 ./jsfuzzer --js=fuzz/target.js || true
      - name: Check crashes
        run: |
          if ls crash-* 2>/dev/null; then
            echo "Crashes found!"
            exit 1
          fi
```

**Copy Template:**
```bash
cp ci_templates/github_actions.yml .github/workflows/fuzzing.yml
# Edit to match your project
```

### GitLab CI

**File:** `.gitlab-ci.yml`

```yaml
stages:
  - fuzz

fuzz:quick:
  stage: fuzz
  only:
    - merge_requests
  script:
    - make
    - timeout 300 ./jsfuzzer --js=fuzz/target.js || true
```

**Copy Template:**
```bash
cp ci_templates/gitlab_ci.yml .gitlab-ci.yml
# Edit to match your project
```

### Jenkins

**File:** `Jenkinsfile`

```groovy
pipeline {
    agent any
    stages {
        stage('Fuzz') {
            steps {
                sh 'make'
                sh 'timeout 600 ./jsfuzzer --js=fuzz/target.js || true'
            }
        }
    }
}
```

**Copy Template:**
```bash
cp ci_templates/jenkins_pipeline.groovy Jenkinsfile
# Edit to match your project
```

### CI/CD Best Practices

**1. Different Durations:**
- PR: 2-5 minutes (quick smoke test)
- Main branch: 10-30 minutes (thorough testing)
- Nightly: 2-8 hours (deep fuzzing)

**2. Parallel Fuzzing:**
- Fuzz multiple targets simultaneously
- Faster overall testing
- Better resource utilization

**3. Corpus Management:**
- Cache corpus between runs
- Upload/download artifacts
- Build corpus over time

**4. Crash Handling:**
- Fail build on crashes in PRs
- Create issues for crashes on main
- Notify team via Slack/email

---

## Advanced Topics

### Structure-Aware Fuzzing

Generate structured data instead of random bytes:

```javascript
function generateStructuredInput(bytes) {
    return {
        header: {
            version: bytes[0],
            type: bytes[1] % 4,
            length: (bytes[2] << 8) | bytes[3]
        },
        payload: Array.from(bytes.slice(4, 4 + bytes[2]))
    };
}

if (typeof FuzzerInput !== 'undefined') {
    const structured = generateStructuredInput(FuzzerInput);
    processMessage(structured);
}
```

### Stateful Fuzzing

Maintain state across iterations:

```javascript
let globalState = { initialized: false, sessions: [] };

function statefulFuzz(input) {
    if (!globalState.initialized) {
        initialize();
        globalState.initialized = true;
    }

    const operation = input[0] % 4;

    switch (operation) {
        case 0: createSession(input.slice(1)); break;
        case 1: updateSession(input.slice(1)); break;
        case 2: deleteSession(input.slice(1)); break;
        case 3: querySession(input.slice(1)); break;
    }
}
```

### Differential Fuzzing

Compare behavior across implementations:

```javascript
function differentialFuzz(input) {
    const str = String.fromCharCode.apply(null, input);

    // Your implementation
    const result1 = yourParser(str);

    // Reference implementation
    const result2 = referenceParser(str);

    // They should match!
    if (JSON.stringify(result1) !== JSON.stringify(result2)) {
        throw new Error('Implementations differ!');
    }
}
```

### Custom Dictionaries

Improve fuzzing with domain-specific tokens:

**File:** `fuzzer.dict`
```
# JavaScript keywords
"function"
"return"
"class"

# JSON tokens
'{"'
'":'
'}'

# Common patterns
"<script>"
"' OR 1=1--"
"../../../etc/passwd"
```

**Use it:**
```bash
./jsfuzzer --js=target.js -dict=fuzzer.dict
```

---

## Troubleshooting

### Problem: Build Fails

**Solution:**
```bash
# Check if LIBFUZZER_A_PATH is set
echo $LIBFUZZER_A_PATH

# Set it manually
export LIBFUZZER_A_PATH=/path/to/libFuzzer.a

# Or use setup script
./setup_macos.sh  # or setup_windows.ps1
```

### Problem: No Crashes Found

**This is good!** But to improve:

```bash
# Run longer
./jsfuzzer --js=target.js -max_total_time=86400  # 24 hours

# Add corpus seeds
echo "valid input" > corpus/seed1

# Try different targets
./jsfuzzer --js=fuzz_targets/regexp_fuzzer.js
```

### Problem: Fuzzer Too Slow

```bash
# Reduce input length
./jsfuzzer --js=target.js -max_len=500

# Reduce timeout
./jsfuzzer --js=target.js -timeout=1

# Multiple workers (if supported)
./jsfuzzer --js=target.js -workers=4 -jobs=4
```

### Problem: Too Many False Positives

```javascript
// Improve your harness to handle expected errors
try {
    yourFunction(input);
} catch (e) {
    // Only crash on unexpected errors
    if (e instanceof TypeError && e.message.includes("expected")) {
        return;  // Expected error, continue
    }
    throw e;  // Unexpected, let it crash
}
```

---

## Next Steps

### Immediate Actions

1. ✅ **Run the examples**
   ```bash
   ./jsfuzzer --js=examples/example1_url_parser.js
   ```

2. ✅ **Deploy to your project**
   ```bash
   ./deploy_fuzzer.sh
   ```

3. ✅ **Integrate CI/CD**
   ```bash
   cp ci_templates/github_actions.yml .github/workflows/
   ```

### Learning Path

**Week 1:** Learn basics
- Run all examples
- Modify examples to test your own functions
- Understand harness patterns

**Week 2:** Integrate into project
- Use deployment script
- Fuzz one component
- Fix any bugs found

**Week 3:** Expand coverage
- Fuzz more components
- Create multiple harnesses
- Build up corpus

**Week 4:** Automate
- Set up CI/CD
- Configure nightly fuzzing
- Monitor for crashes

### Resources

**Guides in This Repository:**
- `FUZZING_INTEGRATION_GUIDE.md` - Comprehensive integration guide
- `VULNERABILITY_RESEARCH_GUIDE.md` - Security research and disclosure
- `QUICK_START_GUIDE.md` - Platform-specific quick starts
- `examples/README.md` - Detailed example walkthroughs
- `fuzz_targets/README.md` - Specialized fuzzer documentation

**External Resources:**
- [The Fuzzing Book](https://www.fuzzingbook.org/) - Comprehensive fuzzing textbook
- [libFuzzer Tutorial](https://github.com/google/fuzzing/blob/master/tutorial/libFuzzerTutorial.md)
- [Google OSS-Fuzz](https://github.com/google/oss-fuzz) - Continuous fuzzing service

---

## Summary

You now know:

✅ What fuzzing is and why it's important
✅ How to write fuzzing harnesses
✅ How to use the deployment script
✅ How to integrate fuzzing in CI/CD
✅ How to find and fix real bugs
✅ Advanced fuzzing techniques

**Key Takeaways:**

1. **Fuzzing finds real bugs** - Major companies use it extensively
2. **Automation is key** - Use the deployment script and CI/CD
3. **Start small** - Fuzz one component at a time
4. **Iterate** - Improve harnesses based on results
5. **Continuous fuzzing** - Run overnight and in CI/CD

---

## Getting Help

**Questions about this fuzzer?**
- Read the guides in this repository
- Check the examples
- Use the deployment script

**Found a vulnerability?**
- Follow responsible disclosure (see `VULNERABILITY_RESEARCH_GUIDE.md`)
- Use official security channels
- Don't publicly disclose before patch

**Contributing:**
- Share your fuzzing examples
- Report issues
- Submit improvements

---

**Happy Fuzzing! 🐛🔍**

Remember: Every bug you find through fuzzing is a bug that won't reach production!
