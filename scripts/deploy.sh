#!/bin/bash
# libfuzzer-js Deployment Script
# This script sets up everything you need to start fuzzing JavaScript code

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FUZZER_DIR="${FUZZER_DIR:-$HOME/fuzzing}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print banner
print_banner() {
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║          libfuzzer-js Deployment Script                   ║
║  JavaScript Fuzzing with LibFuzzer and QuickJS            ║
╚═══════════════════════════════════════════════════════════╝
EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_deps=()

    # Check for required commands
    if ! command -v clang++ &> /dev/null; then
        missing_deps+=("clang++")
    fi

    if ! command -v svn &> /dev/null; then
        missing_deps+=("subversion")
    fi

    if ! command -v make &> /dev/null; then
        missing_deps+=("make")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install them first. On Ubuntu/Debian:"
        echo "    sudo apt-get install clang subversion build-essential"
        exit 1
    fi

    log_success "All prerequisites met"
}

# Setup libFuzzer
setup_libfuzzer() {
    log_info "Setting up libFuzzer..."

    if [ -n "$LIBFUZZER_A_PATH" ] && [ -f "$LIBFUZZER_A_PATH" ]; then
        log_success "libFuzzer already configured at: $LIBFUZZER_A_PATH"
        return 0
    fi

    local fuzzer_build_dir="$FUZZER_DIR/libfuzzer-build"
    mkdir -p "$fuzzer_build_dir"
    cd "$fuzzer_build_dir"

    if [ ! -d "Fuzzer" ]; then
        log_info "Downloading libFuzzer from LLVM repository..."
        svn co https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer Fuzzer
    else
        log_info "libFuzzer already downloaded, updating..."
        cd Fuzzer && svn update && cd ..
    fi

    cd Fuzzer
    log_info "Building libFuzzer..."
    ./build.sh

    export LIBFUZZER_A_PATH="$(pwd)/libFuzzer.a"

    # Save to environment file
    echo "export LIBFUZZER_A_PATH=\"$LIBFUZZER_A_PATH\"" > "$FUZZER_DIR/fuzzer-env.sh"

    log_success "libFuzzer built at: $LIBFUZZER_A_PATH"
    log_info "Run 'source $FUZZER_DIR/fuzzer-env.sh' to set the environment variable"
}

# Build libfuzzer-js
build_fuzzer() {
    log_info "Building libfuzzer-js..."

    cd "$PROJECT_ROOT"

    # Check if QuickJS needs to be built
    if [ ! -f "quickjs/libquickjs.a" ]; then
        log_info "Building QuickJS..."
        cd quickjs && make libquickjs.a && cd ..
    fi

    # Build the fuzzer
    make

    log_success "libfuzzer-js built successfully: $PROJECT_ROOT/jsfuzzer"
}

