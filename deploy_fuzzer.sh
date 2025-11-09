#!/bin/bash
# Universal Fuzzing Deployment Script
# Helps you integrate fuzzing into your own codebase

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUZZER_BIN="$SCRIPT_DIR/jsfuzzer"
FUZZER_PROJECT_DIR=""
FUZZ_OUTPUT_DIR=""

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                        ║${NC}"
echo -e "${CYAN}║        Universal JavaScript Fuzzing Deployment        ║${NC}"
echo -e "${CYAN}║            Fuzz Your Own Code in Minutes!             ║${NC}"
echo -e "${CYAN}║                                                        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print section header
print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Function to ask yes/no question
ask_yes_no() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Step 1: Check if fuzzer is built
print_section "Step 1: Checking Fuzzer Installation"

if [ ! -f "$FUZZER_BIN" ]; then
    echo -e "${YELLOW}Fuzzer not found at $FUZZER_BIN${NC}"
    echo ""

    if ask_yes_no "Would you like to build the fuzzer now?"; then
        echo -e "${GREEN}Building fuzzer...${NC}"

        # Check for libFuzzer
        if [ -z "$LIBFUZZER_A_PATH" ]; then
            echo -e "${YELLOW}LIBFUZZER_A_PATH not set. Building libFuzzer...${NC}"

            BUILD_DIR="$HOME/fuzzer_build"
            mkdir -p "$BUILD_DIR"
            cd "$BUILD_DIR"

            if [ ! -d "Fuzzer" ]; then
                echo "Downloading libFuzzer..."
                svn co https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer Fuzzer
            fi

            cd Fuzzer
            if [ ! -f "libFuzzer.a" ]; then
                ./build.sh
            fi

            export LIBFUZZER_A_PATH="$(pwd)/libFuzzer.a"
            echo -e "${GREEN}✓ libFuzzer built at: $LIBFUZZER_A_PATH${NC}"

            cd "$SCRIPT_DIR"
        fi

        # Build the fuzzer
        make clean 2>/dev/null || true
        make

        echo -e "${GREEN}✓ Fuzzer built successfully!${NC}"
    else
        echo -e "${RED}Please build the fuzzer first using 'make' or run setup script${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Fuzzer found at: $FUZZER_BIN${NC}"
fi

# Step 2: Interactive project selection
print_section "Step 2: Select Your Project"

echo "What would you like to fuzz?"
echo ""
echo "  1) My own JavaScript files (I'll provide paths)"
echo "  2) A directory containing JavaScript files"
echo "  3) Create a new fuzzing project from scratch"
echo "  4) Run example fuzzers (tutorial mode)"
echo ""

read -p "Select option (1-4): " project_option

case $project_option in
    1)
        # User provides specific files
        echo ""
        echo -e "${YELLOW}You can provide one or more JavaScript files to fuzz${NC}"
        echo "These files will be concatenated and fuzzed together"
        echo ""

        JS_FILES=()
        while true; do
            read -p "Enter JavaScript file path (or press Enter to finish): " js_file
            if [ -z "$js_file" ]; then
                break
            fi

            if [ -f "$js_file" ]; then
                JS_FILES+=("$js_file")
                echo -e "${GREEN}✓ Added: $js_file${NC}"
            else
                echo -e "${RED}✗ File not found: $js_file${NC}"
            fi
        done

        if [ ${#JS_FILES[@]} -eq 0 ]; then
            echo -e "${RED}No valid files provided. Exiting.${NC}"
            exit 1
        fi

        FUZZER_PROJECT_DIR="$(dirname "${JS_FILES[0]}")"
        ;;

    2)
        # User provides directory
        echo ""
        read -p "Enter directory path containing JavaScript files: " js_dir

        if [ ! -d "$js_dir" ]; then
            echo -e "${RED}Directory not found: $js_dir${NC}"
            exit 1
        fi

        FUZZER_PROJECT_DIR="$(cd "$js_dir" && pwd)"

        # Find all .js files
        JS_FILES=($(find "$FUZZER_PROJECT_DIR" -name "*.js" -type f))

        echo ""
        echo -e "${GREEN}Found ${#JS_FILES[@]} JavaScript files:${NC}"
        for file in "${JS_FILES[@]}"; do
            echo "  - $(basename $file)"
        done
        echo ""
        ;;

    3)
        # Create new project
        echo ""
        read -p "Enter name for new fuzzing project: " project_name

        FUZZER_PROJECT_DIR="$HOME/fuzzing_projects/$project_name"
        mkdir -p "$FUZZER_PROJECT_DIR"

        echo -e "${GREEN}✓ Created project directory: $FUZZER_PROJECT_DIR${NC}"

        # Create example files
        cat > "$FUZZER_PROJECT_DIR/my_code.js" << 'EOF'
