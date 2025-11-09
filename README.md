# libfuzzer-js

libFuzzer-based JavaScript fuzzing using Bellard's [QuickJS](https://bellard.org/quickjs/).

## Building

You need a recent version of libFuzzer for optimal coverage capturing.

Run this from any path:

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

## Example Fuzzers

Example fuzzer scripts are available in the `examples/` directory:

- `json_fuzzer.js` - Tests JSON parsing
- `regex_fuzzer.js` - Tests regular expressions
- `arithmetic_fuzzer.js` - Tests numeric operations

## Notes

This is a work in progress. Capabilities and internal structure may change without prior notice.
