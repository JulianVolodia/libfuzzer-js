#!/bin/bash
# Easy fuzzing campaign runner for libfuzzer-js

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FUZZER_BIN="$PROJECT_ROOT/jsfuzzer"

# Default values
TIME_LIMIT=0
MAX_LEN=4096
WORKERS=1
JOBS=0
CORPUS_DIR=""
ARTIFACT_PREFIX=""
DICT_FILE=""
EXTRA_ARGS=()
JS_FILE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $(basename "$0") <javascript-file> [OPTIONS]

Run a fuzzing campaign on a JavaScript file.

Arguments:
  javascript-file     Path to the JavaScript fuzzer file (required)

Options:
  -t, --time SECONDS  Maximum time to fuzz (default: unlimited)
  -w, --workers NUM   Number of parallel workers (default: 1)
  -j, --jobs NUM      Number of jobs (default: 0)
  -l, --len BYTES     Maximum input length (default: 4096)
  -c, --corpus DIR    Corpus directory (default: auto-generated)
  -d, --dict FILE     Dictionary file for structured fuzzing
  -a, --artifact DIR  Artifact prefix/directory for crashes
  -r, --resume        Resume previous fuzzing campaign
  -m, --minimize      Run in minimization mode
  -M, --merge         Merge corpora
  --detect-leaks      Enable leak detection (slower)
  --asan              Enable AddressSanitizer features
  -v, --verbose       Verbose output
  -h, --help          Show this help message

Examples:
  # Fuzz for 60 seconds
  $(basename "$0") my_fuzzer.js -t 60

  # Fuzz with 4 parallel workers for 5 minutes
  $(basename "$0") my_fuzzer.js -w 4 -t 300

  # Fuzz with custom corpus and dictionary
  $(basename "$0") my_fuzzer.js -c ./my_corpus -d ./my.dict

  # Resume previous campaign
  $(basename "$0") my_fuzzer.js -r

  # Minimize a crash input
  $(basename "$0") my_fuzzer.js -m crash-xyz

Environment Variables:
  LIBFUZZER_A_PATH   Path to libFuzzer.a (required for building)

EOF
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

# Check if fuzzer is built
check_fuzzer() {
    if [ ! -f "$FUZZER_BIN" ]; then
        log_error "Fuzzer binary not found: $FUZZER_BIN"
        log_info "Run: $PROJECT_ROOT/scripts/deploy.sh"
        exit 1
    fi
}

# Parse arguments
parse_args() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    # First argument is the JS file
    if [[ "$1" != -* ]]; then
        JS_FILE="$1"
        shift
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--time)
                TIME_LIMIT="$2"
                shift 2
                ;;
            -w|--workers)
                WORKERS="$2"
                shift 2
                ;;
            -j|--jobs)
                JOBS="$2"
                shift 2
                ;;
            -l|--len)
                MAX_LEN="$2"
                shift 2
                ;;
            -c|--corpus)
                CORPUS_DIR="$2"
                shift 2
                ;;
            -d|--dict)
                DICT_FILE="$2"
                shift 2
                ;;
            -a|--artifact)
                ARTIFACT_PREFIX="$2"
                shift 2
                ;;
            -r|--resume)
                # Corpus dir should already exist
                shift
                ;;
            -m|--minimize)
                EXTRA_ARGS+=("-minimize_crash=1" "-runs=10000")
                if [ -n "$2" ] && [[ "$2" != -* ]]; then
                    EXTRA_ARGS+=("$2")
                    shift
                fi
                shift
                ;;
            -M|--merge)
                EXTRA_ARGS+=("-merge=1")
                shift
                ;;
            --detect-leaks)
                EXTRA_ARGS+=("-detect_leaks=1")
                shift
                ;;
            --asan)
                EXTRA_ARGS+=("-detect_odr_violation=0")
                shift
                ;;
            -v|--verbose)
                EXTRA_ARGS+=("-verbosity=1")
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [ -z "$JS_FILE" ]; then
        log_error "JavaScript file required"
        usage
        exit 1
    fi

    if [ ! -f "$JS_FILE" ]; then
        log_error "JavaScript file not found: $JS_FILE"
        exit 1
    fi
}

