# Quick Start Guide - libfuzzer-js for Security Research

## Overview

This repository contains a libFuzzer-based JavaScript fuzzer targeting the QuickJS engine. This guide will help you get started with fuzzing for vulnerability research and responsible disclosure to major tech companies.

---

## Quick Start by Platform

### macOS

```bash
# 1. Run the automated setup script
chmod +x setup_macos.sh
./setup_macos.sh

# 2. Start fuzzing with an example target
./jsfuzzer --js=example_fuzz.js

# 3. Or use a specialized fuzzer
./jsfuzzer --js=fuzz_targets/regexp_fuzzer.js
```

### Windows

```powershell
# 1. Open PowerShell as Administrator
# 2. Run the setup script
.\setup_windows.ps1

# 3. Start fuzzing
.\jsfuzzer.exe --js=example_fuzz.js

# Alternative: Use WSL (recommended)
wsl
# Then follow Linux instructions below
```

### Linux (or WSL)

```bash
# 1. Install dependencies
sudo apt-get update
sudo apt-get install -y clang subversion make

# 2. Download and build libFuzzer
svn co https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer Fuzzer
cd Fuzzer
./build.sh
export LIBFUZZER_A_PATH=$(realpath libFuzzer.a)
cd ..

# 3. Build libfuzzer-js
make

# 4. Run fuzzer
./jsfuzzer --js=fuzz_targets/regexp_fuzzer.js
```

---

## What This Fuzzer Does

**Current Target:** QuickJS JavaScript Engine

**Capabilities:**
- Coverage-guided fuzzing using libFuzzer
- Detects memory corruption (buffer overflows, use-after-free)
- Finds crashes and undefined behavior
- Discovers ReDoS and other logic bugs

**Important:** This currently fuzzes QuickJS. To find vulnerabilities in Chrome (V8), Safari (JavaScriptCore), or Firefox (SpiderMonkey), you need to adapt the fuzzer. See [VULNERABILITY_RESEARCH_GUIDE.md](VULNERABILITY_RESEARCH_GUIDE.md).

---

## Available Fuzzing Targets

| Target | Focus | Typical Vulnerabilities |
|--------|-------|-------------------------|
| `regexp_fuzzer.js` | Regular expressions | ReDoS, memory corruption |
| `json_fuzzer.js` | JSON parsing | Stack overflow, integer overflow |
| `array_fuzzer.js` | Arrays & TypedArrays | Out-of-bounds, buffer overflows |
| `type_confusion_fuzzer.js` | Type coercion | Type confusion, prototype pollution |
| `string_fuzzer.js` | String operations | Buffer overflows, Unicode bugs |
| `comprehensive_fuzzer.js` | All features | General bugs across subsystems |

See [fuzz_targets/README.md](fuzz_targets/README.md) for detailed information.

---

## Basic Usage

### Start Fuzzing

```bash
# Basic fuzzing
./jsfuzzer --js=fuzz_targets/TARGET.js

# With timeout (recommended)
./jsfuzzer --js=fuzz_targets/regexp_fuzzer.js -timeout=10

# Long-running campaign
./jsfuzzer --js=fuzz_targets/json_fuzzer.js -max_total_time=86400
```

### When a Crash is Found

libFuzzer saves crashing inputs as `crash-*` files:

```bash
# 1. Reproduce the crash
./jsfuzzer --js=fuzz_targets/TARGET.js crash-abc123

# 2. Minimize the crashing input
./jsfuzzer --js=fuzz_targets/TARGET.js -minimize_crash=1 crash-abc123

# 3. Analyze the crash
# Check the sanitizer output for details

# 4. Create a minimal test case
# Manually reduce the input to its simplest form

# 5. Report through responsible disclosure
# See VULNERABILITY_RESEARCH_GUIDE.md
```

---

## Fuzzing for Different Vendors

### Google (Chrome/V8)

**Current Status:** This fuzzer targets QuickJS, NOT V8

**To fuzz V8:**
1. Clone V8: `git clone https://chromium.googlesource.com/v8/v8.git`
2. Use V8's built-in fuzzers: `ninja -C out.gn/x64.release v8_simple_json_fuzzer`
3. Or adapt this fuzzer's harness to use V8 API

