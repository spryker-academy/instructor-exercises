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

Open `config/Shared/config_default.php` and add `'SprykerAcademy'` to the `PROJECT_NAMESPACES` array:

```php
$config[KernelConstants::PROJECT_NAMESPACES] = [
    'Pyz',
    'SprykerAcademy',
];
```

> **Why both?** The `composer.json` entry tells PHP where to autoload the classes. The `PROJECT_NAMESPACES` entry tells Spryker's kernel class resolver to look in `SprykerAcademy` when resolving Facades, Factories, and other module classes. Without this, you'll get "class not found" or "FacadeNotFoundException" errors.

> **Note:** The `load.sh` script also does this automatically, but it's good to do it once manually so the project is ready from the start.

## Step 5: Boot the Docker Environment

```bash
docker/sdk boot deploy.dev.yml
docker/sdk up
```

Wait for all services to be ready. This may take several minutes on first run.

---

## Loading Exercises

Use the `exercises/load.sh` script to load any exercise. It handles everything automatically: cloning repos, switching branches, copying files into `src/`, and configuring the project.

```bash
./exercises/load.sh <package> <branch>
```

After loading, run:

```bash
docker/sdk console c:e
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console propel:install
```

---

## Exercise Progression

### Part 1: Basics (Hello World)

#### Module 1: Hello World Back Office

```bash
./exercises/load.sh hello-world basics/hello-world-back-office/skeleton
```

Your task: Implement a Zed controller and Twig template to display a "Hello World" page in the Back Office.

Files to work on: `src/SprykerAcademy/Zed/HelloWorld/`

Check the solution:

```bash
./exercises/load.sh hello-world basics/hello-world-back-office/complete
```

---

#### Module 2: Data Transfer Objects

```bash
./exercises/load.sh hello-world basics/data-transfer-object/skeleton
```

Your task: Define transfer objects for the HelloWorld module.

After modifying transfer XML files, run:

```bash
docker/sdk console transfer:generate
```

Check the solution:

```bash
./exercises/load.sh hello-world basics/data-transfer-object/complete
```

---

#### Module 3: Message Table Schema

```bash
./exercises/load.sh hello-world basics/message-table-schema/skeleton
```

Your task: Define the Propel database schema for the message table.

After modifying schema XML files, run:

```bash
docker/sdk console propel:install
docker/sdk console transfer:generate
```

Check the solution:

```bash
./exercises/load.sh hello-world basics/message-table-schema/complete
```

---

#### Module 4: Module Layers

```bash
./exercises/load.sh hello-world basics/module-layers/skeleton
```

Your task: Implement the full module layer architecture (Business, Persistence, Communication, Client, Yves).

Check the solution:

```bash
./exercises/load.sh hello-world basics/module-layers/complete
```

---

### Part 2: Basics (Supplier - Table Schema)

#### Module 4b: Supplier Table Schema

```bash
./exercises/load.sh supplier basics/supplier-table-schema/skeleton
```

Your task: Define the Propel database schema for supplier tables.

After modifying schema XML files, run:

```bash
docker/sdk console propel:install
docker/sdk console transfer:generate
```

---

### Part 3: Intermediate (Supplier)

#### Module 6: Back Office (CRUD)

```bash
./exercises/load.sh supplier intermediate/back-office/skeleton
```

Your task: Build the Back Office GUI for managing suppliers (list, create, edit, delete).

Check the solution:

```bash
./exercises/load.sh supplier intermediate/back-office/complete
```

---

#### Module 7: Data Import

```bash
./exercises/load.sh supplier intermediate/data-import/skeleton
```

Your task: Implement data importers for suppliers and supplier locations.

After implementing, run:

```bash
docker/sdk console data:import
```

Check the solution:

```bash
./exercises/load.sh supplier intermediate/data-import/complete
```

---

#### Module 8: Publish & Synchronize

```bash
./exercises/load.sh supplier intermediate/publish-synchronize/skeleton
```

Your task: Implement event publishing and synchronization for supplier data to storage/search.

After implementing, run:

```bash
docker/sdk console event:trigger
docker/sdk console queue:worker:start
```

Check the solution:

```bash
./exercises/load.sh supplier intermediate/publish-synchronize/complete
```

---

#### Module 9: Search

```bash
./exercises/load.sh supplier intermediate/search/skeleton
```

Your task: Implement Elasticsearch integration for supplier search.

Check the solution:

```bash
./exercises/load.sh supplier intermediate/search/complete
```

---

#### Module: Storage Client

```bash
./exercises/load.sh supplier intermediate/storage-client/skeleton
```

Your task: Implement the Client layer to read supplier data from Redis storage.

Check the solution:

```bash
./exercises/load.sh supplier intermediate/storage-client/complete
```

---

#### Module 10: Glue Storefront API

```bash
./exercises/load.sh supplier intermediate/glue-storefront/skeleton
```

Your task: Build a Glue API resource for exposing supplier data to storefront applications.

After implementing, run:

```bash
docker/sdk console glue-api:controller:cache:warm-up
```

Check the solution:

```bash
./exercises/load.sh supplier intermediate/glue-storefront/complete
```

---

#### Module 11: Order Management System (OMS)

```bash
./exercises/load.sh supplier intermediate/oms/skeleton
```

Your task: Define OMS states, transitions, events, conditions, and commands in `config/Zed/oms/Demo01.xml` and implement the OMS plugins.

Check the solution:

```bash
./exercises/load.sh supplier intermediate/oms/complete
```

---

## Common Commands Reference

| Command | When to use |
|---------|-------------|
| `docker/sdk cli composer dump-autoload` | After loading a new exercise |
| `docker/sdk console transfer:generate` | After modifying `.transfer.xml` files |
| `docker/sdk console propel:install` | After modifying `.schema.xml` files |
| `docker/sdk console data:import` | After implementing data importers |
| `docker/sdk console event:trigger` | To trigger publish & sync events |
| `docker/sdk console queue:worker:start` | To process queued messages |
| `docker/sdk console search:setup:sources` | After modifying search schemas |
| `docker/sdk console glue-api:controller:cache:warm-up` | After adding Glue API resources |
| `docker/sdk console router:cache:warm-up` | After adding new route providers |
| `docker/sdk console navigation:build-cache` | After modifying navigation XML |

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

**Cache issues:**
```bash
docker/sdk console cache:empty-all
```

**List available branches:**
```bash
./exercises/load.sh
```
