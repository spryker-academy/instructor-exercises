# Exercise 10: Publish & Synchronize - Supplier

In this exercise, you will make supplier data available in Elasticsearch (search) and Redis (storage) using Spryker's Publish & Synchronize (P&S) pattern. This is a two-step process: first you **publish** data from the main database into intermediate tables, then the **synchronization** behavior automatically pushes that data to the storefront storages.

You will learn how to:
- Configure publish and synchronize queues in RabbitMQ
- Set up queue message processors to handle events
- Add Propel behaviors (event + synchronization) to trigger and sync data
- Register publisher plugins that react to entity events
- Implement publisher plugins that delegate to business logic
- Build writers that process events in bulk
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
docker/sdk console messenger:setup-transports
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
Publish queue                            Sync queue
    ↓                                        ↓
Queue processor → Publisher Plugin       Queue processor → Sync plugin
    ↓                                        ↓
Writer (business logic)                  Elasticsearch / Redis
    ↓
Insert/Update pyz_*_search/storage
```

**Why two modules?** Spryker separates the logic by target storage:
- `SupplierSearch` — publishes to Elasticsearch (for full-text search)
- `SupplierStorage` — publishes to Redis (for key-value lookups)

Both follow the same pattern but write to different intermediate tables.

---

## Working on the Exercise

### Part 1: Understand the Constants

Open `src/SprykerAcademy/Shared/SupplierSearch/SupplierSearchConfig.php` and review the constants:

| Constant | Purpose |
|----------|---------|
| `SUPPLIER_PUBLISH_SEARCH_QUEUE` | Queue name for publish events (step 1) |
| `SUPPLIER_SYNC_SEARCH_QUEUE` | Queue name for sync events (step 2) |
| `ENTITY_PYZ_SUPPLIER_CREATE/UPDATE/DELETE` | Events fired by Propel's event behavior |
| `SUPPLIER_PUBLISH` | Manual publish event (fired from code) |

Similar constants exist in `SupplierStorageConfig` for the Redis pipeline. You'll use these constants throughout the exercise — never use plain strings for queue names or event names.

---

### Part 2: Set Up the Queues

P&S uses four queues — two per pipeline (Search + Storage):

| Queue | Purpose | Step |
|-------|---------|------|
| `publish.search.supplier` | Carries publish events for search | Publish |
| `sync.search.supplier` | Carries sync messages to Elasticsearch | Synchronize |
| `publish.storage.supplier` | Carries publish events for storage | Publish |
| `sync.storage.supplier` | Carries sync messages to Redis | Synchronize |

**Coding time:**

Open `src/Pyz/Client/SymfonyMessenger/SymfonyMessengerConfig.php`:

1. In `getPublishQueueConfiguration()`, add both publish queue constants (`SupplierSearchConfig::SUPPLIER_PUBLISH` and `SupplierStorageConfig::SUPPLIER_PUBLISH`)
2. In `getSynchronizationQueueConfiguration()`, add both sync queue constants (`SupplierSearchConfig::SUPPLIER_SYNC_SEARCH_QUEUE` and `SupplierStorageConfig::SUPPLIER_SYNC_STORAGE_QUEUE`)

> **Symfony Messenger:** Spryker 202512.0+ uses Symfony Messenger as the queue transport instead of direct RabbitMQ. Queues are configured in `SymfonyMessengerConfig` and the transport handles queue creation automatically. The queue worker processes messages through the same `queue:worker:start` command.

---

### Part 3: Set Up Queue Processors

Each queue needs a processor to handle its messages. Spryker provides out-of-the-box processor plugins.

**Coding time:**

Open `src/Pyz/Zed/Queue/QueueDependencyProvider.php`. For each queue, assign the appropriate processor:

| Queue | Processor Plugin |
|-------|-----------------|
| Publish queues (both) | `EventQueueMessageProcessorPlugin` |
| Search sync queue | `SynchronizationSearchQueueMessageProcessorPlugin` |
| Storage sync queue | `SynchronizationStorageQueueMessageProcessorPlugin` |

> **How it works:** The queue worker reads messages from a queue and passes them to the assigned processor. Publish queues contain "event" messages (processed by `EventQueueMessageProcessorPlugin`), while sync queues contain serialized data (processed by `Synchronization*` plugins that push to Elasticsearch/Redis).

---

### Part 4: Add Propel Behaviors

#### 4.1 Event Behavior — Fire Events on Entity Changes

The `event` behavior makes Propel fire events whenever an entity is created, updated, or deleted. These events are the starting point of the P&S flow.

**Coding time:**

Open `src/SprykerAcademy/Zed/Supplier/Persistence/Propel/Schema/pyz_supplier.schema.xml`. Add the `event` behavior to the `pyz_supplier` table to detect changes on all columns.

> **Event behavior format:** The parameter name is arbitrary (conventionally `tablename_all`), and `column="*"` watches all columns. This triggers events like `Entity.pyz_supplier.create`, `Entity.pyz_supplier.update`, and `Entity.pyz_supplier.delete`.

#### 4.2 Synchronization Behavior — Auto-Sync to Storefront

The `synchronization` behavior on the intermediate tables (`pyz_supplier_search`, `pyz_supplier_storage`) automatically pushes data to the sync queue whenever a record is written.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/Persistence/Propel/Schema/pyz_supplier_search.schema.xml`. Add the `synchronization` behavior with these parameters:
- `resource` — the resource name (e.g., `"supplier"`) — used to build the Elasticsearch/Redis key
- `key_suffix_column` — the column holding the entity ID (use the `fk_supplier` column)
- `queue_group` — which sync queue to write messages to (use the sync queue constant value)

