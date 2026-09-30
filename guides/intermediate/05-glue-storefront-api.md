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

The loader copies the completed Search branch source into the project before the Glue exercise files. This ensures the SupplierSearch TODOs are already implemented; you do not need to load the Search complete branch separately.

```bash
./exercises/load.sh supplier intermediate/glue-storefront/skeleton --run
```

`--run` also runs the commands the loader lists after loading (cache, Propel, transfers and whatever this exercise needs, such as queues or Glue resources) and stops at the first one that fails. Leave it out to run them yourself.

---

## Setup: The SprykerAcademy Source Directory

API Platform discovers resource YAML files by scanning the **source directories** configured per Glue application in `config/<Application>/packages/spryker_api_platform.php`. The demo shop lists `src/Pyz` and the vendor directories.

The exercise loader added `src/SprykerAcademy` to that list when you loaded your first exercise (look at `config/Glue/packages/spryker_api_platform.php`):

```php
$sprykerApiPlatform->sourceDirectories([
    'src/Pyz',
    'src/SprykerAcademy',
    'vendor/spryker',
    // ...
]);
```

In this demo shop the storefront API runs in the **Glue** application (`glue.eu.spryker.local`, `apiTypes(['storefront'])` in `config/Glue/packages/spryker_api_platform.php`). Generate its resources with:

```bash
docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront
```

> **Important:** You must specify the Glue application via the `GLUE_APPLICATION` environment variable. Without it, the command doesn't know which application's configuration to use. Shops with a separate storefront application (`glue-storefront.*`) use `GLUE_APPLICATION=GLUE_STOREFRONT`.

This command scans all registered source directories for `.resource.yml` files and generates PHP Resource classes (e.g., `Generated\Api\Storefront\SuppliersStorefrontResource`) in `src/Generated/Api/Storefront`.

### API Platform Commands Reference

| Command | Purpose |
|---------|---------|
| `GLUE_APPLICATION=GLUE glue api:generate` | Generate Storefront API resources |
| `GLUE_APPLICATION=GLUE_BACKEND glue api:generate` | Generate Backend API resources |
| `GLUE_APPLICATION=GLUE glue api:generate --dry-run` | Preview what would be generated without writing |
| `GLUE_APPLICATION=GLUE glue api:generate --validate-only` | Validate schemas without generating |
| `GLUE_APPLICATION=GLUE glue api:generate -r suppliers` | Generate only the `suppliers` resource |
| `GLUE_APPLICATION=GLUE glue api:debug --list` | List all registered resources |
| `GLUE_APPLICATION=GLUE glue api:debug suppliers` | Inspect a specific resource's merged schema |
| `GLUE_APPLICATION=GLUE glue api:debug suppliers --show-sources` | Show all source files with priority |
| `GLUE_APPLICATION=GLUE glue api:debug suppliers --show-merged` | Display the final merged YAML schema |

> **Tip:** All `glue` CLI commands require the `GLUE_APPLICATION` env var. Prefix every command with `GLUE_APPLICATION=GLUE` (the storefront API of this shop) or `GLUE_APPLICATION=GLUE_BACKEND` as needed.

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

Open `src/SprykerAcademy/Glue/Supplier/resources/api/storefront/suppliers.resource.yml`:

1. Add the `provider` field pointing to the full class name of the Provider class
2. Add the resource properties: `name` (string), `description` (string), `status` (int), `email` (string), `phone` (string)

The skeleton already has the resource name, operations (Get + GetCollection), pagination config, and the `idSupplier` identifier property.

> **Resource YAML structure:**
> - `provider:` — full class name of the PHP Provider that handles requests
> - `operations:` — list of HTTP operations (Get, GetCollection, Post, Patch, Delete)
> - `properties:` — schema definition with types, descriptions, and identifier flag
> - `identifier: true` — marks the property used in the URL path (e.g., `/suppliers/{idSupplier}`)

After modifying the YAML, regenerate the resource classes:

```bash
docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront
```

