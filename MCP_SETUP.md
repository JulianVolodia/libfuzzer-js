# MCP Server Setup for Claude Code in the Web

This guide will help you set up the libfuzzer-js MCP server with Claude Code in the Web.

## Prerequisites

1. Node.js 18+ installed
2. libFuzzer built and `LIBFUZZER_A_PATH` environment variable set
3. libfuzzer-js project cloned and accessible

## Installation Steps

### 1. Build the MCP Server

```bash
cd mcp-server
npm install
npm run build
```

### 2. Configure Claude Code

You need to add the MCP server to your Claude Code configuration. The configuration file location depends on your system:

- **Linux/macOS**: `~/.config/claude-code/mcp_settings.json`
- **Windows**: `%APPDATA%\claude-code\mcp_settings.json`

Add the following configuration (adjust paths as needed):

```json
{
  "mcpServers": {
    "libfuzzer-js": {
      "command": "node",
      "args": ["/absolute/path/to/libfuzzer-js/mcp-server/build/index.js"],
      "env": {
        "LIBFUZZER_A_PATH": "/absolute/path/to/libFuzzer.a"
      }
    }
  }
}
```

**Important:** Replace the paths with your actual absolute paths:
- `/absolute/path/to/libfuzzer-js/` - Path to your libfuzzer-js project
- `/absolute/path/to/libFuzzer.a` - Path to your built libFuzzer.a file

### 3. Restart Claude Code

After updating the configuration, restart Claude Code in the Web for the changes to take effect.

## Verifying the Setup

Once configured, you can verify the MCP server is working by asking Claude:

1. "What MCP tools are available?"
2. "Build the fuzzer"
3. "Create a JSON fuzzer template called test"

If Claude can see and use the tools, your setup is complete!

## Available Tools

The MCP server provides these tools:

- **build** - Build the fuzzer from source
- **create-fuzzer-template** - Generate fuzzer script templates
- **run-fuzzer** - Execute fuzzing campaigns
- **list-crashes** - Show discovered crashes
- **analyze-crash** - Examine specific crash files
- **get-fuzzer-stats** - Display corpus statistics

## Example Usage

After setup, you can interact with Claude naturally:

- "Build the fuzzer with a clean build"
- "Create a JSON fuzzer template called api_test"
- "Run the fuzzer on examples/json_fuzzer.js for 60 seconds"
- "Show me any crashes that were found"
- "Analyze the latest crash"

## Troubleshooting

### MCP Server Not Found

If Claude can't find the MCP server:
1. Verify the path in your configuration is absolute, not relative
2. Check that `build/index.js` exists in the mcp-server directory
3. Ensure Node.js is in your system PATH
4. Restart Claude Code

### Build Errors

If the fuzzer build fails:
1. Verify `LIBFUZZER_A_PATH` points to a valid libFuzzer.a file
2. Ensure clang++ is installed and in PATH
3. Check that the QuickJS submodule is initialized

### Permission Errors

If you get permission errors:
```bash
chmod +x /path/to/libfuzzer-js/mcp-server/build/index.js
```

## Advanced Configuration

### Using with npx

For testing without modifying PATH:

```json
{
  "mcpServers": {
    "libfuzzer-js": {
      "command": "npx",
      "args": ["-y", "/absolute/path/to/libfuzzer-js/mcp-server/build/index.js"],
      "env": {
        "LIBFUZZER_A_PATH": "/absolute/path/to/libFuzzer.a"
      }
    }
  }
}
```

### Multiple Instances

You can configure multiple instances with different settings:

```json
{
  "mcpServers": {
    "libfuzzer-js-dev": {
      "command": "node",
      "args": ["/path/to/dev/libfuzzer-js/mcp-server/build/index.js"],
      "env": {
        "LIBFUZZER_A_PATH": "/path/to/libFuzzer.a"
      }
    },
    "libfuzzer-js-prod": {
      "command": "node",
      "args": ["/path/to/prod/libfuzzer-js/mcp-server/build/index.js"],
      "env": {
        "LIBFUZZER_A_PATH": "/path/to/libFuzzer.a"
      }
    }
  }
}
```

## Getting Help

For more information:
- See [mcp-server/README.md](mcp-server/README.md) for detailed tool documentation
- Visit [Model Context Protocol documentation](https://modelcontextprotocol.io/)
- Check the [libfuzzer-js README](README.md) for project-specific details