**Bug Bounty:** https://bughunters.google.com/
- Rewards: $500 - $150,000+
- Focus: Memory corruption, sandbox escapes

### Apple (Safari/JavaScriptCore)

**Current Status:** This fuzzer targets QuickJS, NOT JavaScriptCore

**To fuzz JavaScriptCore:**
1. Clone WebKit: `git clone https://github.com/WebKit/WebKit.git`
2. Build JSC: `Tools/Scripts/build-jsc --release`
3. Adapt fuzzer harness to use JavaScriptCore C API

**Bug Bounty:** https://security.apple.com/bounty/
- Email: product-security@apple.com
- Rewards: $5,000 - $1,000,000+
- Focus: WebKit/JSC vulnerabilities, Safari bugs

### Microsoft (Edge/ChakraCore)

**Current Status:** This fuzzer targets QuickJS, NOT ChakraCore

**To fuzz ChakraCore:**
1. Clone ChakraCore: `git clone https://github.com/chakra-core/ChakraCore.git`
2. Build with fuzzing support
3. Adapt fuzzer harness

**Note:** Modern Edge uses Chromium (V8), not ChakraCore

**Bug Bounty:** https://www.microsoft.com/en-us/msrc/bounty
- Email: secure@microsoft.com
- Rewards: $500 - $250,000+

### Mozilla (Firefox/SpiderMonkey)

**Current Status:** This fuzzer targets QuickJS, NOT SpiderMonkey

**To fuzz SpiderMonkey:**
1. Clone Firefox: `hg clone https://hg.mozilla.org/mozilla-central/`
2. Build SpiderMonkey: `cd js/src && autoconf2.13 && ./configure && make`
3. Use Funfuzz or adapt this harness

**Bug Bounty:** https://www.mozilla.org/en-us/security/bug-bounty/
- Bugzilla: https://bugzilla.mozilla.org/
- Rewards: $500 - $10,000+

---

## Responsible Disclosure

### ✅ Do

- Report vulnerabilities through official channels
- Give vendors 90 days to patch before public disclosure
- Provide detailed reproduction steps
- Test only authorized systems (your own, bug bounties)
- Follow bug bounty program rules

### ❌ Don't

- Publicly disclose before vendors patch
- Exploit vulnerabilities maliciously
- Test production systems without permission
- Sell vulnerabilities on black markets
- Access data you don't need

### Disclosure Channels

| Company | Primary Contact |
|---------|----------------|
| **Google** | https://bughunters.google.com/report |
| **Apple** | product-security@apple.com |
| **Microsoft** | https://msrc.microsoft.com/report |
| **Mozilla** | https://bugzilla.mozilla.org/ (mark security-sensitive) |

See [VULNERABILITY_RESEARCH_GUIDE.md](VULNERABILITY_RESEARCH_GUIDE.md) for detailed procedures.

---

## Expected Rewards (JavaScript Engine Bugs)

| Severity | Type | Typical Reward |
|----------|------|----------------|
| **Critical** | RCE, Sandbox Escape | $10,000 - $150,000+ |
| **High** | Memory Corruption | $5,000 - $50,000 |
| **Medium** | DoS, Logic Errors | $1,000 - $10,000 |
| **Low** | Info Disclosure | $500 - $3,000 |

**Note:** Rewards vary by vendor and specific vulnerability impact.

---

## Advanced Topics

### Continuous Fuzzing

```bash
# Use corpus directory
mkdir corpus
./jsfuzzer --js=fuzz_targets/regexp_fuzzer.js corpus/

# Parallel fuzzing (multiple terminals)
./jsfuzzer --js=fuzz_targets/TARGET1.js corpus/ &
./jsfuzzer --js=fuzz_targets/TARGET2.js corpus/ &
./jsfuzzer --js=fuzz_targets/TARGET3.js corpus/ &
```

### Build with More Sanitizers

Edit `Makefile`:
```makefile
CFLAGS += -fsanitize=address,undefined
```