Do the same for `pyz_supplier_storage.schema.xml`.

After adding both behaviors:

```bash
docker/sdk console propel:install
```

> **What the synchronization behavior does:** It auto-adds `key`, `data`, `created_at`, and `updated_at` columns to the table. When you save an entity to this table, the behavior automatically generates a key (e.g., `supplier:1`), serializes the data as JSON, and emits a message to the sync queue.

---

### Part 5: Register Publisher Plugins

Publisher plugins react to entity events and delegate to the business logic. You need to register them so the system knows which plugins handle which events.

**Coding time:**

Open `src/Pyz/Zed/Publisher/PublisherDependencyProvider.php`. The format maps a queue name to an array of publisher plugins:

```php
return [
    QueueName::CONSTANT => [
        new MyWritePublisherPlugin(),
    ],
];
```

1. Create a method that returns the Search publisher plugin mapped to the search publish queue
2. Create a method that returns the Storage publisher plugin mapped to the storage publish queue
3. Add both to `getPublisherPlugins()`

> **Queue routing:** By specifying the queue as the array key, you tell the system: "put events for these plugins on this queue." If no key is specified, events go to the default publish queue.

---

### Part 6: Implement Publisher Plugins

The publisher plugin is the entry point for handling events. It receives a batch of event transfers and delegates to the Facade.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/Communication/Plugin/Publisher/SupplierSearchWritePublisherPlugin.php`:

1. `getSubscribedEvents()` — return an array of event names this plugin reacts to. Use constants from `SupplierSearchConfig`: the manual publish event, plus entity create and update events
2. `handleBulk()` — use `$this->getFacade()` to call the write method, passing the event transfers

> **Why subscribe to both manual and entity events?** Entity events (`Entity.pyz_supplier.create`) are triggered automatically by the event behavior on `pyz_supplier`. The manual event (`SupplierSearch.supplier.publish`) is triggered explicitly from code (e.g., data import). The plugin handles both the same way.

Do the same for `SupplierStorageWritePublisherPlugin` using `SupplierStorageConfig` constants.

---

### Part 7: Build the Business Logic Chain

Now implement the chain that the publisher plugin calls: Facade → Factory → Writer.

#### 7.1 Implement the Writer

The writer is the core business logic. It processes a batch of events in bulk.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/Business/Writer/SupplierSearchWriter.php`. The skeleton has the iteration logic. You need to fill in the data-loading methods:

1. Create a `SupplierCriteriaTransfer`, populate it with the supplier IDs, and use the `SupplierFacade` to load supplier entities
2. Create a `SupplierSearchCriteriaTransfer`, populate it with the same IDs, and use the Repository to load existing search records
3. The rest of the loop (create/update per supplier) is provided

> **Bulk processing:** Loading all suppliers in one query is critical. The writer receives an array of events (potentially hundreds) — doing one query per event would be extremely slow.

Apply the same pattern to `SupplierStorageWriter`.

#### 7.2 Provide Module Dependencies

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/SupplierSearchDependencyProvider.php`:

1. Implement `addEventBehaviorFacade()` — the `EventBehaviorFacade` provides helpers to extract entity IDs from event transfers. Access via `$container->getLocator()->eventBehavior()->facade()`
2. Implement `addSupplierFacade()` — the core `SupplierFacade` for reading supplier data
3. Call both in `provideBusinessLayerDependencies()`

Do the same for `SupplierStorageDependencyProvider`.

#### 7.3 Implement the BusinessFactory

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/Business/SupplierSearchBusinessFactory.php`:

1. Implement `getEventBehaviorFacade()` and `getSupplierFacade()` using `getProvidedDependency()`
2. Wire all four dependencies into the Writer constructor: the two facades, plus `getRepository()` and `getEntityManager()` (available from the parent class)

Do the same for `SupplierStorageBusinessFactory`.

#### 7.4 Implement the Facade

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierSearch/Business/SupplierSearchFacade.php`. Delegate `writeCollectionBySupplierEvents()` to the writer via the factory.

Do the same for `SupplierStorageFacade`.

---

### Part 8: Trigger Publish from Data Import

The Propel event behavior is **disabled during data import** for performance (to avoid millions of events during bulk imports). You need to manually trigger publish events.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierDataImport/Business/DataImportStep/SupplierWriterStep.php`. The step extends `PublishAwareStep` which provides `addPublishEvents()`. After saving a supplier entity (inside the `isNew() || isModified()` condition), call it twice:
- Once for search (using `SupplierSearchConfig::SUPPLIER_PUBLISH`)
- Once for storage (using `SupplierStorageConfig::SUPPLIER_PUBLISH`)

Pass the supplier ID as the second parameter.

---

## The Complete Flow

After implementing all parts, here's what happens when a supplier is created or imported:

```
1. Supplier entity saved
   → Event behavior fires Entity.pyz_supplier.create
   → (or DataImport fires SupplierSearch.supplier.publish manually)

2. Event goes to publish.search.supplier queue
   → EventQueueMessageProcessorPlugin processes it
   → SupplierSearchWritePublisherPlugin.handleBulk() called

3. Plugin calls Facade → Factory → Writer
   → Writer loads supplier data from DB
   → Writer inserts/updates pyz_supplier_search row

4. Synchronization behavior on pyz_supplier_search triggers
   → Message goes to sync.search.supplier queue
   → SynchronizationSearchQueueMessageProcessorPlugin processes it
   → Data pushed to Elasticsearch

(Same flow in parallel for Storage → Redis)
```

---

## Testing the Flow

### Setup: Ensure Queues and Exchanges Exist

After registering queues in the config files, you must create the AMQP infrastructure (queues, exchanges, bindings) in RabbitMQ:

```bash
docker/sdk console messenger:setup-transports
```

This reads the `SymfonyMessengerConfig::getQueueConfiguration()` and creates the corresponding AMQP exchanges and queues. **Without this step, messages are silently dropped** because the Symfony Messenger transport has no exchange to route them through.

> **Three config files required:** Queues must be registered in:
> 1. `SymfonyMessengerConfig` — Symfony Messenger transport routing
> 2. `RabbitMqConfig` — AMQP queue declaration
> 3. `QueueDependencyProvider` — queue message processors
>
> The `load.sh` script handles all three and also creates queues/exchanges via the RabbitMQ management API as a fallback.

Verify the queues exist at http://queue.spryker.local (login: `spryker`/`secret`):
- `publish.search.supplier`
- `publish.storage.supplier`
- `sync.search.supplier`
- `sync.storage.supplier`

### Test the Flow

1. Add a new supplier to the CSV and import:
   ```bash
   docker/sdk console data:import supplier
   ```

2. Process the event queue first (routes events to publish queues):
   ```bash
   docker/sdk console queue:worker:start --stop-when-empty
   ```

3. Process again (handles publish → search/storage tables → sync queues → Elasticsearch/Redis):
   ```bash
   docker/sdk console queue:worker:start --stop-when-empty
   ```
   You may need to run the worker multiple times — the first run processes publish events (writes to intermediate tables), the second processes sync events (pushes to Elasticsearch/Redis).

4. Check the intermediate tables using any DB client (credentials in `deploy.dev.yml`):
   ```sql
   SELECT count(*) FROM pyz_supplier_search;
   SELECT count(*) FROM pyz_supplier_storage;
   ```

5. Verify Elasticsearch:
   ```bash
   curl -s 'localhost:9200/_search' -H 'Content-type: application/json' \
     -d '{"query":{"exists":{"field":"id_supplier"}}}'
   ```

6. Creating a supplier via the Back Office also triggers P&S automatically (via the event behavior) — no manual queue processing needed if the scheduler is running.

### Troubleshooting

- **No messages in queues after import:** Ensure `DataImportPublisherPlugin` is registered in `DataImportDependencyProvider::getDataImportAfterImportHookPlugins()`
- **Queue not found error:** Run `docker/sdk boot deploy.dev.yml` to recreate infrastructure, or create queues manually via the RabbitMQ API
- **Data in tables but not in Elasticsearch:** Process the sync queues with `queue:worker:start --stop-when-empty`

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
