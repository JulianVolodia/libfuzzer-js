#!/bin/bash
# Create a new fuzzer from templates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $(basename "$0") <name> [type] [options]

Create a new fuzzer from a template.

Arguments:
  name          Name of the fuzzer (without .js extension)
  type          Template type (default: custom)

Template Types:
  custom        Generic fuzzer template
  json          JSON parsing and manipulation
  regex         Regular expression testing
  arithmetic    Numeric operations
  string        String operations and encoding
  api           API/function testing template
  protocol      Protocol/format parser template
  import        Import existing code for fuzzing

Options:
  -o, --output DIR    Output directory (default: current directory)
  -f, --file PATH     Import code from file (with 'import' type)
  --open              Open in editor after creation
  -h, --help          Show this help

Examples:
  # Create a JSON fuzzer
  $(basename "$0") my_json_fuzzer json

  # Create a custom fuzzer in specific directory
  $(basename "$0") api_test custom -o ./fuzzers/

  # Import existing code for fuzzing
  $(basename "$0") my_lib import -f ./mylib.js

  # Create and open in editor
  $(basename "$0") parser protocol --open

EOF
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Generate fuzzer content based on type
generate_fuzzer() {
    local name="$1"
    local type="${2:-custom}"
    local import_file="$3"

    local content=""

    case "$type" in
        json)
            content=$(cat << 'FUZZER_END'
// JSON Fuzzer Template
// Tests JSON parsing, manipulation, and edge cases

const inputStr = String.fromCharCode.apply(null, FuzzerInput);

try {
    // Parse JSON
    const obj = JSON.parse(inputStr);

    // Test JSON operations
    if (obj !== null && typeof obj === 'object') {
        // Stringify and re-parse
        const str = JSON.stringify(obj);
        const obj2 = JSON.parse(str);

        // Test property access
        for (let key in obj) {
            if (obj.hasOwnProperty(key)) {
                const value = obj[key];
                // Process value based on type
                if (typeof value === 'string') {
                    value.length;
                } else if (typeof value === 'number') {
                    value.toString();
                } else if (typeof value === 'object' && value !== null) {
                    JSON.stringify(value);
                }
            }
        }

        // ADD YOUR CODE HERE
        // Example: processMyJSON(obj);
    }
} catch (e) {
    // Invalid JSON - expected for most random inputs
}
FUZZER_END
)
            ;;

        regex)
            content=$(cat << 'FUZZER_END'
// Regular Expression Fuzzer Template
// Tests regex compilation and matching

const inputStr = String.fromCharCode.apply(null, FuzzerInput);

// Split input for pattern and test string
const mid = Math.floor(FuzzerInput.length / 2);
const pattern = String.fromCharCode.apply(null, FuzzerInput.slice(0, mid));
const testStr = String.fromCharCode.apply(null, FuzzerInput.slice(mid));

try {
    // Create regex
    const regex = new RegExp(pattern);

    // Test regex operations
    regex.test(testStr);
    const match = regex.exec(testStr);

    if (match) {
        match.index;
        match.groups;
    }

    // Test string methods
    testStr.match(regex);
    testStr.search(regex);
    testStr.replace(regex, 'X');
    testStr.split(regex);

    // Test with flags
    if (pattern.length > 0 && pattern.length < 100) {
        const flagRegex = new RegExp(pattern, 'gi');
        flagRegex.test(testStr);
    }

    // ADD YOUR CODE HERE
    // Example: myRegexFunction(pattern, testStr);
} catch (e) {
    // Invalid regex - expected
}
FUZZER_END
)
            ;;

        arithmetic)
            content=$(cat << 'FUZZER_END'
// Arithmetic Fuzzer Template
// Tests numeric operations and edge cases

if (FuzzerInput.length >= 16) {
    // Extract integers from input
    const readInt32 = (offset) => {
        return FuzzerInput[offset] |
               (FuzzerInput[offset+1] << 8) |
               (FuzzerInput[offset+2] << 16) |
               (FuzzerInput[offset+3] << 24);
    };

    const a = readInt32(0);
    const b = readInt32(4);
    const c = readInt32(8);
    const d = readInt32(12);

    // Basic arithmetic
    const sum = a + b;
    const diff = a - b;
    const prod = a * b;

    // Safe division
    if (b !== 0) {
        const div = a / b;
        const mod = a % b;
    }

    // Bitwise operations
    const and = a & b;
    const or = a | b;
    const xor = a ^ b;
    const shift = a << (b & 31);

    // Floating point
    const fa = a / 1000.0;
    const fb = b / 1000.0;
    const sqrt = Math.sqrt(Math.abs(fa));
    const pow = Math.pow(fa, (fb % 10));

    // Array operations
    const arr = [a, b, c, d];
    arr.sort((x, y) => x - y);
    arr.filter(x => x > 0);
    arr.map(x => x * 2);
    arr.reduce((acc, x) => acc + x, 0);

    // ADD YOUR CODE HERE
    // Example: myMathFunction(a, b, c, d);
}
FUZZER_END
)
            ;;

        string)
            content=$(cat << 'FUZZER_END'
// String Operations Fuzzer Template
// Tests string manipulation and encoding

const inputStr = String.fromCharCode.apply(null, FuzzerInput);

try {
    // Basic string operations
    inputStr.length;
    inputStr.toUpperCase();
    inputStr.toLowerCase();
    inputStr.trim();

    // Substring operations
    if (inputStr.length > 2) {
        const mid = Math.floor(inputStr.length / 2);
        inputStr.substring(0, mid);
        inputStr.substring(mid);
        inputStr.slice(0, mid);
    }

    // Splitting and joining
    const parts = inputStr.split('');
    parts.join(',');

    // Encoding operations
    try {
        encodeURI(inputStr);
        encodeURIComponent(inputStr);
        decodeURI(inputStr);
        decodeURIComponent(inputStr);
    } catch (e) {
        // Invalid encoding
    }

    // Character operations
    for (let i = 0; i < Math.min(inputStr.length, 100); i++) {
        inputStr.charAt(i);
        inputStr.charCodeAt(i);
    }

    // ADD YOUR CODE HERE
    // Example: processString(inputStr);
} catch (e) {
    // Handle errors
}
FUZZER_END
)
            ;;

        api)
            content=$(cat << 'FUZZER_END'
// API Fuzzer Template
// Template for fuzzing your own APIs and functions

// Import your code here (concatenate files before fuzzing)
// Example:
// function myAPI(input) { ... }

const inputStr = String.fromCharCode.apply(null, FuzzerInput);

// Extract different data types from fuzzer input
const extractByte = (offset) => FuzzerInput[offset] || 0;
const extractInt16 = (offset) => {
    return (FuzzerInput[offset] || 0) |
           ((FuzzerInput[offset+1] || 0) << 8);
};
const extractInt32 = (offset) => {
    return (FuzzerInput[offset] || 0) |
           ((FuzzerInput[offset+1] || 0) << 8) |
           ((FuzzerInput[offset+2] || 0) << 16) |
           ((FuzzerInput[offset+3] || 0) << 24);
};

try {
    // Example: Call your API with fuzzer input
    // const result = myAPI(inputStr);

    // Or with structured data:
    // const arg1 = extractInt32(0);
    // const arg2 = extractByte(4);
    // const arg3 = inputStr.substring(5);
    // const result = myAPI(arg1, arg2, arg3);

    // ADD YOUR API CALLS HERE
    // Test all your API functions with various inputs

} catch (e) {
    // Catch expected errors
    // Only crashes outside catch blocks are bugs
}
FUZZER_END
)
            ;;

        protocol)
            content=$(cat << 'FUZZER_END'
// Protocol/Format Fuzzer Template
// Template for testing parsers and protocol implementations

// Protocol state machine or parser
function parseProtocol(data) {
    // Example protocol parser
    const view = {
        data: data,
        offset: 0,

        readByte: function() {
            if (this.offset >= this.data.length) return 0;
            return this.data[this.offset++];
        },

        readInt16: function() {
            const low = this.readByte();
            const high = this.readByte();
            return low | (high << 8);
        },

        readInt32: function() {
            const a = this.readByte();
            const b = this.readByte();
            const c = this.readByte();
            const d = this.readByte();
            return a | (b << 8) | (c << 16) | (d << 24);
        },

        readString: function(length) {
            const bytes = [];
            for (let i = 0; i < length && this.offset < this.data.length; i++) {
                bytes.push(this.readByte());
            }
            return String.fromCharCode.apply(null, bytes);
        }
    };

    // Example protocol format:
    // [magic:4] [version:2] [length:2] [data:length]

    const magic = view.readInt32();
    const version = view.readInt16();
    const length = view.readInt16();
    const payload = view.readString(length);

    return {
        magic: magic,
        version: version,
        payload: payload
    };
}

try {
    // Parse protocol from fuzzer input
    const message = parseProtocol(FuzzerInput);

    // ADD YOUR PROTOCOL HANDLING CODE HERE
    // Example: handleMessage(message);

} catch (e) {
    // Parser errors expected for invalid input
}
FUZZER_END
)
            ;;

        import)
            if [ -n "$import_file" ] && [ -f "$import_file" ]; then
                content=$(cat << FUZZER_END
// Fuzzer for imported code: $(basename "$import_file")
// Original code imported from: $import_file

$(cat "$import_file")

// ===== FUZZER CODE BELOW =====

const inputStr = String.fromCharCode.apply(null, FuzzerInput);

try {
    // TODO: Call your imported functions here
    // Example: yourFunction(inputStr);

    // You can extract structured data from FuzzerInput:
    if (FuzzerInput.length >= 4) {
        const arg1 = FuzzerInput[0] | (FuzzerInput[1] << 8);
        const arg2 = FuzzerInput[2] | (FuzzerInput[3] << 8);
        // const result = yourFunction(arg1, arg2);
    }

} catch (e) {
    // Expected errors from invalid input
}
FUZZER_END
)
            else
                echo "Error: Import file not found or not specified" >&2
                echo "Use: -f <file> to specify import file" >&2
                return 1
            fi
            ;;

        custom|*)
            content=$(cat << 'FUZZER_END'
// Custom Fuzzer Template
// Customize this template for your fuzzing needs

// FuzzerInput is a Uint8Array with random data

// Convert to string
const inputStr = String.fromCharCode.apply(null, FuzzerInput);

// Helper functions to extract data
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

try {
    // ADD YOUR CODE HERE

    // Example 1: Process as string
    // yourFunction(inputStr);

    // Example 2: Process as bytes
    // if (FuzzerInput.length > 0) {
    //     const cmd = readByte(0);
    //     const value = readInt32(1);
    //     handleCommand(cmd, value);
    // }

    // Example 3: Parse structured data
    // if (FuzzerInput.length >= 8) {
    //     const header = readInt32(0);
    //     const payload = inputStr.substring(4);
    //     processMessage(header, payload);
    // }

} catch (e) {
    // Expected errors - only crashes outside catch are bugs
}
FUZZER_END
)
            ;;
    esac

    echo "$content"
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    local name=""
    local type="custom"
    local output_dir="."
    local import_file=""
    local open_editor=false

    # Parse first positional argument
    if [[ "$1" != -* ]]; then
        name="$1"
        shift
    fi

    # Parse second positional argument (type)
    if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
        type="$1"
        shift
    fi

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -f|--file)
                import_file="$2"
                shift 2
                ;;
            --open)
                open_editor=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "Error: Fuzzer name required" >&2
        usage
        exit 1
    fi

    # Create output directory
    mkdir -p "$output_dir"

    # Generate output filename
    local output_file="$output_dir/${name}.js"

    # Check if file exists
    if [ -f "$output_file" ]; then
        echo -e "${YELLOW}Warning: File already exists: $output_file${NC}"
        read -p "Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    fi

    # Generate fuzzer
    log_info "Creating $type fuzzer: $output_file"

    local content=$(generate_fuzzer "$name" "$type" "$import_file")
    if [ $? -ne 0 ]; then
        exit 1
    fi

    echo "$content" > "$output_file"

    log_success "Fuzzer created: $output_file"

    # Show next steps
    cat << EOF

Next steps:
1. Edit the fuzzer: vim $output_file
2. Add your code to test
3. Run fuzzing: $PROJECT_ROOT/scripts/fuzz.sh $output_file -t 60

EOF

    # Open in editor if requested
    if [ "$open_editor" = true ]; then
        if command -v ${EDITOR:-vim} &> /dev/null; then
            ${EDITOR:-vim} "$output_file"
        else
            log_info "Editor not found, open manually: $output_file"
        fi
    fi
}

main "$@"