// Your code to fuzz goes here

function parseInput(input) {
    // Example function that might have bugs
    if (typeof input !== 'string') {
        throw new Error('Input must be string');
    }

    // Parse JSON
    const data = JSON.parse(input);

    // Process data
    return processData(data);
}

function processData(data) {
    // Your complex logic here
    if (data.value) {
        return data.value * 2;
    }
    return 0;
}
EOF

        echo -e "${GREEN}✓ Created example code file: my_code.js${NC}"

        JS_FILES=("$FUZZER_PROJECT_DIR/my_code.js")
        ;;

    4)
        # Tutorial mode
        echo ""
        echo -e "${CYAN}Tutorial Mode: Running Example Fuzzers${NC}"
        echo ""

        if [ -d "$SCRIPT_DIR/fuzz_targets" ]; then
            echo "Available example fuzzers:"
            echo "  1) regexp_fuzzer.js - Fuzz regular expressions"
            echo "  2) json_fuzzer.js - Fuzz JSON parsing"
            echo "  3) array_fuzzer.js - Fuzz array operations"
            echo "  4) string_fuzzer.js - Fuzz string operations"
            echo "  5) comprehensive_fuzzer.js - Fuzz all features"
            echo ""

            read -p "Select fuzzer (1-5) or 'a' for all: " tutorial_option

            case $tutorial_option in
                1) TARGET="regexp_fuzzer.js" ;;
                2) TARGET="json_fuzzer.js" ;;
                3) TARGET="array_fuzzer.js" ;;
                4) TARGET="string_fuzzer.js" ;;
                5) TARGET="comprehensive_fuzzer.js" ;;
                a|A)
                    echo ""
                    echo -e "${GREEN}Running all example fuzzers for 60 seconds each...${NC}"

                    for target in regexp_fuzzer.js json_fuzzer.js array_fuzzer.js string_fuzzer.js; do
                        echo ""
                        echo -e "${YELLOW}Fuzzing: $target${NC}"
                        timeout 60 "$FUZZER_BIN" --js="$SCRIPT_DIR/fuzz_targets/$target" \
                            -max_len=1000 -timeout=10 || true
                    done

                    echo ""
                    echo -e "${GREEN}Tutorial complete!${NC}"
                    echo ""

                    if ls crash-* 1> /dev/null 2>&1; then
                        echo -e "${YELLOW}Crashes found! See crash-* files${NC}"
                    else
                        echo "No crashes found (this is good!)"
                    fi

                    exit 0
                    ;;
                *)
                    echo -e "${RED}Invalid option${NC}"
                    exit 1
                    ;;
            esac

            echo ""
            echo -e "${YELLOW}Running $TARGET for 60 seconds...${NC}"
            echo -e "${CYAN}Press Ctrl+C to stop early${NC}"
            echo ""

            timeout 60 "$FUZZER_BIN" --js="$SCRIPT_DIR/fuzz_targets/$TARGET" \
                -max_len=1000 -timeout=10 || true

            echo ""
            echo -e "${GREEN}Fuzzing complete!${NC}"

            if ls crash-* 1> /dev/null 2>&1; then
                echo -e "${YELLOW}Crashes found! See crash-* files${NC}"
                echo "Reproduce with: $FUZZER_BIN --js=$SCRIPT_DIR/fuzz_targets/$TARGET crash-FILE"
            else
                echo "No crashes found (this is good!)"
            fi

            exit 0
        else
            echo -e "${RED}Example fuzzers not found. Please run from repository root.${NC}"
            exit 1
        fi
        ;;

    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# Step 3: Create fuzzing harness
print_section "Step 3: Creating Fuzzing Harness"

echo "I need to create a fuzzing harness for your code."
echo "This harness tells the fuzzer how to test your code."
echo ""
echo "What type of input does your code expect?"
echo ""
echo "  1) String input (text, JSON, etc.)"
echo "  2) Binary data (bytes, buffers)"
echo "  3) Structured data (objects with specific fields)"
echo "  4) I'll write my own harness"
echo ""

