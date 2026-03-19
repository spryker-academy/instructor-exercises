# Exercise 4: Module Layers - Back Office Step

In this exercise, you will create a message through a Back Office controller and persist it in the database. You will learn how to work with the Persistence, Business, and Communication layers in Zed.

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

Open `src/SprykerAcademy/Shared/ContactRequest/Transfer/contact_request.transfer.xml` and add a DTO named **ContactRequestCriteria** with:
- Property `idContactRequest` of type `int`
- Property `message` of type `string`

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
1. Get the message query from the factory
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

Open `src/SprykerAcademy/Shared/ContactRequest/Transfer/contact_request.transfer.xml` and add a DTO named **ContactRequestResponse** with:
- Property `message` of type `Message`
- Property `isSuccessful` of type `bool`

Regenerate:

```bash
docker/sdk console transfer:generate
```

#### 2.2 The Writer

Separate reading from writing. The Writer uses the EntityManager.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Business/Writer/ContactRequestWriter.php`:
- Inject `ContactRequestEntityManagerInterface` through the constructor
- In the `create()` method, use the EntityManager to create and return the message

#### 2.3 The Reader

The Reader uses the Repository and prepares the response.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Business/Reader/ContactRequestReader.php`:
- Inject `ContactRequestRepositoryInterface` through the constructor
- In the `findContactRequest()` method, use the Repository to find a message by criteria
- Create a `ContactRequestResponseTransfer` and set `message` and `isSuccessful` based on the result
- Return the response

#### 2.4 Instantiate Business Models

Each layer has its own Factory. The Business Factory can access `getEntityManager()` and `getRepository()`.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Business/ContactRequestBusinessFactory.php`. Instantiate `ContactRequestWriter` and `ContactRequestReader` with their dependencies.

#### 2.5 Expose Functionality through the Facade

The Facade is the module's public API. Use `getFactory()` to access the Business Factory.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Business/ContactRequestFacade.php`. Implement `createContactRequest()` and `findContactRequest()` using the factory's writer and reader.

---

### 3. Visual in the Back Office

#### 3.1 Controller for the Back Office

The controller uses the `message` query parameter for simplicity. Use `getFacade()` to access the module's Facade.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Communication/Controller/IndexController.php`. Complete `addAction()`:
1. Instantiate `ContactRequestCriteriaTransfer` and set the message name from the query parameter
2. Use the Facade to find the message
3. If no message is found, create a new `ContactRequestTransfer` with the name and use the Facade to create it

#### 3.2 Template for the Back Office

The controller passes `message` (a `ContactRequestTransfer`) to the template. Access object properties with dot notation: `objectName.objectProperty`.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Presentation/Index/add.twig`. Replace the placeholder `'show-message-name-here'` with the actual message value using dot notation (`message.message`).

Clear cache:

```bash
docker/sdk console cache:empty-all
```

Visit: http://backoffice.eu.spryker.local/contact-request/index/add
Use query parameter `?message=YourName` to create a contact request with a custom message.

---

## Verify Your Work

Run the automated tests for this exercise:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise4
```

This tests the ContactRequestReader and ContactRequestWriter business logic. All tests should pass if your implementation is correct.

---

## Solution

```bash
./exercises/load.sh contact-request basics/module-layers/complete
```
