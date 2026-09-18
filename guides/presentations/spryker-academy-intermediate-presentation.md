<!-- Generated from guides-html/spryker-academy-intermediate-presentation.html. Edit the HTML, then run: python3 tools/presentation_to_markdown.py <html> <md> -->

# Spryker Academy

## Intermediate Exercises

Supplier Module \| Data Import, Back Office, P&S, Search, API, OMS

Namespace: `SprykerAcademy\` \| Module: `Supplier`

---

## Agenda

| \#  | Exercise                    | Key Concepts                                                 |
|-----|-----------------------------|--------------------------------------------------------------|
| 8   | Data Import                 | CSV, WriterSteps, DataSetStepBroker, Plugins                 |
| 9   | Back Office                 | Tables, Forms, CRUD Controllers, Gui module                  |
| 10  | Publish & Synchronize       | Events, Publishers, Queues, Elasticsearch/Redis              |
| 11  | Search                      | Query Plugins, Result Formatters, SearchClient               |
| 12  | Glue Storefront API         | API Platform, Providers, Resource YAML                       |
| 13  | OMS                         | State Machine, Commands, Conditions, Events                  |
| 14  | Storage Client              | Redis, StorageClient, Key Generation, SynchronizationService |
| 15  | Merchant Portal — Table     | GuiTable, DataProvider, Angular Web Components, ACL          |
| 16  | Merchant Portal — Form      | Drawer Forms, ZedUI Actions, Symfony Forms                   |
| 17  | Merchant Portal — Locations | Editable GuiTable, Nested Tables, DataTransformer            |

> **Prerequisites:** Basics exercises 1-7 completed. Understanding of Facade, Factory, DependencyProvider patterns.

---

## Exercise 8: Data Import

### Populating the Database from CSV

> **Goal:** Import suppliers from a CSV file using Spryker's DataImport pipeline

---

### Data Import Pipeline

```text
  CSV File
      |
  DataImporter (reads rows into DataSet objects)
      |
  DataSetStepBroker (orchestrates steps in order)
      |
      +-- DescriptionToLowercaseStep (processor: transforms)
      |
      +-- SupplierWriterStep (writer: persists to DB)
      |
  Database (pyz_supplier)
```

-   **DataSet** — ArrayAccess object, keys = CSV column headers
-   **Processor steps** — transform data in-place (run first)
-   **Writer steps** — persist to database (run last)
-   Steps chained via `DataSetStepBroker::addStep()`

---

### WriterStep Pattern

```php
class SupplierWriterStep extends PublishAwareStep
    implements DataImportStepInterface
{
    public function execute(DataSetInterface $dataSet): void
    {
        // 1. Find or create entity
        $entity = PyzSupplierQuery::create()
            ->filterByName($dataSet[SupplierDataSetInterface::COLUMN_NAME])
            ->findOneOrCreate();

        // 2. Assign fields from dataset
        $entity->setDescription($dataSet[COLUMN_DESCRIPTION]);

        // 3. Save only if new or modified (idempotent)
        if ($entity->isNew() || $entity->isModified()) {
            $entity->save();
            // 4. Trigger P&S events (for next exercise)
            $this->addPublishEvents(SUPPLIER_PUBLISH, $entity->getId());
        }
    }
}
```

> **Exception:** Propel in Business Layer is allowed for DataImport (performance with bulk data).

---

### Pluginization

```php
// Plugin exposes import to console command
class SupplierDataImportPlugin extends AbstractPlugin
    implements DataImportPluginInterface
{
    public function import(?DataImporterConfigurationTransfer $config): DataImporterReportTransfer
    {
        return $this->getFacade()->importSupplier($config);
    }

    public function getImportType(): string
    {
        return SupplierDataImportConfig::IMPORT_TYPE_SUPPLIER;
    }
}
```

Register in `DataImportDependencyProvider::getDataImporterPlugins()`

YAML mapping in `data/import/local/full_EU.yml`

```bash
docker/sdk console data:import supplier
```

---

## Exercise 9: Back Office CRUD

### Tables, Forms, Controllers

> **Goal:** Build a complete supplier management interface in the Back Office

---

### Back Office Table (AbstractTable)

```php
class SupplierTable extends AbstractTable
{
    protected function configure(TableConfiguration $config): TableConfiguration
    {
        $config->setHeader([COL_NAME => 'Name', COL_STATUS => 'Status', ...]);
        $config->setSortable([COL_NAME, COL_STATUS, ...]);
        $config->setSearchable([COL_NAME, COL_DESCRIPTION, ...]);
        $config->setRawColumns([COL_ACTIONS]); // HTML not escaped
        return $config;
    }