read -p "Select input type (1-4): " input_type

# Create output directory
FUZZ_OUTPUT_DIR="$FUZZER_PROJECT_DIR/fuzzing_output"
mkdir -p "$FUZZ_OUTPUT_DIR/corpus"
mkdir -p "$FUZZ_OUTPUT_DIR/crashes"

HARNESS_FILE="$FUZZ_OUTPUT_DIR/fuzz_harness.js"

case $input_type in
    1)
        # String input harness
        cat > "$HARNESS_FILE" << 'EOF'
// Fuzzing Harness - String Input
// Generated by deploy_fuzzer.sh

// This harness converts fuzzer bytes to strings and feeds them to your code

if (typeof FuzzerInput !== 'undefined') {
    try {
        // Convert fuzzer bytes to string
        const inputString = String.fromCharCode.apply(null, FuzzerInput);

        // TODO: Call your function here
        // Example: myFunction(inputString);

        // If you have multiple functions, test them all:
        // parseInput(inputString);
        // validateInput(inputString);
        // processInput(inputString);

    } catch (e) {
        // Expected errors (invalid input, validation failures)
        // Memory corruption will still be caught by sanitizers
    }
}
EOF
        echo -e "${GREEN}✓ Created string input harness${NC}"
        ;;

    2)
        # Binary data harness
        cat > "$HARNESS_FILE" << 'EOF'
// Fuzzing Harness - Binary Data
// Generated by deploy_fuzzer.sh

if (typeof FuzzerInput !== 'undefined') {
    try {
        // FuzzerInput is already a Uint8Array
        // Use it directly for binary operations

        // TODO: Call your function here
        // Example: processBinaryData(FuzzerInput);

        // You can also create typed arrays:
        // const int32View = new Int32Array(FuzzerInput.buffer);
        // const float64View = new Float64Array(FuzzerInput.buffer);

    } catch (e) {
        // Expected errors
    }
}
EOF
        echo -e "${GREEN}✓ Created binary data harness${NC}"
        ;;

    3)
        # Structured data harness
        cat > "$HARNESS_FILE" << 'EOF'
// Fuzzing Harness - Structured Data
// Generated by deploy_fuzzer.sh

function extractStructuredData(bytes) {
    if (bytes.length < 20) return null;

    // Extract fields from fuzzer input
    return {
        // Customize these fields for your needs
        id: (bytes[0] << 8) | bytes[1],
        type: bytes[2] % 4,
        flags: bytes[3],
        name: String.fromCharCode.apply(null, bytes.slice(4, 20)),
        value: (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23],
        data: Array.from(bytes.slice(24))
    };
}

if (typeof FuzzerInput !== 'undefined') {
    try {
        const structured = extractStructuredData(FuzzerInput);

        if (structured) {
            // TODO: Call your function with structured data
            // Example: processMessage(structured);
            // Example: validateObject(structured);
        }

    } catch (e) {
        // Expected errors
    }
}
EOF
        echo -e "${GREEN}✓ Created structured data harness${NC}"
        ;;

    4)
        # User will write their own
        cat > "$HARNESS_FILE" << 'EOF'
// Fuzzing Harness - Custom
// Write your custom fuzzing logic here

if (typeof FuzzerInput !== 'undefined') {
    try {
        // Your custom fuzzing code
        // FuzzerInput is a Uint8Array containing random bytes

        // Example: Convert to string
        // const str = String.fromCharCode.apply(null, FuzzerInput);

        // Example: Extract parameters
        // const param1 = FuzzerInput[0];
        // const param2 = (FuzzerInput[1] << 8) | FuzzerInput[2];

        // TODO: Add your fuzzing logic here

    } catch (e) {
        // Handle expected errors
    }
}
EOF
        echo -e "${GREEN}✓ Created custom harness template${NC}"
        echo -e "${YELLOW}Please edit $HARNESS_FILE to add your fuzzing logic${NC}"
        ;;
esac

# Step 4: Combine files
print_section "Step 4: Combining Your Code with Harness"

COMBINED_FILE="$FUZZ_OUTPUT_DIR/combined_fuzz_target.js"

echo "// Combined Fuzzing Target" > "$COMBINED_FILE"
echo "// Auto-generated by deploy_fuzzer.sh" >> "$COMBINED_FILE"
echo "// $(date)" >> "$COMBINED_FILE"
echo "" >> "$COMBINED_FILE"

