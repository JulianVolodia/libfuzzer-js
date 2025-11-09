# libfuzzer-js MCP Server

Model Context Protocol (MCP) server for libfuzzer-js - enabling Claude Code to assist with JavaScript fuzzing workflows using LibFuzzer and QuickJS.

## Overview

This MCP server provides tools for building, running, and managing JavaScript fuzzing campaigns with libfuzzer-js. It integrates directly with Claude Code in the Web, allowing you to:

- Build the fuzzer from source
- Create fuzzer script templates
- Run fuzzing campaigns with various configurations
- Analyze crashes and fuzzing statistics
- Manage corpus and artifacts

## Prerequisites

Before using this MCP server, ensure you have:

1. **libFuzzer** - A recent version of libFuzzer for optimal coverage capturing
2. **Clang/LLVM** - C++ compiler with fuzzing support
3. **Node.js** - Version 18 or higher
4. **libfuzzer-js** - Built and ready (see main project README)

### Setting up libFuzzer

```sh
svn co https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer Fuzzer
cd Fuzzer
./build.sh
export LIBFUZZER_A_PATH=$(realpath libFuzzer.a)
```

## Installation

1. Navigate to the MCP server directory:

```sh
cd mcp-server
```

2. Install dependencies:

```sh
npm install
```

3. Build the TypeScript code:

```sh
npm run build
```

## Configuration for Claude Code in the Web

To use this MCP server with Claude Code in the Web, add it to your MCP configuration:

### Option 1: Using npx (Recommended for testing)

Add to your Claude Code MCP settings:

```json
{
  "mcpServers": {
    "libfuzzer-js": {
      "command": "npx",
      "args": ["-y", "/home/user/libfuzzer-js/mcp-server/build/index.js"],
      "env": {
        "LIBFUZZER_A_PATH": "/path/to/libFuzzer.a"
      }
    }
  }
}
```

### Option 2: Using Node directly

```json
{
  "mcpServers": {
    "libfuzzer-js": {
      "command": "node",
      "args": ["/home/user/libfuzzer-js/mcp-server/build/index.js"],
      "env": {
        "LIBFUZZER_A_PATH": "/path/to/libFuzzer.a"
      }
    }
  }
}
```

### Option 3: Global installation

Install the server globally:

```sh
npm install -g .
```

Then configure:

```json
{
  "mcpServers": {
    "libfuzzer-js": {
      "command": "libfuzzer-js-mcp",
      "env": {
        "LIBFUZZER_A_PATH": "/path/to/libFuzzer.a"
      }
    }
  }
}
```

## Available Tools

### 1. `build`

Build the libfuzzer-js fuzzer from source.

**Parameters:**
- `clean` (boolean, optional): Clean build artifacts before building

**Example:**
```javascript
{
  "clean": true
}
```

### 2. `create-fuzzer-template`

Create a JavaScript fuzzer template with common patterns.

**Parameters:**
- `name` (string, required): Name of the fuzzer file (without .js extension)
- `type` (string, optional): Template type - "json", "regex", "arithmetic", or "custom" (default: "custom")

**Example:**
```javascript
{
  "name": "my_fuzzer",
  "type": "json"
}
```

### 3. `run-fuzzer`

Run a fuzzing campaign with the specified JavaScript file.

**Parameters:**
- `jsFile` (string): Path to JavaScript file to fuzz (relative to project root)
- `bcFile` (string): Path to QuickJS bytecode file (alternative to jsFile)
- `maxTotalTime` (number, optional): Maximum total time in seconds
- `maxLen` (number, optional): Maximum length of test input (default: 4096)
- `workers` (number, optional): Number of parallel workers (default: 1)
- `jobs` (number, optional): Number of jobs
- `corpusDir` (string, optional): Directory for corpus files (default: "corpus")
- `artifactPrefix` (string, optional): Prefix for crash/artifact files
- `extraArgs` (array, optional): Additional libFuzzer arguments

