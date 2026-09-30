#!/bin/bash
#
# Exercise Loader - Loads exercise code into the Spryker project
#
# Usage:
#   ./exercises/load.sh <package> <branch> [--run]
#
# Examples:
#   ./exercises/load.sh contact-request basics/contact-request-back-office/skeleton
#   ./exercises/load.sh supplier intermediate/back-office/complete --run
#   ./exercises/load.sh ai-foundation advanced/ai-foundation-hello/skeleton
#
# What it does:
#   1. Fetches the package and checks out the branch exactly as it is on GitHub.
#   2. Prepares the project once for the SprykerAcademy namespace (composer autoload, kernel
#      project namespaces, API Platform source directories, Glue service loading). None of this
#      refers to a single exercise class, so it never has to be undone.
#   3. Replaces src/SprykerAcademy and tests/SprykerAcademyTest with the branch's copy, and copies
#      the branch's own data and config files (CSV files, import configuration, OMS process).
#
# The contact-request and supplier branches carry their complete wiring themselves: a dependency
# provider or config class in src/SprykerAcademy that extends the Pyz one wins over it, because
# SprykerAcademy is listed before Pyz in the kernel's project namespaces. Navigation comes from the
# module's Communication/navigation.xml. The loader therefore never edits a file the shop owns
# for those packages. (The ai-foundation package still wires its complete branches into the
# project's AI configuration, see below.)
#
# --run  also runs the post-load commands (cache, Propel, transfers, Glue resources).
#

set -e
trap 'echo -e "\033[0;31mload.sh failed at line $LINENO: $BASH_COMMAND\033[0m" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPOS_DIR="$SCRIPT_DIR/repos"
# Project-relative paths of the files the last load copied outside src/SprykerAcademy and tests/SprykerAcademyTest
MANIFEST="$SCRIPT_DIR/.loaded-files"

# Override a package source to try unpublished branches, e.g.
#   ACADEMY_SUPPLIER_REPO=/path/to/supplier ./exercises/load.sh supplier intermediate/oms/complete
CONTACT_REQUEST_REPO="${ACADEMY_CONTACT_REQUEST_REPO:-https://github.com/spryker-academy/contact-request.git}"
SUPPLIER_REPO="${ACADEMY_SUPPLIER_REPO:-https://github.com/spryker-academy/supplier.git}"
AI_FOUNDATION_REPO="${ACADEMY_AI_FOUNDATION_REPO:-https://github.com/spryker-academy/ai-foundation.git}"

SETUP_MARKER="spryker-academy setup"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Helper functions
log_info() { echo -e "${YELLOW}$1${NC}"; }
log_success() { echo -e "  ${GREEN}$1${NC}"; }
log_error() { echo -e "${RED}$1${NC}"; }

# Check if file exists and doesn't contain pattern
file_needs_update() {
    local file="$1"
    local pattern="$2"
    [ -f "$file" ] || return 1
    local count
    count=$(grep -c "$pattern" "$file" 2>/dev/null) || count=0
    [ "$count" = "0" ]
}

relpath() { echo "${1#"$PROJECT_DIR"/}"; }

usage() {
    echo "Usage: ./exercises/load.sh <package> <branch> [--run]"
    echo ""
    echo "Packages: contact-request, supplier, ai-foundation"
    echo "  --run   also run the post-load commands (cache, Propel, transfers, Glue resources)"
    echo ""
    echo "Contact Request branches:"
    echo "  basics/contact-request-back-office/skeleton"
    echo "  basics/contact-request-back-office/complete"
    echo "  basics/data-transfer-object/skeleton"
    echo "  basics/data-transfer-object/complete"
    echo "  basics/contact-request-table-schema/skeleton"
    echo "  basics/contact-request-table-schema/complete"
    echo "  basics/module-layers/skeleton"
    echo "  basics/module-layers/complete"
    echo "  basics/configuration/skeleton"
    echo "  basics/configuration/complete"
    echo "  basics/extending-core-modules/skeleton"
    echo "  basics/extending-core-modules/complete"
    echo "  basics/extending-core-modules/complete-ajax"
    echo ""
    echo "Supplier branches:"
    echo "  basics/supplier-table-schema/skeleton"
    echo "  intermediate/data-import/skeleton"
    echo "  intermediate/data-import/complete"
    echo "  intermediate/back-office/skeleton"
    echo "  intermediate/back-office/complete"
    echo "  intermediate/publish-synchronize/skeleton"
    echo "  intermediate/publish-synchronize/complete"
    echo "  intermediate/search/skeleton"
    echo "  intermediate/search/complete"
    echo "  intermediate/glue-storefront/skeleton"
    echo "  intermediate/glue-storefront/complete"
    echo "  intermediate/oms/skeleton"
    echo "  intermediate/oms/complete"
    echo "  intermediate/storage-client/skeleton"
    echo "  intermediate/storage-client/complete"
    echo "  intermediate/merchant-portal-table/skeleton"
    echo "  intermediate/merchant-portal-table/complete"
    echo "  intermediate/merchant-portal-form/skeleton"
    echo "  intermediate/merchant-portal-form/complete"
    echo "  intermediate/merchant-portal-locations/skeleton"
    echo "  intermediate/merchant-portal-locations/complete"
    echo "  intermediate/yves-storefront/skeleton"
    echo "  intermediate/yves-storefront/complete"
    echo ""
    echo "AI Foundation branches (see guides/advanced/):"
    echo "  advanced/ai-foundation-hello/skeleton"
    echo "  advanced/ai-foundation-hello/complete"
    echo "  advanced/ai-foundation-catalog/skeleton"
    echo "  advanced/ai-foundation-catalog/complete"
    echo "  advanced/ai-foundation-agent/skeleton      (requires the Back Office Assistant)"
    echo "  advanced/ai-foundation-agent/complete"
    exit 1
}

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
RUN_STEPS=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --run) RUN_STEPS=1 ;;
        -h|--help) usage ;;
        *) ARGS+=("$arg") ;;
    esac
done
[ "${#ARGS[@]}" -eq 2 ] || usage

PACKAGE="${ARGS[0]}"
BRANCH="${ARGS[1]}"

case "$PACKAGE" in
    contact-request) REPO_URL="$CONTACT_REQUEST_REPO" ;;
    supplier) REPO_URL="$SUPPLIER_REPO" ;;
    ai-foundation) REPO_URL="$AI_FOUNDATION_REPO" ;;
    *)
        log_error "Error: Package must be 'contact-request', 'supplier' or 'ai-foundation'"
        usage
        ;;
esac

# ---------------------------------------------------------------------------
# 1. Fetch the package and check out the branch exactly as it is on GitHub
# ---------------------------------------------------------------------------
REPO_DIR="$REPOS_DIR/$PACKAGE"

