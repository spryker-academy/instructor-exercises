# Exercise 12: Glue Storefront API - Supplier

In this exercise, you will expose supplier data through a REST API endpoint using Spryker's API Platform. You will create a Glue Storefront API resource that provides both single-item and collection endpoints for suppliers.

You will learn how to:
- Define an API resource using YAML configuration (`.resource.yml`)
- Implement a Provider class that fetches and maps data
- Map internal Transfer objects to generated API Resource objects
- Work with Spryker's API Platform (not the legacy GlueApplication approach)
- Handle both Get (single) and GetCollection (list) operations

## Prerequisites

- Completed Exercises 8-11 (Data Import, Back Office, P&S, Search)
- Suppliers should exist in the database

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/glue-storefront/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
```

---

## Setup: Register Custom Namespace

API Platform discovers resource YAML files by scanning **source directories** configured in `config/GlueStorefront/packages/spryker_api_platform.php`. By default, only `src/Spryker`, `src/SprykerFeature`, and `src/Pyz` are registered.

Since our code lives in `src/SprykerAcademy/`, we need to add it:

```php
// config/GlueStorefront/packages/spryker_api_platform.php
$sprykerApiPlatform->sourceDirectories([
    'src/Spryker',
    'src/SprykerFeature',
    'src/Pyz',
    'src/SprykerAcademy',  // <-- Add this
]);
```

> **Backend API:** If you also need to expose resources via the Backend API, add `src/SprykerAcademy` to `config/GlueBackend/packages/spryker_api_platform.php` as well.

After adding the source directory, generate the API resources:

```bash
docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate
```

> **Important:** You must specify the Glue application via the `GLUE_APPLICATION` environment variable. Without it, the command doesn't know which API type to generate for and may fail or generate for the wrong application.

This command scans all registered source directories for `.resource.yml` files and generates PHP Resource classes (e.g., `Generated\Api\Storefront\SuppliersStorefrontResource`).

### API Platform Commands Reference

| Command | Purpose |
|---------|---------|
| `GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate` | Generate Storefront API resources |
| `GLUE_APPLICATION=GLUE_BACKEND glue api:generate` | Generate Backend API resources |
| `GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate --dry-run` | Preview what would be generated without writing |
| `GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate --validate-only` | Validate schemas without generating |
| `GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate -r suppliers` | Generate only the `suppliers` resource |
| `GLUE_APPLICATION=GLUE_STOREFRONT glue api:debug --list` | List all registered resources |
| `GLUE_APPLICATION=GLUE_STOREFRONT glue api:debug suppliers` | Inspect a specific resource's merged schema |
| `GLUE_APPLICATION=GLUE_STOREFRONT glue api:debug suppliers --show-sources` | Show all source files with priority |
| `GLUE_APPLICATION=GLUE_STOREFRONT glue api:debug suppliers --show-merged` | Display the final merged YAML schema |

> **Tip:** All `glue` CLI commands require the `GLUE_APPLICATION` env var. Prefix every command with `GLUE_APPLICATION=GLUE_STOREFRONT` or `GLUE_APPLICATION=GLUE_BACKEND` as needed.

> **Docs:** [Spryker API Platform Architecture](https://docs.spryker.com/docs/dg/dev/architecture/api-platform) | [Resource Schemas](https://docs.spryker.com/docs/dg/dev/architecture/api-platform/resource-schemas.html)

---

## Background: Spryker API Platform

Spryker 202512.0+ introduces **API Platform** as the recommended approach for building new REST APIs. The existing GlueApplication APIs remain **retrocompatible** (not deprecated) — they continue to work alongside API Platform.

**For all new API development, use API Platform.**

| Aspect | GlueApplication (retrocompatible) | API Platform (recommended) |
|--------|----------------------------------|---------------------------|
| Resource definition | PHP plugin classes | YAML `.resource.yml` files |
| Controller | Custom controller extending `AbstractRestResource` | Provider class implementing `ProviderInterface` |
| Registration | Plugin registered in DependencyProvider | Provider referenced in YAML config |
| Dependency injection | Factory + DependencyProvider | Constructor injection (auto-wired) |
| Response format | Manual `RestResource` building | Generated Resource classes |

**API Platform flow:**

```
GET /suppliers/1
    → YAML resource definition (suppliers.resource.yml)
    → Provider::provide($operation, $uriVariables)
    → Load data from Client/Facade
    → Map Transfer → Generated Resource class
    → JSON:API response