    protected function prepareData(TableConfiguration $config): array
    {
        $collection = $this->runQuery($this->supplierQuery, $config, true);
        return $this->mapReturns($collection);
    }
}
```

> **Two-action pattern:** `indexAction()` renders HTML, `tableAction()` returns JSON via AJAX.

---

### Spryker Button Helpers

**In table rows** (PHP — AbstractTable methods):

```php
$this->generateEditButton($url, 'Edit')
$this->generateRemoveButton($url, 'Delete')
$this->generateViewButton($url, 'View')
// URL generation:
$url = Url::generate('/supplier-gui/edit', [
    EditController::REQUEST_PARAM_ID_SUPPLIER => $id,
]);
```

**In Twig templates** (page-level action buttons):

```twig
{{ createActionButton('/supplier-gui/create', 'Create Supplier') }}
{{ editActionButton('/supplier-gui/edit?id=' ~ id, 'Edit') }}
{{ backActionButton(backUrl, 'Back') }}
{{ removeActionButton('/supplier-gui/delete?id=' ~ id, 'Delete') }}
```

---

### Back Office Forms

```php
class SupplierCreateForm extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder
            ->add('name', TextType::class, ['constraints' => [new NotBlank()]])
            ->add('description', TextType::class, [...])
            ->add('isActive', CheckboxType::class, [
                'mapped' => false,     // Not on transfer
                'required' => false,
                'data' => $options['isActive'],
            ]);
    }

    public function configureOptions(OptionsResolver $resolver): void
    {
        $resolver->setDefaults([
            'data_class' => SupplierTransfer::class,
            'isActive' => true,
        ]);
    }
}
```

---

### DependencyProvider → Factory → Controller

```php
// DependencyProvider: inject Propel query + Facade
$container->set(PROPEL_QUERY_SUPPLIER,
    $container->factory(fn () => PyzSupplierQuery::create()));
$container->set(FACADE_SUPPLIER,
    fn (Container $c) => $c->getLocator()->supplier()->facade());
```

```php
// Factory: create table, get facade
public function createSupplierTable(): SupplierTable {
    return new SupplierTable($this->getSupplierQuery());
}
public function getSupplierFacade(): SupplierFacadeInterface {
    return $this->getProvidedDependency(FACADE_SUPPLIER);
}
```

```php
// Controller: use factory
$table = $this->getFactory()->createSupplierTable();
return $this->viewResponse(['supplierTable' => $table->render()]);
```

---

## Exercise 10: Publish & Synchronize

### Event-Driven Data Pipeline to Elasticsearch & Redis

> **Goal:** Make supplier data available in Elasticsearch and Redis using Spryker's P&S pattern

---

### Two-Step Process

```text
  STEP 1: PUBLISH                    STEP 2: SYNCHRONIZE
  ──────────────                     ───────────────────

  Entity change (save)               Write to pyz_*_search/storage
      |                                   |
  Event behavior fires               Synchronization behavior fires
      |                                   |
  Publish queue                       Sync queue
      |                                   |
  Publisher Plugin                    Queue processor
      |                                   |
  Writer (business logic)            Elasticsearch / Redis
      |
  pyz_supplier_search/storage
```

---

### Propel Behaviors

**Event behavior** — fires events on entity changes:

```xml
<!-- pyz_supplier.schema.xml -->
<behavior name="event">
    <parameter name="pyz_supplier_all" column="*"/>
</behavior>
<!-- Triggers: Entity.pyz_supplier.create / .update / .delete -->
```

**Synchronization behavior** — auto-syncs to storefront storage:

```xml
<!-- pyz_supplier_search.schema.xml -->
<behavior name="synchronization">
    <parameter name="resource" value="supplier"/>
    <parameter name="key_suffix_column" value="fk_supplier"/>
    <parameter name="queue_group" value="sync.search.supplier"/>