# Add user's JavaScript files
for js_file in "${JS_FILES[@]}"; do
    echo "// ============================================" >> "$COMBINED_FILE"
    echo "// From: $js_file" >> "$COMBINED_FILE"
    echo "// ============================================" >> "$COMBINED_FILE"
    cat "$js_file" >> "$COMBINED_FILE"
    echo "" >> "$COMBINED_FILE"
    echo -e "${GREEN}✓ Added: $(basename $js_file)${NC}"
done

# Add harness
echo "// ============================================" >> "$COMBINED_FILE"
echo "// Fuzzing Harness" >> "$COMBINED_FILE"
echo "// ============================================" >> "$COMBINED_FILE"
cat "$HARNESS_FILE" >> "$COMBINED_FILE"

echo -e "${GREEN}✓ Created combined target: $COMBINED_FILE${NC}"

# Step 5: Create run script
print_section "Step 5: Creating Run Scripts"

RUN_SCRIPT="$FUZZ_OUTPUT_DIR/run_fuzzing.sh"

cat > "$RUN_SCRIPT" << EOF
#!/bin/bash
# Fuzzing Run Script
# Auto-generated by deploy_fuzzer.sh

set -e

FUZZER="$FUZZER_BIN"
TARGET="$COMBINED_FILE"
CORPUS="$FUZZ_OUTPUT_DIR/corpus"
CRASHES="$FUZZ_OUTPUT_DIR/crashes"

echo "Starting fuzzer..."
echo "Target: \$TARGET"
echo "Corpus: \$CORPUS"
echo ""

# Run fuzzer with good default options
"\$FUZZER" --js="\$TARGET" \\
    \$CORPUS \\
    -max_len=\${MAX_LEN:-10000} \\
    -timeout=\${TIMEOUT:-10} \\
    -max_total_time=\${FUZZ_TIME:-0} \\
    -artifact_prefix="\$CRASHES/" \\
    "\$@"

echo ""
echo "Fuzzing complete!"

# Check for crashes
if ls "\$CRASHES"/crash-* 1> /dev/null 2>&1; then
    echo ""
    echo "WARNING: Crashes found in \$CRASHES/"
    echo ""
    echo "To reproduce a crash:"
    echo "  \$FUZZER --js=\$TARGET \$CRASHES/crash-FILE"
    echo ""
    echo "To minimize a crash:"
    echo "  \$FUZZER --js=\$TARGET -minimize_crash=1 \$CRASHES/crash-FILE"
    exit 1
else
    echo "No crashes found!"
    exit 0
fi
EOF

chmod +x "$RUN_SCRIPT"
echo -e "${GREEN}✓ Created run script: $RUN_SCRIPT${NC}"

# Create quick test script
QUICK_TEST_SCRIPT="$FUZZ_OUTPUT_DIR/quick_test.sh"

cat > "$QUICK_TEST_SCRIPT" << EOF
#!/bin/bash
# Quick Fuzzing Test (60 seconds)
# Auto-generated by deploy_fuzzer.sh

export FUZZ_TIME=60
export MAX_LEN=1000
export TIMEOUT=10

echo "Running quick fuzzing test (60 seconds)..."
bash "$RUN_SCRIPT"
EOF

chmod +x "$QUICK_TEST_SCRIPT"
echo -e "${GREEN}✓ Created quick test script: $QUICK_TEST_SCRIPT${NC}"

# Create continuous fuzzing script
CONTINUOUS_SCRIPT="$FUZZ_OUTPUT_DIR/continuous_fuzzing.sh"

cat > "$CONTINUOUS_SCRIPT" << 'EOF'
#!/bin/bash
# Continuous Fuzzing Script
# Runs fuzzer indefinitely with periodic corpus minimization

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_SCRIPT="$SCRIPT_DIR/run_fuzzing.sh"
CORPUS="$SCRIPT_DIR/corpus"
CORPUS_MIN="$SCRIPT_DIR/corpus_minimized"

# Fuzzing duration between minimizations (seconds)
CYCLE_TIME=${1:-3600}  # Default: 1 hour

echo "Starting continuous fuzzing..."
echo "Cycle time: $CYCLE_TIME seconds"
echo ""

