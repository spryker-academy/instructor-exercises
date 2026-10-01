# Exercise 12: Glue Storefront API - Supplier

In this exercise, you will expose supplier data through a REST API endpoint using Spryker's API Platform. You will create a Glue Storefront API resource that provides both single-item and collection endpoints for suppliers.

You will learn how to:
- Define an API resource using YAML configuration (`.resource.yml`)
- Implement a Provider class that fetches and maps data
- Map internal Transfer objects to generated API Resource objects
- Work with Spryker's API Platform (not the legacy GlueApplication approach)
- Handle both Get (single) and GetCollection (list) operations

## Prerequisites

- **You do not need your own solutions of the earlier exercises.** The branch contains them, and `load.sh --run` imports the sample suppliers and publishes them to Redis and Elasticsearch, so `/suppliers` has data to return.

## Loading the Exercise

Like every exercise from Exercise 9 on, the branch builds on the solutions of the earlier ones.

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
| `docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront` | Generate Storefront API resources |
| `docker/sdk cli GLUE_APPLICATION=GLUE_BACKEND glue api:generate backend` | Generate Backend API resources |
| `docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear` | Delete the compiled Glue container and its metadata cache, so the next request reads the generated resources again |
| `docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate --dry-run` | Preview what would be generated without writing |
| `docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate --validate-only` | Validate schemas without generating |
| `docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront -r Suppliers` | Generate only the `Suppliers` resource |
| `docker/sdk cli GLUE_APPLICATION=GLUE glue api:debug --list` | List all registered resources |
| `docker/sdk cli GLUE_APPLICATION=GLUE glue api:debug Suppliers` | Inspect a specific resource's merged schema |
| `docker/sdk cli GLUE_APPLICATION=GLUE glue api:debug Suppliers --show-sources` | Show all source files with priority |
| `docker/sdk cli GLUE_APPLICATION=GLUE glue api:debug Suppliers --show-merged` | Display the final merged YAML schema |

> **Resource names are case-sensitive.** `-r` and `api:debug` take the `name` of the resource YAML (`resource: name: Suppliers`), not the file name or the URL path `/suppliers`. `api:debug suppliers` fails with *Resource "suppliers" not found for ApiType "storefront"*, and `api:generate -r suppliers` silently generates nothing. `api:debug --list` shows the exact names.

> **Tip:** All `glue` CLI commands require the `GLUE_APPLICATION` env var. Run them inside the CLI container with `docker/sdk cli` and prefix every command with `GLUE_APPLICATION=GLUE` (the storefront API of this shop) or `GLUE_APPLICATION=GLUE_BACKEND` as needed.

### Why `cache:clear` Follows `api:generate`

The two commands work on different things:

- **`api:generate`** reads the `*.resource.yml` files and writes PHP resource classes to `src/Generated/Api/Storefront/`. It only writes files; it clears nothing.
- **The running Glue application never reads those files per request.** On its first request it compiles a Symfony container into `data/cache/Glue/<environment>/`: the API Platform services and source directories are baked into it, and API Platform stores its resource metadata (which classes are resources, their operations and routes, which provider handles them) in the cache pools next to it. Every later request uses that cache.

Nothing invalidates the cache when the generated classes change. So after a generate, Glue keeps answering from the old metadata:

| You changed | Without `cache:clear` |
|---|---|
| Added a resource | `404`: the resource is not in the cached list |
| Renamed or removed a resource, or changed its provider | `500`: the cached metadata points at a class that no longer exists |
| Only the code inside an existing provider method | Works: classes are autoloaded on every request |
| A provider's constructor, a new service, a source directory | Stale wiring: those are compiled into the container |

`glue cache:clear` deletes that cache, and the next request builds it from the current files. `docker/sdk console cache:empty-all` does **not** reach it: it clears the Zed, Yves and console caches, not the per-application Glue container. Rule of thumb: **after every change to a `resource.yml` run both commands, generate first.**

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

