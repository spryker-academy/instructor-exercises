# Spryker Backend Developer Training - Student Setup Guide

## Prerequisites

- Docker Desktop installed and running
- Git installed

---

## Step 1: Clone the Spryker B2B Demo Shop

```bash
git clone https://github.com/spryker-shop/b2b-demo-marketplace.git
cd b2b-demo-marketplace
```

## Step 2: Clone the Docker SDK

```bash
git clone --single-branch https://github.com/spryker/docker-sdk docker
```

## Step 3: Clone the Exercises

```bash
git clone https://github.com/spryker-academy/instructor-exercises exercises
```

## Step 4: Register the SprykerAcademy Namespace

Before running any exercises, register the `SprykerAcademy` namespace so Spryker can find the exercise classes.

**4a. Add to composer.json autoload:**

Open `composer.json` and add `SprykerAcademy` to the `autoload.psr-4` section:

```json
"autoload": {
    "psr-4": {
        "Pyz\\": "src/Pyz/",
        "SprykerAcademy\\": "src/SprykerAcademy/"
    }
}
```

**4b. Add to Spryker kernel namespaces:**

Open `config/Shared/config_default.php` and add `'SprykerAcademy'` to the `PROJECT_NAMESPACES` array, **before** `'Pyz'`:

```php
$config[KernelConstants::PROJECT_NAMESPACES] = [
    'SprykerAcademy',
    'Pyz',
];
```

> **Why both?** The `composer.json` entry tells PHP where to autoload the classes. The `PROJECT_NAMESPACES` entry tells Spryker's kernel class resolver to look in `SprykerAcademy` when resolving Facades, Factories, and other module classes. Without this, you'll get "class not found" or "FacadeNotFoundException" errors.
>
> **Why first?** The resolver takes the first namespace that has the class. Several exercises extend a project class from `src/SprykerAcademy` - `SprykerAcademy\Zed\DataImport\DataImportDependencyProvider extends Pyz\Zed\DataImport\DataImportDependencyProvider`, for example - and that only takes effect when `SprykerAcademy` comes before `Pyz`.

**4c. Rebuild the autoloader:**

```bash
docker/sdk cli composer dump-autoload
```

> **Why this is not optional.** PHP never reads `composer.json` at runtime. It resolves classes through the generated map in `vendor/composer/autoload_psr4.php`, and that file only changes when you dump the autoloader. Until you do, every `SprykerAcademy` class is unknown - and the error does not say "autoloader": the Zed router finds your controller file on disk, derives the class name from its path, calls `class_exists()`, gets `false` and aborts with `Expected class "SprykerAcademy\Zed\...\IndexController" not found!`. Check it with `grep SprykerAcademy vendor/composer/autoload_psr4.php`.

> **Note:** The `load.sh` script does all three steps automatically (together with the API Platform and Merchant Portal settings the later exercises need), but it's good to do them once manually so you know what they are.

## Step 5: Boot the Docker Environment

```bash
docker/sdk boot deploy.dev.yml
docker/sdk up
```

Wait for all services to be ready. This may take several minutes on first run.

---

## Loading Exercises

