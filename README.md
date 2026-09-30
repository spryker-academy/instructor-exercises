# Instructor Exercises

This package contains the exercise loader and guides for Spryker Academy hands-on training.

## Overview

The `load.sh` script loads an exercise branch of a training package into a Spryker project:

- It clones the package (`contact-request`, `supplier`, `ai-foundation`) into `exercises/repos/` and checks out the branch exactly as it is on GitHub. Uncommitted work in that clone is stashed first.
- It replaces `src/SprykerAcademy` and `tests/SprykerAcademyTest` with the branch's copy, and copies the branch's own data and config files (CSV files, import configuration, OMS process). Those files are listed in `exercises/.loaded-files` and removed again by the next load; a file the project already has is never overwritten.
- It removes what the previous exercise left in caches the usual cache clear does not reach: the generated API Platform resources, the compiled Glue containers and the Yves route cache.

The contact-request and supplier branches carry their complete wiring themselves. A dependency provider or config class in `src/SprykerAcademy` that extends the `Pyz` one wins over it, because `SprykerAcademy` is listed before `Pyz` in `KernelConstants::PROJECT_NAMESPACES`; menu entries ship as the module's `Communication/navigation*.xml`; a template override lives in the module's theme. So for these packages the loader never edits a file the shop owns.

### One-time project setup

On its first run the loader prepares the project for the `SprykerAcademy` namespace. None of it refers to a single exercise, so it never has to be undone:

- `composer.json`: `SprykerAcademy\\` and `SprykerAcademyTest\\` autoload entries
- `config/Shared/config_default.php`: `SprykerAcademy` in `KernelConstants::PROJECT_NAMESPACES`, before `Pyz`
- `config/Glue*/packages/spryker_api_platform.php`: `src/SprykerAcademy` as an API Platform source directory
- `config/Glue*/ApplicationServices.php`: the SprykerAcademy Clients and Business layers as Symfony services, for API Platform providers
- `frontend/merchant-portal/entry-points.js` and `tsconfig.mp.json`: `src/SprykerAcademy/Zed` in the Merchant Portal build

It also removes what earlier loader versions wrote into project files (marked blocks, merged menu entries, `full_EU.yml` entries, copied files).

The ai-foundation branches work the same way: their AI configuration, tool sets, agent and streaming setting are `SprykerAcademy` overrides of `AiFoundationConfig`, `AiFoundationDependencyProvider`, `AiCommerceDependencyProvider` and `AiCommerceConfig`. They extend the project's classes when the Back Office Assistant setup created them, and the core ones otherwise.

## Usage

```bash
./exercises/load.sh <package> <branch> [--run]
```

`--run` also runs the post-load commands the loader lists for the branch (cache, Propel, transfers, menu, queues, search index, Merchant Portal build, Glue resources) and stops at the first one that fails. To try unpublished branches, point the loader at a local copy of a package: `ACADEMY_SUPPLIER_REPO=/path/to/supplier ./exercises/load.sh supplier <branch>` (likewise `ACADEMY_CONTACT_REQUEST_REPO`, `ACADEMY_AI_FOUNDATION_REPO`).

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
- `basics/configuration/skeleton`
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

The ai-foundation `complete` branches carry their wiring in `src/SprykerAcademy/Zed/AiFoundation` and `src/SprykerAcademy/Zed/AiCommerce`; in the skeletons it is part of the exercise. The agent exercise needs the Back Office Assistant set up once (`guides/advanced/01-back-office-assistant-setup.md`).

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

The loader prints the commands a branch needs after loading and runs them with `--run`. For contact-request and supplier they start with:

```bash
docker/sdk console c:e
docker/sdk console propel:install
docker/sdk console transfer:generate
```

Keep this order. `cache:empty-all` deletes `data/cache`, which also holds the Propel table map (`data/cache/propel/generated-conf/loadDatabase.php`); until `propel:install` (or `propel:model:build`) has written it again, every Zed request and every console command fails with "Database map was not initialized". So whenever you run `cache:empty-all` later on, follow it with `docker/sdk console propel:model:build`. It also deletes the synced configuration schemas (`data/cache/configuration`): follow it with `docker/sdk console configuration:sync` as well.

Depending on the branch, the list continues with `navigation:build-cache`, `queue:setup`, `messenger:setup-transports`, `search:setup:sources`, `acl-entity:synchronize`, the Merchant Portal build (`frontend:mp:build`) and the Glue resources (`GLUE_APPLICATION=GLUE glue api:generate storefront`, `glue cache:clear`).

Every list ends with `configuration:sync`: `cache:empty-all` also deletes the synced configuration schemas (`data/cache/configuration`), which the Back Office settings and the AI configurations read.

## Student Setup Guide

See [STUDENT_SETUP_GUIDE.md](STUDENT_SETUP_GUIDE.md) for detailed setup instructions.

## Guides

- `guides/` - Markdown format guides
- `guides/basics/06b-configuration-module.md` - Exercise 6b: move the Exercise 6 value into the Back Office with the Configuration module (schema YAML, `configuration:sync`, Configuration facade; no exercise branch)
- `guides/basics/06c-ai-dev-sdk.md` - Exercise 6c: reset the shop and let the AI Dev SDK rebuild the module from a short business requirement - Back Office table, Storefront API and an optional Yves page (no exercise branch; the assistant gets a cold start with no code, wiring or tests, and the handmade version comes back with `load.sh` afterwards for the diff)
- `guides/intermediate/02b-ai-commerce-configuration.md` - Exercise 9b: configure AI Commerce in the Back Office (Configuration module, AI Vendor token, Smart PIM; no exercise branch)
- `guides-html/` - HTML format guides and the reveal.js presentations (fundamentals, intermediate, AI Foundation)
- `guides/advanced/` - Back Office Assistant setup and the AI Foundation exercises
- `guides/presentations/` - Markdown versions of the three instructor presentations, readable on GitHub (generated from the HTML with `tools/presentation_to_markdown.py`)
- `guides-pptx/` - PowerPoint slides generated from the HTML presentations with `html_to_pptx.py`
- `tools/compare-modules.sh` - diffs two SprykerAcademy modules that implement the same feature, normalising the module name in both paths and file contents; `--ref <gitref>` reads the second module from a commit instead of the working tree (`./exercises/tools/compare-modules.sh ContactRequest CustomerRequest --ref HEAD`, used in Exercise 6c)

## Requirements

- Docker SDK environment running
- PHP (for script execution)
- Git (for cloning repositories)

## Repository URLs

- Contact Request: `https://github.com/spryker-academy/contact-request.git`
- Supplier: `https://github.com/spryker-academy/supplier.git`
- AI Foundation: `https://github.com/spryker-academy/ai-foundation.git`
