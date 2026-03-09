# Exercise 11: Search - Supplier

In this exercise, you will build a search client that queries Elasticsearch for suppliers by name and displays the result in the Yves storefront. You will work with Spryker's Elasticsearch abstraction: query plugins, result formatter plugins, and the SearchClient.

You will learn how to:
- Define an Elasticsearch mapping (analyzer, index schema)
- Build a search query plugin using Elastica's BoolQuery
- Build a result formatter plugin to convert Elasticsearch results to Transfer objects
- Wire the SearchClient through the DependencyProvider and Factory
- Create a Client module that exposes search functionality
- Display search results in a Yves storefront page

## Prerequisites

- Completed Exercise 10 (Publish & Synchronize) — suppliers must be indexed in Elasticsearch
- Suppliers should exist in the `pyz_supplier_search` table

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/search/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console propel:install
docker/sdk console search:setup
```

---

## Background: Search Architecture in Spryker

Spryker uses Elasticsearch as the search storage. The Client layer provides an abstraction over raw Elasticsearch queries:

```
SupplierSearchClient
    ↓
SupplierSearchFactory
    ├── createSupplierQueryPlugin(name) → builds Elastica Query
    ├── getSearchQueryFormatters()      → result formatter plugins
    └── getSearchClient()               → Spryker SearchClient
                                              ↓
                                         Elasticsearch
                                              ↓
                                         ResultSet
                                              ↓
                                    SupplierSearchResultFormatterPlugin
                                              ↓
                                         SupplierTransfer
