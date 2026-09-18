# Exercise 11: Search - Supplier

In this exercise, you will build a search client that queries Elasticsearch for suppliers. You will work with Spryker's Elasticsearch abstraction: query plugins, result formatter plugins, and the SearchClient. The storefront page that displays the results is built in Exercise 11 (Yves Storefront).

You will learn how to:
- Define an Elasticsearch mapping (analyzer, index schema)
- Build a search query plugin using Elastica's BoolQuery
- Build a result formatter plugin to convert Elasticsearch results to Transfer objects
- Wire the SearchClient through the DependencyProvider and Factory
- Create a Client module that exposes search functionality

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
SupplierSearchClient::searchSuppliers()
    ↓
SupplierSearchFactory::createSupplierSearchReader()
    ├── getSearchClient()                        → Spryker SearchClient
    ├── getSupplierSearchQueryPlugin()           → builds the Elastica Query
    ├── getSupplierSearchQueryExpanderPlugins()  → optional query expanders (empty here)
    └── getSupplierSearchResultFormatterPlugins() → result formatter plugins
                                              ↓
                                   SupplierSearchReader::searchSuppliers()
                                              ↓
                                         Elasticsearch
                                              ↓
                                         ResultSet
                                              ↓
                                    SupplierSearchResultFormatterPlugin
                                              ↓
                                    SupplierCollectionTransfer
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

Both plugins are provided by the skeleton. **Review time:**

Open `src/SprykerAcademy/Client/SupplierSearch/Plugin/Elasticsearch/Query/SupplierSearchQueryPlugin.php`:

1. `createSearchQuery()` builds a query using `Elastica\Query\Exists` on the `id_supplier` field. This returns all documents that have a supplier ID (i.e., all suppliers in the index).

2. `getSearchContext()` returns a `SearchContextTransfer` with the source identifier `SupplierSearchConfig::SUPPLIER_SOURCE_IDENTIFIER` (`'supplier'`).

Open `src/SprykerAcademy/Client/SupplierSearch/Plugin/Elasticsearch/Query/SupplierByIdSearchQueryPlugin.php`:

1. `createSearchQuery()` builds a query using `Elastica\Query\Term` on the `id_supplier` field with the value from `$this->idSupplier`. The `Term` query performs an **exact match** — no analysis or tokenization, just a direct value comparison. The query size is 1 since we expect a single result.

2. `setIdSupplier()` stores the ID and resets the cached query (so it rebuilds with the new ID).

> **Exists vs Term vs MatchQuery:**
> - `Exists('field')` — returns documents where the field is present (any value). Used for "give me all suppliers".
> - `Term(['field' => value])` — exact match on a keyword/integer field. Used for "find supplier with ID 5". No analysis applied.
> - `MatchQuery('field', 'text')` — full-text search with analysis and tokenization. Used for searching text fields like name or description. **Not suitable** for filtering by type or ID.
>
> Since the `sourceIdentifier` already targets the supplier-specific Elasticsearch index, we don't need a type filter — every document in that index is a supplier.

> **SearchContextAwareQueryInterface:** The plugin implements this to tell Spryker which Elasticsearch index to query. The source identifier `'supplier'` gets resolved to the actual index name (e.g., `eu_search_supplier`) by the search infrastructure.

---

### Part 3: Build the Result Formatter Plugin

The result formatter converts raw Elasticsearch results into Spryker Transfer objects. It is provided by the skeleton.

**Review time:**

Open `src/SprykerAcademy/Client/SupplierSearch/Plugin/Elasticsearch/ResultFormatter/SupplierSearchResultFormatterPlugin.php`:

`formatSearchResult()` iterates through the result set, takes the source data of every document and adds a `SupplierTransfer` built from it to a `SupplierCollectionTransfer`. `getName()` returns the key under which the SearchClient returns this formatted result (`SupplierSearchCollection`).

> **Document source:** Each Elasticsearch result has a `_source` field containing the original JSON document. Elastica provides it via `$document->getSource()`, which returns an array.

> **Transfer fromArray():** Spryker transfers can be populated from arrays: `(new SupplierTransfer())->fromArray($sourceArray)`. This works because the keys in Elasticsearch match the transfer property names.

---

### Part 4: Wire the Dependencies

#### 4.1 DependencyProvider

**Coding time:**

Open `src/SprykerAcademy/Client/SupplierSearch/SupplierSearchDependencyProvider.php`:

Complete the four TODOs in `provideServiceLayerDependencies()`. Every dependency is registered with `$container->set(KEY, closure)`:

1. `CLIENT_SEARCH` — the core Search client: `fn (Container $container) => $container->getLocator()->search()->client()`
2. `PLUGIN_SUPPLIER_SEARCH_QUERY` — a new `SupplierSearchQueryPlugin`
3. `PLUGINS_SUPPLIER_SEARCH_RESULT_FORMATTER` — an array with a new `SupplierSearchResultFormatterPlugin`
4. `PLUGINS_SUPPLIER_SEARCH_QUERY_EXPANDER` — an empty array (no query expanders in this exercise)

> **Client vs Zed DependencyProvider:** In the Client layer, the method is `provideServiceLayerDependencies()` (not `provideBusinessLayerDependencies()` like in Zed).

#### 4.2 Factory

**Coding time:**

Open `src/SprykerAcademy/Client/SupplierSearch/SupplierSearchFactory.php`:

Complete the five TODOs:

1. `createSupplierSearchReader()` — create the `SupplierSearchReader` with the Search client, the query plugin, the query expander plugins and the result formatter plugins (the skeleton passes empty arrays for the last two)
2. `getSearchClient()`, `getSupplierSearchQueryPlugin()`, `getSupplierSearchQueryExpanderPlugins()`, `getSupplierSearchResultFormatterPlugins()` — return the corresponding provided dependency with `$this->getProvidedDependency(SupplierSearchDependencyProvider::...)`

The `SupplierSearchReader` (provided) runs the search: it expands the query, calls `SearchClient::search()` with the formatters and returns the `SupplierCollectionTransfer` the formatter produced. `findSupplierById()` does the same with the `SupplierByIdSearchQueryPlugin`.

---

### Part 5: Implement the SupplierSearchClient

The client is the public entry point of the module and only delegates to the reader.

**Coding time:**

Open `src/SprykerAcademy/Client/SupplierSearch/SupplierSearchClient.php`. In `searchSuppliers()`, replace the empty collection with:

```php
return $this->getFactory()->createSupplierSearchReader()->searchSuppliers($requestParameters);
```

> **SearchClient::search()** returns an associative array keyed by formatter names. Our formatter is named `SupplierSearchCollection`, so the reader takes the collection from `$result['SupplierSearchCollection']`.

---

### Part 6: Try it out

After completing all parts:

```bash
docker/sdk console cache:empty-all
docker/sdk console propel:model:build
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/Supplier/ Search
```

The storefront page that lists the suppliers through this client is built in Exercise 11 (Yves Storefront).

---

## Testing

1. Ensure suppliers are indexed in Elasticsearch:
   ```bash
   curl -s 'localhost:9200/_search' -H 'Content-type: application/json' \
     -d '{"query":{"exists":{"field":"id_supplier"}}}'
   ```

2. Run the automated tests below

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
