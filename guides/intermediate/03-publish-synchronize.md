# Exercise 10: Publish & Synchronize - Supplier

In this exercise, you will make supplier data available in Elasticsearch (search) and Redis (storage) using Spryker's Publish & Synchronize (P&S) pattern. This is a two-step process: first you **publish** data from the main database into intermediate tables, then the **synchronization** behavior automatically pushes that data to the storefront storages.

You will learn how to:
- Understand the two-step Publish & Synchronize flow
- Add Propel event behavior to trigger events on entity changes
- Add Propel synchronization behavior for automatic data sync to Elasticsearch/Redis
- Create publisher plugins that react to entity events
- Implement business logic writers for bulk-processing events
- Configure publish and synchronize queues
- Register publisher plugins and queue message processors
- Trigger publish events manually from data import

## Prerequisites

- Completed Exercise 8 (Data Import) — suppliers must be in the database
- Understanding of the Facade, DependencyProvider, and Factory patterns

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/publish-synchronize/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console propel:install
```

---

## Background: Publish & Synchronize Architecture

Spryker uses a two-step process to move data from the Zed database to the storefront storages (Elasticsearch, Redis):

```
Step 1: PUBLISH                          Step 2: SYNCHRONIZE
─────────────────                        ────────────────────
Entity change                            Synchronization behavior
    ↓                                        ↓
Event (entity.create/update)             Auto-triggers on table write
    ↓                                        ↓
Publisher Plugin                         Sync queue message
    ↓                                        ↓
Writer (business logic)                  Queue processor
    ↓                                        ↓
Insert/Update pyz_*_search/storage       Elasticsearch / Redis
```

**Why two modules?** Spryker separates the logic by target storage:
- `SupplierSearch` — publishes to Elasticsearch (for full-text search)
- `SupplierStorage` — publishes to Redis (for key-value lookups)

Both follow the same pattern but write to different intermediate tables with different synchronization behaviors.

**Key components:**

| Component | Role |
|-----------|------|
| Event behavior (Propel) | Fires events on entity create/update/delete |
| Publisher Plugin | Listens to events, delegates to Facade |
| Writer | Business logic: loads entities, writes to search/storage tables |
| Synchronization behavior (Propel) | Auto-syncs table data to Elasticsearch/Redis via queues |
| Queue processors | Process publish events and sync messages |

---

## Working on the Exercise

### Part 1: Understand the Constants

Open `src/SprykerAcademy/Shared/SupplierSearch/SupplierSearchConfig.php` and review the constants:

| Constant | Purpose |
|----------|---------|
| `SUPPLIER_PUBLISH_SEARCH_QUEUE` | Queue for publish events (step 1) |
| `SUPPLIER_SYNC_SEARCH_QUEUE` | Queue for sync events (step 2) |
| `ENTITY_PYZ_SUPPLIER_CREATE/UPDATE/DELETE` | Events fired by Propel's event behavior |
| `SUPPLIER_PUBLISH` | Manual publish event (fired from code) |
| `SUPPLIER_UNPUBLISH` | Manual unpublish event |

Similar constants exist in `SupplierStorageConfig` for the Redis pipeline.

---

### Part 2: Build the Search Publish Logic

#### 2.1 Implement the SupplierSearchWriter

The writer is the core business logic. It processes a batch of events: loads the affected suppliers, loads or creates search records, and persists them.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/Business/Writer/SupplierSearchWriter.php`. The class receives events and needs to:

1. Extract supplier IDs from event transfers using the `EventBehaviorFacade`
2. Load supplier entities by those IDs using a `SupplierCriteriaTransfer`
3. Load existing search records for those IDs using a `SupplierSearchCriteriaTransfer`
4. For each supplier: create or update the search record with de-normalized data

The skeleton has the iteration logic in place. You need to fill in the methods that load data from the facades and repositories.

> **Bulk processing:** The writer accepts an array of events and processes them in bulk. This is critical for performance — loading all suppliers in one query is much faster than one query per event.

#### 2.2 Provide Module Dependencies

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/SupplierSearchDependencyProvider.php`:

1. Implement `addEventBehaviorFacade()` — provide the `EventBehaviorFacade` via the locator
2. Implement `addSupplierFacade()` — provide the `SupplierFacade` via the locator
3. Call both methods in `provideBusinessLayerDependencies()`

> **EventBehaviorFacade:** This Spryker core facade provides helper methods like extracting entity IDs from event transfers. Access it via `$container->getLocator()->eventBehavior()->facade()`.

#### 2.3 Implement the BusinessFactory

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/Business/SupplierSearchBusinessFactory.php`:

1. Implement `getEventBehaviorFacade()` and `getSupplierFacade()` using `getProvidedDependency()`
2. Wire all dependencies into the `SupplierSearchWriter` constructor: the two facades, plus `getRepository()` and `getEntityManager()` which are available from the parent class

#### 2.4 Implement the Facade

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/Business/SupplierSearchFacade.php`:

Delegate `writeCollectionBySupplierEvents()` to the writer via the factory.

#### 2.5 Implement the Publisher Plugin

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/Communication/Plugin/Publisher/SupplierSearchWritePublisherPlugin.php`:

1. In `handleBulk()` — use `getFacade()` to call the write method with the event transfers
2. In `getSubscribedEvents()` — return an array of event names this plugin reacts to: the manual publish event plus entity create and update events (use constants from `SupplierSearchConfig`)

---

### Part 3: Build the Storage Publish Logic

The Storage module (`SupplierStorage`) follows the **exact same pattern** as Search. The only differences are the target table (`pyz_supplier_storage` instead of `pyz_supplier_search`) and the constants used.

**Coding time:**

Apply the same pattern to the SupplierStorage module:
- `SupplierStorageDependencyProvider` — add facades
- `SupplierStorageBusinessFactory` — wire dependencies
- `SupplierStorageFacade` — delegate to writer
- `SupplierStorageWriter` — same bulk logic
- `SupplierStorageWritePublisherPlugin` — same plugin pattern

> **DRY principle:** The Search and Storage writers have nearly identical code. In production, you might extract a shared abstract class. For the exercise, implementing both helps reinforce the pattern.

---

### Part 4: Configure Queues

Publish & Synchronize uses two types of queues per pipeline:
- **Publish queue** — carries event messages that trigger the writer
- **Sync queue** — carries sync messages that push data to Elasticsearch/Redis

#### 4.1 Register Publish Queues

**Coding time:**

Open `src/Pyz/Client/RabbitMq/RabbitMqConfig.php`. In `getPyzPublishQueueConfiguration()`, add the publish queues for both Search and Storage using the constants from `SupplierSearchConfig` and `SupplierStorageConfig`.

#### 4.2 Register Sync Queues

In the same file, in `getPyzSynchronizationQueueConfiguration()`, add the sync queues for both pipelines.

---

### Part 5: Register Publisher Plugins

**Coding time:**

Open `src/Pyz/Zed/Publisher/PublisherDependencyProvider.php`. Create methods that return arrays mapping queue names to publisher plugin instances:

```php
// Format:
return [
    QueueConstant::QUEUE_NAME => [
        new MyPublisherPlugin(),
    ],
];
```

Register both `SupplierSearchWritePublisherPlugin` (on the search publish queue) and `SupplierStorageWritePublisherPlugin` (on the storage publish queue).

Add both to the `getPublisherPlugins()` method.

---

### Part 6: Register Queue Processors

**Coding time:**

Open `src/Pyz/Zed/Queue/QueueDependencyProvider.php`. For each queue, assign the appropriate processor plugin:

| Queue | Processor |
|-------|-----------|
| Publish queues | `EventQueueMessageProcessorPlugin` |
| Search sync queue | `SynchronizationSearchQueueMessageProcessorPlugin` |
| Storage sync queue | `SynchronizationStorageQueueMessageProcessorPlugin` |

---

### Part 7: Add Propel Behaviors

#### 7.1 Event Behavior (Trigger Source)

**Coding time:**

Open `src/SprykerAcademy/Zed/Supplier/Persistence/Propel/Schema/pyz_supplier.schema.xml`. Add the `event` behavior to detect changes on all columns. This causes Propel to fire events like `Entity.pyz_supplier.create` whenever a supplier entity is saved.

> **Event behavior format:** `<parameter name="pyz_supplier_all" column="*"/>` watches all columns. The parameter name is arbitrary but conventionally uses `tablename_all`.

#### 7.2 Synchronization Behavior (Sync Target)

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/Persistence/Propel/Schema/pyz_supplier_search.schema.xml`. Add the `synchronization` behavior with parameters:
- `resource` — name of the resource (e.g., `"supplier"`)
- `key_suffix_column` — column holding the entity ID (the `fk_supplier` column)
- `queue_group` — which sync queue to use

Do the same for `pyz_supplier_storage.schema.xml`.

After adding behaviors:

```bash
docker/sdk console propel:install
```

---

### Part 8: Trigger Publish from Data Import

The Propel event behavior is disabled during data import for performance. You need to manually trigger publish events.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierDataImport/Business/DataImportStep/SupplierWriterStep.php`. The step extends `PublishAwareStep` which provides `addPublishEvents()`. After saving a supplier entity, call it twice — once for search, once for storage — passing the publish event constant and the supplier ID.

---

## Testing the Flow

1. Import suppliers with new data:
   ```bash
   docker/sdk console data:import supplier
   ```

2. Process the queues (if scheduler isn't running):
   ```bash
   docker/sdk console queue:worker:start --stop-when-empty
   ```

3. Check the intermediate tables:
   ```sql
   SELECT * FROM pyz_supplier_search;
   SELECT * FROM pyz_supplier_storage;
   ```

4. Verify Elasticsearch has the data:
   ```bash
   curl -s 'localhost:9200/_search' -H 'Content-type: application/json' -d '{"query":{"exists":{"field":"id_supplier"}}}'
   ```

5. Creating a supplier via the Back Office should also trigger the full P&S flow automatically (via the event behavior).

---

## Run Automated Tests

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/Supplier/ PublishSync
```

---

## Solution

```bash
./exercises/load.sh supplier intermediate/publish-synchronize/complete
```