```

**Key components:**

| Component | Role |
|-----------|------|
| Query Plugin | Builds the Elastica `Query` with filters and search terms |
| Result Formatter | Converts Elastica `ResultSet` into Transfer objects |
| SearchClient | Core Spryker client that executes queries against Elasticsearch |
| Source Identifier | Maps the query to a specific Elasticsearch index |

---

## Working on the Exercise

### Part 1: Elasticsearch Mapping

The exercise provides an Elasticsearch mapping schema at `src/SprykerAcademy/Shared/SupplierSearch/Schema/supplier.json`. Open it and review:

- The `settings` define an `edge_ngram` analyzer for partial matching (typing "Sup" matches "Supplier")
- The `mappings` define the document structure with field types:
  - `text` for searchable fields (`name`, `description`) - analyzed and tokenized
  - `integer` for the status field (matches the Propel schema INTEGER type)
  - `keyword` for exact match fields (`email`, `phone`) - not analyzed
  - `integer` for the supplier ID

**Mapping structure:**
```json
{
    "mappings": {
        "supplier": {
            "properties": {
                "id_supplier": { "type": "integer" },
                "name": { "type": "text", "analyzer": "default_analyzer" },
                "description": { "type": "text", "analyzer": "default_analyzer" },
                "status": { "type": "integer" },
                "email": { "type": "keyword" },
                "phone": { "type": "keyword" }
            }
        }
    }
}
```

The mapping type name (`supplier`) must match the `type` parameter in the synchronization behavior from `pyz_supplier_search.schema.xml`.

After loading the exercise, run `docker/sdk console search:setup` to create the index in Elasticsearch.

> **Index name whitelisting:** The schema filename (`supplier.json`) must be whitelisted in `SearchElasticsearchConfig` for auto-discovery. Check if this is configured in the project.

---

### Part 2: Build the Search Query Plugins

The query plugins build the Elastica queries that get sent to Elasticsearch. There are two plugins:

| Plugin | Purpose | Elastica Query |
|--------|---------|----------------|
| `SupplierSearchQueryPlugin` | Returns all suppliers | `Exists('id_supplier')` |
| `SupplierByIdSearchQueryPlugin` | Finds one supplier by ID | `Term(['id_supplier' => $id])` |

Both plugins implement `SearchContextAwareQueryInterface` with `sourceIdentifier = 'supplier'`. This tells Spryker which Elasticsearch index to query — since every document in the supplier index is already a supplier, we don't need a `type` filter.

**Coding time:**

Open `src/SprykerAcademy/Client/SupplierSearch/Plugin/Elasticsearch/Query/SupplierSearchQueryPlugin.php`:

1. In `createSearchQuery()`, build a query using `Elastica\Query\Exists` on the `id_supplier` field. This returns all documents that have a supplier ID (i.e., all suppliers in the index).

2. Implement `getSearchContext()` to return a `SearchContextTransfer` with the source identifier set to `'supplier'`.

Open `src/SprykerAcademy/Client/SupplierSearch/Plugin/Elasticsearch/Query/SupplierByIdSearchQueryPlugin.php`:

1. In `createSearchQuery()`, build a query using `Elastica\Query\Term` on the `id_supplier` field with the value from `$this->idSupplier`. The `Term` query performs an **exact match** — no analysis or tokenization, just a direct value comparison. Set the query size to 1 since we expect a single result.

2. Implement `setIdSupplier()` as a setter that stores the ID and resets the cached query (so it rebuilds with the new ID).

> **Exists vs Term vs MatchQuery:**
> - `Exists('field')` — returns documents where the field is present (any value). Used for "give me all suppliers".
> - `Term(['field' => value])` — exact match on a keyword/integer field. Used for "find supplier with ID 5". No analysis applied.
> - `MatchQuery('field', 'text')` — full-text search with analysis and tokenization. Used for searching text fields like name or description. **Not suitable** for filtering by type or ID.
>
> Since the `sourceIdentifier` already targets the supplier-specific Elasticsearch index, we don't need a type filter — every document in that index is a supplier.

> **SearchContextAwareQueryInterface:** The plugin implements this to tell Spryker which Elasticsearch index to query. The source identifier `'supplier'` gets resolved to the actual index name (e.g., `eu_search_supplier`) by the search infrastructure.

---

### Part 3: Build the Result Formatter Plugin

The result formatter converts raw Elasticsearch results into Spryker Transfer objects.

**Coding time:**

Open `src/SprykerAcademy/Client/SupplierSearch/Plugin/Elasticsearch/ResultFormatter/SupplierSearchResultFormatterPlugin.php`:

In `formatSearchResult()`, iterate through the result set, get the source data from the first document, and create a `SupplierTransfer` from it.

> **Document source:** Each Elasticsearch result has a `_source` field containing the original JSON document. Elastica provides it via `$document->getSource()`, which returns an array.

> **Transfer fromArray():** Spryker transfers can be populated from arrays: `(new SupplierTransfer())->fromArray($sourceArray)`. This works because the keys in Elasticsearch match the transfer property names.

---

### Part 4: Wire the Dependencies

#### 4.1 DependencyProvider

**Coding time:**

Open `src/SprykerAcademy/Client/SupplierSearch/SupplierSearchDependencyProvider.php`:

1. In `provideServiceLayerDependencies()`, call `addSearchClient()` and `addSupplierSearchResultFormatterPlugins()`
2. In `addSearchClient()`, provide the core `SearchClient` via the locator
3. In `getSupplierSearchResultFormatterPlugins()`, return an array containing the `SupplierSearchResultFormatterPlugin` instance

> **Client vs Zed DependencyProvider:** In the Client layer, the method is `provideServiceLayerDependencies()` (not `provideBusinessLayerDependencies()` like in Zed).

#### 4.2 Factory

**Coding time:**

Open `src/SprykerAcademy/Client/SupplierSearch/SupplierSearchFactory.php`:

1. `getSearchQueryFormatters()` — return the formatters from the DependencyProvider
2. `getSearchClient()` — return the SearchClient from the DependencyProvider

---

### Part 5: Implement the SupplierSearchClient

The client orchestrates the search: creates the query, gets the formatters, executes the search, and returns the result.

**Coding time:**

Open `src/SprykerAcademy/Client/SupplierSearch/SupplierSearchClient.php`. In `getSupplierByName()`:

1. Create the query plugin via the factory (passing the name)
2. Get the result formatter plugins via the factory
3. Execute the search using the SearchClient's `search()` method (passing query + formatters)
4. Return the supplier from the results array using the formatter's `NAME` constant as key

> **SearchClient::search()** returns an associative array keyed by formatter names. Since our formatter is named `'supplier'`, the result is at `$results['supplier']`.

---

### Part 6: Display in Yves

The exercise provides a `SupplierPage` Yves module with two routes:

| Route | Action | Description |
|-------|--------|-------------|
| `/suppliers` | `listAction` | Shows all suppliers in a table |
| `/supplier/{idSupplier}` | `detailAction` | Shows a single supplier by ID |

Review these files:
- `SupplierPageRouteProviderPlugin` — registers both routes
- `SupplierPageDependencyProvider` — provides the `SupplierSearchClient`
- `SupplierPageFactory` — accesses the client
- `IndexController` — `listAction()` calls `searchSuppliers()`, `detailAction()` calls `findSupplierById()`

**Router registration:** The route provider is registered via `SprykerAcademy\Yves\Router\RouterDependencyProvider`, which extends the Pyz Router and adds the `SupplierPageRouteProviderPlugin`. This is done automatically by the exercise — no project modification needed.

After completing all parts:

```bash
docker/sdk console cache:empty-all
```

- Visit http://yves.eu.spryker.local/suppliers to see the supplier list
- Click a supplier to see its detail page at `/supplier/{id}`

---

## Testing

1. Ensure suppliers are indexed in Elasticsearch:
   ```bash
   curl -s 'localhost:9200/_search' -H 'Content-type: application/json' \
     -d '{"query":{"exists":{"field":"id_supplier"}}}'
   ```

2. Visit the Yves supplier list page and verify the table renders
3. Click a supplier and verify the detail page loads

---

## Run Automated Tests

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/Supplier/ Search
```

---

## Solution

```bash
./exercises/load.sh supplier intermediate/search/complete
```