</behavior>
<!-- Auto-generates key, data columns; emits to sync queue on write -->
```

---

### Publisher Plugin

```php
class SupplierSearchWritePublisherPlugin extends AbstractPublisherPlugin
{
    public function getSubscribedEvents(): array
    {
        return [
            SupplierSearchConfig::SUPPLIER_PUBLISH,           // Manual
            SupplierSearchConfig::ENTITY_PYZ_SUPPLIER_CREATE, // Auto
            SupplierSearchConfig::ENTITY_PYZ_SUPPLIER_UPDATE, // Auto
        ];
    }

    public function handleBulk(array $eventEntityTransfers, $eventName): void
    {
        $this->getFacade()
            ->writeCollectionBySupplierEvents($eventEntityTransfers);
    }
}
```

> Registered in `PublisherDependencyProvider` mapped to the publish queue name.

---

### Queue Configuration (3 Files Required)

| File                      | Purpose                | Method                                                                      |
|---------------------------|------------------------|-----------------------------------------------------------------------------|
| `SymfonyMessengerConfig`  | Transport routing      | `getPublishQueueConfiguration()` + `getSynchronizationQueueConfiguration()` |
| `RabbitMqConfig`          | AMQP queue declaration | `getPublishQueueConfiguration()` + `getSynchronizationQueueConfiguration()` |
| `QueueDependencyProvider` | Message processors     | `getProcessorMessagePlugins()`                                              |

```bash
# After adding queues — creates AMQP exchanges:
docker/sdk console messenger:setup-transports
```

> **Critical:** Without `messenger:setup-transports`, messages are silently dropped (no AMQP exchange).

---

### Queue Processors

| Queue              | Processor                                           |
|--------------------|-----------------------------------------------------|
| Publish queues     | `EventQueueMessageProcessorPlugin`                  |
| Search sync queue  | `SynchronizationSearchQueueMessageProcessorPlugin`  |
| Storage sync queue | `SynchronizationStorageQueueMessageProcessorPlugin` |

```bash
# Process all queues:
docker/sdk console queue:worker:start --stop-when-empty
# May need to run twice (publish -> sync)
```

---

## Exercise 11: Search

### Querying Elasticsearch from the Client Layer

> **Goal:** Build a search client that queries Elasticsearch for suppliers by name

---

### Search Architecture

```text
  SupplierSearchClient
      |
  Factory
      |-- createSupplierQueryPlugin(name)
      |-- getSearchQueryFormatters()
      |-- getSearchClient()
              |
         Elasticsearch
              |
         ResultSet
              |
  SupplierSearchResultFormatterPlugin
              |
         SupplierTransfer