# Setup fuzzing workspace
setup_workspace() {
    log_info "Setting up fuzzing workspace at: $FUZZER_DIR"

    mkdir -p "$FUZZER_DIR"/{corpus,crashes,fuzzers}

    # Copy example fuzzers
    if [ -d "$PROJECT_ROOT/examples" ]; then
        cp -r "$PROJECT_ROOT/examples"/* "$FUZZER_DIR/fuzzers/" 2>/dev/null || true
    fi

    # Create workspace info file
    cat > "$FUZZER_DIR/README.txt" << EOF
Fuzzing Workspace
=================

This directory contains your fuzzing workspace:

- corpus/     : Corpus directories for your fuzzing campaigns
- crashes/    : Crash files and artifacts
- fuzzers/    : Your fuzzer JavaScript files

Fuzzer binary: $PROJECT_ROOT/jsfuzzer

Quick Start:
-----------
1. Create a fuzzer script in fuzzers/ directory
2. Run: $PROJECT_ROOT/scripts/fuzz.sh fuzzers/your_fuzzer.js
3. Check crashes/ for any findings

Examples:
--------
Run JSON fuzzer:
  $PROJECT_ROOT/scripts/fuzz.sh fuzzers/json_fuzzer.js -t 60

Run with 4 workers:
  $PROJECT_ROOT/scripts/fuzz.sh fuzzers/regex_fuzzer.js -w 4 -t 300

For more help:
  $PROJECT_ROOT/scripts/fuzz.sh --help
EOF

    log_success "Workspace created at: $FUZZER_DIR"
}

# Setup MCP server (optional)
setup_mcp() {
    log_info "Setting up MCP server for Claude Code..."

    if ! command -v node &> /dev/null; then
        log_warning "Node.js not found. Skipping MCP server setup."
        log_info "Install Node.js 18+ to use the MCP server with Claude Code"
        return 0
    fi

    cd "$PROJECT_ROOT/mcp-server"

    if [ ! -d "node_modules" ]; then
        log_info "Installing MCP server dependencies..."
        npm install
    fi

    log_info "Building MCP server..."
    npm run build

    log_success "MCP server built successfully"
    log_info "See MCP_SETUP.md for configuration instructions"
}

# Create convenience scripts
create_scripts() {
    log_info "Creating convenience scripts..."

    # Make all scripts in scripts/ executable
    chmod +x "$PROJECT_ROOT"/scripts/*.sh 2>/dev/null || true

    log_success "Scripts ready to use"
}

# Print final instructions
print_instructions() {
    cat << EOF

╔═══════════════════════════════════════════════════════════╗
║                  Setup Complete!                          ║
╚═══════════════════════════════════════════════════════════╝

Environment Setup:
------------------
Add this to your ~/.bashrc or ~/.zshrc:
  source $FUZZER_DIR/fuzzer-env.sh

Or run it now:
  source $FUZZER_DIR/fuzzer-env.sh

Quick Start:
-----------
1. Create a fuzzer (see examples in $FUZZER_DIR/fuzzers/)

2. Run fuzzing campaign:
   $PROJECT_ROOT/scripts/fuzz.sh $FUZZER_DIR/fuzzers/json_fuzzer.js -t 60

3. Create custom fuzzer:
   $PROJECT_ROOT/scripts/create-fuzzer.sh my_api_fuzzer json

4. Analyze crashes:
   $PROJECT_ROOT/scripts/analyze-crash.sh <crash-file>

Available Scripts:
-----------------
  fuzz.sh           - Run fuzzing campaigns
  create-fuzzer.sh  - Generate fuzzer templates
  analyze-crash.sh  - Analyze crash files
  minimize-crash.sh - Minimize crash inputs
  corpus-stats.sh   - Show corpus statistics

Documentation:
-------------
  Main README:     $PROJECT_ROOT/README.md
  MCP Setup:       $PROJECT_ROOT/MCP_SETUP.md
  MCP Tools:       $PROJECT_ROOT/mcp-server/README.md
  Workspace:       $FUZZER_DIR/README.txt

Examples:
--------
  $FUZZER_DIR/fuzzers/json_fuzzer.js
  $FUZZER_DIR/fuzzers/regex_fuzzer.js
  $FUZZER_DIR/fuzzers/arithmetic_fuzzer.js

Happy Fuzzing! 🐛🔍

EOF
}

# Main deployment flow
main() {
    print_banner

    # Parse arguments
    SKIP_LIBFUZZER=0
    SKIP_MCP=0

    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-libfuzzer)
                SKIP_LIBFUZZER=1
                shift
                ;;
            --skip-mcp)
                SKIP_MCP=1
                shift
                ;;
            --fuzzer-dir)
                FUZZER_DIR="$2"
                shift 2
                ;;
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --skip-libfuzzer    Skip libFuzzer download and build
  --skip-mcp          Skip MCP server setup
  --fuzzer-dir DIR    Set fuzzing workspace directory (default: ~/fuzzing)
  --help              Show this help message

Environment Variables:
  LIBFUZZER_A_PATH    Path to existing libFuzzer.a file
  FUZZER_DIR          Fuzzing workspace directory

EOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    log_info "Starting deployment..."
    log_info "Fuzzing workspace: $FUZZER_DIR"
    echo

    check_prerequisites

    if [ $SKIP_LIBFUZZER -eq 0 ]; then
        setup_libfuzzer
        # Source the environment file for this session
        source "$FUZZER_DIR/fuzzer-env.sh"
    fi

    build_fuzzer
    setup_workspace
    create_scripts

    if [ $SKIP_MCP -eq 0 ]; then
        setup_mcp
    fi

    print_instructions
}

# Run main function
main "$@"