Use the `exercises/load.sh` script to load any exercise. It clones the package, checks out the branch exactly as it is on GitHub, and copies its files (`src/SprykerAcademy`, `tests/SprykerAcademyTest`, and the exercise's own CSV and config files) into the project. It never edits your project files for an exercise: the solutions carry their wiring in `src/SprykerAcademy`.

```bash
./exercises/load.sh <package> <branch> --run
```

The loader registers the `SprykerAcademy` namespace and runs `composer dump-autoload` itself, so the classes it copies are loadable right away. `--run` then runs the post-load commands for you; without it the loader prints them. For every branch they start with:

```bash
docker/sdk console c:e
docker/sdk console propel:install
docker/sdk console transfer:generate
```

The loader prints the exact list for the branch you loaded (the AI exercises add `configuration:sync` or the Glue API commands). Keep `c:e` first: `cache:empty-all` deletes the Propel table map together with the other caches, and `propel:install` writes it again. If you run `cache:empty-all` on its own later, follow it with `docker/sdk console propel:model:build`, otherwise the Back Office and the console fail with "Database map was not initialized". In the AI exercises also run `docker/sdk console configuration:sync` afterwards, because `cache:empty-all` deletes the synced configuration schemas the AI configurations reference.

---

## Exercise Progression

### Part 1: Basics (Contact Request)

#### Module 1: Contact Request Back Office

```bash
./exercises/load.sh contact-request basics/contact-request-back-office/skeleton
```

Your task: Implement a Zed controller and Twig template to display a "Contact Request" page in the Back Office.

Files to work on: `src/SprykerAcademy/Zed/ContactRequest/`

Check the solution:

```bash
./exercises/load.sh contact-request basics/contact-request-back-office/complete
```

---

#### Module 2: Data Transfer Objects

```bash
./exercises/load.sh contact-request basics/data-transfer-object/skeleton
```

Your task: Define transfer objects for the ContactRequest module.

After modifying transfer XML files, run:

```bash
docker/sdk console transfer:generate
```

Check the solution:

```bash
./exercises/load.sh contact-request basics/data-transfer-object/complete
```

---

#### Module 3: Contact Request Table Schema

```bash
./exercises/load.sh contact-request basics/contact-request-table-schema/skeleton
```

Your task: Define the Propel database schema for the contact request table.

After modifying schema XML files, run:

```bash
docker/sdk console propel:install
docker/sdk console transfer:generate
```

Check the solution:

```bash
./exercises/load.sh contact-request basics/contact-request-table-schema/complete
```

---

#### Module 4: Module Layers

```bash
./exercises/load.sh contact-request basics/module-layers/skeleton
```

Your task: Implement the full module layer architecture (Business, Persistence, Communication, Client, Yves).

Check the solution:

```bash
./exercises/load.sh contact-request basics/module-layers/complete
```

---

### Part 2: Basics (Supplier - Table Schema)

#### Supplier Table Schema

```bash
./exercises/load.sh supplier basics/supplier-table-schema/skeleton --run
```

Your task: Define the Propel database schema for the supplier tables in `src/SprykerAcademy/Zed/Supplier/Persistence/Propel/Schema/pyz_supplier.schema.xml`. After changing a schema file, run:

```bash
docker/sdk console propel:install
docker/sdk console transfer:generate
```

---

### Part 3: Intermediate (Supplier)

The supplier exercises build on each other: every skeleton contains the solutions of the exercises before it. Each has its own guide in `guides/intermediate/`, and its solution is the `complete` branch of the same name:

| Exercise | Guide | Skeleton branch |
|---|---|---|
| 8 Data Import | `01-data-import.md` | `intermediate/data-import/skeleton` |
| 9 Back Office (CRUD) | `02-back-office.md` | `intermediate/back-office/skeleton` |
| 10 Publish & Synchronize | `03-publish-synchronize.md` | `intermediate/publish-synchronize/skeleton` |
| 11 Search | `04-search.md` | `intermediate/search/skeleton` |
| 12 Glue Storefront and Backend API | `05-glue-storefront-api.md` | `intermediate/glue-storefront/skeleton` |
| 13 Order Management System | `06-oms.md` | `intermediate/oms/skeleton` |
| 14 Storage Client | `07-storage-client.md` | `intermediate/storage-client/skeleton` |
| 15 Merchant Portal - Supplier Table | `08-merchant-portal-table.md` | `intermediate/merchant-portal-table/skeleton` |
| 16 Merchant Portal - Create/Edit Form | `09-merchant-portal-form.md` | `intermediate/merchant-portal-form/skeleton` |
| 17 Merchant Portal - Supplier Locations | `10-merchant-portal-locations.md` | `intermediate/merchant-portal-locations/skeleton` |
| 18 Yves Storefront | `11-yves-storefront.md` | `intermediate/yves-storefront/skeleton` |

```bash
./exercises/load.sh supplier intermediate/data-import/skeleton --run     # an exercise
./exercises/load.sh supplier intermediate/data-import/complete --run     # its solution
```

A few things the guides rely on:

- **Imports** use the exercise's own configuration: `docker/sdk console data:import --config=data/import/local/supplier_import.yml`.
- **Queues** (from exercise 10): `docker/sdk console queue:worker:start --stop-when-empty` processes publish and sync messages; `docker/sdk console publish:trigger-events -r supplier` republishes every supplier to search and storage.
- **Glue** (exercise 12): `docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront` and `docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear` after changing a resource.
- **Merchant Portal** (exercises 15-17): log in at http://mp.eu.spryker.local as `harald@spryker.com` / `change123`; after changing an Angular component run `docker/sdk console frontend:mp:build`. The first `--run` of a merchant portal branch installs the npm dependencies, which takes a while.

---

#### Module 16: AI Foundation - Hello AI Storefront API

Prerequisite: the AI Commerce feature is installed and an OpenAI API token is saved in the Back Office under Configuration > AI Vendor.

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-hello/skeleton
```

Your task: Complete an API Platform POST resource and its processor. The processor sends the message to an LLM through the AiFoundation client and returns the answer. A conversation reference gives the LLM memory.

After loading, run the commands in this order:

```bash
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console cache:empty-all
docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront
docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear
```

Verify your work without spending AI tokens:

```bash
docker/sdk cli vendor/bin/codecept build -c tests/SprykerAcademyTest/Glue/HelloAi/
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Glue/HelloAi/ Exercise19
```

Check the solution:

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-hello/complete
```

---

#### Module 17: AI Foundation - Ask the Catalog

Prerequisite: Module 16 completed. The Back Office Assistant is not required.

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-catalog/skeleton
```

Your task: Complete a tool plugin that reads a product, a tool set, a structured answer transfer, and the processor that requests both. Then register the tool set and add an AI configuration with a guardrail system prompt.

After loading, run the same commands as in Module 16.

Verify your work without spending AI tokens:

```bash
docker/sdk cli vendor/bin/codecept build -c tests/SprykerAcademyTest/Zed/CatalogAssistant/
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/CatalogAssistant/ Exercise20
```

Check the solution:

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-catalog/complete
```

---

#### Module 18: AI Foundation - Product Creation Agent

Prerequisite: the Back Office Assistant must be installed and working. Follow `exercises/guides/advanced/01-back-office-assistant-setup.md` first.

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-agent/skeleton
```

Your task: Complete an AI tool, the tool parameters, the tool set, and the agent plugin. Then wire the agent into the Back Office Assistant.

After loading, run the commands in this order:

```bash
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console configuration:sync
docker/sdk console cache:empty-all
```

Verify your work without spending AI tokens:

```bash
docker/sdk cli vendor/bin/codecept build -c tests/SprykerAcademyTest/Zed/AiProductCreation/
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/AiProductCreation/ Exercise21
```

Check the solution. The loader wires the agent into the project for you:

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-agent/complete
```

---

## Common Commands Reference

| Command | When to use |
|---------|-------------|
| `docker/sdk cli composer dump-autoload` | After adding a class in a namespace PHP does not know yet (the loader runs it for you) |
| `docker/sdk console transfer:generate` | After modifying `.transfer.xml` files |
| `docker/sdk console propel:install` | After modifying `.schema.xml` files |
| `docker/sdk console data:import --config=<file>.yml` | After implementing data importers; without `--config` only the entries of `data/import/local/full_EU.yml` run (the supplier exercises: `--config=data/import/local/supplier_import.yml`) |
| `docker/sdk console publish:trigger-events -r <resource>` | To publish existing rows again (e.g. `-r supplier`); then run the queue workers |
| `docker/sdk console queue:worker:start` | To process queued messages |
| `docker/sdk console search:setup:sources` | After modifying search schemas |
| `docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront` | After adding or changing API Platform resources (`*.resource.yml`); follow it with `glue cache:clear` |
| `docker/sdk console router:cache:warm-up` | After adding new route providers |
| `docker/sdk console navigation:build-cache` | After modifying navigation XML |
| `docker/sdk console cache:empty-all` | After loading Yves or Merchant Portal exercises |
| `docker/sdk console configuration:sync` | After adding or changing `*.configuration.yml` setting schemas |
| `docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear` | After changing API Platform resources or source directories (see *Troubleshooting* in the Glue Storefront and Backend API guide) |

## Development Settings: Fewer Cache Clears

Some caches of the demo shop stay on in the development environment, and each one means a change does not show until you clear or rebuild it. The first `load.sh` run lists the main ones at the end of `config/Shared/config_default-docker.dev.php`, set to `true` (Spryker's default):

```php
// >>> spryker-academy setup: caches of the local development environment
$config[\Spryker\Shared\Kernel\KernelConstants::RESOLVABLE_CLASS_NAMES_CACHE_ENABLED] = true;
$config[\Spryker\Shared\Kernel\KernelConstants::RESOLVED_INSTANCE_CACHE_ENABLED] = true;
$config[\Spryker\Shared\Router\RouterConstants::ZED_IS_CACHE_ENABLED] = true;
// <<< spryker-academy setup
```

**If you do not want to clear the cache after every change, set them to `false`.** Requests get a little slower, in exchange:

- **Class resolver** (`RESOLVABLE_CLASS_NAMES_CACHE_ENABLED`, `RESOLVED_INSTANCE_CACHE_ENABLED`): a new `SprykerAcademy` dependency provider, config or factory is used immediately, without `cache:class-resolver:build` (see *Troubleshooting*).
- **Zed router** (`ZED_IS_CACHE_ENABLED`): a new Back Office controller or route is found without rebuilding the router cache.

The Back Office menu has its own cache: with `$config[\Spryker\Shared\ZedNavigation\ZedNavigationConstants::ZED_NAVIGATION_CACHE_ENABLED] = false;` in the same file, a changed `navigation.xml` shows without `navigation:build-cache`.

Change these only in `config_default-docker.dev.php`. `config_default.php` is shared with production, where the caches must stay on. What you do **not** need to switch off: edited Twig templates are recompiled automatically in this environment.

What no setting removes:

- **Generated code is not a cache.** After a `.transfer.xml` change run `transfer:generate`, after a schema change `propel:install`.
- **The Glue API Platform container** (`data/cache/Glue`) is compiled once and never checked again, because Glue runs without the Symfony debug flag. After changing a `*.resource.yml`, a provider's constructor or the API source directories, run `glue api:generate` and `glue cache:clear` (see the Glue Storefront API guide, which also shows where to read the error behind a `500`).

## Troubleshooting

**Script says "not found" or permission denied:**
```bash
chmod +x exercises/load.sh
```

**Transfer/Propel errors after switching exercises:**
Always regenerate after switching:

```bash
docker/sdk cli composer dump-autoload
docker/sdk console propel:install
docker/sdk console transfer:generate
```

**`Expected class "SprykerAcademy\...\SomeController" not found!` although the file exists:**
The composer autoloader has no entry for the namespace. `composer.json` alone does not count - PHP reads the generated map:

```bash
grep SprykerAcademy vendor/composer/autoload_psr4.php   # no output = stale autoloader
docker/sdk cli composer dump-autoload
docker/sdk console cache:empty-all
```

**A `SprykerAcademy` dependency provider or config is ignored, and the same change only works in `Pyz`:**
For example `SprykerAcademy\Zed\Queue\QueueDependencyProvider`, `SymfonyMessengerConfig` or `RabbitMqConfig`: the queues are not created, or the queue processors are not called.

This is Spryker's **class resolver cache**. To find a module's dependency provider, config, factory or facade, Spryker tries the project namespaces in order (`SprykerAcademy`, then `Pyz`, then the core) and takes the first class that exists. With `KernelConstants::RESOLVABLE_CLASS_NAMES_CACHE_ENABLED = true` (the demo shop sets it in `config/Shared/config_default.php`) it first looks the answer up in `src/Generated/Shared/Kernel/<namespaces>/resolvableClassCache*.php`, and only searches when the module is not in that file. The file is written by `console cache:class-resolver:build`, which the install recipe `config/install/docker.yml` runs on `docker/sdk up`. So:

1. You run `docker/sdk up` while an earlier exercise is loaded: the cache records `Pyz\Zed\Queue\QueueDependencyProvider`, because there is no `SprykerAcademy` one yet.
2. You load an exercise that brings `SprykerAcademy\Zed\Queue\QueueDependencyProvider`. Spryker never looks for it: the cached `Pyz` class wins.
3. `cache:empty-all` does not help: it clears `data/cache`, and this file lives in `src/Generated`.

`load.sh` deletes the folder on every load. When you add an override class yourself, do one of these:

```bash
rm -rf src/Generated/Shared/Kernel                       # Spryker searches again; the next build records your class
docker/sdk console cache:class-resolver:build            # or rebuild the cache with the classes that exist now
```

Or switch the cache off for your development environment: set `RESOLVABLE_CLASS_NAMES_CACHE_ENABLED` and `RESOLVED_INSTANCE_CACHE_ENABLED` to `false` in the block `load.sh` added to `config/Shared/config_default-docker.dev.php` (see *Development Settings* above). Every lookup is then a search again: a bit slower, but a new override works immediately and there is nothing to clean or rebuild.

**Cache issues:**
```bash
docker/sdk console cache:empty-all
```

**List available branches:**
```bash
./exercises/load.sh
```
