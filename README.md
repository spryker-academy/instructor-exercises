# Instructor Exercises

This package contains the exercise loader and guides for Spryker Academy hands-on training.

## Overview

The `load.sh` script automates the process of loading exercise code into a Spryker project. It handles:
- Cloning exercise repositories
- Switching to the correct branch
- Copying source files to the project
- Configuring autoload namespaces
- Setting up project configurations (navigation, data import, publishers, queues, etc.)

## Usage

```bash
./exercises/load.sh <package> <branch>
```

### Packages

- **hello-world**: Basic Spryker concepts (back-office, DTOs, message broker, module layers)
- **supplier**: Intermediate topics (back-office, data import, publish-synchronize, search, storage, Glue API, OMS)

### Available Branches

#### Hello World
- `basics/hello-world-back-office/skeleton`
- `basics/hello-world-back-office/complete`
- `basics/data-transfer-object/skeleton`
- `basics/data-transfer-object/complete`
- `basics/message-table-schema/skeleton`
- `basics/message-table-schema/complete`
- `basics/module-layers/skeleton`
- `basics/module-layers/complete`
- `basics/extending-core-modules/skeleton`
- `basics/extending-core-modules/complete`
- `basics/configuration/complete`

#### Supplier
- `basics/supplier-table-schema/skeleton`
- `intermediate/back-office/skeleton`
- `intermediate/back-office/complete`
- `intermediate/data-import/skeleton`
- `intermediate/data-import/complete`
- `intermediate/publish-synchronize/skeleton`
- `intermediate/publish-synchronize/complete`
- `intermediate/search/skeleton`
- `intermediate/search/complete`
- `intermediate/storage-client/skeleton`
- `intermediate/storage-client/complete`
- `intermediate/glue-storefront/skeleton`
- `intermediate/glue-storefront/complete`
- `intermediate/oms/skeleton`
- `intermediate/oms/complete`
- `intermediate/yves-storefront/skeleton`
- `intermediate/yves-storefront/complete`

## Examples

```bash
# Load Hello World back-office exercise
./exercises/load.sh hello-world basics/hello-world-back-office/skeleton

# Load Supplier back-office complete solution
./exercises/load.sh supplier intermediate/back-office/complete

# Load Supplier data-import exercise
./exercises/load.sh supplier intermediate/data-import/skeleton
```

## Post-Installation Steps

After loading an exercise, run these commands:

```bash
docker/sdk console c:e
docker/sdk cli composer dump-autoload
docker/sdk console propel:install
docker/sdk console transfer:generate
```

## Student Setup Guide

See [STUDENT_SETUP_GUIDE.md](STUDENT_SETUP_GUIDE.md) for detailed setup instructions.

## Guides

- `guides/` - Markdown format guides
- `guides-html/` - HTML format guides

## Requirements

- Docker SDK environment running
- PHP (for script execution)
- Git (for cloning repositories)

## Repository URLs

- Hello World: `https://github.com/spryker-academy/hello-world.git`
- Supplier: `https://github.com/spryker-academy/supplier.git`
