# Spryker Backend Development: Best Practices & Architecture Guide

A comprehensive reference building on the exercises you have completed. Every pattern shown here is drawn from real Spryker modules and the training codebase.

---

## Table of Contents

1. [Module Architecture](#1-module-architecture)
2. [Persistence Layer](#2-persistence-layer)
3. [Transfer Objects (DTOs)](#3-transfer-objects)
4. [Business Layer](#4-business-layer)
5. [Communication Between Yves and Zed](#5-communication-between-yves-and-zed)
6. [DependencyProvider Patterns](#6-dependencyprovider-patterns)
7. [Plugin Architecture](#7-plugin-architecture)
8. [Query Best Practices & Avoiding N+1](#8-query-best-practices--avoiding-n1)
9. [Testing](#9-testing)
10. [Common Commands Reference](#10-common-commands-reference)

---

## 1. Module Architecture

Spryker separates concerns across four application layers. Each module lives in a namespace that encodes both the vendor and the layer.

```
src/
└── SprykerAcademy/
    ├── Zed/          # Backend: persistence, business logic, Back Office UI
    │   └── HelloWorld/
    │       ├── Business/
    │       │   ├── HelloWorldFacade.php
    │       │   ├── HelloWorldFacadeInterface.php
    │       │   ├── HelloWorldBusinessFactory.php
    │       │   ├── Reader/
    │       │   └── Writer/
    │       ├── Communication/
    │       │   └── Controller/
    │       ├── Persistence/
    │       │   ├── HelloWorldRepository.php
    │       │   ├── HelloWorldEntityManager.php
    │       │   ├── HelloWorldPersistenceFactory.php
    │       │   ├── Mapper/
    │       │   └── Propel/Schema/
    │       └── Presentation/
    ├── Yves/         # Storefront: rendering, routing
    │   └── HelloWorldPage/
    │       ├── Controller/
    │       ├── Plugin/Router/
    │       └── Theme/
    ├── Client/       # Bridge between Yves and Zed
    │   └── HelloWorld/
    │       └── Stub/
    └── Shared/       # Transfer definitions, constants
        └── HelloWorld/Transfer/
```

### Layer Responsibilities

| Layer | Namespace | Responsibility |
|-------|-----------|----------------|
| **Zed** | `Namespace\Zed\Module\` | Business logic, persistence, Back Office controllers, console commands |
| **Yves** | `Namespace\Yves\ModulePage\` | Storefront controllers, Twig templates, routing |
| **Client** | `Namespace\Client\Module\` | HTTP calls to Zed via ZedRequestClient |
| **Shared** | `Namespace\Shared\Module\` | Transfer XMLs, constants visible to all layers |

### Key Rule: Yves Must Never Access the Database Directly

Yves communicates with Zed exclusively through the Client layer:

```
Yves Controller
  -> Client (HelloWorldClient)
    -> Stub (HelloWorldStub)
      -> ZedRequestClient::call('/hello-world/gateway/find-message', $transfer)
        -> Zed GatewayController
          -> Facade -> Business Logic -> Repository/EntityManager
```

---

## 2. Persistence Layer

### 2.1 Repository vs EntityManager

**Repository = reads only. EntityManager = writes only.** This separation ensures clean architecture and testability.

**Repository** (reads):

```php
class HelloWorldRepository extends AbstractRepository implements HelloWorldRepositoryInterface
{
    public function findMessage(MessageCriteriaTransfer $messageCriteria): ?MessageTransfer
    {
        $query = $this->getFactory()->createMessageQuery();
        $messageEntity = null;

        if ($messageCriteria->getIdMessage()) {
            $messageEntity = $query->findOneByIdMessage($messageCriteria->getIdMessage());
        } elseif ($messageCriteria->getMessage()) {
            $messageEntity = $query->filterByMessage(
                sprintf('%%%s%%', $messageCriteria->getMessage()),
                Criteria::LIKE,
            )->findOne();
        }

        if (!$messageEntity) {
            return null;
        }

        return $this->getFactory()
            ->createMessageMapper()
            ->mapEntityToMessageTransfer($messageEntity, new MessageTransfer());
    }
}
```

**EntityManager** (writes):

```php
class HelloWorldEntityManager extends AbstractEntityManager implements HelloWorldEntityManagerInterface
{
    public function createMessage(MessageTransfer $messageTransfer): MessageTransfer
    {
        $messageEntity = $this->getFactory()
            ->createMessageMapper()
            ->mapMessageTransferToEntity($messageTransfer);

        $messageEntity->save();

        return $this->getFactory()
            ->createMessageMapper()
            ->mapEntityToMessageTransfer($messageEntity, new MessageTransfer());
    }
}
```

### 2.2 PersistenceFactory

All Propel query objects and mappers are created through the PersistenceFactory. Never instantiate them directly.

```php
class HelloWorldPersistenceFactory extends AbstractPersistenceFactory
{
    public function createMessageQuery(): PyzMessageQuery
    {
        return PyzMessageQuery::create(); // Always use ::create(), never new
    }

    public function createMessageMapper(): MessageMapper
    {
        return new MessageMapper();
    }
}
```

When providing queries to the Communication layer (e.g., for GUI tables), use `$container->factory()` to get a fresh instance each time:

```php
$container->set(
    static::PROPEL_QUERY_SUPPLIER,
    $container->factory(fn () => PyzSupplierQuery::create()),
);
```

### 2.3 Mapper Pattern

Mappers are dedicated classes in `Persistence/Mapper/` that contain no business logic - only field mapping.

```php
class SupplierMapper
{
    // Transfer -> Entity: use modifiedToArray() so only set fields are mapped
    public function mapSupplierTransferToSupplierEntity(
        SupplierTransfer $supplierTransfer,
        PyzSupplier $supplierEntity,
    ): PyzSupplier {
        return $supplierEntity->fromArray($supplierTransfer->modifiedToArray());
    }

    // Entity -> Transfer: use toArray() + ignoreMissingProperties=true
    public function mapSupplierEntityToSupplierTransfer(
        PyzSupplier $supplierEntity,
        SupplierTransfer $supplierTransfer,
    ): SupplierTransfer {
        return $supplierTransfer->fromArray($supplierEntity->toArray(), true);
    }
}
```

**Important:** Use `modifiedToArray()` (not `toArray()`) when writing to the database. This ensures only explicitly-set properties are written, preventing accidental overwriting of defaults or existing values.

### 2.4 Propel Schema Conventions

```xml
<database name="zed"
          namespace="Orm\Zed\HelloWorld\Persistence"
          package="src.Orm.Zed.HelloWorld.Persistence">

    <table name="pyz_message" idMethod="native" allowPkInsert="true" phpName="PyzMessage">
        <column name="id_message" required="true" type="INTEGER" primaryKey="true" autoIncrement="true"/>
        <column name="message" required="true" type="VARCHAR" size="255"/>
        <unique name="pyz_message-message">
            <unique-column name="message"/>
        </unique>
        <id-method-parameter value="pyz_message_pk_seq"/>
    </table>
</database>
```

**Conventions:**
- Project-level tables use `pyz_` prefix (Spryker core uses `spy_`)
- PHP class name (`phpName`) uses PascalCase prefixed with `Pyz`
- Generated ORM classes land in `Orm\Zed\{Module}\Persistence\`

---

## 3. Transfer Objects

### 3.1 Transfer XML Definition

Transfers live in `Shared/{Module}/Transfer/*.transfer.xml` and are generated into `Generated\Shared\Transfer\`.

```xml
<transfers xmlns="spryker:transfer-01"
           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
           xsi:schemaLocation="spryker:transfer-01 http://static.spryker.com/transfer-01.xsd">

    <!-- Core entity transfer -->
    <transfer name="Message">
        <property name="idMessage" type="int"/>
        <property name="message" type="string"/>
    </transfer>

    <!-- Criteria transfer: used for search/filter parameters -->
    <transfer name="MessageCriteria">
        <property name="idMessage" type="int"/>
        <property name="message" type="string"/>
    </transfer>

    <!-- Response transfer: wraps results with success flag -->
    <transfer name="MessageResponse">
        <property name="message" type="Message"/>
        <property name="isSuccessful" type="bool"/>
    </transfer>
</transfers>
```

For collections of IDs, use the `singular` attribute:

```xml
<transfer name="SupplierCriteria">
    <property name="idsSupplier" singular="idSupplier" type="array"/>
    <property name="idSupplier" type="int"/>
    <property name="name" type="string"/>
</transfer>
```

### 3.2 Naming Conventions

| Purpose | Convention | Example |
|---------|-----------|---------|
| Core entity | `{Entity}Transfer` | `SupplierTransfer` |
| Search/filter parameters | `{Entity}CriteriaTransfer` | `MessageCriteriaTransfer` |
| Wrapping a result | `{Entity}ResponseTransfer` | `MessageResponseTransfer` |
| Collection container | `{Entity}CollectionTransfer` | `SupplierCollectionTransfer` |
| Primary key property | `id{Entity}` | `idSupplier` |
| Foreign key property | `fk{Entity}` | `fkSupplier` |
| Array of IDs | `ids{Entity}` with `singular` | `idsSupplier` |

### 3.3 Key Methods

| Method | Purpose |
|--------|---------|
| `$transfer->toArray()` | Returns ALL properties, including nulls |
| `$transfer->modifiedToArray()` | Returns ONLY explicitly-set properties - **use for DB writes** |
| `$transfer->fromArray($array, true)` | Populate from array, ignore missing keys (safe for Entity->Transfer) |
| `$transfer->requireField()` | Throws exception if the field is null - use for validation |
| `$transfer->getFieldOrFail()` | Returns value or throws exception |

---

## 4. Business Layer

### 4.1 Facade: The Module's Public API

The Facade is the **only** public entry point to a module. It delegates immediately to business objects created by the Factory.

```php
/**
 * @method \SprykerAcademy\Zed\Supplier\Business\SupplierBusinessFactory getFactory()
 */
class SupplierFacade extends AbstractFacade implements SupplierFacadeInterface
{
    /**
     * @api
     */
    public function createSupplier(SupplierTransfer $supplierTransfer): SupplierTransfer
    {
        return $this->getFactory()
            ->createSupplierWriter()
            ->create($supplierTransfer);
    }

    /**
     * @api
     */
    public function getSuppliers(SupplierCriteriaTransfer $supplierCriteriaTransfer): array
    {
        return $this->getFactory()
            ->createSupplierReader()
            ->getSuppliers($supplierCriteriaTransfer);
    }
}
```

**Rules:**
- Every public method is tagged `@api`
- The Facade contains **no logic** - only delegation
- `@method` docblocks on the class provide IDE autocomplete for `getFactory()`, `getRepository()`, etc.

### 4.2 BusinessFactory: Wiring Dependencies

The Factory creates business objects and injects dependencies. Naming convention: `create*()` for new instances, `get*()` for provided dependencies.

```php
/**
 * @method \SprykerAcademy\Zed\Supplier\Persistence\SupplierEntityManagerInterface getEntityManager()
 * @method \SprykerAcademy\Zed\Supplier\Persistence\SupplierRepositoryInterface getRepository()
 */
class SupplierBusinessFactory extends AbstractBusinessFactory
{
    public function createSupplierWriter(): SupplierWriter
    {
        return new SupplierWriter(
            $this->getEntityManager(),
        );
    }

    public function createSupplierReader(): SupplierReader
    {
        return new SupplierReader(
            $this->getRepository(),
        );
    }
}
```

### 4.3 Reader/Writer Separation

**Reader** classes only call the Repository. **Writer** classes only call the EntityManager. This makes testing trivial and prevents mutations in read paths.

```php
readonly class SupplierReader
{
    public function __construct(protected SupplierRepositoryInterface $supplierRepository)
    {
    }

    public function getSuppliers(SupplierCriteriaTransfer $supplierCriteriaTransfer): array
    {
        return $this->supplierRepository->getSuppliers($supplierCriteriaTransfer);
    }
}
```

```php
readonly class SupplierWriter
{
    public function __construct(protected SupplierEntityManagerInterface $supplierEntityManager)
    {
    }

    public function create(SupplierTransfer $supplierTransfer): SupplierTransfer
    {
        return $this->supplierEntityManager->createSupplier($supplierTransfer);
    }
}
```

---

## 5. Communication Between Yves and Zed

### Step 1: Yves Controller calls the Client

```php
class MessageController extends AbstractController
{
    public function getAction(int $idMessage): View
    {
        $messageCriteriaTransfer = new MessageCriteriaTransfer();
        $messageCriteriaTransfer->setIdMessage($idMessage);

        $messageResponseTransfer = $this->getFactory()
            ->getHelloWorldClient()
            ->findMessage($messageCriteriaTransfer);

        return $this->view(
            ['message' => $messageResponseTransfer->getMessage()],
            [],
            '@HelloWorldPage/views/message/get.twig',
        );
    }
}
```

### Step 2: Client delegates to the Stub

```php
class HelloWorldClient extends AbstractClient implements HelloWorldClientInterface
{
    public function findMessage(MessageCriteriaTransfer $messageCriteria): MessageResponseTransfer
    {
        return $this->getFactory()->createHelloWorldStub()->findMessage($messageCriteria);
    }
}
```

### Step 3: Stub makes the HTTP call

```php
class HelloWorldStub
{
    public function __construct(protected ZedRequestClientInterface $zedRequestClient)
    {
    }

    public function findMessage(MessageCriteriaTransfer $messageCriteria): MessageResponseTransfer
    {
        // URL convention: /{module-name}/gateway/{action-name}
        return $this->zedRequestClient->call(
            '/hello-world/gateway/find-message',
            $messageCriteria,
        );
    }
}
```

### Step 4: GatewayController receives the call in Zed

```php
class GatewayController extends AbstractGatewayController
{
    public function findMessageAction(MessageCriteriaTransfer $messageCriteria): MessageResponseTransfer
    {
        return $this->getFacade()->findMessage($messageCriteria);
    }
}
```

**Gateway URL convention:** `/hello-world/gateway/find-message` maps to `HelloWorld` module -> `GatewayController` -> `findMessageAction()`. Transfers are serialized/deserialized automatically.

---

## 6. DependencyProvider Patterns

DependencyProviders wire external dependencies (facades, clients, services) into a module's container.

### Client Layer

```php
class HelloWorldDependencyProvider extends AbstractDependencyProvider
{
    public const string CLIENT_ZED_REQUEST = 'CLIENT_ZED_REQUEST';

    public function provideServiceLayerDependencies(Container $container): Container
    {
        $container = $this->addZedRequestClient($container);
        return $container;
    }

    protected function addZedRequestClient(Container $container): Container
    {
        $container->set(
            static::CLIENT_ZED_REQUEST,
            fn () => $container->getLocator()->zedRequest()->client(),
        );
        return $container;
    }
}
```

### Yves Layer

```php
class HelloWorldPageDependencyProvider extends AbstractBundleDependencyProvider
{
    public const string CLIENT_HELLO_WORLD = 'CLIENT_HELLO_WORLD';

    public function provideDependencies(Container $container): Container
    {
        $container->set(
            static::CLIENT_HELLO_WORLD,
            fn () => $container->getLocator()->helloWorld()->client(),
        );
        return $container;
    }
}
```

### Container Methods

| Method | Behavior | Use For |
|--------|----------|---------|
| `$container->set(key, fn)` | Singleton: resolved once, cached | Facades, clients, services |
| `$container->factory(fn)` | New instance every resolution | Propel Query objects (stateful) |

---

## 7. Plugin Architecture

Plugins are Spryker's extension mechanism. They implement a defined interface and are registered in a DependencyProvider.

### Publisher Plugin (Publish & Synchronize)

```php
class SupplierSearchWritePublisherPlugin extends AbstractPlugin implements PublisherPluginInterface
{
    public function handleBulk(array $eventEntityTransfers, $eventName): void
    {
        $this->getFacade()->writeCollectionBySupplierEvents($eventEntityTransfers);
    }

    public function getSubscribedEvents(): array
    {
        return [
            SupplierSearchConfig::SUPPLIER_PUBLISH,
            SupplierSearchConfig::ENTITY_PYZ_SUPPLIER_CREATE,
            SupplierSearchConfig::ENTITY_PYZ_SUPPLIER_UPDATE,
        ];
    }
}
```

### Router Plugin (Yves Routing)

```php
class HelloWorldPageRouteProviderPlugin extends AbstractRouteProviderPlugin
{
    public function addRoutes(RouteCollection $routeCollection): RouteCollection
    {
        $route = $this->buildRoute(
            'hello-world/message/{idMessage}',
            'HelloWorldPage',  // Module
            'Message',         // Controller
            'getAction',       // Action
        );
        $route = $route->setMethods(['GET']);
        $routeCollection->add('hello-world-message', $route);

        return $routeCollection;
    }
}
```

**Plugin rules:**
- Plugins are thin - they delegate to the Facade, no logic inside
- Registered in project-level DependencyProviders
- `@method` docblock links the Plugin to its Facade for IDE support

---

## 8. Query Best Practices & Avoiding N+1

### 8.1 The N+1 Problem

The N+1 problem occurs when you fetch a list of entities, then make a separate database query for each entity's related data. If you have 100 suppliers, this means 1 query to get the list + 100 queries for related data = 101 queries.

**Bad - N+1 pattern (DO NOT DO THIS):**

```php
// 1 query to fetch all suppliers
$suppliers = $this->supplierRepository->getSuppliers($criteria);

foreach ($suppliers as $supplier) {
    // N queries - one per supplier!
    $storageData = $this->storageRepository->findByFkSupplier($supplier->getIdSupplier());
    // ... process
}
```

### 8.2 The Indexed Collection Pattern (Solution)

Fetch ALL related data in one query using `filterBy*_In()`, then index by ID for O(1) lookups:

```php
protected function writeCollectionBySupplierIds(array $supplierIds): void
{
    // Step 1: Fetch ALL suppliers in ONE query, index by ID
    $supplierTransfersIndexed = $this->getSupplierTransfersIndexed($supplierIds);

    // Step 2: Fetch ALL storage data in ONE query, index by FK
    $supplierStorageTransfersIndexed = $this->getSupplierStorageTransfersIndexed(
        array_keys($supplierTransfersIndexed),
    );

    // Step 3: Iterate with array lookups - NO database calls inside the loop
    foreach ($supplierTransfersIndexed as $supplierId => $supplierTransfer) {
        $storageTransfer = $supplierStorageTransfersIndexed[$supplierId]
            ?? new SupplierStorageTransfer();
        // ... process
    }
}

protected function getSupplierTransfersIndexed(array $supplierIds): array
{
    $criteria = (new SupplierCriteriaTransfer())->setIdsSupplier($supplierIds);
    $suppliers = $this->supplierFacade->getSupplierCollection($criteria);

    $indexed = [];
    foreach ($suppliers as $supplier) {
        $indexed[$supplier->getIdSupplier()] = $supplier;
    }
    return $indexed;
}
```

### 8.3 Bulk Fetching with filterBy*_In()

Propel generates `filterBy*_In()` methods that produce SQL `WHERE column IN (...)` clauses:

```php
public function getSuppliers(SupplierCriteriaTransfer $criteria): array
{
    $query = $this->getFactory()->createSupplierQuery();

    if ($criteria->getIdsSupplier()) {
        $query->filterByIdSupplier_In($criteria->getIdsSupplier());
    }

    if ($criteria->getName() !== null) {
        $query->filterByName($criteria->getName());
    }

    return $this->mapEntitiesToTransfers($query->find());
}
```

### 8.4 Guard Against Empty IN Clauses

An empty `IN ()` clause causes a SQL error. Always check before querying:

```php
public function getSupplierSearches(SupplierSearchCriteriaTransfer $criteria): array
{
    if ($criteria->getFksSupplier() === []) {
        return []; // Guard: never execute IN with empty array
    }

    $entities = $this->getFactory()
        ->createSupplierSearchQuery()
        ->filterByFkSupplier_In($criteria->getFksSupplier())
        ->find();

    return $this->mapEntitiesToTransfers($entities);
}
```

### 8.5 Propel Query Method Reference

| Method | SQL | Use Case |
|--------|-----|----------|
| `filterByColumn($value)` | `WHERE column = ?` | Exact match |
| `filterByColumn($value, Criteria::LIKE)` | `WHERE column LIKE ?` | Partial match (use `%` wildcards) |
| `filterByColumn_In($array)` | `WHERE column IN (?, ?, ...)` | Bulk fetch by multiple values |
| `findOne()` | `LIMIT 1` | Get single result |
| `find()` | No limit | Get collection |
| `findOneByColumnName($value)` | `WHERE column = ? LIMIT 1` | Shorthand for filter + findOne |
| `findOneOrCreate()` | Finds or creates entity | Upsert patterns (data import) |
| `count()` | `SELECT COUNT(*)` | Count results without fetching |

### 8.6 Criteria Pattern for Complex Queries

Instead of adding many method parameters, use a CriteriaTransfer to encapsulate search conditions:

```php
// Repository applies conditions based on what's set in criteria
public function findMessage(MessageCriteriaTransfer $criteria): ?MessageTransfer
{
    $query = $this->getFactory()->createMessageQuery();

    if ($criteria->getIdMessage()) {
        $query->findOneByIdMessage($criteria->getIdMessage());
    } elseif ($criteria->getMessage()) {
        $query->filterByMessage(
            sprintf('%%%s%%', $criteria->getMessage()),
            Criteria::LIKE,
        )->findOne();
    }

    // ... map and return
}
```

This pattern scales cleanly as you add more filter options - just add properties to the CriteriaTransfer and conditions in the Repository.

---

## 9. Testing

### 9.1 Unit Tests: Mock the Interface

Test a single class in isolation. Mock ALL collaborators via their interfaces:

```php
/**
 * @group SprykerAcademyTest
 * @group Zed
 * @group Supplier
 * @group Business
 * @group SupplierReaderTest
 */
class SupplierReaderTest extends Unit
{
    public function testGetSuppliersReturnsRepositoryResult(): void
    {
        $criteria = new SupplierCriteriaTransfer();
        $expected = [(new SupplierTransfer())->setIdSupplier(1)];

        // Mock the interface, not the concrete class
        $repositoryMock = $this->createMock(SupplierRepositoryInterface::class);
        $repositoryMock->expects($this->once())
            ->method('getSuppliers')
            ->with($criteria)
            ->willReturn($expected);

        $reader = new SupplierReader($repositoryMock);
        $actual = $reader->getSuppliers($criteria);

        $this->assertSame($expected, $actual);
    }
}
```

### 9.2 Testing Write Operations

```php
public function testCreateDelegatesToEntityManager(): void
{
    $input = (new SupplierTransfer())->setName('Supplier A');
    $expected = (new SupplierTransfer())->setIdSupplier(1)->setName('Supplier A');

    $entityManagerMock = $this->createMock(SupplierEntityManagerInterface::class);
    $entityManagerMock->expects($this->once())
        ->method('createSupplier')
        ->with($input)
        ->willReturn($expected);

    $writer = new SupplierWriter($entityManagerMock);
    $actual = $writer->create($input);

    $this->assertSame($expected, $actual);
}
```

### 9.3 Integration Tests: Clean State

Use `setUp()` and `tearDown()` to ensure database isolation:

```php
class SupplierDataImportTest extends Unit
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->cleanTestData();
    }

    protected function tearDown(): void
    {
        $this->cleanTestData();
        parent::tearDown();
    }
}
```

### 9.4 Group Annotations

Every test class must carry `@group` annotations mirroring the namespace hierarchy:

```php
/**
 * @group SprykerAcademyTest
 * @group Zed
 * @group Supplier
 * @group Business
 * @group SupplierReaderTest
 */
```

This enables running subsets of tests: `vendor/bin/codecept run --group Supplier`.

---

## 10. Common Commands Reference

| Command | When to Use |
|---------|-------------|
| `docker/sdk cli composer dump-autoload` | After loading a new exercise |
| `docker/sdk console transfer:generate` | After modifying `.transfer.xml` files |
| `docker/sdk console propel:install` | After modifying `.schema.xml` files |
| `docker/sdk console data:import` | After implementing data importers |
| `docker/sdk console event:trigger` | To trigger publish & sync events |
| `docker/sdk console queue:worker:start` | To process queued messages |
| `docker/sdk console search:setup:sources` | After modifying search schemas |
| `docker/sdk console glue-api:controller:cache:warm-up` | After adding Glue API resources |
| `docker/sdk console router:cache:warm-up` | After adding new route providers |
| `docker/sdk console navigation:build-cache` | After modifying navigation XML |
| `docker/sdk console cache:empty-all` | When experiencing cache issues |
| `docker/sdk console c:e` | Shortcut for cache:empty-all |

---

## Quick Reference: File Naming and Location

| What | Path Pattern | Example |
|------|-------------|---------|
| Facade | `Zed/{Module}/Business/{Module}Facade.php` | `HelloWorldFacade.php` |
| Facade Interface | `Zed/{Module}/Business/{Module}FacadeInterface.php` | `HelloWorldFacadeInterface.php` |
| Business Factory | `Zed/{Module}/Business/{Module}BusinessFactory.php` | `HelloWorldBusinessFactory.php` |
| Reader | `Zed/{Module}/Business/Reader/{Entity}Reader.php` | `MessageReader.php` |
| Writer | `Zed/{Module}/Business/Writer/{Entity}Writer.php` | `MessageWriter.php` |
| Repository | `Zed/{Module}/Persistence/{Module}Repository.php` | `HelloWorldRepository.php` |
| Repository Interface | `Zed/{Module}/Persistence/{Module}RepositoryInterface.php` | `HelloWorldRepositoryInterface.php` |
| EntityManager | `Zed/{Module}/Persistence/{Module}EntityManager.php` | `HelloWorldEntityManager.php` |
| PersistenceFactory | `Zed/{Module}/Persistence/{Module}PersistenceFactory.php` | `HelloWorldPersistenceFactory.php` |
| Mapper | `Zed/{Module}/Persistence/Mapper/{Entity}Mapper.php` | `MessageMapper.php` |
| Propel Schema | `Zed/{Module}/Persistence/Propel/Schema/pyz_{table}.schema.xml` | `pyz_message.schema.xml` |
| GatewayController | `Zed/{Module}/Communication/Controller/GatewayController.php` | `GatewayController.php` |
| Back Office Controller | `Zed/{Module}/Communication/Controller/{Name}Controller.php` | `MessageController.php` |
| Twig Template | `Zed/{Module}/Presentation/{Controller}/{action}.twig` | `Message/add.twig` |
| Client | `Client/{Module}/{Module}Client.php` | `HelloWorldClient.php` |
| Stub | `Client/{Module}/Stub/{Module}Stub.php` | `HelloWorldStub.php` |
| Transfer XML | `Shared/{Module}/Transfer/{module}.transfer.xml` | `helloworld.transfer.xml` |
| DependencyProvider | `{Layer}/{Module}/{Module}DependencyProvider.php` | `HelloWorldDependencyProvider.php` |
| Route Plugin | `Yves/{Module}/Plugin/Router/{Module}RouteProviderPlugin.php` | `HelloWorldPageRouteProviderPlugin.php` |
| Unit Test | `tests/{Ns}Test/Zed/{Module}/Business/{Class}Test.php` | `SupplierReaderTest.php` |
