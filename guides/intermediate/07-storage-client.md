# Exercise 13: Storage Client - Redis Supplier Lookup

In this exercise, you will build a Client module that reads supplier data from Redis (the key-value storage). While the Search module uses Elasticsearch for full-text search, the Storage module uses Redis for fast key-value lookups by ID.

You will learn how to:
- Read data from Redis using the `StorageClient`
- Generate storage keys using the `SynchronizationService`
- Build a Storage Reader pattern for key-value access
- Wire dependencies through the Client layer's `DependencyProvider` and `Factory`
- Distinguish between Search (Elasticsearch) and Storage (Redis) use cases

## Prerequisites

- Completed Exercise 10 (Publish & Synchronize) — suppliers must be synchronized to Redis
- Understanding of the Client layer and DependencyProvider pattern

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/storage-client/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
```

---

## Background: Search vs Storage Architecture

Spryker uses two different storage systems for different access patterns:

| Feature | Search (Elasticsearch) | Storage (Redis) |
|---------|------------------------|-----------------|
| **Use case** | Full-text search, filtering, aggregation | Fast key-value lookup by ID |
| **Query type** | Complex queries (BoolQuery, Match, etc.) | Simple key lookup |
| **Data structure** | Indexed documents with analyzers | Serialized JSON by key |
| **Key format** | Index + type + ID | Resource name + ID |
| **Spryker module** | `SupplierSearch` (Client) | `SupplierStorage` (Client) |

**Storage Key Format:**
```
resource_name:id

Example:
supplier:1
supplier:2
```

**Flow for Storage Read:**
```
Yves/Client
    ↓
SupplierStorageClient::findSupplierById()
    ↓
SupplierStorageReader::findSupplierStorageData()
    ↓
SynchronizationService::getStorageKeyBuilder('supplier')->buildKey(1)
    ↓
StorageClient::get('supplier:1')
    ↓
Redis
```

---

## Working on the Exercise

### Part 1: Understand the Storage Key Generation

When data is synchronized to Redis (via the Publish & Synchronize flow), the `synchronization` behavior on `pyz_supplier_storage` automatically:

1. Generates a storage key using the `resource` parameter (e.g., `"supplier"`)
2. Serializes the supplier data as JSON
3. Stores it in Redis with the key `supplier:{fk_supplier}`

The `SynchronizationService` provides a key builder to generate these keys consistently:

```php
$key = $this->synchronizationService
    ->getStorageKeyBuilder('supplier')
    ->buildKey((string)$idSupplier);
// Result: "supplier:1"
```

> **Resource name:** This must match the `resource` parameter in the synchronization behavior from `pyz_supplier_storage.schema.xml` (not to be confused with `pyz_supplier_search` which goes to Elasticsearch).

---

### Part 2: Implement the Storage Reader

The `SupplierStorageReader` is the core class that fetches data from Redis.

**Coding time:**

Open `src/SprykerAcademy/Client/SupplierStorage/Storage/SupplierStorageReader.php`:

#### 2.1 Add the Resource Name Constant

Add a class constant for the resource name to avoid hardcoding strings:

```php
protected const RESOURCE_NAME = 'supplier';
```

> **Best practice:** Use constants for resource identifiers. This prevents typos and makes refactoring easier.

#### 2.2 Add Static Cache for Key Builder

Add a static property to cache the key builder instance (avoid repeated service lookups):

```php
protected static ?SynchronizationKeyGeneratorPluginInterface $storageKeyBuilder = null;
```

#### 2.3 Implement `findSupplierStorageData()`

This method fetches a single supplier by ID from Redis:

1. Generate the storage key using `generateStorageKey()`
2. Call `$this->storageClient->get($key)` to fetch from Redis
3. Return the data array or null if not found

> **Note:** The `StorageClient->get()` method already performs `json_decode` automatically. The returned data is already a PHP array.

#### 2.4 Implement `getAllSuppliers()`

This method returns all suppliers from Redis (useful for dropdowns):

1. Generate a pattern using `generateStorageKeyPattern()` (use `*` as wildcard)
2. Get all matching keys using `$this->storageClient->getKeys($pattern)`
3. Fetch data for each key and filter out nulls

> **Redis Pattern:** The `buildKey('*')` generates a pattern like `supplier:*` which matches all supplier keys.

#### 2.5 Add Helper Methods

Implement the helper methods for clean code:

- `generateStorageKey(int $idSupplier): string` — Uses `SynchronizationDataTransfer` to generate a single key
- `generateStorageKeyPattern(): string` — Uses `SynchronizationDataTransfer` with wildcard reference
- `getStorageKeyBuilder(): SynchronizationKeyGeneratorPluginInterface` — Returns cached key builder (creates if null)
- `getDataByKey(string $key): ?array` — Fetches and returns data for a single key

> **SynchronizationDataTransfer:** This transfer object is used by the key builder. Set the reference (ID) and optionally parameters:
> ```php
> $synchronizationDataTransfer = (new SynchronizationDataTransfer())
>     ->setReference((string)$idSupplier);
> $key = $this->getStorageKeyBuilder()->generateKey($synchronizationDataTransfer);
> ```

---

### Part 3: Wire the Dependencies

#### 3.1 DependencyProvider

Open `src/SprykerAcademy/Client/SupplierStorage/SupplierStorageDependencyProvider.php`:

Implement the two provider methods:

1. `addStorageClient()` — Uses `$container->set()` with `CLIENT_STORAGE` constant and locator: `$container->getLocator()->storage()->client()`
2. `addSynchronizationService()` — Uses `$container->set()` with `SERVICE_SYNCHRONIZATION` constant and locator: `$container->getLocator()->synchronization()->service()`

Call both methods in `provideServiceLayerDependencies()`.

> **Client layer difference:** The method is `provideServiceLayerDependencies()` (not Business like in Zed).

#### 3.2 Factory

Open `src/SprykerAcademy/Client/SupplierStorage/SupplierStorageFactory.php`:

1. Implement `getStorageClient()` — Returns the StorageClient using `getProvidedDependency()`
2. Implement `getSynchronizationService()` — Returns the SynchronizationService using `getProvidedDependency()`
3. Implement `createSupplierStorageReader()` — Instantiates `SupplierStorageReader` passing both dependencies

> **Naming convention:** `get*()` for dependencies, `create*()` for new object instantiation.

---

### Part 4: Implement the Client

The Client is the public API that other modules use.

**Coding time:**

Open `src/SprykerAcademy/Client/SupplierStorage/SupplierStorageClient.php`:

Implement the two methods:

1. `findSupplierById(int $idSupplier): ?SupplierTransfer`
   - Get the reader from the factory
   - Call `findSupplierStorageData()`
   - If data exists, create a `SupplierTransfer` and call `fromArray()`
   - Return the transfer or null

2. `getAllSuppliers(): SupplierCollectionTransfer`
   - Get the reader from the factory
   - Call `getAllSuppliers()` to get array of arrays
   - Map each array to a `SupplierTransfer` using `fromArray()`
   - Create a `SupplierCollectionTransfer`, set the suppliers using `setSuppliers()`
   - Return the collection

> **Transfer hydration:** The `fromArray()` method automatically maps array keys to transfer properties. Ensure the array keys match the transfer property names.

---

## Testing the Storage Client

### Verify Data Exists in Redis

First, ensure suppliers are synchronized to Redis (from the P&S exercise):

```bash
# Check if data exists in the storage table
docker/sdk cli mysql -e "SELECT COUNT(*) FROM pyz_supplier_storage;"

