#!/bin/bash
#
# Module comparison - diffs two SprykerAcademy modules that implement the same feature
#
# Usage:
#   ./exercises/tools/compare-modules.sh [MyModule] [TheirModule]
#
# Defaults to ContactRequest (yours, Exercises 1-6b) and CustomerRequest (the one the
# AI Dev SDK builds in Exercise 6c). The module name is mapped in all three spellings -
# ContactRequest, contact_request, contact-request - in file paths and in file contents,
# so that two implementations of the same feature become comparable.
#
# Output per file: "only in <module>", "differs", or counted as identical.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
NAMESPACE_DIR="src/SprykerAcademy"

MINE="${1:-ContactRequest}"
THEIRS="${2:-CustomerRequest}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# The exercises clone normally sits inside the project, but allow running from a project root
if [ ! -d "$PROJECT_DIR/$NAMESPACE_DIR" ] && [ -d "$PWD/$NAMESPACE_DIR" ]; then
    PROJECT_DIR="$PWD"
fi

if [ ! -d "$PROJECT_DIR/$NAMESPACE_DIR" ]; then
    echo -e "${RED}No $NAMESPACE_DIR found (looked in $PROJECT_DIR).${NC}" >&2
    echo "Run this from the project root, or from the exercises clone inside it." >&2
    exit 1
fi

cd "$PROJECT_DIR/$NAMESPACE_DIR"

# ContactRequest -> contact_request / contact-request
snake() { echo "$1" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]'; }
MINE_SNAKE="$(snake "$MINE")";     THEIRS_SNAKE="$(snake "$THEIRS")"
MINE_KEBAB="${MINE_SNAKE//_/-}";   THEIRS_KEBAB="${THEIRS_SNAKE//_/-}"

for module in "$MINE" "$THEIRS"; do
    if ! find . -type d -name "${module}*" | grep -q .; then
        echo -e "${RED}No module folder matching '$module' under $NAMESPACE_DIR.${NC}" >&2
        exit 1
    fi
done

# Path of the counterpart file, in the other module's spelling
counterpart() {
    echo "$1" | sed "s/$2/$3/g; s/$(snake "$2")/$(snake "$3")/g; s/$(snake "$2" | tr '_' '-')/$(snake "$3" | tr '_' '-')/g"
}

# The file with every spelling of its own module name replaced by a placeholder
normalized() {
    sed "s/$2/MODULE/g; s/$(snake "$2")/module/g; s/$(snake "$2" | tr '_' '-')/module/g" "$1"
}

only_mine=0; only_theirs=0; differs=0; identical=0; total=0

echo -e "${YELLOW}Comparing $MINE (yours) with $THEIRS${NC}"
echo

while read -r mine_file; do
    total=$((total + 1))
    theirs_file="$(counterpart "$mine_file" "$MINE" "$THEIRS")"
    if [ ! -f "$theirs_file" ]; then
        echo -e "${YELLOW}only in $MINE:${NC} $mine_file"
        only_mine=$((only_mine + 1))
        continue
    fi
    if diff -q <(normalized "$mine_file" "$MINE") <(normalized "$theirs_file" "$THEIRS") >/dev/null; then
        identical=$((identical + 1))
    else
        echo -e "${RED}differs:${NC} $mine_file"
        differs=$((differs + 1))
    fi
done < <(find . -type f \( -path "*$MINE*" -o -path "*$MINE_SNAKE*" -o -path "*$MINE_KEBAB*" \) | sort)

while read -r theirs_file; do
    mine_file="$(counterpart "$theirs_file" "$THEIRS" "$MINE")"
    if [ ! -f "$mine_file" ]; then
        echo -e "${GREEN}only in $THEIRS:${NC} $theirs_file"
        only_theirs=$((only_theirs + 1))
        total=$((total + 1))
    fi
done < <(find . -type f \( -path "*$THEIRS*" -o -path "*$THEIRS_SNAKE*" -o -path "*$THEIRS_KEBAB*" \) | sort)

echo
echo "identical after renaming: $identical of $total files"
echo "differs: $differs   only in $MINE: $only_mine   only in $THEIRS: $only_theirs"

if [ "$total" -gt 0 ] && [ "$identical" -gt $((total / 2)) ]; then
    echo
    echo -e "${YELLOW}More than half the files are identical once the module name is normalised.${NC}"
    echo "That is a rename-and-paste of $MINE rather than a design. Worth raising with the assistant."
fi
