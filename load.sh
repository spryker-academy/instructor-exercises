#!/bin/bash
#
# Exercise Loader - Loads exercise code into the Spryker project
#
# Usage:
#   ./exercises/load.sh <package> <branch>
#
# Examples:
#   ./exercises/load.sh contact-request basics/contact-request-back-office/skeleton
#   ./exercises/load.sh supplier intermediate/back-office/skeleton
#   ./exercises/load.sh ai-foundation advanced/ai-foundation-hello/skeleton
#
# First run will clone the repos and configure the project automatically.
#

set -e
trap 'echo -e "\033[0;31mload.sh failed at line $LINENO: $BASH_COMMAND\033[0m" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPOS_DIR="$SCRIPT_DIR/repos"

CONTACT_REQUEST_REPO="https://github.com/spryker-academy/contact-request.git"
SUPPLIER_REPO="https://github.com/spryker-academy/supplier.git"
AI_FOUNDATION_REPO="https://github.com/spryker-academy/ai-foundation.git"

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

usage() {
    echo "Usage: ./exercises/load.sh <package> <branch>"
    echo ""
    echo "Packages: contact-request, supplier, ai-foundation"
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
    echo "  basics/extending-core-modules/skeleton"
    echo "  basics/extending-core-modules/complete"
    echo "  basics/extending-core-modules/complete-ajax"
    echo "  basics/configuration/complete"
    echo ""
    echo "Supplier branches:"
    echo "  basics/supplier-table-schema/skeleton"
    echo "  intermediate/back-office/skeleton"
    echo "  intermediate/back-office/complete"
    echo "  intermediate/data-import/skeleton"
    echo "  intermediate/data-import/complete"
    echo "  intermediate/publish-synchronize/skeleton"
    echo "  intermediate/publish-synchronize/complete"
    echo "  intermediate/search/skeleton"
    echo "  intermediate/search/complete"
    echo "  intermediate/storage-client/skeleton"
    echo "  intermediate/storage-client/complete"
    echo "  intermediate/yves-storefront/skeleton"
    echo "  intermediate/yves-storefront/complete"
    echo "  intermediate/glue-storefront/skeleton"
    echo "  intermediate/glue-storefront/complete"
    echo "  intermediate/oms/skeleton"
    echo "  intermediate/oms/complete"
    echo "  intermediate/merchant-portal-table/skeleton"
    echo "  intermediate/merchant-portal-table/complete"
    echo "  intermediate/merchant-portal-form/skeleton"
    echo "  intermediate/merchant-portal-form/complete"
    echo "  intermediate/merchant-portal-locations/skeleton"
    echo "  intermediate/merchant-portal-locations/complete"
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

# Validate arguments
if [ $# -ne 2 ]; then
    usage
fi

PACKAGE="$1"
BRANCH="$2"

if [ "$PACKAGE" != "contact-request" ] && [ "$PACKAGE" != "supplier" ] && [ "$PACKAGE" != "ai-foundation" ]; then
    log_error "Error: Package must be 'contact-request', 'supplier' or 'ai-foundation'"
    usage
fi

# Determine repo URL
if [ "$PACKAGE" = "contact-request" ]; then
    REPO_URL="$CONTACT_REQUEST_REPO"
elif [ "$PACKAGE" = "ai-foundation" ]; then
    REPO_URL="$AI_FOUNDATION_REPO"
else
    REPO_URL="$SUPPLIER_REPO"
fi

REPO_DIR="$REPOS_DIR/$PACKAGE"

# Clone repo if not present
if [ ! -d "$REPO_DIR" ]; then
    log_info "Cloning $PACKAGE repository..."
    mkdir -p "$REPOS_DIR"
    git clone "$REPO_URL" "$REPO_DIR"
fi

# Fetch latest and checkout branch
log_info "Switching to branch: $BRANCH"
cd "$REPO_DIR"
git fetch origin
git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH"
git pull origin "$BRANCH" 2>/dev/null || true
cd "$PROJECT_DIR"

# Verify the branch has src/SprykerAcademy
if [ ! -d "$REPO_DIR/src/SprykerAcademy" ] && [ ! -d "$REPO_DIR/src/Pyz" ]; then
    log_info "Note: This branch has no src/ files (empty skeleton)."
fi

# Clean previous exercise files
log_info "Cleaning previous exercise files..."
rm -rf "$PROJECT_DIR/src/SprykerAcademy"

# Always create SprykerAcademy directory so skeleton exercises have a place to write code
mkdir -p "$PROJECT_DIR/src/SprykerAcademy"

# Copy SprykerAcademy source files if present in the exercise branch
if [ -d "$REPO_DIR/src/SprykerAcademy" ]; then
    cp -R "$REPO_DIR/src/SprykerAcademy/." "$PROJECT_DIR/src/SprykerAcademy/"
fi

# Always add SprykerAcademy namespace to composer.json autoload (skeleton exercises need it too)
if file_needs_update "$PROJECT_DIR/composer.json" '"SprykerAcademy\\\\": "src/SprykerAcademy/"'; then
    php -r '
        $file = $argv[1] . "/composer.json";
        $json = json_decode(file_get_contents($file), true);
        if (!isset($json["autoload"]["psr-4"]["SprykerAcademy\\"])) {
            $json["autoload"]["psr-4"]["SprykerAcademy\\"] = "src/SprykerAcademy/";
            file_put_contents($file, json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
        }
    ' "$PROJECT_DIR"
    log_success "Added SprykerAcademy\\ to composer.json autoload"
fi

# Always add SprykerAcademy to Spryker kernel PROJECT_NAMESPACES (skeleton exercises need it too)
CONFIG_DEFAULT="$PROJECT_DIR/config/Shared/config_default.php"
if file_needs_update "$CONFIG_DEFAULT" "'SprykerAcademy'"; then
    php -r '
        $file = $argv[1];
        $content = file_get_contents($file);
        $content = preg_replace(
            "/(KernelConstants::PROJECT_NAMESPACES\s*\]\s*=\s*\[\s*\n\s*)('\''Pyz'\'')/",
            "$1'\''SprykerAcademy'\'',\n    $2",
            $content,
            1,
        );
        file_put_contents($file, $content);
    ' "$CONFIG_DEFAULT"
    log_success "Added SprykerAcademy to PROJECT_NAMESPACES in config_default.php"
fi

# Copy Pyz overrides if present
if [ -d "$REPO_DIR/src/Pyz" ]; then
    cd "$REPO_DIR/src/Pyz" && find . -type f | while read -r file; do
        mkdir -p "$PROJECT_DIR/src/Pyz/$(dirname "$file")"
        cp "$file" "$PROJECT_DIR/src/Pyz/$file"
    done
    cd "$PROJECT_DIR"
fi

# Copy navigation XML if present in the exercise repo
if [ -f "$REPO_DIR/config/Zed/navigation.xml" ]; then
    # Extract first menu key from exercise navigation.xml for duplicate check
    NAV_KEY=$(grep -oE '<[a-z-]+>' "$REPO_DIR/config/Zed/navigation.xml" | grep -v "<config>" | head -1 | sed 's/[<>]//g')
    if [ -n "$NAV_KEY" ] && file_needs_update "$PROJECT_DIR/config/Zed/navigation.xml" "<$NAV_KEY>"; then
        mkdir -p "$PROJECT_DIR/config/Zed"
        php -r '
            $projectFile = $argv[1] . "/config/Zed/navigation.xml";
            $exerciseFile = $argv[2] . "/config/Zed/navigation.xml";
            
            $projectDom = new DOMDocument();
            $projectDom->preserveWhiteSpace = false;
            $projectDom->formatOutput = true;
            $projectDom->load($projectFile);
            
            $exerciseDom = new DOMDocument();
            $exerciseDom->preserveWhiteSpace = false;
            $exerciseDom->formatOutput = true;
            $exerciseDom->load($exerciseFile);
            
            $projectConfig = $projectDom->getElementsByTagName("config")->item(0);
            
            $firstChild = $projectConfig->firstChild;
            foreach ($exerciseDom->documentElement->childNodes as $child) {
                if ($child->nodeType !== XML_ELEMENT_NODE) continue;
                $name = $child->nodeName;
                if ($projectConfig->getElementsByTagName($name)->item(0)) continue;
                $importedNode = $projectDom->importNode($child, true);
                $projectConfig->insertBefore($importedNode, $firstChild);
            }
            
            $projectDom->save($projectFile);
        ' "$PROJECT_DIR" "$REPO_DIR"
        log_success "Merged navigation.xml entries"
    fi
fi

# Copy merchant portal navigation XML if present in the exercise repo
if [ -f "$REPO_DIR/config/Zed/navigation-main-merchant-portal.xml" ]; then
    NAV_KEY=$(grep -oE '<[a-z-]+>' "$REPO_DIR/config/Zed/navigation-main-merchant-portal.xml" | grep -v "<config>" | head -1 | sed 's/[<>]//g')
    if [ -n "$NAV_KEY" ] && [ -f "$PROJECT_DIR/config/Zed/navigation-main-merchant-portal.xml" ] && file_needs_update "$PROJECT_DIR/config/Zed/navigation-main-merchant-portal.xml" "<$NAV_KEY>"; then
        php -r '
            $projectFile = $argv[1] . "/config/Zed/navigation-main-merchant-portal.xml";
            $exerciseFile = $argv[2] . "/config/Zed/navigation-main-merchant-portal.xml";

            $projectDom = new DOMDocument();
            $projectDom->preserveWhiteSpace = false;
            $projectDom->formatOutput = true;
            $projectDom->load($projectFile);

            $exerciseDom = new DOMDocument();
            $exerciseDom->preserveWhiteSpace = false;
            $exerciseDom->formatOutput = true;
            $exerciseDom->load($exerciseFile);

            $projectConfig = $projectDom->getElementsByTagName("config")->item(0);

            foreach ($exerciseDom->documentElement->childNodes as $child) {
                if ($child->nodeType !== XML_ELEMENT_NODE) continue;
                $name = $child->nodeName;
                if ($projectConfig->getElementsByTagName($name)->item(0)) continue;
                $importedNode = $projectDom->importNode($child, true);
                $projectConfig->appendChild($importedNode);
            }

            $projectDom->save($projectFile);
        ' "$PROJECT_DIR" "$REPO_DIR"
        log_success "Merged merchant portal navigation entries"
    fi
fi

# ContactRequest config value in config_default.php (Exercise 6, Configuration).
# Always removed first: the constant class lives in src/SprykerAcademy, which was just replaced. Added again below when the loaded branch ships it.
CONFIG_FILE="$PROJECT_DIR/config/Shared/config_default.php"
if grep -q "ContactRequest exercise config value\|contact-request exercise" "$CONFIG_FILE" 2>/dev/null; then
    php -r '
        $file = $argv[1];
        $content = file_get_contents($file);
        // block written by this loader version
        $content = preg_replace("/\n[ \t]*\/\/ >>> contact-request exercise.*?\/\/ <<< contact-request exercise[^\n]*/s", "", $content);
        // block written by an earlier loader version
        $content = preg_replace("/\n*\/\/ ContactRequest exercise config value\nuse SprykerAcademy\\\\Shared\\\\ContactRequest\\\\ContactRequestConstants;\n\n\\\$config\[ContactRequestConstants::MY_CONFIG_VALUE\][^\n]*\n?/", "\n", $content);
        file_put_contents($file, rtrim($content) . "\n");
    ' "$CONFIG_FILE"
    log_success "Removed the ContactRequest config value from config_default.php"
fi
if [ ! -f "$PROJECT_DIR/src/SprykerAcademy/Shared/ContactRequest/ContactRequestConstants.php" ] && grep -q "ContactRequestConstants" "$CONFIG_FILE" 2>/dev/null; then
    log_error "Warning: config/Shared/config_default.php still references ContactRequestConstants, which this branch does not contain (manual wiring from Exercise 6)."
    log_error "         Remove those lines, or every console command will fail with a class not found error."
fi
if [ "$PACKAGE" = "contact-request" ] && [ -f "$PROJECT_DIR/src/SprykerAcademy/Shared/ContactRequest/ContactRequestConstants.php" ]; then
    cat >> "$CONFIG_FILE" << 'PHPEOF'

// >>> contact-request exercise
$config[\SprykerAcademy\Shared\ContactRequest\ContactRequestConstants::MY_CONFIG_VALUE] = 'Hello from config!';
// <<< contact-request exercise
PHPEOF
    log_success "Added the ContactRequest config value to config_default.php"
fi

# Register the SprykerAcademy source directory in every API Platform application config and reset their kernel caches
register_api_platform_sources() {
    local updated=0
    for API_CONFIG in "$PROJECT_DIR/config/Glue/packages/spryker_api_platform.php" "$PROJECT_DIR/config/GlueStorefront/packages/spryker_api_platform.php" "$PROJECT_DIR/config/GlueBackend/packages/spryker_api_platform.php"; do
        [ -f "$API_CONFIG" ] || continue
        php -r '
            $file = $argv[1];
            $content = file_get_contents($file);
            if (preg_match("/[\x27\"]src\/SprykerAcademy[\x27\"]/", $content)) {
                exit(0);
            }
            // Insert right after the src/Pyz entry of sourceDirectories([...])
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
        ' "$API_CONFIG" | grep -q "updated" && { log_success "Added SprykerAcademy to API Platform source directories in $(echo "$API_CONFIG" | sed "s#$PROJECT_DIR/##")"; updated=1; }
    done
    # The compiled Glue kernels cache the source directory list; cache:empty-all does not touch them
    rm -rf "$PROJECT_DIR"/data/cache/Glue "$PROJECT_DIR"/data/cache/GlueStorefront "$PROJECT_DIR"/data/cache/GlueBackend 2>/dev/null
    [ "$updated" = 1 ] && log_success "Reset the Glue kernel caches (data/cache/Glue*)"
    return 0
}

# Always remove the Glue service registration of a previous load (the registered directories may no longer exist)
for SERVICES_FILE in "$PROJECT_DIR/config/Glue/ApplicationServices.php" "$PROJECT_DIR/config/GlueBackend/ApplicationServices.php" "$PROJECT_DIR/config/GlueStorefront/ApplicationServices.php"; do
    [ -f "$SERVICES_FILE" ] || continue
    if grep -q "supplier exercise\|services->load('SprykerAcademy" "$SERVICES_FILE"; then
        php -r '
            $file = $argv[1];
            $content = file_get_contents($file);
            $content = preg_replace("/\n[ \t]*\/\/ >>> supplier exercise.*?\/\/ <<< supplier exercise[^\n]*/s", "", $content);
            // line written by an earlier loader version
            $content = preg_replace("/\n[ \t]*\\\$services->load\(\x27SprykerAcademy[^\n]*/", "", $content);
            file_put_contents($file, preg_replace("/\n{2,}(};)\s*$/", "\n$1\n", $content));
        ' "$SERVICES_FILE"
        log_success "Removed the SprykerAcademy service registration from $(echo "$SERVICES_FILE" | sed "s#$PROJECT_DIR/##")"
    fi
done

# Copy config and data files for supplier package
if [ "$PACKAGE" = "supplier" ]; then
    # Copy various config files
    [ -f "$REPO_DIR/config/Zed/oms/Demo01.xml" ] && mkdir -p "$PROJECT_DIR/config/Zed/oms" && cp "$REPO_DIR/config/Zed/oms/Demo01.xml" "$PROJECT_DIR/config/Zed/oms/Demo01.xml"
    [ -f "$REPO_DIR/data/import/supplier.csv" ] && mkdir -p "$PROJECT_DIR/data/import" && cp "$REPO_DIR/data/import/supplier.csv" "$PROJECT_DIR/data/import/supplier.csv"
    [ -f "$REPO_DIR/data/import/supplier_location.csv" ] && cp "$REPO_DIR/data/import/supplier_location.csv" "$PROJECT_DIR/data/import/supplier_location.csv"

    # Add supplier data import entries to full_EU.yml if not present
    IMPORT_YAML="$PROJECT_DIR/data/import/local/full_EU.yml"
    if file_needs_update "$IMPORT_YAML" 'data_entity: supplier$'; then
        cat >> "$IMPORT_YAML" << 'YAMLEOF'

  # Supplier Academy exercises
  - data_entity: supplier
    source: data/import/supplier.csv
  - data_entity: supplier-location
    source: data/import/supplier_location.csv
YAMLEOF
        log_success "Added supplier import entries to full_EU.yml"
    fi

    # Create supplier queues in RabbitMQ via management API (for branches with pub/sync)
    if [ -f "$REPO_DIR/src/SprykerAcademy/Shared/SupplierSearch/SupplierSearchConfig.php" ]; then
        if command -v curl > /dev/null 2>&1; then
            RMQ_API="http://queue.spryker.local/api"
            RMQ_AUTH="spryker:secret"
            for QUEUE in publish.search.supplier publish.storage.supplier sync.search.supplier sync.storage.supplier; do
                curl -s -o /dev/null -u "$RMQ_AUTH" -X PUT "$RMQ_API/queues/eu-docker/$QUEUE" -H 'Content-Type: application/json' -d '{"durable":true,"auto_delete":false}' 2>/dev/null || true
                curl -s -o /dev/null -u "$RMQ_AUTH" -X PUT "$RMQ_API/exchanges/eu-docker/$QUEUE" -H 'Content-Type: application/json' -d '{"type":"direct","durable":true}' 2>/dev/null || true
                curl -s -o /dev/null -u "$RMQ_AUTH" -X POST "$RMQ_API/bindings/eu-docker/e/$QUEUE/q/$QUEUE" -H 'Content-Type: application/json' -d '{}' 2>/dev/null || true
            done
            log_success "Ensured supplier queues and exchanges exist in RabbitMQ"
        fi
    fi

    register_api_platform_sources

    # Register the SprykerAcademy Zed (facades) and Client services in the Glue application containers (marked block, see unwiring above)
    if [ -d "$REPO_DIR/src/SprykerAcademy/Glue" ]; then
        # config/Glue serves glue.eu.spryker.local (storefront and backend resources), so it needs both layers
        for APP_SERVICES in Glue:Zed Glue:Client GlueBackend:Zed GlueStorefront:Client; do
            SERVICES_FILE="$PROJECT_DIR/config/${APP_SERVICES%%:*}/ApplicationServices.php"
            LAYER="${APP_SERVICES##*:}"
            [ -f "$SERVICES_FILE" ] || continue
            php -r '
                $file = $argv[1];
                $layer = $argv[2];
                $content = file_get_contents($file);
                $block = "\n    // >>> supplier exercise\n"
                    . "    \$configurator->services()\n"
                    . "        ->defaults()\n        ->autowire()\n        ->public()\n        ->autoconfigure()\n"
                    . "        ->load(\x27SprykerAcademy\\\\" . $layer . "\\\\\x27, \x27../../src/SprykerAcademy/" . $layer . "/\x27);\n"
                    . "    // <<< supplier exercise\n";
                $content = preg_replace_callback("/\n(};)\s*$/", fn ($m) => $block . $m[1] . "\n", $content, 1, $count);
                if ($count) { file_put_contents($file, $content); echo "updated"; }
            ' "$SERVICES_FILE" "$LAYER" | grep -q updated && log_success "Registered SprykerAcademy\\$LAYER services in config/${APP_SERVICES%%:*}/ApplicationServices.php"
        done
    fi
fi

# ---------------------------------------------------------------------------
# Contact Request package: Yves wiring in the project (marked lines, removed again on every load)
# ---------------------------------------------------------------------------
CR_WIRING_MARKER="contact-request exercise"
YVES_ROUTER="$PROJECT_DIR/src/Pyz/Yves/Router/RouterDependencyProvider.php"
SIDEBAR_TWIG="$PROJECT_DIR/src/Pyz/Yves/CustomerPage/Theme/default/components/molecules/navigation-sidebar/navigation-sidebar.twig"

# Always remove the wiring of a previous load: the classes it points to live in src/SprykerAcademy, which was just replaced
if [ -f "$YVES_ROUTER" ] && grep -q "// $CR_WIRING_MARKER" "$YVES_ROUTER"; then
    php -r '
        $file = $argv[1];
        $marker = preg_quote($argv[2], "/");
        $content = file_get_contents($file);
        // a line that replaced a core plugin gets the core plugin back
        $content = preg_replace("/^([ \t]*)new [^\n]*\/\/ " . $marker . " \(replaces ([A-Za-z]+)\)[^\n]*$/m", "$1new $2(),", $content);
        // every other marked line disappears
        $content = preg_replace("/\n[^\n]*\/\/ " . $marker . "[^\n]*/", "", $content);
        file_put_contents($file, $content);
    ' "$YVES_ROUTER" "$CR_WIRING_MARKER"
    log_success "Removed the Contact Request routes from src/Pyz/Yves/Router/RouterDependencyProvider.php"
fi
if [ -f "$SIDEBAR_TWIG" ] && grep -q "{# >>> $CR_WIRING_MARKER #}" "$SIDEBAR_TWIG"; then
    php -r '
        $file = $argv[1];
        $marker = preg_quote($argv[2], "/");
        $content = file_get_contents($file);
        $content = preg_replace("/\n[ \t]*\{# >>> " . $marker . " #\}.*?\{# <<< " . $marker . " #\}[^\n]*/s", "", $content);
        file_put_contents($file, $content);
    ' "$SIDEBAR_TWIG" "$CR_WIRING_MARKER"
    log_success "Removed the Contact Request menu item from navigation-sidebar.twig"
fi

if [ "$PACKAGE" = "contact-request" ]; then
    CR_CUSTOMER_ROUTE_PLUGIN="$PROJECT_DIR/src/SprykerAcademy/Yves/CustomerPage/Plugin/Router/CustomerPageRouteProviderPlugin.php"

    # Exercise 7 (extending core modules): the routes come from src/SprykerAcademy/Yves/Router. On the complete branches the account
    # sidebar of the project gets the link; in the skeleton the route does not exist yet (path() would fail), so adding it is a student step.
    if [ -f "$CR_CUSTOMER_ROUTE_PLUGIN" ] && [[ "$BRANCH" != */skeleton ]]; then
        if [ -f "$SIDEBAR_TWIG" ]; then
            php -r '
                $file = $argv[1];
                $marker = $argv[2];
                $content = file_get_contents($file);
                $item = "        {# >>> " . $marker . " #}\n"
                    . "        {\n"
                    . "            name: \x27messages\x27,\n"
                    . "            url: path(\x27customer/messages\x27),\n"
                    . "            label: \x27My Contact Requests\x27,\n"
                    . "            icon: \x27envelopes\x27,\n"
                    . "        },\n"
                    . "        {# <<< " . $marker . " #}";
                // last element of the items array in the data definition
                $content = preg_replace_callback(
                    "/(items:\s*\[.*?)(\n[ \t]*\]\s*\n\s*\}\s*%\})/s",
                    fn ($m) => $m[1] . "\n" . $item . $m[2],
                    $content,
                    1,
                    $count,
                );
                if ($count) { file_put_contents($file, $content); echo "updated"; }
            ' "$SIDEBAR_TWIG" "$CR_WIRING_MARKER" | grep -q updated && log_success "Added the My Contact Requests item to navigation-sidebar.twig" \
                || log_error "Warning: could not add the menu item to navigation-sidebar.twig (add a link to customer/messages yourself)"
        fi
    fi
fi

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
MISSING_REFS=$(grep -rhoE "SprykerAcademy(\\\\[A-Za-z0-9_]+)+" "$PROJECT_DIR/src/Pyz" "$PROJECT_DIR/config" --include="*.php" 2>/dev/null | sort -u | while read -r class; do
    rel=$(echo "${class#SprykerAcademy\\}" | tr '\\' '/')
    [ -f "$PROJECT_DIR/src/SprykerAcademy/$rel.php" ] || echo "$class"
done)
if [ -n "$MISSING_REFS" ]; then
    log_error "Warning: src/Pyz or config still references classes this branch does not contain:"
    echo "$MISSING_REFS" | sed 's/^/           /'
    log_error "         Remove those references (manual wiring from another exercise), or the application will fail."
fi

# Copy exercise tests if present
if [ -d "$REPO_DIR/tests/SprykerAcademyTest" ]; then
    log_info "Installing exercise tests..."
    rm -rf "$PROJECT_DIR/tests/SprykerAcademyTest"
    cp -R "$REPO_DIR/tests/SprykerAcademyTest" "$PROJECT_DIR/tests/SprykerAcademyTest"

    if file_needs_update "$PROJECT_DIR/composer.json" '"SprykerAcademyTest\\\\'; then
        php -r '
            $file = $argv[1] . "/composer.json";
            $json = json_decode(file_get_contents($file), true);
            if (!isset($json["autoload-dev"]["psr-4"]["SprykerAcademyTest\\"])) {
                $json["autoload-dev"]["psr-4"]["SprykerAcademyTest\\"] = "tests/SprykerAcademyTest/";
                file_put_contents($file, json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
            }
        ' "$PROJECT_DIR"
        log_success "Added SprykerAcademyTest\\ to composer.json autoload-dev"
    fi
fi

# Count files
FILE_COUNT=$(find "$PROJECT_DIR/src/SprykerAcademy" -type f 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo -e "${GREEN}Exercise loaded successfully!${NC}"
echo -e "  Package: ${GREEN}$PACKAGE${NC}"
echo -e "  Branch:  ${GREEN}$BRANCH${NC}"
echo -e "  Files:   ${GREEN}$FILE_COUNT${NC} files in src/SprykerAcademy/"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
if [ "$PACKAGE" = "ai-foundation" ]; then
    # dump-autoload must run first: config_ai.php references a SprykerAcademy class
    # cache:empty-all deletes data/cache, which holds the Propel table map (data/cache/propel/generated-conf/loadDatabase.php);
    # propel:install (propel:model:build) writes it again, so it must run after cache:empty-all
    echo "  docker/sdk cli composer dump-autoload"
    echo "  docker/sdk console transfer:generate"
    echo "  docker/sdk console c:e"
    echo "  docker/sdk console propel:install"
    # cache:empty-all also deletes data/cache/configuration (the synced configuration schemas the AI configuration references)
    echo "  docker/sdk console configuration:sync"
    if [[ "$BRANCH" == advanced/ai-foundation-hello/* ]] || [[ "$BRANCH" == advanced/ai-foundation-catalog/* ]]; then
        echo "  docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate"
        echo "  docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear"
        echo "  docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue cache:clear"
    fi
else
    # cache:empty-all deletes data/cache, which holds the Propel table map (data/cache/propel/generated-conf/loadDatabase.php);
    # propel:install (propel:model:build) writes it again, so it must run after cache:empty-all
    echo "  docker/sdk console c:e"
    echo "  docker/sdk cli composer dump-autoload"
    echo "  docker/sdk console propel:install"
    echo "  docker/sdk console transfer:generate"
    if [ -d "$PROJECT_DIR/src/SprykerAcademy/Zed/SupplierMerchantPortalGui" ]; then
        echo "  docker/sdk console acl-entity:synchronize   # grants the existing merchant users access to the supplier-merchant-portal-gui bundle"
    fi
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

# Show test run command for contact-request package
if [ "$PACKAGE" = "contact-request" ] && [ -d "$PROJECT_DIR/tests/SprykerAcademyTest" ]; then
    echo ""
    echo -e "${YELLOW}Verify your work:${NC}"

    case "$BRANCH" in
        basics/contact-request-back-office/*)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise1"
            ;;
        basics/data-transfer-object/*)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise1"
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise2"
            ;;
        basics/contact-request-table-schema/*)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise1"
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise2"
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise3"
            ;;
        basics/module-layers/*|basics/extending-core-modules/*|basics/configuration/*)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/"
            ;;
        *)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/"
            ;;
    esac
fi