This generates a `SuppliersStorefrontResource` class in `Generated\Api\Storefront\` that the Provider returns.

---

### Part 2: Implement the Provider

The Provider is the core of the API resource. It receives the HTTP request context and returns data. It replaces the controller + reader pattern from the old approach.

**Coding time:**

Open `src/SprykerAcademy/Glue/Supplier/Api/Storefront/Provider/SuppliersStorefrontProvider.php`. The class implements `ApiPlatform\State\ProviderInterface` and receives the `SupplierSearchClientInterface` of Exercise 11 through its constructor - the storefront reads suppliers from Elasticsearch, not from the database. In the `provide()` method:

1. Read the supplier identifier from `$uriVariables` — the key name must match the `identifier` property in the YAML
2. If the identifier is null, call `searchSuppliers()` to load suppliers. Loop over `SupplierCollectionTransfer::getSuppliers()` and map each transfer to a resource
3. If the identifier is present, call `findSupplierById((int)$idSupplier)`
4. The client returns an empty `SupplierTransfer` for an unknown id: return null then (API Platform answers with a 404)
5. Map the `SupplierTransfer` to a `SuppliersStorefrontResource` using the provided Mapper

> **`$uriVariables`:** For a GET request to `/suppliers/5`, this array contains `['idSupplier' => '5']`. The key name comes from the identifier property in the resource YAML.

> **Collection vs Single:** The `provide()` method handles both. When `idSupplier` is null, it's a GetCollection request; when present, it's a Get request.

---

### Part 3: Review the Mapper

The Mapper converts internal `SupplierTransfer` objects to generated `SuppliersStorefrontResource` objects.

Open `src/SprykerAcademy/Glue/Supplier/Processor/Mapper/SupplierMapper.php` and review how it maps transfers to API resources. Note `toArray(false, true)`: the generated resource reads camel-cased keys (`idSupplier`), while `toArray()` without arguments returns snake_case (`id_supplier`) - the resource would miss its identifier and API Platform could not build the links.

> **Generated Resource classes:** API Platform generates PHP classes from the YAML properties. These classes have `fromArray()` and expose the properties defined in the YAML. The Mapper bridges the internal domain model (Transfer) to the API model (Resource).

---

### Part 4: Test the Endpoint

After completing all parts, generate the API resources and clear the Glue cache - the compiled Glue container keeps the resource list, and `cache:empty-all` does not reach it:

```bash
docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront
docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear
```

Test collection (JSON-LD format):
```bash
curl -s 'http://glue.eu.spryker.local/suppliers' \
  -H 'Accept: application/ld+json' | python3 -m json.tool
```

Test single supplier:
```bash
curl -s 'http://glue.eu.spryker.local/suppliers/1' \
  -H 'Accept: application/ld+json' | python3 -m json.tool
```

Expected collection response:
```json
{
  "@context": "/contexts/Supplier",
  "@id": "/suppliers",
  "@type": "Collection",
  "totalItems": 4,
  "member": [
    {
      "@id": "/suppliers/1",
      "@type": "Supplier",
      "idSupplier": 1,
      "name": "Acme Supplies",
      "description": "leading supplier of industrial equipment",
      "status": 1,
      "email": "contact@acmesupplies.com",
      "phone": "+1-555-1234"
    }
  ],
  "view": {
    "@id": "/suppliers",
    "@type": "PartialCollectionView"
  }
}
```

> **Response formats:** API Platform supports multiple formats via the `Accept` header:
>
> | Accept Header | Format | Description |
> |---------------|--------|-------------|
> | `application/ld+json` | JSON-LD | Default. Linked Data with `@context`, `@id`, `@type` metadata |
> | `application/json` | Plain JSON | Raw JSON without metadata |
> | `application/vnd.api+json` | JSON:API | JSON:API specification format |
>
> JSON-LD is the default and recommended format for API Platform.

---

## Registering Services in the Symfony Container

API Platform providers use **Symfony's dependency injection** - not Spryker's Factory/DependencyProvider pattern. Your provider asks for `SprykerAcademy\Client\SupplierSearch\SupplierSearchClientInterface` in its constructor, and the Glue application's Symfony container has to resolve it.

For Clients and Facades of the core and of `Pyz`, Spryker registers these services automatically. For any other namespace the automatic registration falls back to a proxy that fails as soon as it is called:

```
Could not find the "SprykerAcademy\Client\SupplierSearch\SupplierSearchClientInterface" in any of the attached containers.
```

So the `SprykerAcademy` Clients (and the Business layer, for Backend API providers) are registered explicitly. The exercise loader added this block to `config/Glue/ApplicationServices.php` (and to the `GlueStorefront` and `GlueBackend` ones) once:

```php
// >>> spryker-academy setup: SprykerAcademy Clients and Facades for API Platform providers
$academyServices = $configurator->services()->defaults()->autowire()->public()->autoconfigure();
if (is_dir(__DIR__ . '/../../src/SprykerAcademy/Client')) {
    $academyServices->load('SprykerAcademy\\Client\\', '../../src/SprykerAcademy/Client/');
}
// ... the same for src/SprykerAcademy/Zed/*/Business/
// <<< spryker-academy setup
```

> **`$services->load()`** tells Symfony to scan a directory and auto-register all classes under that namespace as services. Combined with `->autowire()`, Symfony can then resolve an interface to its only implementation.

> **Alternative:** You can also register individual services explicitly:
> ```php
> $services->set(\SprykerAcademy\Client\SupplierSearch\SupplierSearchClientInterface::class, \SprykerAcademy\Client\SupplierSearch\SupplierSearchClient::class);
> ```
> This is more precise but requires updating whenever you add new dependencies.

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
./exercises/load.sh supplier intermediate/glue-storefront/complete --run
```
