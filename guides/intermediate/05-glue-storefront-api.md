# Exercise 12: Glue Storefront and Backend API - Supplier

In this exercise, you will expose supplier data through REST API endpoints using Spryker's API Platform. You will create a Storefront API resource and a Backend API resource for suppliers, page through the collections, and let API clients ask for the locations of a supplier in the same request.

You will learn how to:
- Define an API resource using YAML configuration (`.resource.yml`)
- Implement a Provider class that fetches and maps data
- Map internal Transfer objects to generated API Resource objects
- Work with Spryker's API Platform (not the legacy GlueApplication approach)
- Handle both Get (single) and GetCollection (list) operations
- Tell the Storefront API (published data) from the Backend API (the database, through a facade)
- Page through a collection with `page[offset]` and `page[limit]`
- Declare a relationship, so that `?include=supplier-locations` returns the locations of a supplier

| API | Host | Reads from | Endpoints of this exercise |
|-----|------|-----------|----------------------------|
| Storefront | `glue.eu.spryker.local` | Elasticsearch, through the `SupplierSearch` client | `/suppliers`, `/suppliers/{idSupplier}` |
| Backend | `glue-backend.eu.spryker.local` | The database, through the `Supplier` facade | `/suppliers`, `/suppliers/{idSupplier}`, `/suppliers/{idSupplier}/supplier-locations`, `/supplier-locations/{idSupplierLocation}` |

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

The Backend API is a second application (`glue-backend.eu.spryker.local`, `apiTypes(['backend'])` in `config/GlueBackend/packages/spryker_api_platform.php`) with its own resources, generated classes (`src/Generated/Api/Backend`) and cache:

```bash
docker/sdk cli GLUE_APPLICATION=GLUE_BACKEND glue api:generate backend
```

The API type is the directory a resource file lives in: `resources/api/storefront/suppliers.resource.yml` is a Storefront resource, `resources/api/backend/suppliers.resource.yml` a Backend one. Both may have the same name; they are two different resources with two different providers.

### API Platform Commands Reference

| Command | Purpose |
|---------|---------|
| `docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront` | Generate Storefront API resources |
| `docker/sdk cli GLUE_APPLICATION=GLUE_BACKEND glue api:generate backend` | Generate Backend API resources |
| `docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear` | Delete the compiled Glue container and its metadata cache, so the next request reads the generated resources again |
| `docker/sdk cli GLUE_APPLICATION=GLUE_BACKEND glue cache:clear` | The same for the Backend API application |
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

`glue cache:clear` deletes that cache, and the next request builds it from the current files. `docker/sdk console cache:empty-all` does **not** reach it: it clears the Zed, Yves and console caches, not the per-application Glue container. Rule of thumb: **after every change to a `resource.yml` run both commands, generate first** - and for the application the resource belongs to: `GLUE` + `storefront`, or `GLUE_BACKEND` + `backend`.

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

### Storefront API and Backend API

| | Storefront API | Backend API |
|---|---|---|
| Who calls it | Shops, apps, customers | ERP, PIM, back-office integrations |
| Data source | Published data: Redis and Elasticsearch, through a **Client** | The database, through a **Zed facade** |
| Provider base class | `AbstractStorefrontProvider` | `AbstractBackendProvider` |
| Resource files | `resources/api/storefront/` | `resources/api/backend/` |

The Storefront API never queries the database: it scales with the storefront and serves what Publish & Synchronize put into Redis and Elasticsearch. The Backend API runs next to Zed and works on the source data. That is why the locations of a supplier are available in the Backend API of this exercise only: they are in the database, but nothing publishes them.

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

