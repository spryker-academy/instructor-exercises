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
    echo -e "${RED}Error: Package must be 'hello-world' or 'supplier'${NC}"
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
    echo -e "${YELLOW}Cloning $PACKAGE repository...${NC}"
    mkdir -p "$REPOS_DIR"
    git clone "$REPO_URL" "$REPO_DIR"
fi

# Fetch latest and checkout branch
echo -e "${YELLOW}Switching to branch: $BRANCH${NC}"
cd "$REPO_DIR"
git fetch origin
git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH"
git pull origin "$BRANCH" 2>/dev/null || true
cd "$PROJECT_DIR"

# Verify the branch has src/SprykerAcademy
if [ ! -d "$REPO_DIR/src/SprykerAcademy" ] && [ ! -d "$REPO_DIR/src/Pyz" ]; then
    echo -e "${YELLOW}Note: This branch has no src/ files (empty skeleton).${NC}"
fi

# Clean previous exercise files
echo -e "${YELLOW}Cleaning previous exercise files...${NC}"
rm -rf "$PROJECT_DIR/src/SprykerAcademy"

# Copy SprykerAcademy source files
if [ -d "$REPO_DIR/src/SprykerAcademy" ]; then
    cp -R "$REPO_DIR/src/SprykerAcademy" "$PROJECT_DIR/src/SprykerAcademy"
fi

# Copy Pyz overrides if present
if [ -d "$REPO_DIR/src/Pyz" ]; then
    cd "$REPO_DIR/src/Pyz" && find . -type f | while read -r file; do
        mkdir -p "$PROJECT_DIR/src/Pyz/$(dirname "$file")"
        cp "$file" "$PROJECT_DIR/src/Pyz/$file"
    done
    cd "$PROJECT_DIR"
fi

# Add HelloWorld config value to config_default.php for configuration exercise
if [ "$PACKAGE" = "hello-world" ]; then
    CONFIG_FILE="$PROJECT_DIR/config/Shared/config_default.php"
    if [ -f "$REPO_DIR/src/SprykerAcademy/Shared/HelloWorld/HelloWorldConstants.php" ] && ! grep -q 'HelloWorldConstants' "$CONFIG_FILE"; then
        cat >> "$CONFIG_FILE" << 'PHPEOF'

// HelloWorld exercise config value
use SprykerAcademy\Shared\HelloWorld\HelloWorldConstants;

$config[HelloWorldConstants::MY_CONFIG_VALUE] = 'Hello from config!';
PHPEOF
        echo -e "  ${GREEN}Added HelloWorld config value to config_default.php${NC}"
    fi
fi

# Copy config and data files for supplier package
if [ "$PACKAGE" = "supplier" ]; then
    [ -f "$REPO_DIR/config/Zed/navigation.xml" ] && cp "$REPO_DIR/config/Zed/navigation.xml" "$PROJECT_DIR/config/Zed/navigation.xml"
    [ -f "$REPO_DIR/config/Zed/oms/Demo01.xml" ] && mkdir -p "$PROJECT_DIR/config/Zed/oms" && cp "$REPO_DIR/config/Zed/oms/Demo01.xml" "$PROJECT_DIR/config/Zed/oms/Demo01.xml"
    [ -f "$REPO_DIR/data/import/supplier.csv" ] && mkdir -p "$PROJECT_DIR/data/import" && cp "$REPO_DIR/data/import/supplier.csv" "$PROJECT_DIR/data/import/supplier.csv"
    [ -f "$REPO_DIR/data/import/supplier_location.csv" ] && cp "$REPO_DIR/data/import/supplier_location.csv" "$PROJECT_DIR/data/import/supplier_location.csv"

    # Add supplier data import entries to full_EU.yml if not present
    IMPORT_YAML="$PROJECT_DIR/data/import/local/full_EU.yml"
    if [ -f "$IMPORT_YAML" ] && [ "$(grep -c 'data_entity: supplier$' "$IMPORT_YAML" || true)" = "0" ]; then
        cat >> "$IMPORT_YAML" << 'YAMLEOF'

    # Supplier Academy exercises
    -   data_entity: supplier
        source: data/import/supplier.csv
    -   data_entity: supplier-location
        source: data/import/supplier_location.csv
YAMLEOF
        echo -e "  ${GREEN}Added supplier import entries to full_EU.yml${NC}"
    fi

    # Register supplier data import plugins in DataImportDependencyProvider
    DI_PROVIDER="$PROJECT_DIR/src/Pyz/Zed/DataImport/DataImportDependencyProvider.php"
    if [ -f "$DI_PROVIDER" ] && [ "$(grep -c 'SupplierDataImportPlugin' "$DI_PROVIDER" || true)" = "0" ]; then
        # Use php to safely inject the use statements and plugin registrations
        php -r '
            $file = $argv[1];
            $content = file_get_contents($file);

            // Add use statements before class declaration
            $useStatements = "use SprykerAcademy\Zed\SupplierDataImport\Communication\Plugin\DataImport\SupplierDataImportPlugin;\nuse SprykerAcademy\Zed\SupplierDataImport\Communication\Plugin\DataImport\SupplierLocationDataImportPlugin;\n";
            $content = preg_replace(
                "/(^class\s)/m",
                $useStatements . "\n$1",
                $content,
                1,
            );

            // Add plugins before the last ]; in getDataImporterPlugins
            $content = preg_replace(
                "/(function\s+getDataImporterPlugins.*?)((\s*)\];)/s",
                "$1$3    new SupplierDataImportPlugin(),\n$3    new SupplierLocationDataImportPlugin(),\n$2",
                $content,
                1,
            );

            file_put_contents($file, $content);
        ' "$DI_PROVIDER"
        echo -e "  ${GREEN}Registered SupplierDataImportPlugin in DataImportDependencyProvider${NC}"
    fi
fi

# Copy exercise tests if present
if [ -d "$REPO_DIR/tests/SprykerAcademyTest" ]; then
    echo -e "${YELLOW}Installing exercise tests...${NC}"
    rm -rf "$PROJECT_DIR/tests/SprykerAcademyTest"
    cp -R "$REPO_DIR/tests/SprykerAcademyTest" "$PROJECT_DIR/tests/SprykerAcademyTest"

    # Add SprykerAcademyTest namespace to composer.json autoload-dev if not already present
    if ! grep -q '"SprykerAcademyTest\\\\' "$PROJECT_DIR/composer.json"; then
        # Use php to safely modify composer.json
        php -r '
            $file = $argv[1] . "/composer.json";
            $json = json_decode(file_get_contents($file), true);
            if (!isset($json["autoload-dev"]["psr-4"]["SprykerAcademyTest\\\\"])) {
                $json["autoload-dev"]["psr-4"]["SprykerAcademyTest\\\\"] = "tests/SprykerAcademyTest/";
                file_put_contents($file, json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
            }
        ' "$PROJECT_DIR"
        echo -e "  ${GREEN}Added SprykerAcademyTest\\ to composer.json autoload-dev${NC}"
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
echo "  docker/sdk console transfer:generate"
echo "  docker/sdk console propel:install"

# Show test run command for hello-world package
if [ "$PACKAGE" = "hello-world" ] && [ -d "$PROJECT_DIR/tests/SprykerAcademyTest" ]; then
    echo ""
    echo -e "${YELLOW}Verify your work:${NC}"

    # Determine which exercises are available based on the branch
    case "$BRANCH" in
        basics/hello-world-back-office/*)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise1"
            ;;
        basics/data-transfer-object/*)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise1"
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise2"
            ;;
        basics/message-table-schema/*)
            echo "  docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise1"
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
