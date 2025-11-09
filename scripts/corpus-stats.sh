#!/bin/bash
# Show corpus statistics

BLUE='\033[0;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $(basename "$0") <corpus-directory>

Show statistics about a fuzzing corpus.

Examples:
  $(basename "$0") corpus
  $(basename "$0") ./my_fuzzing_corpus

EOF
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

CORPUS_DIR="$1"

if [ ! -d "$CORPUS_DIR" ]; then
    echo "Error: Directory not found: $CORPUS_DIR" >&2
    exit 1
fi

echo
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              Corpus Statistics                            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo

# Count files
file_count=$(find "$CORPUS_DIR" -type f | wc -l)

if [ $file_count -eq 0 ]; then
    echo "No files in corpus."
    exit 0
fi

echo -e "${CYAN}Corpus Directory:${NC} $CORPUS_DIR"
echo -e "${CYAN}Total Files:${NC} $file_count"
echo

# Size statistics
echo -e "${CYAN}Size Statistics:${NC}"
total_size=$(du -sh "$CORPUS_DIR" | cut -f1)
echo "  Total size: $total_size"

# Find min/max sizes
min_size=$(find "$CORPUS_DIR" -type f -exec ls -l {} \; 2>/dev/null | awk '{print $5}' | sort -n | head -1)
max_size=$(find "$CORPUS_DIR" -type f -exec ls -l {} \; 2>/dev/null | awk '{print $5}' | sort -n | tail -1)
avg_size=$(find "$CORPUS_DIR" -type f -exec ls -l {} \; 2>/dev/null | awk '{sum+=$5} END {if (NR>0) print int(sum/NR); else print 0}')

echo "  Smallest: $min_size bytes"
echo "  Largest: $max_size bytes"
echo "  Average: $avg_size bytes"
echo

# File age
echo -e "${CYAN}Corpus Age:${NC}"
oldest=$(find "$CORPUS_DIR" -type f -printf '%T+\n' 2>/dev/null | sort | head -1)
newest=$(find "$CORPUS_DIR" -type f -printf '%T+\n' 2>/dev/null | sort | tail -1)
echo "  Oldest: $oldest"
echo "  Newest: $newest"
echo

# Top 10 largest files
echo -e "${CYAN}Top 10 Largest Files:${NC}"
find "$CORPUS_DIR" -type f -exec ls -lh {} \; 2>/dev/null | \
    sort -k5 -h -r | \
    head -10 | \
    awk '{printf "  %8s  %s\n", $5, $9}'
echo

# Coverage hint (if available)
if [ -f "$CORPUS_DIR/../coverage.txt" ]; then
    echo -e "${CYAN}Coverage Information:${NC}"
    cat "$CORPUS_DIR/../coverage.txt"
fi

echo -e "${GREEN}Corpus is healthy!${NC}"
echo