Then rebuild:
```bash
make clean
make
```

### Create Custom Fuzzers

See [fuzz_targets/README.md](fuzz_targets/README.md) for templates and examples.

---

## Troubleshooting

### Build Fails

**Problem:** `LIBFUZZER_A_PATH not set`
```bash
export LIBFUZZER_A_PATH=/path/to/Fuzzer/libFuzzer.a
make
```

**Problem:** `clang not found`
```bash
# macOS
xcode-select --install

# Linux
sudo apt-get install clang

# Windows
choco install llvm
```

### Fuzzer Runs Slowly

- Reduce input size: `-max_len=500`
- Decrease timeout: `-timeout=1`
- Use parallel workers: `-workers=8 -jobs=8`

### No Crashes Found

- Run longer: `-max_total_time=86400` (24 hours)
- Try different targets
- Use corpus to improve coverage
- Consider the target may be well-tested already

---

## Learning Resources

### Fuzzing
- The Fuzzing Book: https://www.fuzzingbook.org/
- libFuzzer Tutorial: https://github.com/google/fuzzing/blob/master/tutorial/libFuzzerTutorial.md

### JavaScript Engine Internals
- V8 Blog: https://v8.dev/blog
- WebKit JavaScriptCore: https://trac.webkit.org/wiki/JavaScriptCore
- SpiderMonkey Docs: https://firefox-source-docs.mozilla.org/js/

### Security Research
- OWASP: https://owasp.org/
- PortSwigger Academy: https://portswigger.net/web-security
- LiveOverflow (YouTube): https://www.youtube.com/c/LiveOverflow

---

## Legal Notice

**This tool is for authorized security research only.**

- ✅ Testing your own systems
- ✅ Participating in bug bounty programs
- ✅ Academic research
- ✅ Open-source software testing

- ❌ Testing systems without permission
- ❌ Malicious exploitation
- ❌ Data theft or destruction
- ❌ Unauthorized access

**Know your local laws:** CFAA (US), Computer Misuse Act (UK), GDPR (EU)

Always read and follow bug bounty program safe harbor provisions.

---

## Next Steps

1. **Run the setup script for your platform**
   - macOS: `./setup_macos.sh`
   - Windows: `.\setup_windows.ps1`
   - Linux: Follow manual steps above

2. **Start with an example fuzzer**
   ```bash
   ./jsfuzzer --js=fuzz_targets/regexp_fuzzer.js -timeout=10
   ```

3. **Let it run for a while**
   - Start with 1 hour
   - Then try overnight runs
   - Production fuzzing runs for days/weeks

4. **When you find a bug**
   - Minimize the test case
   - Determine severity
   - Follow responsible disclosure
   - Submit to bug bounty program

5. **Learn more**
   - Read [VULNERABILITY_RESEARCH_GUIDE.md](VULNERABILITY_RESEARCH_GUIDE.md)
   - Explore [fuzz_targets/README.md](fuzz_targets/README.md)
   - Study JavaScript engine internals
   - Practice on open-source projects first

---

## Support

**Found a critical vulnerability?**
- Follow the responsible disclosure procedures in [VULNERABILITY_RESEARCH_GUIDE.md](VULNERABILITY_RESEARCH_GUIDE.md)
- Use official security channels listed above

**Questions about this fuzzer?**
- Check the README.md
- Review the vulnerability research guide
- Study the example fuzzing targets

**Legal questions?**
- Consult a lawyer
- Review bug bounty program terms
- Understand safe harbor provisions

---

## Summary

This repository provides:
- ✅ Automated setup scripts for macOS, Windows, Linux
- ✅ 6 specialized fuzzing targets for different vulnerability classes
- ✅ Comprehensive guide to vulnerability research
- ✅ Responsible disclosure procedures
- ✅ Bug bounty program information

**Current Target:** QuickJS (for Chrome/Safari/Firefox, see adaptation guide)

**Goal:** Find security vulnerabilities through ethical, responsible research

**Remember:** With great fuzzing power comes great responsibility. Always follow ethical guidelines and legal requirements.

---

**Happy (responsible) bug hunting! 🔍🐛**
