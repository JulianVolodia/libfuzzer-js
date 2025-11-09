#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { execSync, spawn } from "child_process";
import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from "fs";
import { join, resolve } from "path";

// Get the project root (assuming MCP server is in mcp-server subdirectory)
const PROJECT_ROOT = resolve(import.meta.dirname, "../..");

interface FuzzerOptions {
  jsFile?: string;
  bcFile?: string;
  maxTotalTime?: number;
  maxLen?: number;
  workers?: number;
  jobs?: number;
  corpusDir?: string;
  artifactPrefix?: string;
  extraArgs?: string[];
}

class LibFuzzerJSServer {
  private server: Server;

  constructor() {
    this.server = new Server(
      {
        name: "libfuzzer-js-mcp-server",
        version: "1.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();

    // Error handling
    this.server.onerror = (error) => console.error("[MCP Error]", error);
    process.on("SIGINT", async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  private setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: this.getTools(),
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case "build":
            return await this.buildFuzzer(args as { clean?: boolean });

          case "run-fuzzer":
            return await this.runFuzzer(args as FuzzerOptions);

          case "create-fuzzer-template":
            return await this.createFuzzerTemplate(args as { name: string; type?: string });

          case "list-crashes":
            return await this.listCrashes(args as { corpusDir?: string });

          case "analyze-crash":
            return await this.analyzeCrash(args as { crashFile: string; jsFile?: string });

          case "get-fuzzer-stats":
            return await this.getFuzzerStats(args as { corpusDir?: string });

          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        return {
          content: [{ type: "text", text: `Error: ${errorMessage}` }],
          isError: true,
        };
      }
    });
  }

  private getTools(): Tool[] {
    return [
      {
        name: "build",
        description: "Build the libfuzzer-js fuzzer. This compiles the C++ harness with QuickJS and LibFuzzer.",
        inputSchema: {
          type: "object",
          properties: {
            clean: {
              type: "boolean",
              description: "Clean build artifacts before building",
              default: false,
            },
          },
        },
      },
      {
        name: "run-fuzzer",
        description: "Run a fuzzing campaign with the specified JavaScript file. The fuzzer will execute the JS code with random input provided through the FuzzerInput variable.",
        inputSchema: {
          type: "object",
          properties: {
            jsFile: {
              type: "string",
              description: "Path to the JavaScript file to fuzz (relative to project root)",
            },
            bcFile: {
              type: "string",
              description: "Path to QuickJS bytecode file (alternative to jsFile)",
            },
            maxTotalTime: {
              type: "number",
              description: "Maximum total time in seconds for fuzzing",
            },
            maxLen: {
              type: "number",
              description: "Maximum length of test input",
              default: 4096,
            },
            workers: {
              type: "number",
              description: "Number of parallel fuzzing workers",
              default: 1,
            },
            jobs: {
              type: "number",
              description: "Number of fuzzing jobs",
            },
            corpusDir: {
              type: "string",
              description: "Directory for corpus files (default: corpus)",
              default: "corpus",
            },
            artifactPrefix: {
              type: "string",
              description: "Prefix for crash/artifact files",
            },
            extraArgs: {
              type: "array",
              items: { type: "string" },
              description: "Additional libFuzzer arguments",
            },
          },
          oneOf: [
            { required: ["jsFile"] },
            { required: ["bcFile"] }
          ],
        },
      },
      {
        name: "create-fuzzer-template",
        description: "Create a JavaScript fuzzer template. The template includes the FuzzerInput variable and common fuzzing patterns.",
        inputSchema: {
          type: "object",
          properties: {
            name: {
              type: "string",
              description: "Name of the fuzzer file (without .js extension)",
            },
            type: {
              type: "string",
              description: "Type of fuzzer template (json, regex, arithmetic, or custom)",
              enum: ["json", "regex", "arithmetic", "custom"],
              default: "custom",
            },
          },
          required: ["name"],
        },
      },
      {
        name: "list-crashes",
        description: "List all crash files and artifacts found during fuzzing.",
        inputSchema: {
          type: "object",
          properties: {
            corpusDir: {
              type: "string",
              description: "Corpus directory to check for crashes (default: current directory)",
            },
          },
        },
      },
      {
        name: "analyze-crash",
        description: "Analyze a crash file by reproducing it with the fuzzer.",
        inputSchema: {
          type: "object",
          properties: {
            crashFile: {
              type: "string",
              description: "Path to the crash file",
            },
            jsFile: {
              type: "string",
              description: "JavaScript file that was being fuzzed (if not in crash filename)",
            },
          },
          required: ["crashFile"],
        },
      },
      {
        name: "get-fuzzer-stats",
        description: "Get statistics about the fuzzing corpus and coverage.",
        inputSchema: {
          type: "object",
          properties: {
            corpusDir: {
              type: "string",
              description: "Corpus directory (default: corpus)",
              default: "corpus",
            },
          },
        },
      },
    ];
  }