```

---

### Query Plugin (Elastica)

```php
class SupplierSearchQueryPlugin implements QueryInterface,
    SearchContextAwareQueryInterface
{
    protected const SOURCE_IDENTIFIER = 'supplier';

    public function getSearchQuery(): Query
    {
        $boolQuery = (new BoolQuery())
            ->addMust(new Exists('id_supplier'))
            ->addMust(new MatchQuery('name', $this->name));

        return (new Query())->setQuery($boolQuery);
    }
}
```

-   `SOURCE_IDENTIFIER` maps to the Elasticsearch index
-   `BoolQuery` combines conditions with AND logic
-   `Exists` ensures only supplier documents match
-   `MatchQuery` performs full-text search on the name field

---

### Result Formatter + Client

```php
// Formatter: converts ES results to Transfer objects
class SupplierSearchResultFormatterPlugin
    extends AbstractElasticsearchResultFormatterPlugin
{
    protected function formatSearchResult(ResultSet $result, array $params): ?SupplierTransfer
    {
        foreach ($result->getResults() as $doc) {
            return (new SupplierTransfer())->fromArray($doc->getSource());
        }
        return null;
    }
}
```

```php
// Client: orchestrates query + formatters + search
class SupplierSearchClient extends AbstractClient
{
    public function getSupplierByName(string $name): ?SupplierTransfer
    {
        $query = $this->getFactory()->createSupplierQueryPlugin($name);
        $formatters = $this->getFactory()->getSearchQueryFormatters();
        $results = $this->getFactory()->getSearchClient()
            ->search($query, $formatters);
        return $results[SupplierSearchResultFormatterPlugin::NAME];
    }
}
```

---

### Elasticsearch Mapping

```json
// Shared/SupplierSearch/Schema/supplier.json
{
    "settings": {
        "analysis": {
            "analyzer": {
                "default_analyzer": {
                    "tokenizer": "standard",
                    "filter": ["lowercase", "fulltext_index_ngram_filter"]
                }
            },
            "filter": {
                "fulltext_index_ngram_filter": {
                    "type": "edge_ngram",
                    "min_gram": 2, "max_gram": 20
                }
            }
        }
    }
}
```

-   `edge_ngram` enables partial matching ("Acm" matches "Acme")
-   File name must match the `resource` param in synchronization behavior
-   Create index: `docker/sdk console search:setup`

---

## API Platform

### Theory

The framework behind Spryker's new API layer

---

### What is API Platform?

-   Open-source PHP framework for building **API-first** applications
-   Built on top of **Symfony** — leverages its DI, routing, serialization
-   Follows standards: **JSON-LD**, **Hydra**, **OpenAPI**, **JSON:API**
-   Adopted by Spryker since **release 202512.0** as the recommended API approach

> **Key idea:** Define your API as a *resource* (data model + operations), and the framework handles routing, serialization, pagination, filtering, and documentation automatically.

---

### API Platform Core Concepts

| Concept           | Description                                                            |
|-------------------|------------------------------------------------------------------------|
| **Resource**      | A data object exposed via the API (e.g., Supplier)                     |
| **Operation**     | An HTTP action on a resource (Get, GetCollection, Post, Patch, Delete) |
| **Provider**      | Reads data — implements `ProviderInterface::provide()`                 |
| **Processor**     | Writes data — implements `ProcessorInterface::process()`               |
| **Serialization** | Automatic conversion between PHP objects and JSON/JSON-LD/XML          |
| **OpenAPI**       | Auto-generated API documentation from resource definitions             |

---

### Request Flow

```text
  HTTP Request: GET /suppliers/1
         │
    ┌────▼────┐
    │ Routing  │  API Platform matches URL to resource + operation
    └────┬────┘
         │
  ┌──────▼──────┐
  │   Provider   │  provide($operation, ['idSupplier' => '1'])
  │              │  → Loads data from facade/client/database
  └──────┬──────┘
         │
  ┌──────▼──────┐
  │ Serializer   │  PHP object → JSON-LD / JSON / JSON:API
  └──────┬──────┘
         │
    ┌────▼────┐
    │ Response │  {"@type": "Supplier", "name": "Acme", ...}
    └─────────┘
```

---

### Response Formats

API Platform supports multiple formats via the `Accept` header:

| Accept Header              | Format     | Description                                          |
|----------------------------|------------|------------------------------------------------------|
| `application/ld+json`      | JSON-LD    | Default. Linked Data with `@context`, `@id`, `@type` |
| `application/json`         | Plain JSON | Raw JSON without metadata                            |
| `application/vnd.api+json` | JSON:API   | JSON:API specification format                        |

```json
// GET /suppliers — JSON-LD response
{
  "@context": "/contexts/Supplier",
  "@type": "Collection",
  "totalItems": 4,
  "member": [
    { "@id": "/suppliers/1", "@type": "Supplier", "name": "Acme Supplies" }
  ]
}
```

---

### API Platform in Spryker

-   Resources defined in **YAML** (`.resource.yml`), not PHP attributes
-   Spryker generates PHP Resource classes from YAML schemas
-   Two API types: **Storefront** (public) and **Backend** (admin)
-   Providers use **Symfony DI** — facades/clients injected via constructor
-   Since **202602**, unified endpoint: `glue.eu.spryker.local` serves both legacy and API Platform

> Spryker scans `sourceDirectories` for `.resource.yml` files → generates Resource classes → auto-registers Providers in the Symfony container.

---

### Spryker API Platform Architecture

```text
  config/GlueStorefront/packages/
  └── spryker_api_platform.php      ← Source directories + API type
          │
  src/SprykerAcademy/Glue/Supplier/
  ├── resources/api/storefront/
  │   └── suppliers.resource.yml    ← Resource definition (YAML)
  └── Api/Storefront/Provider/
      └── SuppliersStorefrontProvider.php  ← Data loading + mapping
                │
      constructor injection (Symfony DI)
                │
      SupplierClientInterface  ← registered in ApplicationServices.php
