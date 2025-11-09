#!/bin/bash
# Analyze crash files from fuzzing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FUZZER_BIN="$PROJECT_ROOT/jsfuzzer"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $(basename "$0") <crash-file> [javascript-file]

Analyze a crash file from fuzzing.

Arguments:
  crash-file        Path to crash/leak/timeout file
  javascript-file   JavaScript fuzzer file (optional, for reproduction)

Options:
  -r, --reproduce   Attempt to reproduce the crash
  -m, --minimize    Minimize the crash input
  -x, --hexdump     Show full hex dump
  -s, --strings     Extract printable strings
  -h, --help        Show this help

Examples:
  # Analyze a crash
  $(basename "$0") crash-abc123

  # Analyze and reproduce
  $(basename "$0") crash-abc123 my_fuzzer.js -r

  # Minimize crash input
  $(basename "$0") crash-abc123 my_fuzzer.js -m

EOF
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Hex dump function
hexdump_file() {
    local file="$1"
    local limit="${2:-256}"

    if command -v xxd &> /dev/null; then
        xxd -l "$limit" "$file"
    else
        od -A x -t x1z -v "$file" | head -20
    fi
}

# Extract printable strings
extract_strings() {
    local file="$1"
    if command -v strings &> /dev/null; then
        strings "$file"
    else
        tr -cd '[:print:]\n' < "$file" | grep -E '.{4,}'
    fi
}

# Analyze file
analyze_file() {
    local crash_file="$1"
    local js_file="$2"
    local show_hexdump="${3:-false}"
    local show_strings="${4:-false}"

    if [ ! -f "$crash_file" ]; then
        log_error "Crash file not found: $crash_file"
        exit 1
    fi

    local filesize=$(stat -c%s "$crash_file" 2>/dev/null || stat -f%z "$crash_file" 2>/dev/null)
    local filetype=$(file -b "$crash_file" 2>/dev/null || echo "unknown")

    cat << EOF

╔═══════════════════════════════════════════════════════════╗
║              Crash File Analysis                          ║
╚═══════════════════════════════════════════════════════════╝

File:       $crash_file
Size:       $filesize bytes
Type:       $filetype

EOF

    # Show hex dump (first 256 bytes by default)
    echo -e "${CYAN}Hex Dump (first 256 bytes):${NC}"
    if [ "$show_hexdump" = true ]; then
        hexdump_file "$crash_file" 99999
    else
        hexdump_file "$crash_file" 256
    fi
    echo

    # Show ASCII representation
    echo -e "${CYAN}ASCII Representation (printable chars only):${NC}"
    head -c 512 "$crash_file" | tr -cd '[:print:]\n' | fold -w 80 | head -10
    echo
    echo

    # Extract strings if requested
    if [ "$show_strings" = true ]; then
        echo -e "${CYAN}Printable Strings:${NC}"
        extract_strings "$crash_file" | head -20
        echo
    fi

    # Show byte statistics
    echo -e "${CYAN}Byte Statistics:${NC}"
    local null_bytes=$(tr -cd '\000' < "$crash_file" | wc -c)
    local printable=$(tr -cd '[:print:]' < "$crash_file" | wc -c)
    echo "  Null bytes: $null_bytes"
    echo "  Printable chars: $printable"
    echo

    # Reproduction command
    if [ -n "$js_file" ] && [ -f "$js_file" ]; then
        echo -e "${GREEN}Reproduction Command:${NC}"
        echo "  $FUZZER_BIN --js=$js_file $crash_file"
        echo
    fi
}

# Reproduce crash
reproduce_crash() {
    local crash_file="$1"
    local js_file="$2"

    if [ ! -f "$FUZZER_BIN" ]; then
        log_error "Fuzzer not found: $FUZZER_BIN"
        exit 1
    fi

    if [ ! -f "$js_file" ]; then
        log_error "JavaScript file not found: $js_file"
        exit 1
    fi

    log_info "Attempting to reproduce crash..."
    echo

    "$FUZZER_BIN" --js="$js_file" "$crash_file"
}

# Minimize crash
minimize_crash() {
    local crash_file="$1"
    local js_file="$2"

    if [ ! -f "$FUZZER_BIN" ]; then
        log_error "Fuzzer not found: $FUZZER_BIN"
        exit 1
    fi

    if [ ! -f "$js_file" ]; then
        log_error "JavaScript file not found: $js_file"
        exit 1
    fi

    local minimized="minimized-$(basename "$crash_file")"

    log_info "Minimizing crash input..."
    log_info "This may take a while..."
    echo

    "$FUZZER_BIN" --js="$js_file" \
        -minimize_crash=1 \
        -exact_artifact_path="$minimized" \
        "$crash_file"

    if [ -f "$minimized" ]; then
        local orig_size=$(stat -c%s "$crash_file" 2>/dev/null || stat -f%z "$crash_file")
        local min_size=$(stat -c%s "$minimized" 2>/dev/null || stat -f%z "$minimized")

        echo
        echo -e "${GREEN}Minimization complete!${NC}"
        echo "  Original: $orig_size bytes"
        echo "  Minimized: $min_size bytes"
        echo "  Reduction: $(( (orig_size - min_size) * 100 / orig_size ))%"
        echo
        echo "  Minimized file: $minimized"
    fi
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    local crash_file=""
    local js_file=""
    local do_reproduce=false
    local do_minimize=false
    local show_hexdump=false
    local show_strings=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--reproduce)
                do_reproduce=true
                shift
                ;;
            -m|--minimize)
                do_minimize=true
                shift
                ;;
            -x|--hexdump)
                show_hexdump=true
                shift
                ;;
            -s|--strings)
                show_strings=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                if [ -z "$crash_file" ]; then
                    crash_file="$1"
                elif [ -z "$js_file" ]; then
                    js_file="$1"
                else
                    log_error "Unknown argument: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$crash_file" ]; then
        log_error "Crash file required"
        usage
        exit 1
    fi

    # Analyze the crash
    analyze_file "$crash_file" "$js_file" "$show_hexdump" "$show_strings"

    # Reproduce if requested
    if [ "$do_reproduce" = true ]; then
        if [ -z "$js_file" ]; then
            log_error "JavaScript file required for reproduction"
            exit 1
        fi
        reproduce_crash "$crash_file" "$js_file"
    fi

    # Minimize if requested
    if [ "$do_minimize" = true ]; then
        if [ -z "$js_file" ]; then
            log_error "JavaScript file required for minimization"
            exit 1
        fi
        minimize_crash "$crash_file" "$js_file"
    fi
}

main "$@"