# If empty, run data import and trigger P&S
docker/sdk console data:import supplier
docker/sdk console queue:worker:start --stop-when-empty
```

### Test via Debug Console

```bash
# Open CLI
docker/sdk cli

# PHP one-liner to test
php -r "
require 'vendor/autoload.php';
\$client = \Spryker\Client\Kernel\Locator::getInstance()->supplierStorage()->client();
\$supplier = \$client->findSupplierById(1);
var_dump(\$supplier);
"
```

### Expected Data Format in Redis

```bash
# Connect to Redis
docker/sdk cli redis-cli -h key_value_store

# Get a supplier
GET "supplier:1"
```

Expected response (JSON):
```json
{
  "id_supplier": 1,
  "name": "Acme Supplies",
  "description": "Leading supplier of industrial equipment",
  "status": 1,
  "email": "contact@acmesupplies.com",
  "phone": "+1-555-1234"
}
```

---

## Key Concepts Summary

### Storage vs Search Client Pattern

| Aspect | Search (SupplierSearchClient) | Storage (SupplierStorageClient) |
|--------|------------------------------|--------------------------------|
| **Query** | Complex (Elastica Query) | Simple key lookup |
| **Key generation** | Source identifier in query plugin | SynchronizationService key builder |
| **Dependencies** | SearchClient, Query plugins | StorageClient, SynchronizationService |
| **Use case** | Search by name, filter, aggregate | Lookup by ID, get all for dropdown |

### Storage Key Generation Pattern

```php
// 1. Create transfer with reference (ID)
$synchronizationDataTransfer = (new SynchronizationDataTransfer())
    ->setReference((string)$idSupplier);

// 2. Get key builder for resource
$keyBuilder = $this->synchronizationService
    ->getStorageKeyBuilder(static::RESOURCE_NAME); // 'supplier'

// 3. Generate key
$key = $keyBuilder->generateKey($synchronizationDataTransfer);
// Result: "supplier:1"
```

### Static Caching Pattern

```php
protected static ?SynchronizationKeyGeneratorPluginInterface $storageKeyBuilder = null;

protected function getStorageKeyBuilder(): SynchronizationKeyGeneratorPluginInterface
{
    if (static::$storageKeyBuilder === null) {
        static::$storageKeyBuilder = $this->synchronizationService
            ->getStorageKeyBuilder(static::RESOURCE_NAME);
    }
    return static::$storageKeyBuilder;
}
```

> **Why static?** The key builder is stateless. Caching it avoids repeated service locator calls.

---

## Run Automated Tests

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/Supplier/ StorageClient
```

---

## Solution

```bash
./exercises/load.sh supplier intermediate/storage-client/complete
```