```

---

### Dependency Injection for Providers

Providers use **Symfony DI**, not Spryker's Factory/DependencyProvider:

```php
// config/GlueStorefront/ApplicationServices.php
$services->load('SprykerAcademy\\Client\\', '../../src/SprykerAcademy/Client/');

// config/GlueBackend/ApplicationServices.php
$services->load('SprykerAcademy\\Zed\\', '../../src/SprykerAcademy/Zed/');
```

> **Why?** Core Spryker modules have pre-compiled service containers. Project-level modules (`SprykerAcademy`) need explicit registration so Symfony can resolve interfaces like `SupplierFacadeInterface` or `SupplierClientInterface`.

Alternative — register individual services:

```php
$services->set(SupplierFacadeInterface::class, SupplierFacade::class);
```

---

### API Platform vs GlueApplication

| Aspect               | GlueApplication (retrocompatible)    | API Platform (recommended)     |
|----------------------|--------------------------------------|--------------------------------|
| Resource definition  | PHP plugin classes                   | YAML `.resource.yml`           |
| Handler              | Controller + Reader                  | Provider class                 |
| Registration         | Plugin in DependencyProvider         | Auto from YAML + DI            |
| Dependency Injection | Spryker Factory + DependencyProvider | Symfony constructor injection  |
| Response building    | Manual `RestResource`                | Generated Resource class       |
| Documentation        | Manual annotations                   | Auto-generated OpenAPI         |
| Pagination           | Manual implementation                | Built-in, configurable in YAML |

> GlueApplication APIs are **retrocompatible** — existing APIs keep working. **API Platform is recommended for all new API development.**

---

## Exercise 12: Glue Storefront API

### REST API with Spryker API Platform

> **Goal:** Expose supplier data through a REST API using Spryker's API Platform

---

### Resource YAML

```yaml
# resources/api/storefront/suppliers.resource.yml
resource:
    name: Suppliers
    provider: SprykerAcademy\Glue\Supplier\Api\Storefront\Provider\SuppliersStorefrontProvider
    paginationEnabled: true
    paginationItemsPerPage: 10
    operations:
        - type: Get
        - type: GetCollection
    properties:
        idSupplier:
            type: int
            identifier: true
        name:
            type: string
        description:
            type: string
```

-   `provider:` — full class name of the PHP Provider
-   `identifier: true` — property used in URL path (`/suppliers/{idSupplier}`)
-   Generates `SuppliersStorefrontResource` class automatically

---

### Provider Pattern

```php
class SuppliersStorefrontProvider implements ProviderInterface
{
    public function __construct(
        protected SupplierClientInterface $supplierClient, // auto-wired
    ) {}

    public function provide(
        Operation $operation,
        array $uriVariables = [],
        array $context = [],
    ): object|array|null {
        $id = $uriVariables['idSupplier'] ?? null;

        if ($id === null) {
            return $this->provideCollection(); // → array = GetCollection
        }

        $supplier = $this->supplierClient->findSupplierById((int)$id);
        if (!$supplier) {
            return null;                       // → null = 404
        }

        return $this->mapToResource($supplier); // → object = Get
    }
}
```

---

### API Platform Commands

| Command                                  | Purpose                                     |
|------------------------------------------|---------------------------------------------|
| `glue api:generate Storefront`           | Generate Storefront API resources from YAML |
| `glue api:generate Backend`              | Generate Backend API resources              |
| `glue api:generate --dry-run`            | Preview without writing files               |
| `glue api:generate --validate-only`      | Validate schemas only                       |
| `glue api:debug --list`                  | List all registered resources               |
| `glue api:debug suppliers`               | Inspect a specific resource                 |
| `glue api:debug suppliers --show-merged` | Show final merged YAML                      |

---

## Exercise 13: Order Management System

### State Machine for Order Lifecycle

> **Goal:** Build a complete order management process with states, transitions, events, commands, and conditions

---

### State Machine Flow

```text
       [new]
         |
    authorize (onEnter, command=Demo/Pay)
         |
  condition: Demo/IsAuthorized
     /        \
  (true)     (false)
    |           |
