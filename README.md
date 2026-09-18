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

- **contact-request**: Basic Spryker concepts (back-office, DTOs, table schema, module layers, configuration, extending core modules)
- **ai-foundation**: Advanced topics on AI Foundation: a Storefront API endpoint that talks to an LLM with memory, a second one where the LLM calls a tool and answers in a structured transfer, and a custom Back Office Assistant agent. The agent exercise requires the Back Office Assistant, see `guides/advanced/01-back-office-assistant-setup.md`
- **supplier**: Intermediate topics (back-office, data import, publish-synchronize, search, storage, Glue API, OMS, Yves storefront, Merchant Portal)

### Available Branches

#### Contact Request
- `basics/contact-request-back-office/skeleton`
- `basics/contact-request-back-office/complete`
- `basics/data-transfer-object/skeleton`
- `basics/data-transfer-object/complete`
- `basics/contact-request-table-schema/skeleton`
- `basics/contact-request-table-schema/complete`
- `basics/module-layers/skeleton`
- `basics/module-layers/complete`
- `basics/extending-core-modules/skeleton`
- `basics/extending-core-modules/complete`
- `basics/extending-core-modules/complete-ajax`
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
- `intermediate/merchant-portal-table/skeleton`
- `intermediate/merchant-portal-table/complete`
- `intermediate/merchant-portal-form/skeleton`
- `intermediate/merchant-portal-form/complete`
- `intermediate/merchant-portal-locations/skeleton`
- `intermediate/merchant-portal-locations/complete`

#### AI Foundation
- `advanced/ai-foundation-hello/skeleton`
- `advanced/ai-foundation-hello/complete`
- `advanced/ai-foundation-catalog/skeleton`
- `advanced/ai-foundation-catalog/complete`
- `advanced/ai-foundation-agent/skeleton`
- `advanced/ai-foundation-agent/complete`

The `complete` branches are wired into the project automatically. Every line the loader adds is marked `ai-foundation exercise` and is removed again when you load a skeleton or another package.

## Examples

```bash
# Load Contact Request back-office exercise
./exercises/load.sh contact-request basics/contact-request-back-office/skeleton

# Load Supplier back-office complete solution
./exercises/load.sh supplier intermediate/back-office/complete

# Load Supplier data-import exercise
./exercises/load.sh supplier intermediate/data-import/skeleton

# Load the AI Foundation agent exercise
./exercises/load.sh ai-foundation advanced/ai-foundation-hello/skeleton
```

## Post-Installation Steps

After loading an exercise, run these commands:

```bash
docker/sdk console c:e
docker/sdk cli composer dump-autoload
docker/sdk console propel:install
docker/sdk console transfer:generate
```

For the AI exercises the order differs, because `config_ai.php` references an exercise class. The loader prints the exact list per branch:

```bash
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console configuration:sync
docker/sdk console c:e
```

## Student Setup Guide

See [STUDENT_SETUP_GUIDE.md](STUDENT_SETUP_GUIDE.md) for detailed setup instructions.

## Guides

- `guides/` - Markdown format guides
- `guides-html/` - HTML format guides and the reveal.js presentations (fundamentals, intermediate, AI Foundation)
- `guides/advanced/` - Back Office Assistant setup and the AI Foundation exercises
- `guides/presentations/` - Markdown versions of the three instructor presentations, readable on GitHub (generated from the HTML with `tools/presentation_to_markdown.py`)
- `guides-pptx/` - PowerPoint slides generated from the HTML presentations with `html_to_pptx.py`

## Requirements

- Docker SDK environment running
- PHP (for script execution)
- Git (for cloning repositories)

## Repository URLs

- Contact Request: `https://github.com/spryker-academy/contact-request.git`
- Supplier: `https://github.com/spryker-academy/supplier.git`
- AI Foundation: `https://github.com/spryker-academy/ai-foundation.git`