if [ ! -d "$REPO_DIR" ]; then
    log_info "Cloning $PACKAGE repository..."
    mkdir -p "$REPOS_DIR"
    git clone "$REPO_URL" "$REPO_DIR"
fi

log_info "Switching to branch: $BRANCH"
cd "$REPO_DIR"
[ "$(git remote get-url origin)" = "$REPO_URL" ] || git remote set-url origin "$REPO_URL"
git fetch --prune origin

# The clone is a cache, not a workspace. Work a student saved in it would otherwise come back
# on the next load of the same branch instead of the published skeleton. Park it and say where.
if [ -n "$(git status --porcelain)" ]; then
    log_error "Uncommitted changes in $REPO_DIR:"
    git --no-pager status --short | sed 's/^/    /'
    git stash push --include-untracked -m "load.sh: work in progress before switching to $BRANCH" >/dev/null
    log_error "Stashed them. To get them back:  git -C \"$REPO_DIR\" stash pop"
fi

if ! git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    log_error "Branch '$BRANCH' does not exist in $REPO_URL."
    log_error "Available branches:"
    git for-each-ref --format='    %(refname:short)' refs/remotes/origin | grep -v 'origin/HEAD' | sed 's#origin/##'
    exit 1
fi
# -B resets a local branch of the same name to the remote one: a force-pushed branch or a commit
# made in the clone can never leave the student on an outdated copy.
git checkout -q -B "$BRANCH" "origin/$BRANCH"
cd "$PROJECT_DIR"