[payment    [invalid]
 pending]
    |
   pay (onEnter)
    |
[payment authorized]
    |
  (auto)
    |
  [paid]
    |
  (auto)
    |
 [closed]
```

---

### State Machine XML

**States** — positions in the workflow:

```xml
<states>
    <state name="new" reserved="true"/>
    <state name="payment pending" reserved="true"/>
    <state name="invalid"/>
    <state name="paid" reserved="true"/>
    <state name="closed"/>
</states>
```

**Events** — triggers with commands:

```xml
<events>
    <event name="authorize" onEnter="true" command="Demo/Pay"/>
    <event name="pay" onEnter="true" manual="true"/>
</events>
```

**Transitions** — with conditions and happy path:

```xml
<transition happy="true" condition="Demo/IsAuthorized">
    <source>new</source>
    <target>payment pending</target>
    <event>authorize</event>
</transition>
```

---

### Command & Condition Plugins

**Command** — executes business logic on event:

```php
class PayCommandPlugin extends AbstractPlugin
    implements CommandByOrderInterface
{
    public function run(
        array $orderItems,
        SpySalesOrder $orderEntity,
        ReadOnlyArrayObject $data,
    ): array {
        // Call payment gateway, update order, etc.
        return [];
    }
}
```

**Condition** — routes between transitions:

```php
class IsAuthorizedConditionPlugin extends AbstractPlugin
    implements ConditionInterface
{
    public function check(SpySalesOrderItem $orderItem): bool
    {
        // true → happy path, false → unhappy path
        return true;
    }
}
```

---

### Plugin Registration

```php
// OmsDependencyProvider — string keys must match XML exactly
$commandCollection->add(new PayCommandPlugin(), 'Demo/Pay');
$conditionCollection->add(new IsAuthorizedConditionPlugin(), 'Demo/IsAuthorized');
```

| Event Type | XML Attribute       | When it fires                     |
|------------|---------------------|-----------------------------------|
| Auto       | `onEnter="true"`    | Immediately on entering state     |
| Manual     | `manual="true"`     | User clicks button in Back Office |
| Timeout    | `timeout="14 days"` | After specified time              |

> **Condition routing:** When two transitions share the same event from the same source, the one WITH a condition is checked first. If `true`, that path is taken. If `false`, the fallback (no condition) is used.

---

## Testing Strategy

### 78 Lightweight Tests, No Kernel Needed

---

### Test Suites

| Suite         | Tests | Coverage                                                     |
|---------------|-------|--------------------------------------------------------------|
| DataImport    | 20    | Constants, steps, factory, facade, plugins, CSV headers      |
| BackOffice    | 20    | Table, controllers, form, factory, DP, navigation, templates |
| PublishSync   | 15    | Writers, facades, plugin events, schema behaviors            |
| Search        | 13    | Query plugin, result formatter, client, ES schema            |
| GlueApi       | 10    | Provider, mapper, config, resource YAML                      |
| StorageClient | 10    | Storage reader, key generation, client, factory, DP          |

```bash
docker/sdk cli vendor/bin/codecept run \
    -c tests/SprykerAcademyTest/Zed/Supplier/ DataImport
docker/sdk cli vendor/bin/codecept run \
    -c tests/SprykerAcademyTest/Zed/Supplier/ BackOffice
docker/sdk cli vendor/bin/codecept run \
    -c tests/SprykerAcademyTest/Zed/Supplier/ PublishSync
docker/sdk cli vendor/bin/codecept run \
    -c tests/SprykerAcademyTest/Zed/Supplier/ Search
docker/sdk cli vendor/bin/codecept run \
    -c tests/SprykerAcademyTest/Zed/Supplier/ GlueApi
