# Exercise 4: Module Layers - Back Office Step

In this exercise, you will create a contact request through a Back Office controller and persist it in the database. You will learn how to work with the Persistence, Business, and Communication layers in Zed.

**Part 1 of 2** - This guide focuses on the Zed layer.

## Loading the Exercise

```bash
./exercises/load.sh contact-request basics/module-layers/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console propel:install
```

---

## Working on the Exercise

### 1. Create the Persistence Layer

#### 1.1 Add a ContactRequestCriteriaTransfer Definition

It is good practice to not use simple types directly for requesting data from the Persistence Layer. Instead, create a `*CriteriaTransfer`.

**Coding time:**

Open `src/SprykerAcademy/Shared/ContactRequest/Transfer/contact_request.transfer.xml` and add a DTO named **ContactRequestCriteria** with `strict="true"` and:
- Property `idContactRequest` of type `int`
- Property `message` of type `string`

> Every transfer in this module carries `strict="true"` so the generated accessors are natively
> typed - see [Exercise 2](02-data-transfer-object.md#11-always-add-stricttrue). It pays off right
> here: `getIdContactRequest(): ?int` means the Repository can branch on the criteria without
> wondering whether it holds an `int`, a numeric string or something else entirely.

Regenerate transfers:

```bash
docker/sdk console transfer:generate
```

#### 1.2 Create the Persistence Layer Factory

Query classes are auto-generated from Propel schema files. All ORM generated query classes have a static `create()` method.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Persistence/ContactRequestPersistenceFactory.php`. In the `createContactRequestQuery()` method, return an instance of `PyzContactRequestQuery`.

#### 1.3 Create the Repository

The Repository reads data. Use `getFactory()` to access the Persistence Factory (provided by `AbstractRepository`).

Key patterns:
- Propel query objects provide magic `findOneBy<ColumnName>()` methods for exact lookups
- For partial matching, use `filterBy<ColumnName>()` with `Criteria::LIKE` as the second parameter, then call `findOne()`. You will need to import `Propel\Runtime\ActiveQuery\Criteria`
- Convert entities to DTOs using the Mapper (available via the factory)

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Persistence/ContactRequestRepository.php`. In the `findContactRequest()` method:
1. Get the ContactRequest query from the factory
2. If the criteria has an `idContactRequest`, find by ID and return the result
3. If the criteria has a `message` string, use LIKE filtering to find a partial match and return only one result
4. Return `null` if no entity was found
5. Map the entity to a DTO using the ContactRequestMapper and return it

#### 1.4 Create the EntityManager

The EntityManager handles writes. Transform the DTO to an entity, save it, and transform it back.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Persistence/ContactRequestEntityManager.php`. In the `createContactRequest()` method:
1. Map the DTO to an entity using the ContactRequestMapper
2. Call `$contactRequestEntity->save()`
3. Map the entity back to a DTO and return it

---

### 2. Build the Business Logic

#### 2.1 Add ContactRequestResponseTransfer Definition

Wrap the DTO in a `*ResponseTransfer` to include success/error information.

**Coding time:**

Open `src/SprykerAcademy/Shared/ContactRequest/Transfer/contact_request.transfer.xml` and add a DTO named **ContactRequestResponse** with `strict="true"` and:
- Property `contactRequest` of type `ContactRequest`
- Property `isSuccessful` of type `bool`

Strict mode gives you `getContactRequest(): ?ContactRequestTransfer` and
`getContactRequestOrFail(): ContactRequestTransfer`. Use the second one once `isSuccessful` told
you the request was found - it throws a clear `NullValueException` instead of handing you a null
that fails somewhere in a template.

Regenerate:

```bash
docker/sdk console transfer:generate
```

#### 2.2 The Writer

Separate reading from writing. The Writer uses the EntityManager.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Business/Writer/ContactRequestWriter.php`:
- Inject `ContactRequestEntityManagerInterface` through the constructor
- In the `create()` method, use the EntityManager to create and return the contact request

#### 2.3 The Reader

The Reader uses the Repository and prepares the response.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Business/Reader/ContactRequestReader.php`:
- Inject `ContactRequestRepositoryInterface` through the constructor
- In the `findContactRequest()` method, use the Repository to find a contact request by criteria
- Create a `ContactRequestResponseTransfer` and set `contactRequest` and `isSuccessful` based on the result
- Return the response

#### 2.4 Expose Functionality through the Facade

The Facade is the module's public API. Since Spryker 202602.0, you can use `$this->getService(ClassName::class)` directly in the Facade instead of going through a Business Factory. Spryker's DI container automatically wires the dependencies of the service class.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Business/ContactRequestFacade.php`. Implement `createContactRequest()` and `findContactRequest()` by delegating to the `ContactRequestWriter` and `ContactRequestReader` services through `$this->getService(ClassName::class)`.

**Hint:** The Writer returns a `ContactRequestTransfer`; the Reader returns a `ContactRequestResponseTransfer`. No Business Factory is needed — the container injects `ContactRequestEntityManagerInterface` into the Writer and `ContactRequestRepositoryInterface` into the Reader automatically.

`ContactRequestFacadeTest` checks this step: it mocks the Writer and the Reader and asserts the Facade hands their result back, so leaving either method empty fails the suite.

---

### 3. Visual in the Back Office

#### 3.1 Controller for the Back Office

Since Spryker 202602.0, controllers support **constructor dependency injection**. You can inject the Facade directly instead of using `$this->getFacade()`.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Communication/Controller/IndexController.php`. The facade is already injected via the constructor — use `$this->contactRequestFacade`. Complete `addAction()`:
1. Instantiate `ContactRequestCriteriaTransfer` and set the message from the query parameter
2. Call `$this->contactRequestFacade->findContactRequest()` to look it up
3. If not found, create a new `ContactRequestTransfer` with the message and persist it via `$this->contactRequestFacade->createContactRequest()`

#### 3.2 Template for the Back Office

The controller passes `contactRequest` (a `ContactRequestTransfer`) to the template. Access object properties with dot notation: `objectName.objectProperty`.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Presentation/Index/add.twig`. Replace the placeholder `'show-contact-request-message-here'` with the message of the contact request using dot notation (`contactRequest.message`).

`AddTemplateTest` checks this step, and `IndexControllerAddActionTest` checks the controller above it.

Clear cache:

```bash
docker/sdk console cache:empty-all
docker/sdk console propel:model:build
```

Visit: http://backoffice.eu.spryker.local/contact-request/index/add
Use query parameter `?message=YourName` to create a contact request with a custom message.

---

## Verify Your Work

Run the automated tests for this exercise:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise4
```

This tests the ContactRequestReader, the ContactRequestWriter, the ContactRequestFacade, `addAction()` on the IndexController and the `add.twig` template. All tests should pass if your implementation is correct.

---

## Solution

```bash
./exercises/load.sh contact-request basics/module-layers/complete
```
