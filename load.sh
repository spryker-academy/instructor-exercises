#!/bin/bash
#
# Exercise Loader - Loads exercise code into the Spryker project
#
# Usage:
#   ./exercises/load.sh <package> <branch>
#
# Examples:
#   ./exercises/load.sh hello-world basics/hello-world-back-office/skeleton
#   ./exercises/load.sh supplier intermediate/back-office/skeleton
#
# First run will clone the repos and configure the project automatically.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPOS_DIR="$SCRIPT_DIR/repos"

HELLO_WORLD_REPO="https://github.com/spryker-academy/hello-world.git"
SUPPLIER_REPO="https://github.com/spryker-academy/supplier.git"

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

# Determine branch type for conditional configuration
# Returns: skip, skeleton, or complete
get_branch_type() {
    local branch="$1"
    case "$branch" in
        intermediate/back-office/*|intermediate/data-import/*|intermediate/yves-storefront/*)
            echo "skip"
            ;;
        intermediate/publish-synchronize/skeleton)
            echo "skeleton"
            ;;
        *)
            echo "complete"
            ;;
    esac
}

# Generic PHP file modifier - adds use statements and modifies content
modify_php_file() {
    local file="$1"
    local use_statements="$2"
    local modification_code="$3"
    
    php -r "
        \$file = '$file';
        \$content = file_get_contents(\$file);
        
        // Add use statements - convert \\n to actual newlines
        \$useStatements = str_replace('\\n', \"\n\", '$use_statements');
        if (!empty(\$useStatements)) {
            // Extract class name from first use statement for duplicate check
            \$firstUseClass = '';
            if (preg_match('/use\\s+([^;]+);/', \$useStatements, \$matches)) {
                \$firstUseClass = trim(\$matches[1]);
            }
            // Only add if the first use class is not already present
            if (!empty(\$firstUseClass) && strpos(\$content, \$firstUseClass) === false) {
                // Find the last use statement and add after it, or before class declaration
                if (preg_match('/use\\s+[^;]+;.*\n/', \$content)) {
                    // Add after last use statement
                    \$content = preg_replace('/(use\\s+[^;]+;.*\n)(?!.*use\\s+)/s', \"\$1\" . \$useStatements . \"\n\", \$content, 1);
                } else {
                    // No use statements, add before class declaration
                    \$content = preg_replace('/(^class\s)/m', \$useStatements . \"\n\$1\", \$content, 1);
                }
            }
        }
        
        // Apply modifications
        $modification_code
        
        file_put_contents(\$file, \$content);
    "
}

usage() {
    echo "Usage: ./exercises/load.sh <package> <branch>"
    echo ""
    echo "Packages: hello-world, supplier"
    echo ""
    echo "Hello World branches:"
    echo "  basics/hello-world-back-office/skeleton"
    echo "  basics/hello-world-back-office/complete"
    echo "  basics/data-transfer-object/skeleton"
    echo "  basics/data-transfer-object/complete"
    echo "  basics/message-table-schema/skeleton"
    echo "  basics/message-table-schema/complete"
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
    exit 1
}

# Validate arguments
if [ $# -ne 2 ]; then
    usage
fi

PACKAGE="$1"
BRANCH="$2"

if [ "$PACKAGE" != "hello-world" ] && [ "$PACKAGE" != "supplier" ]; then
    log_error "Error: Package must be 'hello-world' or 'supplier'"
    usage
fi

# Determine repo URL
if [ "$PACKAGE" = "hello-world" ]; then
    REPO_URL="$HELLO_WORLD_REPO"
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

# Copy SprykerAcademy source files
if [ -d "$REPO_DIR/src/SprykerAcademy" ]; then
    cp -R "$REPO_DIR/src/SprykerAcademy" "$PROJECT_DIR/src/SprykerAcademy"

    # Add SprykerAcademy namespace to composer.json autoload if not already present
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

    # Add SprykerAcademy to Spryker kernel PROJECT_NAMESPACES if not already present
    CONFIG_DEFAULT="$PROJECT_DIR/config/Shared/config_default.php"
    if file_needs_update "$CONFIG_DEFAULT" "'SprykerAcademy'"; then
        php -r '
            $file = $argv[1];
            $content = file_get_contents($file);
            $content = preg_replace(
                "/(KernelConstants::PROJECT_NAMESPACES\s*\]\s*=\s*\[\s*\n\s*'\''Pyz'\'')/",
                "$1,\n    '\''SprykerAcademy'\''",
                $content,
                1,
            );
            file_put_contents($file, $content);
        ' "$CONFIG_DEFAULT"
        log_success "Added SprykerAcademy to PROJECT_NAMESPACES in config_default.php"
    fi
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
    NAV_KEY=$(grep -oP '(?<=<)[a-z-]+(?=>)' "$REPO_DIR/config/Zed/navigation.xml" | head -1)
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
            
            foreach ($exerciseDom->documentElement->childNodes as $child) {
                if ($child->nodeType !== XML_ELEMENT_NODE) continue;
                $name = $child->nodeName;
                if ($projectConfig->getElementsByTagName($name)->item(0)) continue;
                $importedNode = $projectDom->importNode($child, true);
                $projectConfig->appendChild($importedNode);
            }
            
            $projectDom->save($projectFile);
        ' "$PROJECT_DIR" "$REPO_DIR"
        log_success "Merged navigation.xml entries"
    fi
fi

# Register supplier in SearchElasticsearchConfig for search exercise
if [ "$PACKAGE" = "supplier" ]; then
    SEARCH_ES_CONFIG="$PROJECT_DIR/src/Pyz/Shared/SearchElasticsearch/SearchElasticsearchConfig.php"
    if [ -f "$SEARCH_ES_CONFIG" ] && ! grep -q "'supplier'" "$SEARCH_ES_CONFIG"; then
        php -r '
            $file = $argv[1];
            $content = file_get_contents($file);
            // Add supplier to SUPPORTED_SOURCE_IDENTIFIERS array
            $content = preg_replace(
                "/(protected const SUPPORTED_SOURCE_IDENTIFIERS = \[)([^\]]*)(\])/s",
                "$1$2        \x27supplier\x27,\n$3",
                $content
            );
            file_put_contents($file, $content);
        ' "$SEARCH_ES_CONFIG"
        log_success "Added 'supplier' to SearchElasticsearchConfig SUPPORTED_SOURCE_IDENTIFIERS"
    fi
fi

# Add HelloWorld config value to config_default.php for configuration exercise
if [ "$PACKAGE" = "hello-world" ]; then
    CONFIG_FILE="$PROJECT_DIR/config/Shared/config_default.php"
    if file_needs_update "$CONFIG_FILE" 'HelloWorldConstants'; then
        cat >> "$CONFIG_FILE" << 'PHPEOF'

// HelloWorld exercise config value
use SprykerAcademy\Shared\HelloWorld\HelloWorldConstants;

$config[HelloWorldConstants::MY_CONFIG_VALUE] = 'Hello from config!';
PHPEOF
        log_success "Added HelloWorld config value to config_default.php"
    fi
fi

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

    # Register supplier data import plugins in DataImportDependencyProvider
    DI_PROVIDER="$PROJECT_DIR/src/Pyz/Zed/DataImport/DataImportDependencyProvider.php"
    if file_needs_update "$DI_PROVIDER" 'SupplierDataImportPlugin'; then
        modify_php_file "$DI_PROVIDER" \
            'use SprykerAcademy\\Zed\\SupplierDataImport\\Communication\\Plugin\\DataImport\\SupplierDataImportPlugin;\nuse SprykerAcademy\\Zed\\SupplierDataImport\\Communication\\Plugin\\DataImport\\SupplierLocationDataImportPlugin;\n' \
            '
                if (strpos($content, "SupplierDataImportPlugin") === false) {
                    $content = preg_replace(
                        "/(function\s+getDataImporterPlugins.*?)(\s*\];)/s",
                        "$1\n    new SupplierDataImportPlugin(),\n    new SupplierLocationDataImportPlugin(),\n$2",
                        $content, 1
                    );
                }
            '
        log_success "Registered SupplierDataImportPlugin in DataImportDependencyProvider"
    fi

    # Get branch type for conditional SupplierSearch/Storage configuration
    BRANCH_TYPE=$(get_branch_type "$BRANCH")
    
    if [ "$BRANCH_TYPE" != "skip" ]; then
        # Common use statements for SupplierSearch/Storage
        USE_SEARCH_STORAGE=$'use SprykerAcademy\\Shared\\SupplierSearch\\SupplierSearchConfig;\\nuse SprykerAcademy\\Shared\\SupplierStorage\\SupplierStorageConfig;'
        USE_PUBLISHER_PLUGINS="${USE_SEARCH_STORAGE}"$'\\nuse SprykerAcademy\\Zed\\SupplierSearch\\Communication\\Plugin\\Publisher\\SupplierSearchWritePublisherPlugin;\\nuse SprykerAcademy\\Zed\\SupplierStorage\\Communication\\Plugin\\Publisher\\SupplierStorageWritePublisherPlugin;\\n'
        
        # Register supplier publisher plugins in PublisherDependencyProvider
        PUB_PROVIDER="$PROJECT_DIR/src/Pyz/Zed/Publisher/PublisherDependencyProvider.php"
        if file_needs_update "$PUB_PROVIDER" 'SupplierSearchWritePublisherPlugin'; then
            if [ "$BRANCH_TYPE" = "skeleton" ]; then
                modify_php_file "$PUB_PROVIDER" "$USE_PUBLISHER_PLUGINS" '
                    if (strpos($content, "getSupplierPublisherPlugins") === false) {
                        $method = "\n    protected function getSupplierPublisherPlugins(): array\n    {\n        // TODO: Register supplier publisher plugins\n        // Hint: Map SupplierSearchConfig::SUPPLIER_PUBLISH_SEARCH_QUEUE => [new SupplierSearchWritePublisherPlugin()]\n        // Hint: Map SupplierStorageConfig::SUPPLIER_PUBLISH_STORAGE_QUEUE => [new SupplierStorageWritePublisherPlugin()]\n        return [\n        ];\n    }\n";
                        $content = preg_replace("/(\n}\s*$)/", $method . "$1", $content, 1);
                        $content = preg_replace(
                            "/(function\s+getPublisherPlugins.*?return\s+array_merge\s*\()/s",
                            "$1\n            \$this->getSupplierPublisherPlugins(),",
                            $content, 1
                        );
                    }
                '
                log_success "Added Supplier publisher plugin TODOs in PublisherDependencyProvider"
            else
                modify_php_file "$PUB_PROVIDER" "$USE_PUBLISHER_PLUGINS" '
                    if (strpos($content, "getSupplierPublisherPlugins") === false) {
                        $method = "\n    protected function getSupplierPublisherPlugins(): array\n    {\n        return [\n            SupplierSearchConfig::SUPPLIER_PUBLISH_SEARCH_QUEUE => [\n                new SupplierSearchWritePublisherPlugin(),\n            ],\n            SupplierStorageConfig::SUPPLIER_PUBLISH_STORAGE_QUEUE => [\n                new SupplierStorageWritePublisherPlugin(),\n            ],\n        ];\n    }\n";
                        $content = preg_replace("/(\n}\s*$)/", $method . "$1", $content, 1);
                        $content = preg_replace(
                            "/(function\s+getPublisherPlugins.*?return\s+array_merge\s*\()/s",
                            "$1\n            \$this->getSupplierPublisherPlugins(),",
                            $content, 1
                        );
                    }
                '
                log_success "Registered Supplier publisher plugins in PublisherDependencyProvider"
            fi
        fi

        # Register supplier queue processors in QueueDependencyProvider
        QUEUE_PROVIDER="$PROJECT_DIR/src/Pyz/Zed/Queue/QueueDependencyProvider.php"
        if file_needs_update "$QUEUE_PROVIDER" 'SUPPLIER_PUBLISH_SEARCH_QUEUE\|SUPPLIER_SYNC_SEARCH_QUEUE'; then
            if [ "$BRANCH_TYPE" = "skeleton" ]; then
                modify_php_file "$QUEUE_PROVIDER" "$USE_SEARCH_STORAGE" '
                    if (strpos($content, "SupplierSearchConfig::SUPPLIER_PUBLISH_SEARCH_QUEUE") === false) {
                        $supplierQueues = "\n            // TODO: Register supplier queue processors\n            // Hint: Map SupplierSearchConfig::SUPPLIER_PUBLISH_SEARCH_QUEUE => new EventQueueMessageProcessorPlugin()\n            // Hint: Map SupplierStorageConfig::SUPPLIER_PUBLISH_STORAGE_QUEUE => new EventQueueMessageProcessorPlugin()\n            // Hint: Map SupplierSearchConfig::SUPPLIER_SYNC_SEARCH_QUEUE => new SynchronizationSearchQueueMessageProcessorPlugin()\n            // Hint: Map SupplierStorageConfig::SUPPLIER_SYNC_STORAGE_QUEUE => new SynchronizationStorageQueueMessageProcessorPlugin()";
                        $content = preg_replace("/(function\s+getProcessorMessagePlugins.*?return\s*\[)/s", "$1" . $supplierQueues, $content, 1);
                    }
                '
                log_success "Added Supplier queue processor TODOs in QueueDependencyProvider"
            else
                modify_php_file "$QUEUE_PROVIDER" "$USE_SEARCH_STORAGE" '
                    if (strpos($content, "SupplierSearchConfig::SUPPLIER_PUBLISH_SEARCH_QUEUE") === false) {
                        $supplierQueues = "\n            SupplierSearchConfig::SUPPLIER_PUBLISH_SEARCH_QUEUE => new EventQueueMessageProcessorPlugin(),\n            SupplierStorageConfig::SUPPLIER_PUBLISH_STORAGE_QUEUE => new EventQueueMessageProcessorPlugin(),\n            SupplierSearchConfig::SUPPLIER_SYNC_SEARCH_QUEUE => new SynchronizationSearchQueueMessageProcessorPlugin(),\n            SupplierStorageConfig::SUPPLIER_SYNC_STORAGE_QUEUE => new SynchronizationStorageQueueMessageProcessorPlugin(),";
                        $content = preg_replace("/(function\s+getProcessorMessagePlugins.*?return\s*\[)/s", "$1" . $supplierQueues, $content, 1);
                    }
                '
                log_success "Registered Supplier queue processors in QueueDependencyProvider"
            fi
        fi

        # Create supplier queues in RabbitMQ via management API
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

        # Register supplier queues in RabbitMqConfig and SymfonyMessengerConfig
        for CONFIG_CLASS in "RabbitMqConfig:$PROJECT_DIR/src/Pyz/Client/RabbitMq/RabbitMqConfig.php" "SymfonyMessengerConfig:$PROJECT_DIR/src/Pyz/Client/SymfonyMessenger/SymfonyMessengerConfig.php"; do
            IFS=':' read -r CLASS_NAME CONFIG_FILE <<< "$CONFIG_CLASS"
            if [ -f "$CONFIG_FILE" ] && file_needs_update "$CONFIG_FILE" 'SUPPLIER_PUBLISH_SEARCH_QUEUE'; then
                if [ "$BRANCH_TYPE" = "skeleton" ]; then
                    modify_php_file "$CONFIG_FILE" "$USE_SEARCH_STORAGE" '
                        if (strpos($content, "SupplierSearchConfig::SUPPLIER_PUBLISH_SEARCH_QUEUE") === false) {
                            $content = preg_replace(
                                "/(function\s+getPublishQueueConfiguration.*?return\s*\[)/s",
                                "$1\n            // TODO: Register supplier publish queues\n            // Hint: Add SupplierSearchConfig::SUPPLIER_PUBLISH_SEARCH_QUEUE\n            // Hint: Add SupplierStorageConfig::SUPPLIER_PUBLISH_STORAGE_QUEUE",
                                $content, 1
                            );
                        }
                        if (strpos($content, "SupplierSearchConfig::SUPPLIER_SYNC_SEARCH_QUEUE") === false) {
                            $content = preg_replace(
                                "/(function\s+getSynchronizationQueueConfiguration.*?return\s*\[)/s",
                                "$1\n            // TODO: Register supplier sync queues\n            // Hint: Add SupplierSearchConfig::SUPPLIER_SYNC_SEARCH_QUEUE\n            // Hint: Add SupplierStorageConfig::SUPPLIER_SYNC_STORAGE_QUEUE",
                                $content, 1
                            );
                        }
                    '
                    log_success "Added Supplier queue TODOs in $CLASS_NAME"
                else
                    modify_php_file "$CONFIG_FILE" "$USE_SEARCH_STORAGE" '
                        if (strpos($content, "SupplierSearchConfig::SUPPLIER_PUBLISH_SEARCH_QUEUE") === false) {
                            $content = preg_replace(
                                "/(function\s+getPublishQueueConfiguration.*?return\s*\[)/s",
                                "$1\n            SupplierSearchConfig::SUPPLIER_PUBLISH_SEARCH_QUEUE,\n            SupplierStorageConfig::SUPPLIER_PUBLISH_STORAGE_QUEUE,",
                                $content, 1
                            );
                        }
                        if (strpos($content, "SupplierSearchConfig::SUPPLIER_SYNC_SEARCH_QUEUE") === false) {
                            $content = preg_replace(
                                "/(function\s+getSynchronizationQueueConfiguration.*?return\s*\[)/s",
                                "$1\n            SupplierSearchConfig::SUPPLIER_SYNC_SEARCH_QUEUE,\n            SupplierStorageConfig::SUPPLIER_SYNC_STORAGE_QUEUE,",
                                $content, 1
                            );
                        }
                    '
                    log_success "Registered Supplier queues in $CLASS_NAME"
                fi
            fi
        done
    fi

    # Register SprykerAcademy source directory in API Platform configs
    for API_CONFIG in "$PROJECT_DIR/config/GlueStorefront/packages/spryker_api_platform.php" "$PROJECT_DIR/config/GlueBackend/packages/spryker_api_platform.php"; do
        if [ -f "$API_CONFIG" ] && file_needs_update "$API_CONFIG" "'SprykerAcademy'"; then
            sed -i '' "s|'src/Pyz'|'src/Pyz',\n        'src/SprykerAcademy'|" "$API_CONFIG"
            log_success "Added SprykerAcademy to API Platform source directories"
        fi
    done
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
echo "  docker/sdk console c:e"
echo "  docker/sdk cli composer dump-autoload"
echo "  docker/sdk console propel:install"
echo "  docker/sdk console transfer:generate"

# Show test run command for hello-world package
if [ "$PACKAGE" = "hello-world" ] && [ -d "$PROJECT_DIR/tests/SprykerAcademyTest" ]; then
    echo ""
    echo -e "${YELLOW}Verify your work:${NC}"

    case "$BRANCH" in
        basics/hello-world-back-office/*)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise1"
            ;;
        basics/data-transfer-object/*)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise1"
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise2"
            ;;
        basics/message-table-schema/*)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SpkerAcademyTest/Zed/HelloWorld/ Exercise1"
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise2"
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise3"
            ;;
        basics/module-layers/*|basics/extending-core-modules/*|basics/configuration/*)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/"
            ;;
        *)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/"
            ;;
    esac
fi