docker/sdk cli vendor/bin/codecept run \
    -c tests/SprykerAcademyTest/Zed/Supplier/ StorageClient
```

---

## Exercise 14: Storage Client

Redis Key-Value Lookup for Fast ID-Based Access

---

### Search vs Storage

| Feature        | Search (Elasticsearch)      | Storage (Redis)             |
|----------------|-----------------------------|-----------------------------|
| Use case       | Full-text search, filtering | Fast key-value lookup by ID |
| Query type     | Complex (BoolQuery, Match)  | Simple key lookup           |
| Key format     | Index + type + ID           | resource\_name:id           |
| Spryker module | SupplierSearch (Client)     | SupplierStorage (Client)    |

---

### Storage Key Generation

```php
// Generate storage key using SynchronizationService
$synchronizationDataTransfer = (new SynchronizationDataTransfer())
    ->setReference((string)$idSupplier);

$key = $this->synchronizationService
    ->getStorageKeyBuilder('supplier')
    ->generateKey($synchronizationDataTransfer);

// Result: "supplier:1"
```

The `resource` parameter in sync behavior must match: `'supplier'`

---

### Storage Reader Pattern

```php
class SupplierStorageReader
{
    public function findSupplierStorageData(int $idSupplier): ?array
    {
        $key = $this->generateStorageKey($idSupplier);
        $data = $this->storageClient->get($key);
        // StorageClient->get() already json_decodes
        return $data;
    }

    public function getAllSuppliers(): array
    {
        $pattern = $this->generateStorageKeyPattern(); // "supplier:*"
        $keys = $this->storageClient->getKeys($pattern);
        // ...fetch each key
    }
}
```

---

### Dependencies

<table><colgroup><col style="width: 33%" /><col style="width: 33%" /><col style="width: 33%" /></colgroup><thead><tr class="header"><th>DependencyProvider</th><th>Factory</th><th>Client</th></tr></thead><tbody><tr class="odd"><td><code>addStorageClient()</code><br />
<code>addSynchronizationService()</code></td><td><code>createSupplierStorageReader()</code><br />
injects both dependencies</td><td><code>findSupplierById()</code><br />
<code>getAllSuppliers()</code></td></tr></tbody></table>

---

## Merchant Portal

### Exercises 15-17

GuiTable, Angular Web Components, Drawer Forms

---

### Merchant Portal vs Back Office

| Aspect     | Back Office                   | Merchant Portal                           |
|------------|-------------------------------|-------------------------------------------|
| Frontend   | Twig + jQuery                 | Angular Web Components                    |
| Tables     | `AbstractTable` (server HTML) | GuiTable (JSON config + Angular)          |
| Forms      | Full page reload              | Drawer overlay + JSON response            |
| Layout     | `@Gui/Layout/layout.twig`     | `@ZedUi/Layout/merchant-layout-main.twig` |
| Navigation | `navigation.xml`              | `navigation-main-merchant-portal.xml`     |
| Access     | Back Office ACL               | Merchant ACL plugins                      |

---

### GuiTable Architecture

```text
  Page Load: GET /supplier-merchant-portal-gui/supplier
  ├── Controller::indexAction()
  │   └── Returns GuiTable configuration (JSON)
  └── Twig renders <web-mp-supplier-list config='...'>
      └── Angular renders table shell

  AJAX: GET /...supplier/table-data?page=1&pageSize=25
  ├── Controller::tableDataAction()
  ├── GuiTableHttpDataRequestExecutor
  ├── DataProvider::createCriteria() → merchant-scoped
  ├── Repository → Propel query with JOIN
  └── Returns JSON rows → Angular updates table