```

---

## Working on the Exercise

### Part 1: Define the API Resource (YAML)

The API resource definition tells Spryker what endpoints to expose, which Provider handles the requests, and what properties the resource has.

**Coding time:**

Open `src/SprykerAcademy/Glue/SuppliersApi/resources/api/storefront/suppliers.resource.yml`:

1. Add the `provider` field pointing to the full class name of the Provider class
2. Add the resource properties: `name` (string), `description` (string), `status` (int), `email` (string), `phone` (string)

The skeleton already has the resource name, operations (Get + GetCollection), pagination config, and the `idSupplier` identifier property.

> **Resource YAML structure:**
> - `provider:` — full class name of the PHP Provider that handles requests
> - `operations:` — list of HTTP operations (Get, GetCollection, Post, Patch, Delete)
> - `properties:` — schema definition with types, descriptions, and identifier flag
> - `identifier: true` — marks the property used in the URL path (e.g., `/suppliers/{idSupplier}`)

After modifying the YAML, regenerate:

```bash
docker/sdk console transfer:generate
```

This generates a `SuppliersStorefrontResource` class in `Generated\Api\Storefront\` that the Provider returns.

---

### Part 2: Implement the Provider

The Provider is the core of the API resource. It receives the HTTP request context and returns data. It replaces the controller + reader pattern from the old approach.

**Coding time:**

Open `src/SprykerAcademy/Glue/SuppliersApi/Api/Storefront/Provider/SuppliersStorefrontProvider.php`. The class implements `ApiPlatform\State\ProviderInterface`. In the `provide()` method:

1. Read the supplier identifier from `$uriVariables` — the key name must match the `identifier` property in the YAML
2. If the identifier is null, this is a collection request — return an array of mapped resources (load all suppliers via the Client)
3. If the identifier is present, load the single supplier by ID via the Client
4. If the supplier is not found, return null (API Platform handles the 404)
5. Map the `SupplierTransfer` to a `SuppliersStorefrontResource` using the provided Mapper

> **`$uriVariables`:** For a GET request to `/suppliers/5`, this array contains `['idSupplier' => '5']`. The key name comes from the identifier property in the resource YAML.

> **Collection vs Single:** The `provide()` method handles both. When `idSupplier` is null, it's a GetCollection request; when present, it's a Get request.

---

### Part 3: Review the Mapper

The Mapper converts internal `SupplierTransfer` objects to generated `SuppliersStorefrontResource` objects.

Open `src/SprykerAcademy/Glue/SuppliersApi/Processor/Mapper/SupplierMapper.php` and review how it maps transfers to API resources.

> **Generated Resource classes:** API Platform generates PHP classes from the YAML properties. These classes have `fromArray()` and expose the properties defined in the YAML. The Mapper bridges the internal domain model (Transfer) to the API model (Resource).

---

### Part 4: Test the Endpoint

After completing all parts, generate the API resources and clear cache:

```bash
docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate
docker/sdk console cache:empty-all
```

Test single supplier:
```bash
curl -s 'http://glue-storefront.eu.spryker.local/suppliers/1' \
  -H 'Content-Type: application/vnd.api+json' | python3 -m json.tool
```

Test collection:
```bash
curl -s 'http://glue-storefront.eu.spryker.local/suppliers' \
  -H 'Content-Type: application/vnd.api+json' | python3 -m json.tool
```

Expected response format:
```json
{
  "data": {
    "type": "suppliers",
    "id": "1",
    "attributes": {
      "name": "Acme Supplies",
      "description": "leading supplier of industrial equipment",
      "status": 1,
      "email": "contact@acmesupplies.com",
      "phone": "+1-555-1234"
    }
  }
}
```

---

## Registering Services in the Symfony Container

API Platform providers use **Symfony's dependency injection** — not Spryker's Factory/DependencyProvider pattern. When a provider declares a constructor dependency like `SupplierFacadeInterface` or `SupplierClientInterface`, Symfony must know how to resolve it.

Spryker core modules have pre-compiled service containers, but project-level modules (like `SprykerAcademy`) do not. You need to register them explicitly in `ApplicationServices.php`.

**GlueBackend** — register Zed layer services (facades) that backend providers need:

```php
// config/GlueBackend/ApplicationServices.php
$services->load('SprykerAcademy\\Zed\\', '../../src/SprykerAcademy/Zed/');
```

**GlueStorefront** — register Client layer services that storefront providers need:

```php
// config/GlueStorefront/ApplicationServices.php
$services->load('SprykerAcademy\\Client\\', '../../src/SprykerAcademy/Client/');
```

> **`$services->load()`** tells Symfony to scan a directory and auto-register all classes under that namespace as services. Combined with `->defaults()->autowire()` (already set), Symfony can then resolve interfaces to their implementations.

> **Alternative:** You can also register individual services explicitly:
> ```php
> $services->set(SupplierFacadeInterface::class, SupplierFacade::class);
> ```
> This is more precise but requires updating whenever you add new dependencies.

> **Note:** The exercise loader (`load.sh`) handles this registration automatically. You don't need to modify `ApplicationServices.php` manually.

---

## Key Concepts Summary

### API Platform vs Legacy

With API Platform, there's **no need for**:
- DependencyProvider in the Glue layer (constructor injection is auto-wired by Symfony)
- Factory in the Glue layer
- Controller class (the Provider IS the handler)
- Plugin registration in `GlueStorefrontApiApplicationDependencyProvider`

Everything is defined in YAML + one Provider class + service registration in `ApplicationServices.php`.

### Provider Pattern

The Provider implements a single method:

```
provide(Operation $operation, array $uriVariables, array $context): object|array|null
```

- Return an **object** → single resource response
- Return an **array** → collection response
- Return **null** → 404 response

---

## Run Automated Tests

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/Supplier/ GlueApi
```

---

## Solution

```bash
./exercises/load.sh supplier intermediate/glue-storefront/complete
```