CYCLE=1
while true; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Fuzzing Cycle $CYCLE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Run fuzzing for specified time
    export FUZZ_TIME=$CYCLE_TIME
    bash "$RUN_SCRIPT" || true

    # Minimize corpus
    echo ""
    echo "Minimizing corpus..."
    mkdir -p "$CORPUS_MIN"

    # Note: corpus minimization requires fuzzer support
    # Uncomment if your fuzzer supports it:
    # "$FUZZER" --js="$TARGET" -merge=1 "$CORPUS_MIN" "$CORPUS"
    # rm -rf "$CORPUS"
    # mv "$CORPUS_MIN" "$CORPUS"

    CYCLE=$((CYCLE + 1))
    echo ""
    echo "Completed cycle $((CYCLE - 1)). Starting next cycle..."
    echo ""

    sleep 5
done
EOF

chmod +x "$CONTINUOUS_SCRIPT"
echo -e "${GREEN}✓ Created continuous fuzzing script: $CONTINUOUS_SCRIPT${NC}"

# Step 6: Create seed corpus
print_section "Step 6: Creating Seed Corpus (Optional)"

if ask_yes_no "Would you like to create seed corpus files?"; then
    echo ""
    echo "Seed files help the fuzzer find bugs faster by providing example inputs."
    echo "You can add them now or later."
    echo ""

    SEED_NUM=1
    while ask_yes_no "Add seed input #$SEED_NUM?"; do
        echo ""
        echo "Choose seed input method:"
        echo "  1) Type text directly"
        echo "  2) Copy from existing file"
        echo ""

        read -p "Select (1-2): " seed_method

        case $seed_method in
            1)
                echo "Enter seed input (press Ctrl+D when done):"
                cat > "$FUZZ_OUTPUT_DIR/corpus/seed_$SEED_NUM.txt"
                echo -e "${GREEN}✓ Added seed #$SEED_NUM${NC}"
                ;;
            2)
                read -p "Enter path to seed file: " seed_file
                if [ -f "$seed_file" ]; then
                    cp "$seed_file" "$FUZZ_OUTPUT_DIR/corpus/seed_$SEED_NUM"
                    echo -e "${GREEN}✓ Added seed #$SEED_NUM from $seed_file${NC}"
                else
                    echo -e "${RED}File not found${NC}"
                    continue
                fi
                ;;
        esac

        SEED_NUM=$((SEED_NUM + 1))
        echo ""
    done
fi

# Step 7: Summary and next steps
print_section "Setup Complete!"

echo -e "${GREEN}Your fuzzing environment is ready!${NC}"
echo ""
echo -e "${CYAN}Project Directory:${NC} $FUZZER_PROJECT_DIR"
echo -e "${CYAN}Fuzzing Output:${NC} $FUZZ_OUTPUT_DIR"
echo -e "${CYAN}Combined Target:${NC} $COMBINED_FILE"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Review and customize the harness if needed:"
echo -e "   ${CYAN}$HARNESS_FILE${NC}"
echo ""
echo "2. Run a quick test (60 seconds):"
echo -e "   ${CYAN}bash $QUICK_TEST_SCRIPT${NC}"
echo ""
echo "3. Run full fuzzing campaign:"
echo -e "   ${CYAN}bash $RUN_SCRIPT${NC}"
echo ""
echo "4. Run continuous fuzzing (indefinitely):"
echo -e "   ${CYAN}bash $CONTINUOUS_SCRIPT${NC}"
echo ""
echo "5. Customize fuzzing parameters:"
echo "   - MAX_LEN=5000 - Maximum input length"
echo "   - TIMEOUT=25 - Timeout in seconds"
echo "   - FUZZ_TIME=3600 - Total fuzzing time"
echo ""
echo "   Example:"
echo -e "   ${CYAN}MAX_LEN=2000 TIMEOUT=5 bash $RUN_SCRIPT${NC}"
echo ""
echo -e "${YELLOW}Tips:${NC}"
echo "  • Start with a quick test to verify everything works"
echo "  • Review crashes in: $FUZZ_OUTPUT_DIR/crashes/"
echo "  • Add seed inputs to: $FUZZ_OUTPUT_DIR/corpus/"
echo "  • Run overnight for best results"
echo ""

if ask_yes_no "Would you like to run a quick test now?"; then
    echo ""
    echo -e "${GREEN}Running quick fuzzing test...${NC}"
    echo ""

    bash "$QUICK_TEST_SCRIPT"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Fuzzing deployment complete! Happy bug hunting!  ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