After completing all parts, generate the API resources and clear the Glue cache (see [Why `cache:clear` Follows `api:generate`](#why-cacheclear-follows-apigenerate)):

```bash
docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront
docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear
```

Test collection (JSON-LD format):
```bash
curl -s 'http://glue.eu.spryker.local/suppliers' \
  -H 'Accept: application/ld+json' | python3 -m json.tool
```

Test single supplier (use an `idSupplier` from the collection; in a fresh shop the first supplier has id 1):
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

## Troubleshooting: When the Endpoint Does Not Answer

API Platform endpoints are built from three things that live in different places: the resource YAML, the PHP classes **generated** from it, and the Glue application's **compiled Symfony container**. Most problems come from one of them being stale. Work through this list from the top.

| Symptom | Cause | Fix |
|---|---|---|
| `404 Not Found` for `/suppliers`, or your change to the YAML has no effect | The generated resource classes or the compiled Glue container still reflect the old YAML. `cache:empty-all` does **not** clear the Glue containers. | `docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront`, then `docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear` |
| `api:generate` finds nothing | `src/SprykerAcademy` is not in the source directories of the application you generated for, or you generated for another application | Check `sourceDirectories` in `config/Glue/packages/spryker_api_platform.php`; in this shop the storefront API runs in the `GLUE` application |
| `500` with *Could not find the "SprykerAcademy\Client\...Interface" in any of the attached containers* | The Glue container cannot resolve the client your provider injects. It registers Clients and Facades of the core and of `Pyz` automatically, but not of other namespaces. | The block that loads `src/SprykerAcademy/Client` in `config/Glue/ApplicationServices.php` is missing: see [Registering Services](#registering-services-in-the-symfony-container), then `glue cache:clear` |
| `500` after you loaded another exercise, naming a class of the previous one | Generated resources of the old exercise point at a provider that no longer exists | Load exercises with `load.sh` (it deletes them), or delete the files under `src/Generated/Api/Storefront` whose header names a `src/SprykerAcademy` schema, then `api:generate` and `glue cache:clear` |
| Items have no `id`/links, or `idSupplier` is `null` | The mapper fills the resource from snake_case keys (`id_supplier`); the generated resource reads camelCase (`idSupplier`) | `SuppliersStorefrontResource::fromArray($supplierTransfer->toArray(false, true))` |
| Items come back with `name` but `null` for `description`, `email`, ... | The Elasticsearch documents do not have those fields at the top level, so the search result cannot fill the transfer | The search document must be the flat one of `Schema/supplier.json` (Exercise 10). Rebuild the documents: delete the `pyz_supplier_search` rows, `publish:trigger-events -r supplier`, `queue:worker:start --stop-when-empty` |
| An empty collection right after loading | The queue workers write the documents to Elasticsearch a few seconds after `load.sh --run` returns | Wait a moment and call again; check with `curl -s localhost:9200/<store>_supplier/_count` (for example `gluedemo_de_supplier`) |
| `data:import` says *Requested import type "supplier" was not found in .../full_EU.yml* | The command ran without `--config`, so it read the shop's default import list | `docker/sdk console data:import --config=data/import/local/supplier_import.yml` |
| An empty collection that stays empty | Nothing was imported or published (you loaded without `--run`, or emptied the index) | `docker/sdk console data:import --config=data/import/local/supplier_import.yml`, `publish:trigger-events -r supplier`, `queue:worker:start --stop-when-empty` |
| `GET /suppliers/999999` answers `500` instead of `404` | The provider returns an empty resource for an unknown id | Return `null` when the client's transfer has no `idSupplier` |

### Seeing the Real Error Behind a `500`

By default a `500` from an API Platform endpoint only says `"detail":"Internal Server Error"`, even in the development environment. Glue builds its Symfony kernel without the debug flag, so `kernel.debug` is `false` for every environment, and that is what API Platform reads.

The message is always in the log of the Glue container:

```bash
docker logs -f gluedemo_glue_eu_1      # <project>_glue_eu_1; docker ps lists the names
# [error] Uncaught exception on API Platform request "GET /suppliers/...": <message>
```

To get the message and the stack trace **in the response**, two changes, for development only:

1. Switch on the debug option of Spryker's API Platform integration in `config/Glue/packages/spryker_api_platform.php`:

   ```php
   return static function (SprykerApiPlatformConfig $sprykerApiPlatform, string $env): void {
       // ...
       if ($env === 'dockerdev') {
           $sprykerApiPlatform->debug(true);
       }
   };
   ```

2. Make the option reach API Platform. `config/Glue/bundles.php` registers `ApiPlatformBundle` after `SprykerApiPlatformBundle`, and it redefines the error provider and the serializer context builder with `%kernel.debug%`, which overwrites Spryker's wiring of the option. Services defined in `config/Glue/ApplicationServices.php` win over bundle definitions, so define them there again:

   ```php
   use function Symfony\Component\DependencyInjection\Loader\Configurator\param;
   use function Symfony\Component\DependencyInjection\Loader\Configurator\service;

   // inside the closure, after the existing service definitions:
   $configurator->services()
       ->set('api_platform.state.error_provider', \ApiPlatform\State\ErrorProvider::class)
       ->arg('$debug', param('spryker_api_platform.debug'))
       ->arg('$resourceClassResolver', service('api_platform.resource_class_resolver'))
       ->arg('$resourceMetadataCollectionFactory', service('api_platform.metadata.resource.metadata_collection_factory'))
       ->tag('api_platform.state_provider', ['key' => 'api_platform.state.error_provider']);
   $configurator->services()
       ->set('api_platform.serializer.context_builder', \ApiPlatform\Serializer\SerializerContextBuilder::class)
       ->arg(0, service('api_platform.metadata.resource.metadata_collection_factory'))
       ->arg('$debug', param('spryker_api_platform.debug'));
   ```

Then `docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear`. A `500` now carries the exception message in `detail` and the stack in `trace`. With only step 1 the response format changes but the detail stays hidden - check with `grep -rh "ErrorProvider(" data/cache/Glue/dockerdev/` that the compiled provider gets `true`. Never enable this in production: traces expose paths and internals.

> **When in doubt, rebuild all three:** `docker/sdk console c:e`, `docker/sdk console propel:model:build`, `docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront`, `docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear`. `load.sh --run` does exactly this after every load.

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