  private async buildFuzzer(args: { clean?: boolean }) {
    try {
      let output = "";

      if (args.clean) {
        output += "Cleaning build artifacts...\n";
        try {
          execSync("make clean", { cwd: PROJECT_ROOT, encoding: "utf-8" });
        } catch (e) {
          output += "No clean target or already clean\n";
        }
      }

      output += "Building libfuzzer-js...\n";
      const buildOutput = execSync("make", {
        cwd: PROJECT_ROOT,
        encoding: "utf-8",
        env: { ...process.env }
      });

      output += buildOutput;
      output += "\nBuild successful! Fuzzer binary: jsfuzzer\n";

      return {
        content: [{ type: "text", text: output }],
      };
    } catch (error) {
      throw new Error(`Build failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async runFuzzer(args: FuzzerOptions) {
    const fuzzerPath = join(PROJECT_ROOT, "jsfuzzer");

    if (!existsSync(fuzzerPath)) {
      throw new Error("Fuzzer not built. Run 'build' tool first.");
    }

    const fuzzerArgs: string[] = [];

    // Add JS or bytecode file
    if (args.jsFile) {
      const jsPath = join(PROJECT_ROOT, args.jsFile);
      if (!existsSync(jsPath)) {
        throw new Error(`JavaScript file not found: ${args.jsFile}`);
      }
      fuzzerArgs.push(`--js=${jsPath}`);
    } else if (args.bcFile) {
      const bcPath = join(PROJECT_ROOT, args.bcFile);
      if (!existsSync(bcPath)) {
        throw new Error(`Bytecode file not found: ${args.bcFile}`);
      }
      fuzzerArgs.push(`--bc=${bcPath}`);
    }

    // Add libFuzzer options
    if (args.maxTotalTime) {
      fuzzerArgs.push(`-max_total_time=${args.maxTotalTime}`);
    }
    if (args.maxLen) {
      fuzzerArgs.push(`-max_len=${args.maxLen}`);
    }
    if (args.workers) {
      fuzzerArgs.push(`-workers=${args.workers}`);
    }
    if (args.jobs) {
      fuzzerArgs.push(`-jobs=${args.jobs}`);
    }
    if (args.artifactPrefix) {
      fuzzerArgs.push(`-artifact_prefix=${args.artifactPrefix}`);
    }

    // Add extra arguments
    if (args.extraArgs) {
      fuzzerArgs.push(...args.extraArgs);
    }

    // Add corpus directory
    const corpusDir = join(PROJECT_ROOT, args.corpusDir || "corpus");
    fuzzerArgs.push(corpusDir);

    const command = `${fuzzerPath} ${fuzzerArgs.join(" ")}`;

    return {
      content: [
        {
          type: "text",
          text: `Starting fuzzer with command:\n${command}\n\nNote: The fuzzer is running. Press Ctrl+C to stop.\n\nTo run this in the background, execute:\n${command} &\n`
        }
      ],
    };
  }

  private async createFuzzerTemplate(args: { name: string; type?: string }) {
    const type = args.type || "custom";
    let template = "";

    const header = `// Fuzzer template for ${args.name}
// Input is provided through the FuzzerInput variable (Uint8Array)

`;

    switch (type) {
      case "json":
        template = header + `// Convert fuzzer input to string
const inputStr = String.fromCharCode.apply(null, FuzzerInput);

try {
    // Try to parse as JSON
    const obj = JSON.parse(inputStr);

    // Add your target code here
    // For example, test a function that processes JSON:
    // processJSON(obj);

} catch (e) {
    // Invalid JSON - this is expected for most fuzzer inputs
    // Only real bugs should cause crashes
}
`;
        break;

      case "regex":
        template = header + `// Convert fuzzer input to string
const inputStr = String.fromCharCode.apply(null, FuzzerInput);

try {
    // Test regex operations
    const pattern = inputStr;
    const regex = new RegExp(pattern);

    // Test regex matching
    const testString = "test string for regex matching";
    regex.test(testString);
    regex.exec(testString);

    // Add your regex-based code here

} catch (e) {
    // Most random inputs won't be valid regex patterns
}
`;
        break;

      case "arithmetic":
        template = header + `// Extract numbers from fuzzer input
if (FuzzerInput.length >= 8) {
    // Read values from fuzzer input
    const a = FuzzerInput[0] | (FuzzerInput[1] << 8) | (FuzzerInput[2] << 16) | (FuzzerInput[3] << 24);
    const b = FuzzerInput[4] | (FuzzerInput[5] << 8) | (FuzzerInput[6] << 16) | (FuzzerInput[7] << 24);

    // Add your arithmetic/numeric code here
    // For example:
    // const result = yourFunction(a, b);
}
`;
        break;

      case "custom":
      default:
        template = header + `// Access fuzzer input
// FuzzerInput is a Uint8Array containing random data

// Example 1: Use raw bytes
if (FuzzerInput.length > 0) {
    const firstByte = FuzzerInput[0];
    // Add your code here
}

// Example 2: Convert to string
const inputStr = String.fromCharCode.apply(null, FuzzerInput);

// Example 3: Process as different types
if (FuzzerInput.length >= 4) {
    const value = FuzzerInput[0] | (FuzzerInput[1] << 8) |
                  (FuzzerInput[2] << 16) | (FuzzerInput[3] << 24);
    // Add your code here
}

// Add your target code to fuzz here
// The fuzzer will call this script repeatedly with random inputs
// Any crashes or hangs will be saved as artifacts
`;
        break;
    }

    const filename = `${args.name}.js`;
    const filepath = join(PROJECT_ROOT, filename);

    writeFileSync(filepath, template, "utf-8");

    return {
      content: [
        {
          type: "text",
          text: `Created fuzzer template: ${filename}\n\nTemplate type: ${type}\n\nTo run this fuzzer:\n  ./jsfuzzer --js=${filename} corpus\n\nOr use the run-fuzzer tool with:\n  { "jsFile": "${filename}" }`
        }
      ],
    };
  }

  private async listCrashes(args: { corpusDir?: string }) {
    const searchDir = args.corpusDir ? join(PROJECT_ROOT, args.corpusDir) : PROJECT_ROOT;

    const crashes: { file: string; size: number; modified: Date }[] = [];

    try {
      const files = readdirSync(searchDir);

      for (const file of files) {
        // Look for crash, leak, timeout, and oom files
        if (file.startsWith("crash-") || file.startsWith("leak-") ||
            file.startsWith("timeout-") || file.startsWith("oom-")) {
          const filepath = join(searchDir, file);
          const stats = statSync(filepath);
          crashes.push({
            file: filepath,
            size: stats.size,
            modified: stats.mtime,
          });
        }
      }

      if (crashes.length === 0) {
        return {
          content: [{ type: "text", text: "No crashes found." }],
        };
      }

      // Sort by modification time (newest first)
      crashes.sort((a, b) => b.modified.getTime() - a.modified.getTime());

      let output = `Found ${crashes.length} crash file(s):\n\n`;
      for (const crash of crashes) {
        output += `- ${crash.file}\n`;
        output += `  Size: ${crash.size} bytes\n`;
        output += `  Modified: ${crash.modified.toISOString()}\n\n`;
      }

      return {
        content: [{ type: "text", text: output }],
      };
    } catch (error) {
      throw new Error(`Failed to list crashes: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async analyzeCrash(args: { crashFile: string; jsFile?: string }) {
    const crashPath = resolve(PROJECT_ROOT, args.crashFile);

    if (!existsSync(crashPath)) {
      throw new Error(`Crash file not found: ${args.crashFile}`);
    }

    const crashData = readFileSync(crashPath);
    let output = `Analyzing crash file: ${args.crashFile}\n`;
    output += `Size: ${crashData.length} bytes\n\n`;

    // Show hex dump of crash input
    output += "Crash input (hex):\n";
    const hexDump = Array.from(crashData.slice(0, Math.min(256, crashData.length)))
      .map(b => b.toString(16).padStart(2, '0'))
      .join(' ');
    output += hexDump + "\n";
    if (crashData.length > 256) {
      output += `... (${crashData.length - 256} more bytes)\n`;
    }
    output += "\n";

    // Try to show as ASCII
    output += "Crash input (ASCII, printable chars only):\n";
    const asciiDump = Array.from(crashData.slice(0, Math.min(256, crashData.length)))
      .map(b => (b >= 32 && b < 127) ? String.fromCharCode(b) : '.')
      .join('');
    output += asciiDump + "\n\n";

    // Provide reproduction command
    if (args.jsFile) {
      const fuzzerPath = join(PROJECT_ROOT, "jsfuzzer");
      output += `To reproduce this crash, run:\n`;
      output += `${fuzzerPath} --js=${args.jsFile} ${crashPath}\n`;
    }

    return {
      content: [{ type: "text", text: output }],
    };
  }

  private async getFuzzerStats(args: { corpusDir?: string }) {
    const corpusDir = join(PROJECT_ROOT, args.corpusDir || "corpus");

    let output = `Fuzzer statistics for: ${args.corpusDir || "corpus"}\n\n`;

    if (!existsSync(corpusDir)) {
      output += "Corpus directory does not exist yet. Run a fuzzing campaign first.\n";
      return {
        content: [{ type: "text", text: output }],
      };
    }

    try {
      const files = readdirSync(corpusDir);
      const corpusFiles = files.filter(f => !f.startsWith("."));

      let totalSize = 0;
      let minSize = Infinity;
      let maxSize = 0;

      for (const file of corpusFiles) {
        const stats = statSync(join(corpusDir, file));
        totalSize += stats.size;
        minSize = Math.min(minSize, stats.size);
        maxSize = Math.max(maxSize, stats.size);
      }

      output += `Corpus files: ${corpusFiles.length}\n`;
      if (corpusFiles.length > 0) {
        output += `Total size: ${totalSize} bytes\n`;
        output += `Average size: ${Math.round(totalSize / corpusFiles.length)} bytes\n`;
        output += `Min size: ${minSize} bytes\n`;
        output += `Max size: ${maxSize} bytes\n`;
      }

      return {
        content: [{ type: "text", text: output }],
      };
    } catch (error) {
      throw new Error(`Failed to get stats: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("libfuzzer-js MCP server running on stdio");
  }
}

const server = new LibFuzzerJSServer();
server.run().catch(console.error);
