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
  - `keyword` for exact match fields (`status`, `email`, `phone`) - not analyzed
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
                "status": { "type": "keyword" },
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

### Part 2: Build the Search Query Plugin

The query plugin builds the Elastica query that gets sent to Elasticsearch.

**Coding time:**

Open `src/SprykerAcademy/Client/SupplierSearch/Plugin/Elasticsearch/Query/SupplierSearchQueryPlugin.php`:

1. Set the `SOURCE_IDENTIFIER` constant to `'supplier'` — this must match:
   - The `type` parameter in the synchronization behavior from `pyz_supplier_search.schema.xml`
   - The mapping type name in `supplier.json`

2. In `getSearchQuery()`, build a `BoolQuery` with two `addMust()` conditions:
   - An `Exists` filter ensuring the document has an `id_supplier` field (only supplier documents)
   - A `MatchQuery` on the `name` field with the search term stored in `$this->name`

> **Field names:** The field names in your query must match the property names defined in the Elasticsearch mapping (`supplier.json`).

> **BoolQuery:** Elasticsearch's boolean query combines multiple conditions with must/should/must_not logic. `addMust()` means ALL conditions must match (AND logic).

> **SearchContextAwareQueryInterface:** The plugin implements this to tell Spryker which Elasticsearch index to query. The `SOURCE_IDENTIFIER` gets resolved to the actual index name by the search infrastructure.

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

The exercise provides a `SupplierPage` Yves module with a route `/supplier/{name}`. Review these files:
- `SupplierPageRouteProviderPlugin` — registers the route
- `SupplierPageDependencyProvider` — provides the `SupplierSearchClient`
- `SupplierPageFactory` — accesses the client

The controller uses the `SupplierSearchClient` to find a supplier by name and passes it to the Twig template.

After completing all parts:

```bash
docker/sdk console cache:empty-all
```

Visit http://yves.eu.spryker.local/supplier/Acme%20Supplies to see the result.

---

## Testing

1. Ensure suppliers are indexed in Elasticsearch:
   ```bash
   curl -s 'localhost:9200/_search' -H 'Content-type: application/json' \
     -d '{"query":{"exists":{"field":"id_supplier"}}}'
   ```

2. Visit the Yves page with a known supplier name

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
