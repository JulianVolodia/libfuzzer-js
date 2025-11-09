#!/bin/bash
# libfuzzer-js Setup Script for macOS
# This script sets up the fuzzing environment for JavaScript engine vulnerability research

set -e  # Exit on error

echo "=================================================="
echo "libfuzzer-js macOS Setup Script"
echo "JavaScript Engine Fuzzing for Security Research"
echo "=================================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script is for macOS only${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking dependencies...${NC}"

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo -e "${RED}Homebrew not found. Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check for clang
if ! command -v clang &> /dev/null; then
    echo -e "${YELLOW}Installing Xcode Command Line Tools...${NC}"
    xcode-select --install
    echo "Please wait for Xcode tools to install, then run this script again."
    exit 1
fi

# Check for svn (needed to download libFuzzer)
if ! command -v svn &> /dev/null; then
    echo -e "${YELLOW}Installing Subversion...${NC}"
    brew install svn
fi

echo -e "${GREEN}✓ All dependencies satisfied${NC}"
echo ""

# Check clang version
echo -e "${YELLOW}Clang version:${NC}"
clang --version | head -1
echo ""

echo -e "${YELLOW}Step 2: Downloading and building libFuzzer...${NC}"

# Create build directory
BUILD_DIR="$HOME/fuzzer_build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [ ! -d "Fuzzer" ]; then
    echo "Downloading libFuzzer from LLVM repository..."
    svn co https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer Fuzzer
else
    echo "libFuzzer already downloaded, updating..."
    cd Fuzzer
    svn update
    cd ..
fi

cd Fuzzer

# Build libFuzzer
if [ ! -f "libFuzzer.a" ]; then
    echo "Building libFuzzer..."
    ./build.sh
else
    echo -e "${GREEN}libFuzzer already built${NC}"
fi

export LIBFUZZER_A_PATH="$(pwd)/libFuzzer.a"
echo -e "${GREEN}✓ libFuzzer built at: $LIBFUZZER_A_PATH${NC}"
echo ""

# Return to project directory
cd "$OLDPWD"

echo -e "${YELLOW}Step 3: Building libfuzzer-js...${NC}"

# Set environment variable for make
export LIBFUZZER_A_PATH

# Build the project
make clean 2>/dev/null || true
make

echo -e "${GREEN}✓ Build complete!${NC}"
echo ""

echo -e "${YELLOW}Step 4: Creating example fuzzing target...${NC}"

# Create a simple test JavaScript file
cat > example_fuzz.js << 'EOF'
// Example fuzzing target for JavaScript engine
// This code will be executed with FuzzerInput as random data

function processInput(input) {
    try {
        // Test various JavaScript features

        // 1. String operations
        let str = String.fromCharCode.apply(null, input);

        // 2. Array operations
        let arr = Array.from(input);
        arr.sort();
        arr.reverse();

        // 3. Object operations
        let obj = {};
        for (let i = 0; i < Math.min(input.length, 100); i++) {
            obj['key' + i] = input[i];
        }

        // 4. Regular expressions (common vulnerability source)
        if (str.length > 0 && str.length < 1000) {
            try {
                let pattern = str.slice(0, 20);
                let re = new RegExp(pattern);
                re.test("test string");
            } catch(e) {}
        }

        // 5. JSON parsing (common vulnerability source)
        if (input.length > 2 && input.length < 10000) {
            try {
                JSON.parse(str);
            } catch(e) {}
        }

        // 6. Arithmetic operations
        let sum = 0;
        for (let i = 0; i < Math.min(input.length, 1000); i++) {
            sum += input[i];
        }

        // 7. Type conversions
        let num = Number(str);
        let bool = Boolean(sum);

        return sum;

    } catch(e) {
        // Catch exceptions to continue fuzzing
        return -1;
    }
}

// Main fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    processInput(FuzzerInput);
}
EOF

echo -e "${GREEN}✓ Created example_fuzz.js${NC}"
echo ""

echo -e "${GREEN}=================================================="
echo "Setup Complete!"
echo "=================================================="
echo ""
echo "To run the fuzzer:"
echo -e "${YELLOW}./jsfuzzer --js=example_fuzz.js${NC}"
echo ""
echo "To create your own fuzzing targets:"
echo "1. Create a .js file that uses the FuzzerInput variable"
echo "2. Run: ./jsfuzzer --js=your_target.js"
echo ""
echo "The fuzzer will:"
echo "- Generate random inputs"
echo "- Execute your JavaScript with each input"
echo "- Detect crashes, hangs, and memory errors"
echo "- Save crash-inducing inputs to disk"
echo ""
echo "For responsible vulnerability disclosure, see:"
echo "- Apple: https://support.apple.com/en-us/HT201220"
echo "- Microsoft: https://www.microsoft.com/en-us/msrc/bounty"
echo "- Google: https://bughunters.google.com/"
echo ""
echo -e "${RED}IMPORTANT: Only use this for authorized security research!${NC}"
echo "=================================================="