The skeleton already has the resource name, operations (Get + GetCollection), pagination config, the `idSupplier` identifier property and the `pagination` property (see [Pagination](#pagination-pageoffset-and-pagelimit)).

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

### Part 2: Implement the Storefront Provider

The Provider is the core of the API resource. It receives the HTTP request context and returns data. It replaces the controller + reader pattern from the old approach.

**Coding time:**

Open `src/SprykerAcademy/Glue/Supplier/Api/Storefront/Provider/SuppliersStorefrontProvider.php`. The class extends `Spryker\ApiPlatform\State\Provider\AbstractStorefrontProvider` and receives the `SupplierSearchClientInterface` of Exercise 11 through its constructor - the storefront reads suppliers from Elasticsearch, not from the database.

`AbstractStorefrontProvider` implements `ApiPlatform\State\ProviderInterface::provide()` for you: it calls `provideCollection()` for a GetCollection operation and `provideItem()` for a Get.

In `provideItem()` (`GET /suppliers/{idSupplier}`):

1. Read the supplier identifier from `$this->getUriVariables()` - the key name must match the `identifier` property in the YAML
2. Call `findSupplierById((int)$idSupplier)`
3. The client returns an empty `SupplierTransfer` for an unknown id: return null then (API Platform answers with a 404)
4. Map the `SupplierTransfer` to a `SuppliersStorefrontResource` using the provided Mapper

In `provideCollection()` (`GET /suppliers`):

5. Read the requested page with `$this->getPaginationLimit()` and `$this->getPaginationOffset()`
6. Call `searchSuppliers()` with the request parameters `SupplierSearchConfig::PARAMETER_OFFSET` and `SupplierSearchConfig::PARAMETER_LIMIT`
7. Loop over `SupplierCollectionTransfer::getSuppliers()` and map each transfer to a resource
8. Set the pagination on the first resource: `SuppliersPaginationStorefrontObject::fromArray($this->calculatePagination($offset, $limit, $numFound))`, where `$numFound` is `getPagination()->getNbResults()` of the collection transfer

> **URI variables:** For a GET request to `/suppliers/5`, `$this->getUriVariables()` is `['idSupplier' => '5']`. The key name comes from the identifier property in the resource YAML.

#### Pagination: `page[offset]` and `page[limit]`

Spryker's APIs page with an offset and a limit, as the JSON:API convention of the legacy Glue API did:

```
GET /suppliers?page[offset]=2&page[limit]=2
```

Three places work together:

| Where | What it does |
|---|---|
| The provider | Reads `page[offset]` and `page[limit]` (`getPaginationOffset()`, `getPaginationLimit()`; the limit defaults to `paginationItemsPerPage` of the resource YAML) and asks the data source for **that page only** |
| The data source | Cuts the page out and counts all matches. Here: `SupplierPaginationQueryExpanderPlugin` sets Elasticsearch's `from` and `size`, and `SupplierSearchResultFormatterPlugin` puts the total hits into `SupplierCollectionTransfer.pagination.nbResults` |
| The `pagination` property of the resource | The provider sets it on the **first** item of the collection (`numFound`, `currentPage`, `maxPage`, `currentItemsPerPage`). Glue reads it there and adds the `first`, `prev`, `next` and `last` links to the response |

> **Never load everything and slice it in PHP.** `array_slice()` over all suppliers returns the right page, but the database or Elasticsearch still delivers every row for every request. Pass the offset and the limit down to the data source.

> **Why not API Platform's own paginator?** API Platform can page with `?page=2&itemsPerPage=10` when a provider returns a `PaginatorInterface` object. Spryker's relationship handling (`?include=`, Part 6) only works on a plain array, so a provider that returns a paginator loses its includes. Spryker's own resources (orders, catalog search) use the convention shown here.

---

### Part 3: Review the Mapper

The Mapper converts internal `SupplierTransfer` objects to generated `SuppliersStorefrontResource` objects.

Open `src/SprykerAcademy/Glue/Supplier/Processor/Mapper/SupplierMapper.php` and review how it maps transfers to API resources. Note `toArray(false, true)`: the generated resource reads camel-cased keys (`idSupplier`), while `toArray()` without arguments returns snake_case (`id_supplier`) - the resource would miss its identifier and API Platform could not build the links.

> **Generated Resource classes:** API Platform generates PHP classes from the YAML properties. These classes have `fromArray()` and expose the properties defined in the YAML. The Mapper bridges the internal domain model (Transfer) to the API model (Resource).

---

### Part 4: Test the Storefront Endpoints

After completing Parts 1 to 3, generate the API resources and clear the Glue cache (see [Why `cache:clear` Follows `api:generate`](#why-cacheclear-follows-apigenerate)):

```bash
docker/sdk cli GLUE_APPLICATION=GLUE glue api:generate storefront
docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear
```

Test the collection:
```bash
curl -s 'http://glue.eu.spryker.local/suppliers' \
  -H 'Accept: application/vnd.api+json' | python3 -m json.tool
```

Test a single supplier (use an `idSupplier` from the collection; in a fresh shop the first supplier has id 1):
```bash
curl -s 'http://glue.eu.spryker.local/suppliers/1' \
  -H 'Accept: application/vnd.api+json' | python3 -m json.tool
```

Test the second page of two suppliers (`-g` stops curl from interpreting the square brackets):
```bash
curl -s -g 'http://glue.eu.spryker.local/suppliers?page[offset]=2&page[limit]=2' \
  -H 'Accept: application/vnd.api+json' | python3 -m json.tool
```

Expected response of the paged request (4 suppliers, 2 per page, page 2):
```json
{
  "links": {
    "self": "http://glue.eu.spryker.local/suppliers",
    "first": "http://glue.eu.spryker.local/suppliers?page[limit]=2&page[offset]=0",
    "last": "http://glue.eu.spryker.local/suppliers?page[limit]=2&page[offset]=2",
    "prev": "http://glue.eu.spryker.local/suppliers?page[limit]=2&page[offset]=0"
  },
  "meta": {
    "totalItems": 2
  },
  "data": [
    {
      "id": 3,
      "type": "Supplier",
      "attributes": {
        "idSupplier": 3,
        "name": "TechSource Inc",
        "description": "technology products supplier",
        "status": 1,
        "email": "sales@techsource.com",
        "phone": "+1-555-9012",
        "pagination": {
          "numFound": 4,
          "currentPage": 2,
          "maxPage": 2,
          "currentItemsPerPage": 2
        }
      },
      "links": {
        "self": "http://glue.eu.spryker.local/suppliers/3"
      }
    },
    {
      "id": 4,
      "type": "Supplier",
      "attributes": {
        "idSupplier": 4,
        "name": "Green Earth Supply"
      },
      "links": {
        "self": "http://glue.eu.spryker.local/suppliers/4"
      }
    }
  ]
}
```

The last page has no `next` link, the first one no `prev`. `meta.totalItems` counts the items of this response; the number of all suppliers is `pagination.numFound`.

> **Response formats:** API Platform supports multiple formats via the `Accept` header:
>
> | Accept Header | Format | Description |
> |---------------|--------|-------------|
> | `application/vnd.api+json` | JSON:API | Spryker's default. `data`, `attributes`, `relationships`, `included`, `links` |
> | `application/json` | JSON:API | Treated like `application/vnd.api+json` in this shop |
> | `application/ld+json` | JSON-LD | Linked Data with `@context`, `@id`, `@type` metadata |
>
> The page links and the `included` section of Part 6 are JSON:API features: use `application/vnd.api+json` for them.

---

### Part 5: The Backend API Resource

The Backend API serves integrations that work on the source data. Its `suppliers` resource has the same properties as the Storefront one, but its provider reads the database through the `Supplier` facade.

**Coding time:**

1. Open `src/SprykerAcademy/Glue/Supplier/resources/api/backend/suppliers.resource.yml` and add the `provider`: `SprykerAcademy\Glue\Supplier\Api\Backend\Provider\SuppliersBackendProvider`. Leave TODO-2 for Part 6.
2. Open `src/SprykerAcademy/Glue/Supplier/Api/Backend/Provider/SuppliersBackendProvider.php`. The class extends `Spryker\ApiPlatform\State\Provider\AbstractBackendProvider` and receives the `SupplierFacadeInterface` through its constructor.

In `provideItem()`:

1. Read the supplier id from `$this->getUriVariables()`
2. Load the supplier with `findSupplierById((int)$idSupplier)`; the facade returns `null` for an unknown id - return `null` then
3. Map the `SupplierTransfer` to a `SuppliersBackendResource` with the provided `SupplierBackendMapper`

In `provideCollection()`:

4. Read the limit and the offset with the provided `getPageParameter()` (`AbstractBackendProvider` has no pagination helpers)
5. Load the page with `getPaginatedSupplierCollection()`: a `SupplierCriteriaTransfer` with a `PaginationTransfer` that has the offset and the limit
6. Map every `SupplierTransfer` to a resource
7. Set the pagination on the first resource: `SuppliersPaginationBackendObject::fromArray([...])` with `numFound`, `currentPage`, `maxPage` and `currentItemsPerPage`

> **The facade is provided.** `SupplierFacade::getPaginatedSupplierCollection()` and `getSupplierLocationCollection()` come with the exercise. Open `SupplierRepository::getPaginatedSupplierCollection()`: it counts the matching suppliers first, then applies `offset()` and `limit()` to the query - the database cuts the page out.

> **A facade in a Glue class?** In the Storefront API that is forbidden: the storefront must not depend on Zed. The Backend API application runs with access to Zed, so its providers may inject facades. The loader registered the `SprykerAcademy` Business layers as services in `config/GlueBackend/ApplicationServices.php`.

---

### Part 6: Include the Supplier Locations

A supplier has locations (`pyz_supplier_location`, imported in Exercise 8). An API client that shows a supplier usually needs them too. Instead of a second request per supplier, JSON:API lets the client ask for related resources in the same request:

```
GET /suppliers?include=supplier-locations
```

The response then has a `relationships` entry per supplier and the locations in a top-level `included` list. Without `?include=`, the response stays small.

In Spryker's API Platform a relationship is declared in the YAML of the resource that offers it. It names a **target resource**; Glue asks that resource's provider for the related items.

**Coding time:**

1. Review `src/SprykerAcademy/Glue/Supplier/resources/api/backend/supplier-locations.resource.yml`: the `SupplierLocations` resource. Its collection lives under its supplier (`/suppliers/{idSupplier}/supplier-locations`), a single location has its own URL (`/supplier-locations/{idSupplierLocation}`).

2. Open `src/SprykerAcademy/Glue/Supplier/Api/Backend/Provider/SupplierLocationsBackendProvider.php` and implement `provide()`:
   - With `idSupplierLocation` in `$uriVariables`: load that location (criteria `setIdSupplierLocation()`), return the first resource or `null`
   - Without `idSupplier` in `$uriVariables`: return an empty array
   - Otherwise: return the locations of that supplier (criteria `setFkSupplier()`)

3. In `resources/api/backend/suppliers.resource.yml`, add the relationship (TODO-2):

```yaml
    includes:
        - relationshipName: supplier-locations
          targetResource: SupplierLocations
          uriTemplate: /suppliers/{idSupplier}/supplier-locations
          uriVariableMappings:
              idSupplier: idSupplier
```

| Key | Meaning |
|---|---|
| `relationshipName` | The value of `?include=` and the key in `relationships` |
| `targetResource` | The `name` of the related resource's YAML (`SupplierLocations`), not its file name or URL |
| `uriTemplate` | The collection URL of the target resource |
| `uriVariableMappings` | `<URI variable of the target provider>: <property of this resource>`. For every supplier of the response Glue calls `SupplierLocationsBackendProvider::provide()` with `['idSupplier' => <the supplier's idSupplier>]` |

> **One provider, three uses.** `SupplierLocationsBackendProvider` answers `GET /suppliers/6/supplier-locations`, `GET /supplier-locations/7` and the include. For the include there is no HTTP request to the locations URL: Glue calls the provider directly with the mapped URI variables.

> **One query per supplier.** With `uriVariableMappings` Glue calls the target provider once for every supplier of the page: a page of 10 suppliers runs 10 location queries. That is bounded by the page size, and fine here. For larger pages, implement `Spryker\ApiPlatform\Provider\BatchLoadableProviderInterface` in the target provider (Glue then calls it once, with all suppliers' URI variables in `$uriVariables['_batch_data']`), or write a `resolverClass` that implements `PerItemRelationshipResolverInterface`.

> **An include needs an array.** Glue resolves relationships only when the provider returns one resource or a plain array of resources. That is why `provideCollection()` returns an array and carries the pagination in a property.

---

### Part 7: Test the Backend Endpoints

Generate the Backend API resources and clear the cache of the Backend API application:

```bash
docker/sdk cli GLUE_APPLICATION=GLUE_BACKEND glue api:generate backend
docker/sdk cli GLUE_APPLICATION=GLUE_BACKEND glue cache:clear
```

```bash
# The collection, and a page of it
curl -s -g 'http://glue-backend.eu.spryker.local/suppliers?page[offset]=0&page[limit]=2' \
  -H 'Accept: application/vnd.api+json' | python3 -m json.tool

# One supplier with its locations
curl -s 'http://glue-backend.eu.spryker.local/suppliers/1?include=supplier-locations' \
  -H 'Accept: application/vnd.api+json' | python3 -m json.tool

# A page of suppliers, each with its locations
curl -s -g 'http://glue-backend.eu.spryker.local/suppliers?page[limit]=2&include=supplier-locations' \
  -H 'Accept: application/vnd.api+json' | python3 -m json.tool

# The locations of one supplier, and one location
curl -s 'http://glue-backend.eu.spryker.local/suppliers/1/supplier-locations' \
  -H 'Accept: application/vnd.api+json' | python3 -m json.tool
curl -s 'http://glue-backend.eu.spryker.local/supplier-locations/1' \
  -H 'Accept: application/vnd.api+json' | python3 -m json.tool
```

Expected response of `GET /suppliers/1?include=supplier-locations`:
```json
{
  "data": {
    "id": 1,
    "type": "Supplier",
    "attributes": {
      "idSupplier": 1,
      "name": "Acme Supplies",
      "description": "leading supplier of industrial equipment",
      "status": 1,
      "email": "contact@acmesupplies.com",
      "phone": "+1-555-1234"
    },
    "links": {
      "self": "http://glue-backend.eu.spryker.local/suppliers/1?include=supplier-locations"
    },
    "relationships": {
      "supplier-locations": {
        "data": [
          { "type": "SupplierLocation", "id": "1" },
          { "type": "SupplierLocation", "id": "2" }
        ]
      }
    }
  },
  "included": [
    {
      "type": "SupplierLocation",
      "id": "1",
      "attributes": {
        "idSupplierLocation": 1,
        "idSupplier": 1,
        "city": "New York",
        "country": "USA",
        "address": "123 Broadway Ave",
        "zipCode": "10001",
        "isDefault": true
      }
    },
    {
      "type": "SupplierLocation",
      "id": "2",
      "attributes": {
        "idSupplierLocation": 2,
        "idSupplier": 1,
        "city": "Los Angeles",
        "country": "USA",
        "address": "456 Sunset Blvd",
        "zipCode": "90028",
        "isDefault": false
      }
    }
  ]
}
```

In the collection every supplier has its own `relationships` entry, and `included` lists the locations of all suppliers of the page.

> **These endpoints are public.** The Backend API of this shop lets a resource decide who may call it, and the exercise resources do not restrict anything. A real Backend resource adds a `security` expression to its YAML and is called with a Backend API access token.

---

## Registering Services in the Symfony Container

API Platform providers use **Symfony's dependency injection** - not Spryker's Factory/DependencyProvider pattern. Your provider asks for `SprykerAcademy\Client\SupplierSearch\SupplierSearchClientInterface` in its constructor, and the Glue application's Symfony container has to resolve it.

For Clients and Facades of the core and of `Pyz`, Spryker registers these services automatically. For any other namespace the automatic registration falls back to a proxy that fails as soon as it is called:

```
Could not find the "SprykerAcademy\Client\SupplierSearch\SupplierSearchClientInterface" in any of the attached containers.
```

So the `SprykerAcademy` Clients (and the Business layer, for the Backend API providers of Part 5 and 6) are registered explicitly. The exercise loader added this block to `config/Glue/ApplicationServices.php` (and to the `GlueStorefront` and `GlueBackend` ones) once:

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
| `page[limit]=2` still returns all suppliers | The provider does not pass the offset and the limit to the client or the facade | `searchSuppliers([PARAMETER_OFFSET => $offset, PARAMETER_LIMIT => $limit])`; in the Backend provider a `PaginationTransfer` on the criteria |
| The page is right, but the response has no `first`/`next`/`last` links | The first resource has no `pagination`, or the request did not ask for JSON:API | Set `$resources[0]->pagination`; send `Accept: application/vnd.api+json` |
| `last` points to a wrong page, `numFound` equals the page size | `numFound` was filled with `count($resources)` | Use `getPagination()->getNbResults()` of the collection transfer: the total of all pages |
| Every Backend API URL answers `{"errors":[{"status":404,"code":"007","message":"Not found"}]}` | The Backend API has no API Platform routes: `config/GlueBackend/routes/api_platform.php` of the demo shop checks for `src/Generated/Api/Backend` in the wrong directory, or the Backend resources were not generated | `load.sh` corrects the check (`dirname(__DIR__, 3)`); then `GLUE_APPLICATION=GLUE_BACKEND glue api:generate backend` and `GLUE_APPLICATION=GLUE_BACKEND glue cache:clear` |
| The Backend API answers that `404` although `glue debug:router` lists the route | The request failed inside API Platform and Glue fell back to its own "not found". Typical: a legacy Storefront REST plugin ran in the Backend API | Read the log of the `gluebackend_eu` container. The branch ships `src/SprykerAcademy/Glue/GlueApplication/GlueApplicationDependencyProvider.php`, which keeps the Storefront plugins out of the Backend API: run `docker/sdk console c:e` and `glue cache:clear` if it is not picked up |
| `?include=supplier-locations` is ignored: no `relationships`, no `included` | The `includes` block is missing or the resources were not regenerated; `relationshipName` differs from the value in the URL; or the provider returns something other than a resource or a plain array | Check the YAML, `api:generate backend`, `cache:clear`; return an array from `provideCollection()` |
| `included` is empty, `relationships` too | `uriVariableMappings` names a property the supplier resource does not have, or the locations provider ignores `$uriVariables['idSupplier']` | `idSupplier: idSupplier`; filter with `setFkSupplier()` |
| `500`: *Unable to generate an IRI for the item of type ...SupplierLocationsBackendResource* | The resource has no Get operation API Platform can build a link from | Keep the `Get` operation with `uriTemplate: /supplier-locations/{idSupplierLocation}` |
| A change is not there right after `api:generate` + `cache:clear` | The generated files had not reached the Glue container yet when its cache was rebuilt (file sync of the Docker SDK) | Run `glue cache:clear` once more |

### Seeing the Real Error Behind a `500`

A `500` from an API Platform endpoint only says `"detail":"Internal Server Error"`, even in the development environment. The full exception is in the log of the Glue container.

**In the browser:** open http://spryker.local, the Docker SDK dashboard, and choose **Logs**. It shows the log of every container; pick the Glue one (`glue_eu`).

**From a shell:**

```bash
docker ps --format '{{.Names}}' | grep glue      # the container name, e.g. gluedemo_glue_eu_1
docker logs -f gluedemo_glue_eu_1                # follow it, then send the request again
```

The line to look for:

```
[error] Uncaught exception on API Platform request "GET /suppliers/5434543545": Search failed with the following reason: ...
```

> **Why the response hides it.** Glue builds its Symfony kernel without the debug flag, so `kernel.debug` is `false` in every environment, and API Platform's error provider only puts the exception message and trace into the response when it is `true`. Spryker's `debug` option in `config/Glue/packages/spryker_api_platform.php` is meant to switch that on, but in this release it does not reach API Platform: `ApiPlatformBundle` is registered after `SprykerApiPlatformBundle` in `config/Glue/bundles.php` and defines the error provider again with `%kernel.debug%`. Setting `debug(true)` alone therefore only changes the format of the error, not its detail. Read the log instead; it has the message and, with the file and line, everything you need.

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

### Storefront vs Backend

- **Storefront** provider: extends `AbstractStorefrontProvider`, injects a **Client**, reads published data.
- **Backend** provider: extends `AbstractBackendProvider`, injects a **Facade**, reads (and in real projects writes, through a Processor) the database.

### Pagination and Includes

- The provider passes `page[offset]` and `page[limit]` to the data source, returns the page as a plain array and sets `pagination` on its first item; Glue adds the page links.
- `includes` in the resource YAML + a target resource with its own provider = `?include=<relationshipName>`.

### Provider Pattern

The Provider implements a single method:

```
provide(Operation $operation, array $uriVariables, array $context): object|array|null
```

- Return an **object** → single resource response
- Return an **array** → collection response
- Return **null** → 404 response

`AbstractStorefrontProvider` and `AbstractBackendProvider` implement it and split it into `provideItem()` and `provideCollection()`.

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

> **Going further:** The Backend API of this exercise only reads. Writing works with a **Processor** (`processor:` in the YAML, `Post`/`Patch`/`Delete` operations, a class that implements `ApiPlatform\State\ProcessorInterface` and calls `SupplierFacade::createSupplier()`), see `Spryker\Glue\Store\Api\Backend\Processor\StoresBackendProcessor` in the core.