**Example:**
```javascript
{
  "jsFile": "examples/json_fuzzer.js",
  "maxTotalTime": 60,
  "workers": 4,
  "corpusDir": "json_corpus"
}
```

### 4. `list-crashes`

List all crash files and artifacts found during fuzzing.

**Parameters:**
- `corpusDir` (string, optional): Directory to check for crashes

**Example:**
```javascript
{
  "corpusDir": "corpus"
}
```

### 5. `analyze-crash`

Analyze a specific crash file by examining its contents.

**Parameters:**
- `crashFile` (string, required): Path to the crash file
- `jsFile` (string, optional): JavaScript file that was being fuzzed

**Example:**
```javascript
{
  "crashFile": "crash-1234567890abcdef",
  "jsFile": "examples/json_fuzzer.js"
}
```

### 6. `get-fuzzer-stats`

Get statistics about the fuzzing corpus and coverage.

**Parameters:**
- `corpusDir` (string, optional): Corpus directory (default: "corpus")

**Example:**
```javascript
{
  "corpusDir": "corpus"
}
```

## Workflow Example

Here's a typical workflow using Claude Code with this MCP server:

1. **Build the fuzzer:**
   - Ask Claude: "Build the fuzzer with a clean build"
   - Claude will use the `build` tool with `clean: true`

2. **Create a fuzzer script:**
   - Ask Claude: "Create a JSON fuzzer template called api_fuzzer"
   - Claude will use the `create-fuzzer-template` tool

3. **Customize your fuzzer:**
   - Edit the generated `api_fuzzer.js` to test your specific API

4. **Run the fuzzer:**
   - Ask Claude: "Run the fuzzer on api_fuzzer.js for 5 minutes with 4 workers"
   - Claude will use the `run-fuzzer` tool

5. **Check for crashes:**
   - Ask Claude: "List any crashes found"
   - Claude will use the `list-crashes` tool

6. **Analyze crashes:**
   - Ask Claude: "Analyze the latest crash"
   - Claude will use the `analyze-crash` tool

7. **Get statistics:**
   - Ask Claude: "Show me the fuzzing stats"
   - Claude will use the `get-fuzzer-stats` tool

## Writing Fuzzer Scripts

When writing fuzzer scripts, keep in mind:

- **FuzzerInput** is a `Uint8Array` containing random data
- Most inputs will be invalid/malformed - this is expected
- Only crashes/hangs indicate actual bugs
- Wrap operations in try-catch blocks to handle expected errors
- Focus on testing edge cases and boundary conditions

### Example Fuzzer Structure

```javascript
// Convert input to your format
const inputStr = String.fromCharCode.apply(null, FuzzerInput);

try {
    // Your code to test
    const result = yourFunction(inputStr);

    // Perform operations on the result
    doSomething(result);

} catch (e) {
    // Expected errors from invalid input
    // Only crashes/hangs outside of catch blocks are bugs
}
```

## Troubleshooting

### "Fuzzer not built" error
- Run the `build` tool first to compile the fuzzer
- Ensure `LIBFUZZER_A_PATH` environment variable is set correctly

### "JavaScript file not found" error
- Check that the file path is relative to the project root
- Verify the file exists with the correct name

### No crashes found
- This is good! It means no bugs were found
- Try running longer (`maxTotalTime`) or with more workers
- Ensure your fuzzer script is actually testing the target code

### Build fails
- Verify you have clang++ installed
- Check that `LIBFUZZER_A_PATH` points to a valid libFuzzer.a file
- Ensure QuickJS submodule is properly checked out

## Development

To modify the MCP server:

1. Edit TypeScript source in `src/`
2. Rebuild with `npm run build`
3. Restart Claude Code to reload the MCP server

For development with auto-rebuild:

```sh
npm run dev
```

## More Information

- [MCP Documentation](https://modelcontextprotocol.io/)
- [LibFuzzer Documentation](https://llvm.org/docs/LibFuzzer.html)
- [QuickJS](https://bellard.org/quickjs/)

## License

Same as the parent libfuzzer-js project.