```

---

### Exercise 15: Supplier Table

> **Goal:** Display merchant's suppliers using GuiTable framework

-   **ConfigurationProvider** — columns, filters, row actions, data source URL
-   **DataProvider** — creates merchant-scoped criteria, delegates to repository
-   **Repository** — Propel query joining `pyz_supplier` ↔ `pyz_merchant_to_supplier`
-   **Controller** — `indexAction()` + `tableDataAction()`
-   **Angular wiring** — register component in `components.module.ts`

---

### Drawer Form Lifecycle

```text
  Table row → "Edit" action
       │
  AJAX GET /update-supplier?id-supplier=5
       │
  ┌────▼────────────────┐
  │ Controller renders   │
  │ form HTML            │
  │ → JsonResponse       │
  └────┬────────────────┘
       │
  Angular opens drawer with HTML
       │
  User submits form (AJAX POST)
       │
  ┌────▼────────────────┐
  │ Controller validates │
  │ → saves via facade   │
  │ → ZedUI response:    │
  │   closeDrawer()      │
  │   refreshTable()     │
  │   successNotify()    │
  └────┬────────────────┘
       │
  Angular closes drawer, refreshes table, shows toast
```

---

### Exercise 16: Create/Edit Form

> **Goal:** Add create and edit functionality via drawer forms

-   **SupplierForm** — Symfony form type with `SupplierTransfer` data class
-   **CreateSupplierController** — creates supplier + links to merchant
-   **UpdateSupplierController** — loads and updates existing supplier
-   **ZedUiFormResponseBuilder** — drawer actions (close, refresh, notify)
-   **Angular wiring** — register edit component, use `<web-spy-card>`

---

### Editable GuiTable Pattern

```php
// Configuration: enable inline editing + adding rows
$builder->addEditableColumnInput('city', 'City', 'text');
$builder->addEditableColumnInput('country', 'Country', 'text');

$builder->enableAddingNewRows(
    'supplierForm[locations]',  // form input name
    $initialData,
    ['title' => 'Add Location'],
    ['title' => 'Cancel'],
);
```

Data is submitted as nested form fields → `DataTransformerInterface` converts to transfers.

---

### Exercise 17: Nested Locations Table

> **Goal:** Editable locations table inside the supplier edit drawer

-   **LocationGuiTableConfigurationProvider** — editable columns + `enableAddingNewRows()`
-   **LocationGuiTableDataProvider** — fetches locations for a supplier
-   **SupplierLocationTransformer** — `transform()` / `reverseTransform()`
-   **Angular wiring** — register locations table component
-   Embedded in edit drawer: `<web-mp-supplier-locations-table>`

---

### ACL Configuration

```php
// Plugin: allow all routes in the module
class SupplierMerchantPortalGuiMerchantAclRuleExpanderPlugin
    implements MerchantAclRuleExpanderPluginInterface
{
    public function expand(array $ruleTransfers): array
    {
        $ruleTransfers[] = (new RuleTransfer())
            ->setBundle('supplier-merchant-portal-gui')
            ->setController('*')
            ->setAction('*')
            ->setType('allow');
        return $ruleTransfers;
    }
}
```

> Without ACL rules, merchant users get **403 Forbidden** for all module routes.

---

## Key Takeaways

-   <span class="accent">Data Import</span> — CSV pipeline with processor + writer steps, PublishAwareStep for P&S
-   <span class="accent">Back Office</span> — AbstractTable for sortable/searchable tables, Symfony forms, Gui button helpers
-   <span class="accent">Publish & Synchronize</span> — Event behavior triggers, publisher plugins route to queues, sync behavior pushes to ES/Redis
-   <span class="accent">Search</span> — Query plugins build Elastica queries, result formatters convert to transfers
-   <span class="accent">Storage</span> — Redis key-value lookup using StorageClient + SynchronizationService key builder
-   <span class="accent">Glue API</span> — API Platform: YAML resource definition + Provider class, no Factory/DP needed
-   <span class="accent">OMS</span> — XML state machine: states, transitions, events, commands, conditions, happy path
-   <span class="accent">Queues</span> — 3 configs required (SymfonyMessenger + RabbitMq + QueueDP) + `messenger:setup-transports`
-   <span class="accent">Merchant Portal</span> — GuiTable (JSON config + Angular), drawer forms with ZedUI actions, ACL plugins for access
-   <span class="accent">Naming</span> — `*DataImport`, `*Gui`, `*Search`, `*Storage`, `*MerchantPortalGui` module suffixes
-   <span class="accent">Testing</span> — Structural + XML + mock tests, no kernel needed

---

# Questions?

Spryker Academy \| Intermediate Exercises
