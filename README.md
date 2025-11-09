# libfuzzer-js

libFuzzer-based JavaScript fuzzing using Bellard's [QuickJS](https://bellard.org/quickjs/).

## Quick Start

### Automated Deployment (Recommended)

The easiest way to get started:

```sh
./scripts/deploy.sh
source ~/fuzzing/fuzzer-env.sh
```

This will:
- Download and build libFuzzer
- Build libfuzzer-js
- Set up a fuzzing workspace
- Install the MCP server for Claude Code

### Manual Building

If you prefer manual setup, you need a recent version of libFuzzer:

```sh
svn co https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer Fuzzer
cd Fuzzer
./build.sh
export LIBFUZZER_A_PATH=$(realpath libFuzzer.a)
```

In this project's root directory, type:

```sh
make
```

## Writing fuzzers

Input is supplied through the ```FuzzerInput``` variable, which is a ```Uint8Array```.

## API

An API suited for embedding in a larger application (e.g. a differential fuzzer) is defined in ```JS.cpp/h```.

## Running

```sh
./jsfuzzer --js=<javascript file>
```

## Module support

There is currently no support for modules. To use multiple JavaScript files, concatenate all the files you need for now.

E.g.:

```sh
cat foo.js bar.js >file.js
./jsfuzzer --js=file.js
```

## MCP Server for Claude Code

An MCP (Model Context Protocol) server is available to integrate libfuzzer-js with Claude Code in the Web. This allows Claude to help you with fuzzing workflows, including:

- Building the fuzzer
- Creating fuzzer templates
- Running fuzzing campaigns
- Analyzing crashes and statistics

See [mcp-server/README.md](mcp-server/README.md) for setup and usage instructions.

### Quick Start with MCP

```sh
cd mcp-server
npm install
npm run build
```

Then configure Claude Code with the MCP server path. See the MCP server README for detailed configuration.

## Easy Fuzzing with Scripts

Convenient scripts for common fuzzing tasks:

```sh
# Create a new fuzzer from template
./scripts/create-fuzzer.sh my_api json

# Run a fuzzing campaign
./scripts/fuzz.sh my_api.js -t 60 -w 4

# Analyze crashes
./scripts/analyze-crash.sh crash-abc123 my_api.js -r

# View corpus statistics
./scripts/corpus-stats.sh corpus
```

Available scripts:
- **deploy.sh** - Automated deployment and setup
- **fuzz.sh** - Run fuzzing campaigns with easy options
- **create-fuzzer.sh** - Generate fuzzer templates
- **analyze-crash.sh** - Analyze and minimize crashes
- **corpus-stats.sh** - Show corpus statistics

## Example Fuzzers

Example fuzzer scripts are available in the `examples/` directory:

- `json_fuzzer.js` - Tests JSON parsing
- `regex_fuzzer.js` - Tests regular expressions
- `arithmetic_fuzzer.js` - Tests numeric operations

Integration examples showing real-world patterns in `integration-examples/`:

- `1_fuzz_custom_parser.js` - Parser fuzzing pattern
- `2_fuzz_api_library.js` - API testing pattern
- `3_fuzz_state_machine.js` - Stateful code fuzzing
- `4_fuzz_with_dictionary.js` - Dictionary-based fuzzing

## Documentation

- **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)** - Complete guide to integrating fuzzing into your project
- **[MCP_SETUP.md](MCP_SETUP.md)** - Setting up the MCP server for Claude Code
- **[mcp-server/README.md](mcp-server/README.md)** - MCP server API documentation
- **[integration-examples/README.md](integration-examples/README.md)** - Integration patterns and examples

## Notes

This is a work in progress. Capabilities and internal structure may change without prior notice.