# Setup corpus directory
setup_corpus() {
    if [ -z "$CORPUS_DIR" ]; then
        # Auto-generate corpus directory name from JS file
        local js_basename=$(basename "$JS_FILE" .js)
        CORPUS_DIR="corpus_${js_basename}"
    fi

    mkdir -p "$CORPUS_DIR"
    log_info "Corpus directory: $CORPUS_DIR"
}

# Setup artifact prefix
setup_artifacts() {
    if [ -z "$ARTIFACT_PREFIX" ]; then
        ARTIFACT_PREFIX="./"
    fi
    mkdir -p "$(dirname "$ARTIFACT_PREFIX")" 2>/dev/null || true
}

# Build fuzzer arguments
build_args() {
    local args=()

    # Add JavaScript file
    args+=("--js=$JS_FILE")

    # Add libFuzzer options
    if [ $TIME_LIMIT -gt 0 ]; then
        args+=("-max_total_time=$TIME_LIMIT")
    fi

    args+=("-max_len=$MAX_LEN")

    if [ $WORKERS -gt 1 ]; then
        args+=("-workers=$WORKERS")
        args+=("-jobs=$JOBS")
    fi

    if [ -n "$DICT_FILE" ] && [ -f "$DICT_FILE" ]; then
        args+=("-dict=$DICT_FILE")
    fi

    if [ -n "$ARTIFACT_PREFIX" ]; then
        args+=("-artifact_prefix=$ARTIFACT_PREFIX")
    fi

    # Add extra arguments
    args+=("${EXTRA_ARGS[@]}")

    # Add corpus directory
    args+=("$CORPUS_DIR")

    echo "${args[@]}"
}

# Display fuzzing info
display_info() {
    cat << EOF

╔═══════════════════════════════════════════════════════════╗
║            Starting Fuzzing Campaign                      ║
╚═══════════════════════════════════════════════════════════╝

Target:         $JS_FILE
Corpus:         $CORPUS_DIR
Max Length:     $MAX_LEN bytes
Workers:        $WORKERS
Time Limit:     $([ $TIME_LIMIT -gt 0 ] && echo "$TIME_LIMIT seconds" || echo "unlimited")
Artifacts:      $ARTIFACT_PREFIX

Press Ctrl+C to stop fuzzing.

EOF
}

# Run the fuzzer
run_fuzzer() {
    local args=$(build_args)
    local cmd="$FUZZER_BIN $args"

    log_info "Command: $cmd"
    echo

    # Run the fuzzer
    $cmd
}

# Show results
show_results() {
    echo
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              Fuzzing Campaign Complete                    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo

    # Count corpus files
    local corpus_count=$(find "$CORPUS_DIR" -type f | wc -l)
    log_info "Corpus files: $corpus_count"

    # Check for crashes
    local crashes=$(find . -maxdepth 1 -name "crash-*" -o -name "leak-*" -o -name "timeout-*" 2>/dev/null | wc -l)
    if [ $crashes -gt 0 ]; then
        log_warning "Found $crashes crash/leak/timeout files!"
        echo
        echo "Crash files:"
        find . -maxdepth 1 \( -name "crash-*" -o -name "leak-*" -o -name "timeout-*" \) -exec ls -lh {} \;
        echo
        log_info "Analyze crashes with: $PROJECT_ROOT/scripts/analyze-crash.sh <crash-file>"
    else
        log_success "No crashes found!"
    fi

    # Show corpus statistics
    if [ $corpus_count -gt 0 ]; then
        echo
        log_info "Corpus statistics:"
        local total_size=$(du -sh "$CORPUS_DIR" | cut -f1)
        echo "  Total size: $total_size"

        local smallest=$(find "$CORPUS_DIR" -type f -exec ls -l {} \; | sort -k5 -n | head -1 | awk '{print $5}')
        local largest=$(find "$CORPUS_DIR" -type f -exec ls -l {} \; | sort -k5 -n | tail -1 | awk '{print $5}')
        echo "  Smallest: $smallest bytes"
        echo "  Largest: $largest bytes"
    fi
}

# Main function
main() {
    parse_args "$@"
    check_fuzzer
    setup_corpus
    setup_artifacts
    display_info
    run_fuzzer
    show_results
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Fuzzing interrupted by user${NC}"; show_results; exit 0' INT

main "$@"