# ---------------------------------------------------------------------------
# 2. Project setup for the SprykerAcademy namespace (idempotent, exercise-agnostic)
# ---------------------------------------------------------------------------
setup_project() {
    # composer autoload: the exercise classes and the exercise tests
    php -r '
        $file = $argv[1] . "/composer.json";
        $json = json_decode(file_get_contents($file), true);
        $changed = false;
        if (!isset($json["autoload"]["psr-4"]["SprykerAcademy\\"])) {
            $json["autoload"]["psr-4"]["SprykerAcademy\\"] = "src/SprykerAcademy/";
            $changed = true;
        }
        if (!isset($json["autoload-dev"]["psr-4"]["SprykerAcademyTest\\"])) {
            $json["autoload-dev"]["psr-4"]["SprykerAcademyTest\\"] = "tests/SprykerAcademyTest/";
            $changed = true;
        }
        if ($changed) {
            file_put_contents($file, json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
            echo "updated";
        }
    ' "$PROJECT_DIR" | grep -q updated && log_success "Registered SprykerAcademy\\ and SprykerAcademyTest\\ in composer.json"

    # Kernel project namespaces: SprykerAcademy BEFORE Pyz, so an exercise class that extends a Pyz
    # one (a dependency provider, a config) is the one the kernel resolves.
    local config_default="$PROJECT_DIR/config/Shared/config_default.php"
    if file_needs_update "$config_default" "'SprykerAcademy'"; then
        php -r '
            $file = $argv[1];
            $content = file_get_contents($file);
            $content = preg_replace(
                "/(KernelConstants::PROJECT_NAMESPACES\s*\]\s*=\s*\[\s*\n\s*)(\x27Pyz\x27)/",
                "$1\x27SprykerAcademy\x27,\n    $2",
                $content,
                1,
                $count,
            );
            if ($count) {
                file_put_contents($file, $content);
                echo "updated";
            }
        ' "$config_default" | grep -q updated \
            && log_success "Added SprykerAcademy to PROJECT_NAMESPACES in config/Shared/config_default.php" \
            || log_error "Warning: could not add SprykerAcademy to KernelConstants::PROJECT_NAMESPACES in config/Shared/config_default.php - add it before 'Pyz' yourself."
    fi

    # API Platform scans these directories for resources/api/<type>/*.resource.yml
    local api_config
    for api_config in "$PROJECT_DIR"/config/Glue/packages/spryker_api_platform.php "$PROJECT_DIR"/config/GlueStorefront/packages/spryker_api_platform.php "$PROJECT_DIR"/config/GlueBackend/packages/spryker_api_platform.php; do
        [ -f "$api_config" ] || continue
        php -r '
            $file = $argv[1];
            $content = file_get_contents($file);
            if (preg_match("/[\x27\"]src\/SprykerAcademy[\x27\"]/", $content)) {
                exit(0);
            }
            $content = preg_replace(
                "/(sourceDirectories\(\[[^\]]*?\n(\s*)[\x27\"]src\/Pyz[\x27\"],?)/",
                "$1\n$2\x27src/SprykerAcademy\x27,",
                $content,
                1,
                $count,
            );
            if ($count) {
                file_put_contents($file, $content);
                echo "updated";
            }
        ' "$api_config" | grep -q updated && log_success "Added src/SprykerAcademy to the API Platform source directories in $(relpath "$api_config")"
    done

    # The Glue containers resolve the Clients and Facades an API Platform provider asks for. Core
    # and Pyz ones are registered automatically; for any other namespace the automatic proxy fails
    # with "Could not find ... in any of the attached containers". Load the SprykerAcademy Client
    # and Zed Business layers. is_dir() keeps it harmless while a branch has no such layer.
    local services_file
    for services_file in "$PROJECT_DIR"/config/Glue/ApplicationServices.php "$PROJECT_DIR"/config/GlueStorefront/ApplicationServices.php "$PROJECT_DIR"/config/GlueBackend/ApplicationServices.php; do
        [ -f "$services_file" ] || continue
        grep -q ">>> $SETUP_MARKER" "$services_file" && continue
        php -r '
            $file = $argv[1];
            $marker = $argv[2];
            $content = file_get_contents($file);
            $block = "\n    // >>> " . $marker . ": SprykerAcademy Clients and Facades for API Platform providers\n"
                . "    \$academyServices = \$configurator->services()->defaults()->autowire()->public()->autoconfigure();\n"
                . "    if (is_dir(__DIR__ . \x27/../../src/SprykerAcademy/Client\x27)) {\n"
                . "        \$academyServices->load(\x27SprykerAcademy\\\\Client\\\\\x27, \x27../../src/SprykerAcademy/Client/\x27);\n"
                . "    }\n"
                . "    if (glob(__DIR__ . \x27/../../src/SprykerAcademy/Zed/*/Business\x27, GLOB_ONLYDIR)) {\n"
                . "        \$academyServices->load(\x27SprykerAcademy\\\\Zed\\\\\x27, \x27../../src/SprykerAcademy/Zed/*/Business/\x27);\n"
                . "    }\n"
                . "    // <<< " . $marker . "\n";
            $content = preg_replace_callback("/\n(};)\s*$/", fn ($m) => $block . $m[1] . "\n", $content, 1, $count);
            if ($count) {
                file_put_contents($file, $content);
                echo "updated";
            }
        ' "$services_file" "$SETUP_MARKER" | grep -q updated && log_success "Registered the SprykerAcademy Client and Facade services in $(relpath "$services_file")"
    done

    # Merchant Portal frontend: the Angular build collects the component entry points of
    # vendor/spryker and src/Pyz/Zed only. Add src/SprykerAcademy/Zed to the scan and to the
    # TypeScript sources, so an exercise's Presentation/Components/entry.ts is built as well.
    local mp_entry_points="$PROJECT_DIR/frontend/merchant-portal/entry-points.js"
    if [ -f "$mp_entry_points" ] && ! grep -q "$SETUP_MARKER" "$mp_entry_points"; then
        php -r '
            $file = $argv[1];
            $marker = $argv[2];
            $content = file_get_contents($file);
            $scan = "\n    // >>> " . $marker . ": Merchant Portal components of src/SprykerAcademy/Zed\n"
                . "    const academyDir = path.join(ROOT_SPRYKER_PROJECT_DIR, \x27../../SprykerAcademy/Zed\x27);\n"
                . "    const academy = require(\x27fs\x27).existsSync(academyDir) ? await entryPointsMap(academyDir, MP_PROJECT_ENTRY_POINT_FILE) : {};\n"
                . "    // <<< " . $marker . "\n";
            $content = preg_replace("/(\n\s*const project = await entryPointsMap\(ROOT_SPRYKER_PROJECT_DIR, MP_PROJECT_ENTRY_POINT_FILE\);\n)/", "$1" . $scan, $content, 1, $count);
            $content = preg_replace("/return \{ \.\.\.core, \.\.\.project, /", "return { ...core, ...project, ...academy, ", $content, 1, $count2);
            if ($count && $count2) {
                file_put_contents($file, $content);
                echo "updated";
            }
        ' "$mp_entry_points" "$SETUP_MARKER" | grep -q updated \
            && log_success "Added src/SprykerAcademy/Zed to the Merchant Portal entry points (frontend/merchant-portal/entry-points.js)" \
            || log_error "Warning: could not add src/SprykerAcademy/Zed to frontend/merchant-portal/entry-points.js - the merchant portal exercises need it."
    fi
    local mp_tsconfig="$PROJECT_DIR/tsconfig.mp.json"
    if [ -f "$mp_tsconfig" ] && ! grep -q "src/SprykerAcademy/Zed" "$mp_tsconfig"; then
        php -r '
            $file = $argv[1];
            $json = json_decode(file_get_contents($file), true);
            if (!is_array($json) || !isset($json["include"])) {
                exit(1);
            }
            $json["include"][] = "src/SprykerAcademy/Zed/*/Presentation/Components/entry.ts";
            file_put_contents($file, json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
            echo "updated";
        ' "$mp_tsconfig" | grep -q updated && log_success "Added src/SprykerAcademy/Zed entry points to tsconfig.mp.json"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Removes what earlier loader versions wrote into project files. Those versions wired the
# exercises into the shop's own files; the branches now carry that wiring themselves, and a
# second copy would register every plugin twice. Safe to run on every load.
# ---------------------------------------------------------------------------
remove_legacy_wiring() {
    local file

    # Marked lines and blocks in PHP files: // >>> marker ... // <<< marker, and "... // marker" lines
    strip_marked() {
        # $1 file, $2..$n markers
        local target="$1"
        shift
        [ -f "$target" ] || return 0
        php -r '
            $file = $argv[1];
            $markers = array_slice($argv, 2);
            $content = $original = file_get_contents($file);
            foreach ($markers as $marker) {
                $quoted = preg_quote($marker, "/");
                $content = preg_replace("/\n[ \t]*\/\/ >>> " . $quoted . ".*?\/\/ <<< " . $quoted . "[^\n]*/s", "", $content);
                // a line that replaced a core plugin gets the core plugin back
                $content = preg_replace("/^([ \t]*)new [^\n]*\/\/ " . $quoted . " \(replaces ([A-Za-z]+)\)[^\n]*$/m", "$1new $2(),", $content);
                $content = preg_replace("/\n[^\n]*\/\/ " . $quoted . "[^\n]*/", "", $content);
            }
            if ($content !== $original) {
                $content = preg_replace("/\n{3,}/", "\n\n", $content);
                file_put_contents($file, $content);
                echo "updated";
            }
        ' "$target" "$@"
    }

    file="$PROJECT_DIR/src/Pyz/Zed/DataImport/DataImportDependencyProvider.php"
    strip_marked "$file" "supplier data-import exercise TODO" "supplier data-import exercise" | grep -q updated \
        && log_success "Removed the supplier importer wiring of an earlier loader from $(relpath "$file")"

    file="$PROJECT_DIR/src/Pyz/Yves/Router/RouterDependencyProvider.php"
    strip_marked "$file" "contact-request exercise" | grep -q updated \
        && log_success "Removed the Contact Request routes of an earlier loader from $(relpath "$file")"

    for file in "$PROJECT_DIR"/config/Glue/ApplicationServices.php "$PROJECT_DIR"/config/GlueBackend/ApplicationServices.php "$PROJECT_DIR"/config/GlueStorefront/ApplicationServices.php; do
        [ -f "$file" ] || continue
        php -r '
            $file = $argv[1];
            $content = $original = file_get_contents($file);
            $content = preg_replace("/\n[ \t]*\/\/ >>> supplier exercise.*?\/\/ <<< supplier exercise[^\n]*/s", "", $content);
            // line written by an even earlier loader version
            $content = preg_replace("/\n[ \t]*\\\$services->load\(\x27SprykerAcademy[^\n]*/", "", $content);
            if ($content !== $original) {
                file_put_contents($file, $content);
                echo "updated";
            }
        ' "$file" | grep -q updated && log_success "Removed the per-exercise service registration of an earlier loader from $(relpath "$file")"
    done

    # config_default.php: the ContactRequest config value (Exercise 6)
    file="$PROJECT_DIR/config/Shared/config_default.php"
    if grep -q "ContactRequest exercise config value\|>>> contact-request exercise" "$file" 2>/dev/null; then
        php -r '
            $file = $argv[1];
            $content = file_get_contents($file);
            $content = preg_replace("/\n[ \t]*\/\/ >>> contact-request exercise.*?\/\/ <<< contact-request exercise[^\n]*/s", "", $content);
            $content = preg_replace("/\n*\/\/ ContactRequest exercise config value\nuse SprykerAcademy\\\\Shared\\\\ContactRequest\\\\ContactRequestConstants;\n\n\\\$config\[ContactRequestConstants::MY_CONFIG_VALUE\][^\n]*\n?/", "\n", $content);
            file_put_contents($file, rtrim($content) . "\n");
        ' "$file"
        log_success "Removed the ContactRequest config value of an earlier loader from config/Shared/config_default.php"
    fi

    # The account menu item of Exercise 7. Twig expressions have no comments, so the item carries
    # no marker and is recognised by its name.
    file="$PROJECT_DIR/src/Pyz/Yves/CustomerPage/Theme/default/components/molecules/navigation-sidebar/navigation-sidebar.twig"
    if [ -f "$file" ] && grep -q "name: 'contact-requests'\|{# >>> contact-request exercise #}" "$file"; then
        php -r '
            $file = $argv[1];
            $content = file_get_contents($file);
            $content = preg_replace("/\n[ \t]*\{# >>> contact-request exercise #\}.*?\{# <<< contact-request exercise #\}[^\n]*/s", "", $content);
            $content = preg_replace("/\n[ \t]*\{[^{}]*name: \x27contact-requests\x27,[^{}]*\},/s", "", $content);
            file_put_contents($file, $content);
        ' "$file"
        log_success "Removed the My Contact Requests item of an earlier loader from $(relpath "$file")"
    fi

    # Menu entries an earlier loader merged into the project navigation. The branches now ship
    # them as src/SprykerAcademy/Zed/<Module>/Communication/navigation*.xml.
    for file in "$PROJECT_DIR/config/Zed/navigation.xml" "$PROJECT_DIR/config/Zed/navigation-main-merchant-portal.xml"; do
        [ -f "$file" ] || continue
        grep -qE '<(supplier-gui|supplier-merchant-portal-gui|contact-request)>' "$file" || continue
        php -r '
            $file = $argv[1];
            $dom = new DOMDocument();
            $dom->preserveWhiteSpace = true;
            $dom->load($file);
            $removed = 0;
            foreach (["supplier-gui", "supplier-merchant-portal-gui", "contact-request"] as $name) {
                foreach (iterator_to_array($dom->documentElement->childNodes) as $node) {
                    if ($node->nodeType === XML_ELEMENT_NODE && $node->nodeName === $name) {
                        $dom->documentElement->removeChild($node);
                        $removed++;
                    }
                }
            }
            if ($removed) {
                $dom->save($file);
                echo "updated";
            }
        ' "$file" | grep -q updated && log_success "Removed the exercise menu entries of an earlier loader from $(relpath "$file")"
    done

    # Import entries an earlier loader appended to the project import configuration
    file="$PROJECT_DIR/data/import/local/full_EU.yml"
    if grep -q "# Supplier Academy exercise" "$file" 2>/dev/null; then
        php -r '
            $file = $argv[1];
            $content = file_get_contents($file);
            $content = preg_replace("/\n*[ \t]*# Supplier Academy exercises?\n[ \t]*- data_entity: supplier(-location)?\n[ \t]*source: [^\n]*(\n[ \t]*- data_entity: supplier-location\n[ \t]*source: [^\n]*)?/", "", $content);
            file_put_contents($file, rtrim($content) . "\n");
        ' "$file"
        log_success "Removed the supplier import entries of an earlier loader from data/import/local/full_EU.yml"
    fi

    # Files an earlier loader copied without recording them
    if [ ! -f "$MANIFEST" ]; then
        for file in data/import/supplier.csv data/import/supplier_location.csv config/Zed/oms/Demo01.xml; do
            [ -f "$PROJECT_DIR/$file" ] && rm -f "$PROJECT_DIR/$file" && log_success "Removed $file (copied by an earlier loader)"
        done
        # The supplier branches used to ship a Pyz CacheConfig; remove it only if it is that very file
        file="$PROJECT_DIR/src/Pyz/Zed/Cache/CacheConfig.php"
        if [ -f "$file" ] && grep -q "Includes Symfony application caches for all applications (Glue, GlueStorefront, GlueBackend, Zed, Yves)" "$file"; then
            rm -f "$file"
            rmdir "$PROJECT_DIR/src/Pyz/Zed/Cache" 2>/dev/null || true
            log_success "Removed src/Pyz/Zed/Cache/CacheConfig.php (copied by an earlier loader)"
        fi
    fi

    return 0
}

# ---------------------------------------------------------------------------
# 3. Install the branch
# ---------------------------------------------------------------------------
# Copies the branch's own files outside src/ and tests/ (data/**, config/**) into the project.
# A file the project already has and that the last load did not put there belongs to the shop:
# it is never overwritten.
install_branch_files() {
    local previous=()
    [ -f "$MANIFEST" ] && while IFS= read -r line; do [ -n "$line" ] && previous+=("$line"); done < "$MANIFEST"

    # Remove what the previous load copied
    local file
    for file in "${previous[@]}"; do
        rm -f "$PROJECT_DIR/$file"
    done

    : > "$MANIFEST"
    local copied=0
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        if [ -e "$PROJECT_DIR/$file" ]; then
            log_error "Warning: the branch ships $file, but the project already has its own copy - left untouched."
            continue
        fi
        mkdir -p "$PROJECT_DIR/$(dirname "$file")"
        cp "$REPO_DIR/$file" "$PROJECT_DIR/$file"
        echo "$file" >> "$MANIFEST"
        copied=$((copied + 1))
    done < <(cd "$REPO_DIR" && git ls-files -- data config 2>/dev/null)

    [ "$copied" -gt 0 ] && log_success "Copied $copied data/config file(s) of the branch (listed in $(relpath "$MANIFEST"))"
    return 0
}

log_info "Preparing the project for the SprykerAcademy namespace..."
setup_project
remove_legacy_wiring

log_info "Installing the exercise files..."
rm -rf "$PROJECT_DIR/src/SprykerAcademy"
mkdir -p "$PROJECT_DIR/src/SprykerAcademy"
if [ -d "$REPO_DIR/src/SprykerAcademy" ]; then
    cp -R "$REPO_DIR/src/SprykerAcademy/." "$PROJECT_DIR/src/SprykerAcademy/"
else
    log_info "Note: This branch has no src/ files (empty skeleton)."
fi
if [ -d "$REPO_DIR/src/Pyz" ]; then
    log_error "Warning: this branch ships src/Pyz files. They are not copied: exercise branches extend Pyz classes from src/SprykerAcademy instead."
fi

rm -rf "$PROJECT_DIR/tests/SprykerAcademyTest"
if [ -d "$REPO_DIR/tests/SprykerAcademyTest" ]; then
    cp -R "$REPO_DIR/tests/SprykerAcademyTest" "$PROJECT_DIR/tests/SprykerAcademyTest"
fi

install_branch_files

# Generated API Platform resources built from an earlier branch's schema files point at providers
# that may no longer exist, and the Glue container then fails to compile. The generator writes
# the source schema into each file's header, which identifies ours.
STALE_API_RESOURCES=$(grep -rl "src/SprykerAcademy/" "$PROJECT_DIR"/src/Generated/Api 2>/dev/null || true)
if [ -n "$STALE_API_RESOURCES" ]; then
    echo "$STALE_API_RESOURCES" | while read -r generated; do rm -f "$generated"; done
    log_success "Removed the API Platform resources generated from the previous exercise (glue api:generate rebuilds them)"
fi

# The compiled Glue kernels cache the service and resource lists; cache:empty-all does not reach them
rm -rf "$PROJECT_DIR"/data/cache/Glue "$PROJECT_DIR"/data/cache/GlueStorefront "$PROJECT_DIR"/data/cache/GlueBackend 2>/dev/null || true

# ai-foundation calls this for its storefront API exercises; the setup above already did the work
register_api_platform_sources() { return 0; }

# ---------------------------------------------------------------------------
# AI Foundation package (Exercise 19: Hello AI, Exercise 20: Ask the Catalog, Exercise 21: Product Creation agent)
# ---------------------------------------------------------------------------
AI_WIRING_MARKER="ai-foundation exercise"
AI_WIRING_MARKERS="$AI_WIRING_MARKER|ai-product-creation exercise" # second value: marker of an earlier loader version

# Always remove wiring that a previous "complete" load added: other packages and other branches must not reference
# classes that src/SprykerAcademy no longer contains, and in the skeleton branches the wiring is a student task.
# The complete branches add their own wiring again below.
if true; then
    AI_WIRED_FILES=$(grep -rlE "$AI_WIRING_MARKERS" "$PROJECT_DIR/src/Pyz" "$PROJECT_DIR/src/Demo" "$PROJECT_DIR/config/Shared/config_ai.php" --include="*.php" 2>/dev/null || true)
    if [ -n "$AI_WIRED_FILES" ]; then
        echo "$AI_WIRED_FILES" | while read -r wired_file; do
            php -r '
                $file = $argv[1];
                $content = file_get_contents($file);
                foreach (explode("|", $argv[2]) as $marker) {
                    $marker = preg_quote($marker, "/");
                    $content = preg_replace("/\n[ \t]*\/\/ >>> " . $marker . ".*?\/\/ <<< " . $marker . "[^\n]*/s", "", $content);
                    $content = preg_replace("/\n[^\n]*\/\/ " . $marker . "[^\n]*/", "", $content);
                }
                $content = preg_replace("/\n{3,}/", "\n\n", $content);
                file_put_contents($file, rtrim($content) . "\n");
            ' "$wired_file" "$AI_WIRING_MARKERS"
        done
        log_success "Removed automatic AI Foundation wiring from the project"
    fi
    if [ "$PACKAGE" != "ai-foundation" ]; then
        rm -f "$PROJECT_DIR/data/configuration/ai_product_creation.configuration.yml"
        if grep -rq "AiProductCreation\|HelloAi\|CatalogAssistant" "$PROJECT_DIR/src/Pyz" "$PROJECT_DIR/config/Shared/config_ai.php" 2>/dev/null; then
            log_error "Warning: the project still references an AI exercise module (AiProductCreation, HelloAi, CatalogAssistant) (manual wiring from the AI exercises)."
            log_error "         Remove those lines, or the application will fail because src/SprykerAcademy was replaced."
        fi
    fi
fi

if [ "$PACKAGE" = "ai-foundation" ]; then
    CONFIG_AI="$PROJECT_DIR/config/Shared/config_ai.php"

    # --- Storefront API exercises need the SprykerAcademy sources in the API Platform configs
    if [ -d "$REPO_DIR/src/SprykerAcademy/Glue" ]; then
        register_api_platform_sources
    fi

    # --- Configuration schema of the agent: project-level schemas live in data/configuration
    if [ -d "$REPO_DIR/resources/configuration" ]; then
        mkdir -p "$PROJECT_DIR/data/configuration"
        cp "$REPO_DIR"/resources/configuration/*.configuration.yml "$PROJECT_DIR/data/configuration/"
        log_success "Copied agent configuration schema to data/configuration/"
    else
        rm -f "$PROJECT_DIR/data/configuration/ai_product_creation.configuration.yml"
    fi

    # --- Exercise 19 (Hello AI), complete branch: register the AI configuration
    if [[ "$BRANCH" == advanced/ai-foundation-hello/complete ]] && [ -f "$CONFIG_AI" ] && file_needs_update "$CONFIG_AI" "AI_CONFIGURATION_HELLO_AI"; then
        cat >> "$CONFIG_AI" <<'CONFIGEOF'

// >>> ai-foundation exercise
$config[\Spryker\Shared\AiFoundation\AiFoundationConstants::AI_CONFIGURATIONS][\SprykerAcademy\Shared\HelloAi\HelloAiConstants::AI_CONFIGURATION_HELLO_AI] = [
    'provider_name' => \Spryker\Shared\AiFoundation\AiFoundationConstants::PROVIDER_OPENAI,
    'provider_config' => [
        'key' => \Spryker\Shared\AiFoundation\AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . \Pyz\Shared\AiCommerce\AiCommerceConstants::CONFIGURATION_KEY_OPENAI_API_TOKEN,
        'model' => 'gpt-4.1-mini',
    ],
    'system_prompt' => 'You are a friendly assistant for a Spryker developer training. Answer in one or two short sentences.',
];
// <<< ai-foundation exercise
CONFIGEOF
        log_success "Added the Hello AI configuration to config_ai.php"
    fi

    # Registers a plugin instance inside a dependency provider method, marked so it can be removed again
    wire_plugin() {
        # $1 file, $2 method name, $3 fully qualified plugin class
        if file_needs_update "$1" "$(basename "${3//\\//}")"; then
            php -r '
                [$file, $method, $class, $marker] = [$argv[1], $argv[2], $argv[3], $argv[4]];
                $content = file_get_contents($file);
                $pattern = "/(function " . preg_quote($method, "/") . "\(\): array\s*\{\s*return \[.*?)(\n\s*\];)/s";
                $line = "\n            new \\" . $class . "(), // " . $marker;
                $updated = preg_replace($pattern, "$1" . str_replace("\\", "\\\\", $line) . "$2", $content, 1, $count);
                if ($count === 1) {
                    file_put_contents($file, $updated);
                    echo "updated";
                }
            ' "$1" "$2" "$3" "$AI_WIRING_MARKER" | grep -q "updated" && log_success "Registered $(basename "${3//\\//}") in $(basename "$1")"
        fi
    }

    # --- Exercise 20 (Ask the Catalog), complete branch: AI configuration and tool set registration
    if [[ "$BRANCH" == advanced/ai-foundation-catalog/complete ]]; then
        if [ -f "$CONFIG_AI" ] && file_needs_update "$CONFIG_AI" "AI_CONFIGURATION_CATALOG_ASSISTANT"; then
            cat >> "$CONFIG_AI" <<'CONFIGEOF'

// >>> ai-foundation exercise
$config[\Spryker\Shared\AiFoundation\AiFoundationConstants::AI_CONFIGURATIONS][\SprykerAcademy\Shared\CatalogAssistant\CatalogAssistantConstants::AI_CONFIGURATION_CATALOG_ASSISTANT] = [
    'provider_name' => \Spryker\Shared\AiFoundation\AiFoundationConstants::PROVIDER_OPENAI,
    'provider_config' => [
        'key' => \Spryker\Shared\AiFoundation\AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . \Pyz\Shared\AiCommerce\AiCommerceConstants::CONFIGURATION_KEY_OPENAI_API_TOKEN,
        'model' => 'gpt-4.1-mini',
    ],
    'system_prompt' => 'You are a product advisor for an online shop. You answer questions about one product at a time. ALWAYS call get_product_details with the given SKU before answering, even for follow-up questions. Answer only with facts from the tool result. If the tool returns an error or the details do not cover the question, say so and set confidence to low. Prices in the tool result are gross amounts in cents; show them in major units. Keep the answer under 80 words.',
];
// <<< ai-foundation exercise
CONFIGEOF
            log_success "Added the Catalog Assistant AI configuration to config_ai.php"
        fi

        TOOLSET_PROVIDER=$(grep -rl "function getAiToolSetPlugins" "$PROJECT_DIR/src" --include="*.php" 2>/dev/null | head -1)
        if [ -z "$TOOLSET_PROVIDER" ]; then
            # No project-level AiFoundationDependencyProvider yet (Back Office Assistant not installed): create a minimal one
            TOOLSET_PROVIDER="$PROJECT_DIR/src/Pyz/Zed/AiFoundation/AiFoundationDependencyProvider.php"
            mkdir -p "$(dirname "$TOOLSET_PROVIDER")"
            cat > "$TOOLSET_PROVIDER" <<'PROVIDEREOF'
<?php

declare(strict_types = 1);

namespace Pyz\Zed\AiFoundation;

use Spryker\Zed\AiFoundation\AiFoundationDependencyProvider as SprykerAiFoundationDependencyProvider;

class AiFoundationDependencyProvider extends SprykerAiFoundationDependencyProvider
{
    /**
     * @return array<\Spryker\Zed\AiFoundation\Dependency\Tools\ToolSetPluginInterface>
     */
    protected function getAiToolSetPlugins(): array
    {
        return [
        ];
    }
}
PROVIDEREOF
            log_success "Created src/Pyz/Zed/AiFoundation/AiFoundationDependencyProvider.php"
        fi
        wire_plugin "$TOOLSET_PROVIDER" "getAiToolSetPlugins" 'SprykerAcademy\Zed\CatalogAssistant\Communication\Plugin\AiFoundation\CatalogToolSetPlugin'
    fi

    # --- Exercise 21 (agent): needs the Back Office Assistant
    if [[ "$BRANCH" == advanced/ai-foundation-agent/* ]]; then
        AGENT_PROVIDER=$(grep -rl "function getBackofficeAssistantAgentPlugins" "$PROJECT_DIR/src" --include="*.php" 2>/dev/null | head -1)
        TOOLSET_PROVIDER=$(grep -rl "function getAiToolSetPlugins" "$PROJECT_DIR/src" --include="*.php" 2>/dev/null | head -1)

        if [ -z "$AGENT_PROVIDER" ] || [ -z "$TOOLSET_PROVIDER" ]; then
            log_error "Warning: the Back Office Assistant is not installed in this project."
            log_error "         Follow exercises/guides/advanced/01-back-office-assistant-setup.md first."
        fi
    fi

    # The complete branch of the agent is wired automatically. In the skeleton branch wiring is part of the exercise.
    if [[ "$BRANCH" == advanced/ai-foundation-agent/complete ]] && [ -n "$AGENT_PROVIDER" ] && [ -n "$TOOLSET_PROVIDER" ]; then
        wire_plugin "$AGENT_PROVIDER" "getBackofficeAssistantAgentPlugins" 'SprykerAcademy\Zed\AiProductCreation\Communication\Plugin\Agent\ProductCreationAgentPlugin'
        wire_plugin "$TOOLSET_PROVIDER" "getAiToolSetPlugins" 'SprykerAcademy\Zed\AiProductCreation\Communication\Plugin\AiFoundation\ProductCreationToolSetPlugin'

        # AI configuration (OpenAI) for the agent
        if file_needs_update "$CONFIG_AI" "AI_CONFIGURATION_PRODUCT_CREATION_OPENAI"; then
            cat >> "$CONFIG_AI" <<'CONFIGEOF'

// >>> ai-foundation exercise
$config[\Spryker\Shared\AiFoundation\AiFoundationConstants::AI_CONFIGURATIONS][\SprykerAcademy\Shared\AiProductCreation\AiProductCreationConstants::AI_CONFIGURATION_PRODUCT_CREATION_OPENAI] = [
    'provider_name' => \Spryker\Shared\AiFoundation\AiFoundationConstants::PROVIDER_OPENAI,
    'provider_config' => [
        'key' => \Spryker\Shared\AiFoundation\AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . \Pyz\Shared\AiCommerce\AiCommerceConstants::CONFIGURATION_KEY_OPENAI_API_TOKEN,
        'model' => \Spryker\Shared\AiFoundation\AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . \Pyz\Shared\AiCommerce\AiCommerceConstants::CONFIGURATION_KEY_BACKOFFICE_ASSISTANT_OPENAI_MODEL,
    ],
    'system_prompt' => \Spryker\Shared\AiFoundation\AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . \SprykerAcademy\Shared\AiProductCreation\AiProductCreationConstants::CONFIGURATION_KEY_SYSTEM_PROMPT,
];
// <<< ai-foundation exercise
CONFIGEOF
            log_success "Added the Product Creation AI configuration to config_ai.php"
        fi

        # SSE streaming: tool call progress is only streamed for listed AI configuration names
        SSE_CONFIG=$(grep -l "function getBackofficeAssistantSseAiConfigurationNames" "$PROJECT_DIR"/src/*/Zed/AiCommerce/AiCommerceConfig.php 2>/dev/null | head -1)
        [ -z "$SSE_CONFIG" ] && SSE_CONFIG="$PROJECT_DIR/src/Pyz/Zed/AiCommerce/AiCommerceConfig.php"
        if file_needs_update "$SSE_CONFIG" "AI_CONFIGURATION_PRODUCT_CREATION_OPENAI"; then
            php -r '
                [$file, $marker] = [$argv[1], $argv[2]];
                $content = file_get_contents($file);
                $constant = "\\SprykerAcademy\\Shared\\AiProductCreation\\AiProductCreationConstants::AI_CONFIGURATION_PRODUCT_CREATION_OPENAI";
                if (strpos($content, "function getBackofficeAssistantSseAiConfigurationNames") !== false) {
                    $pattern = "/(function getBackofficeAssistantSseAiConfigurationNames\(\): array\s*\{.*?)(\n\s*\]\)\);)/s";
                    $content = preg_replace_callback($pattern, fn ($m) => $m[1] . "\n            " . $constant . ", // " . $marker . $m[2], $content, 1);
                } else {
                    $method = "\n    // >>> " . $marker . "\n"
                        . "    /**\n     * @return array<string>\n     */\n"
                        . "    public function getBackofficeAssistantSseAiConfigurationNames(): array\n    {\n"
                        . "        return array_values(array_filter([\n"
                        . "            ...parent::getBackofficeAssistantSseAiConfigurationNames(),\n"
                        . "            " . $constant . ",\n"
                        . "        ]));\n    }\n"
                        . "    // <<< " . $marker . "\n";
                    $position = strrpos($content, "}");
                    $content = rtrim(substr($content, 0, $position)) . "\n" . $method . "}\n";
                }
                file_put_contents($file, $content);
            ' "$SSE_CONFIG" "$AI_WIRING_MARKER"
            log_success "Enabled SSE streaming for the agent in $(basename "$SSE_CONFIG")"
        fi
    fi
fi


# Safety net: warn about project files that still reference SprykerAcademy classes this branch does not contain (manual wiring from another exercise)
MISSING_REFS=$(grep -rhE "SprykerAcademy(\\\\[A-Za-z0-9_]+)+" "$PROJECT_DIR/src/Pyz" "$PROJECT_DIR/config" --include="*.php" 2>/dev/null \
    | grep -vE '^[[:space:]]*(//|#|\*|/\*)' \
    | grep -oE "SprykerAcademy(\\\\[A-Za-z0-9_]+)+" | sort -u | while read -r class; do
    rel=$(echo "${class#SprykerAcademy\\}" | tr '\\' '/')
    # a namespace prefix in a service registration (SprykerAcademy\Client\) is not a class
    [ -d "$PROJECT_DIR/src/SprykerAcademy/$rel" ] && continue
    [ -f "$PROJECT_DIR/src/SprykerAcademy/$rel.php" ] || echo "$class"
done)
if [ -n "$MISSING_REFS" ]; then
    log_error "Warning: src/Pyz or config still references classes this branch does not contain:"
    echo "$MISSING_REFS" | sed 's/^/           /'
    log_error "         Leftover wiring from another exercise. A bare \`use\` import of them is harmless; any line that actually"
    log_error "         calls one will fatal with a class not found error. Check those files before you carry on."
fi

# ---------------------------------------------------------------------------
# Regenerate the composer autoloader.
#
# Registering the namespace in composer.json is only half the job: PHP resolves classes
# through the generated map in vendor/composer/autoload_psr4.php. While the SprykerAcademy
# prefix is missing there, every exercise class is invisible to PHP - the Zed router finds
# src/SprykerAcademy/.../IndexController.php on disk, calls class_exists() on the name it
# derived from the path, gets false and aborts the request with
#   Expected class "SprykerAcademy\Zed\ContactRequest\Communication\Controller\IndexController" not found!
# which reads as if the file were missing. Dump it on every run: composer.json may already
# carry the entry from an earlier load while the generated map is still stale.
# ---------------------------------------------------------------------------
DUMP_AUTOLOAD_DONE=0
dump_autoload() {
    local map="$PROJECT_DIR/vendor/composer/autoload_psr4.php"

    log_info "Regenerating the composer autoloader..."

    if [ -x "$PROJECT_DIR/docker/sdk" ] \
        && (cd "$PROJECT_DIR" && docker/sdk cli composer dump-autoload) </dev/null >/dev/null 2>&1; then
        DUMP_AUTOLOAD_DONE=1
    elif command -v composer >/dev/null 2>&1 \
        && (cd "$PROJECT_DIR" && composer dump-autoload) </dev/null >/dev/null 2>&1; then
        DUMP_AUTOLOAD_DONE=1
    fi

    if [ "$DUMP_AUTOLOAD_DONE" = "0" ]; then
        log_error "Warning: could not run composer dump-autoload (is the shop up?)."
        log_error "         Run it yourself before you open the Back Office, or PHP will not"
        log_error "         know a single SprykerAcademy class:"
        log_error "           docker/sdk cli composer dump-autoload"

        return 0
    fi

    # composer wrote vendor/ inside the container, so the copy on the host can lag a moment
    local attempt=0
    while [ "$attempt" -lt 10 ] && file_needs_update "$map" "SprykerAcademy"; do
        attempt=$((attempt + 1))
        sleep 1
    done

    if [ -f "$map" ] && file_needs_update "$map" "SprykerAcademy"; then
        log_error "Warning: vendor/composer/autoload_psr4.php still has no SprykerAcademy entry."
        log_error "         Check the autoload.psr-4 section of composer.json."

        return 0
    fi

    log_success "composer dump-autoload (SprykerAcademy is registered in vendor/composer/autoload_psr4.php)"
}
dump_autoload

# Drop the cached Yves route collection.
#
# console cache:empty-all clears src/Generated/Zed/Router and src/Generated/Yves/Twig, but not
# src/Generated/Yves/Router. That collection is built on the first request and never invalidated,
# so after switching to a branch that adds Yves routes every path() to a new route dies with
#   None of the chained routers were able to generate route: Route 'customer/...' not found
# while the pages of the previous branch still work. Deleting it costs nothing - the next request
# rebuilds it.
if [ -d "$PROJECT_DIR/src/Generated/Yves/Router" ]; then
    rm -rf "$PROJECT_DIR/src/Generated/Yves/Router"
    log_success "Dropped the cached Yves route collection (src/Generated/Yves/Router)"
fi

# ---------------------------------------------------------------------------
# Post-load commands. Printed, and run with --run.
# ---------------------------------------------------------------------------
STEPS=()
ACADEMY_DIR="$PROJECT_DIR/src/SprykerAcademy"
has_academy() { compgen -G "$ACADEMY_DIR/$1" > /dev/null; }

if [ "$PACKAGE" = "ai-foundation" ]; then
    # config_ai.php references a SprykerAcademy class, so the autoloader comes first (dump_autoload
    # already ran it; only ask for it when that failed). cache:empty-all deletes data/cache, which
    # holds the Propel table map (data/cache/propel/generated-conf/loadDatabase.php), so
    # propel:install must run after it; it also deletes the synced configuration schemas.
    [ "$DUMP_AUTOLOAD_DONE" = "1" ] || STEPS+=("docker/sdk cli composer dump-autoload")
    STEPS+=("docker/sdk console transfer:generate")
    STEPS+=("docker/sdk console c:e")
    STEPS+=("docker/sdk console propel:install")
    STEPS+=("docker/sdk console configuration:sync")
else
    # cache:empty-all deletes data/cache, which holds the Propel table map
    # (data/cache/propel/generated-conf/loadDatabase.php); propel:install writes it again,
    # so it must run after cache:empty-all
    STEPS+=("docker/sdk console c:e")
    [ "$DUMP_AUTOLOAD_DONE" = "1" ] || STEPS+=("docker/sdk cli composer dump-autoload")
    STEPS+=("docker/sdk console propel:install")
    STEPS+=("docker/sdk console transfer:generate")
fi
if has_academy "Zed/*/Communication/navigation*.xml"; then
    STEPS+=("docker/sdk console navigation:build-cache")
fi
if has_academy "Client/RabbitMq"; then
    # creates the supplier publish and sync queues declared in src/SprykerAcademy/Client/RabbitMq
    STEPS+=("docker/sdk console queue:setup")
fi
if has_academy "Client/SymfonyMessenger"; then
    # creates the transports (exchanges, queues) of the queues in src/SprykerAcademy/Client/SymfonyMessenger
    STEPS+=("docker/sdk console messenger:setup-transports")
fi
if has_academy "Shared/SearchElasticsearch"; then
    # creates the supplier search index declared in src/SprykerAcademy/Shared/SearchElasticsearch
    STEPS+=("docker/sdk console search:setup:sources")
fi
if has_academy "Zed/SupplierMerchantPortalGui"; then
    # grants the existing merchant users access to the supplier-merchant-portal-gui bundle
    STEPS+=("docker/sdk console acl-entity:synchronize")
fi
if has_academy "Zed/*/Presentation/Components/entry.ts"; then
    # the Angular components of the merchant portal exercises are part of the merchant portal bundle
    STEPS+=("docker/sdk cli \"[ -d node_modules ] || vendor/bin/console frontend:project:install-dependencies\"")
    STEPS+=("docker/sdk console frontend:mp:build")
fi
if has_academy "Glue/*/resources/api/storefront"; then
    STEPS+=("docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront")
fi
if has_academy "Glue/*/resources/api/backend"; then
    STEPS+=("docker/sdk cli GLUE_APPLICATION=GLUE_BACKEND glue api:generate backend")
fi
if has_academy "Glue/*/resources/api/*"; then
    STEPS+=("docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear")
    [ -d "$PROJECT_DIR/config/GlueBackend" ] && STEPS+=("docker/sdk cli GLUE_APPLICATION=GLUE_BACKEND glue cache:clear")
fi

# Count files
FILE_COUNT=$(find "$PROJECT_DIR/src/SprykerAcademy" -type f 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo -e "${GREEN}Exercise loaded successfully!${NC}"
echo -e "  Package: ${GREEN}$PACKAGE${NC}"
echo -e "  Branch:  ${GREEN}$BRANCH${NC}"
echo -e "  Files:   ${GREEN}$FILE_COUNT${NC} files in src/SprykerAcademy/"
echo ""

if [ "$RUN_STEPS" = "1" ]; then
    log_info "Running the post-load commands..."
    for step in "${STEPS[@]}"; do
        echo -e "  ${YELLOW}\$ $step${NC}"
        # a step is printed for copy & paste, so it is run the way a shell reads it
        # a failed step gets one retry: files the loader just removed on the host can still be on
        # their way into the container (file sync), which makes a cache clear trip over a vanishing directory
        if ! (cd "$PROJECT_DIR" && eval "$step") </dev/null > "$SCRIPT_DIR/.last-step.log" 2>&1 \
            && ! { sleep 5; (cd "$PROJECT_DIR" && eval "$step") </dev/null > "$SCRIPT_DIR/.last-step.log" 2>&1; }; then
            tail -20 "$SCRIPT_DIR/.last-step.log" | sed 's/^/    /'
            log_error "Failed: $step (full output in $(relpath "$SCRIPT_DIR/.last-step.log"))"
            exit 1
        fi
    done
    rm -f "$SCRIPT_DIR/.last-step.log"
    log_success "All post-load commands passed"
else
    echo -e "${YELLOW}Next steps:${NC}"
    for step in "${STEPS[@]}"; do
        echo "  $step"
    done
    echo "  (or load again with --run to have them run for you)"
fi

if [ "$PACKAGE" = "ai-foundation" ]; then
    echo ""
    if [[ "$BRANCH" == */skeleton ]]; then
        echo -e "${YELLOW}This is the skeleton:${NC} complete the TODOs and do the project wiring yourself."
    fi
    if [[ "$BRANCH" == advanced/ai-foundation-hello/* ]]; then
        echo "  Guide: exercises/guides/advanced/02-ai-foundation-hello.md"
        echo -e "${YELLOW}Verify your work:${NC}"
        echo "  docker/sdk cli vendor/bin/codecept build -c tests/SprykerAcademyTest/Glue/HelloAi/"
        echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Glue/HelloAi/ Exercise19"
        echo "  curl -s -X POST http://glue.eu.spryker.local/ai-chats -H 'Content-Type: application/vnd.api+json' -d '{\"data\":{\"type\":\"ai-chats\",\"attributes\":{\"message\":\"Hello world!\"}}}'"
    elif [[ "$BRANCH" == advanced/ai-foundation-catalog/* ]]; then
        echo "  Guide: exercises/guides/advanced/03-ai-foundation-catalog.md"
        echo -e "${YELLOW}Verify your work:${NC}"
        echo "  docker/sdk cli vendor/bin/codecept build -c tests/SprykerAcademyTest/Zed/CatalogAssistant/"
        echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/CatalogAssistant/ Exercise20"
        echo "  curl -s -X POST http://glue.eu.spryker.local/product-questions -H 'Content-Type: application/vnd.api+json' -d '{\"data\":{\"type\":\"product-questions\",\"attributes\":{\"sku\":\"M1000785\",\"question\":\"Is it in stock?\"}}}'"
    else
        echo "  Guide: exercises/guides/advanced/04-ai-foundation-agent.md"
        echo -e "${YELLOW}Verify your work:${NC}"
        echo "  docker/sdk cli vendor/bin/codecept build -c tests/SprykerAcademyTest/Zed/AiProductCreation/"
        echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/AiProductCreation/ Exercise21"
    fi
fi

# Test suites of the loaded branch: every directory with a codeception.yml
if [ "$PACKAGE" != "ai-foundation" ] && [ -d "$PROJECT_DIR/tests/SprykerAcademyTest" ]; then
    SUITES=$(cd "$PROJECT_DIR" && find tests/SprykerAcademyTest -name codeception.yml -exec dirname {} \; | sort)
    if [ -n "$SUITES" ]; then
        echo ""
        echo -e "${YELLOW}Verify your work:${NC}"
        echo "$SUITES" | while read -r suite; do
            echo "  docker/sdk cli vendor/bin/codecept build -c $suite/"
            echo "  docker/sdk cli vendor/bin/codecept run -c $suite/"
        done
    fi
fi
