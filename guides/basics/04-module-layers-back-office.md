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

#### 2.5 Register the Interface Bindings

`config/Zed/ApplicationServices.php` loads every class of every project module into Symfony's DI container with autowiring switched on. That is what fills the Writer and the Reader without a Business Factory. Ask the container what it decided:

```bash
docker/sdk cli vendor/bin/console debug:container ContactRequestReader --show-arguments
```

```
Service ID   SprykerAcademy\Zed\ContactRequest\Business\Reader\ContactRequestReader
Arguments    Service(SprykerAcademy\Zed\ContactRequest\Persistence\ContactRequestRepository)
```

Your constructor asked for `ContactRequestRepositoryInterface` and the container answered with `ContactRequestRepository`. It can do that only while exactly one class implements the interface: autowiring matches a service by its class **and** by the interfaces that class implements. Add a second implementation - a caching repository, an archive repository, whatever - and there are two candidates and no rule for choosing.

State the binding instead of relying on there being only one. Open `config/Zed/ApplicationServices.php` and add the imports at the top, next to the existing `use` statements:

```php
use SprykerAcademy\Zed\ContactRequest\Persistence\ContactRequestEntityManager;
use SprykerAcademy\Zed\ContactRequest\Persistence\ContactRequestEntityManagerInterface;
use SprykerAcademy\Zed\ContactRequest\Persistence\ContactRequestRepository;
use SprykerAcademy\Zed\ContactRequest\Persistence\ContactRequestRepositoryInterface;
```

and the two bindings at the end of the returned closure, after the loop that loads the project modules:

```php
    $services->set(ContactRequestRepositoryInterface::class, ContactRequestRepository::class);
    $services->set(ContactRequestEntityManagerInterface::class, ContactRequestEntityManager::class);
};
```

`$services` already carries `->autowire()->public()->autoconfigure()` from the `defaults()` block at the top of the file, so each class you bind still gets its own constructor arguments injected.

```bash
docker/sdk console cache:empty-all
docker/sdk console propel:install
```

Ask the container again. The interface is a service of its own now, and it resolves to the class you picked:

```
docker/sdk cli vendor/bin/console debug:container ContactRequestRepositoryInterface

Service ID   SprykerAcademy\Zed\ContactRequest\Persistence\ContactRequestRepositoryInterface
Class        SprykerAcademy\Zed\ContactRequest\Persistence\ContactRequestRepository
```

`docker/sdk cli vendor/bin/console lint:container` answers *The container was linted successfully* when every argument still resolves. Do the same for every interface you inject through a constructor from now on.

> **Zed only.** `config/Yves/ApplicationServices.php` is an empty stub in the demo shop, so nothing of yours is in the Yves container - Yves keeps using the Factory and the DependencyProvider, which is what Exercise 5 builds.

> **When the container cannot find your class at all.** `Expected to find class "SprykerAcademy\..." in file "..." while importing services from resource "...", but it was not found! Check the namespace prefix used with the resource in config/Zed/ApplicationServices.php` is not a namespace-prefix problem, whatever it says. It means PHP cannot autoload the class: `SprykerAcademy` is missing from `vendor/composer/autoload_psr4.php`. Run `docker/sdk cli composer dump-autoload` and check with `grep SprykerAcademy vendor/composer/autoload_psr4.php`.

#### 2.6 What You Can Type-Hint, and What You Cannot

Two different mechanisms fill the Zed container, and they cover different things.

`config/Zed/ApplicationServices.php` loads **project modules only** - every class under
`src/SprykerAcademy/<App>/<Module>/` becomes a service. That is why your Reader, Writer,
Repository and EntityManager are injectable at all.

Core modules are never scanned by that file. Instead a Symfony compiler pass
(`Spryker\Service\Container\Pass\SprykerDefaultsPass`, added in
`Spryker\Shared\Application\Kernel::build()`) walks **every** module the module finder sees, core
included, and registers each module's conventional entry points:

| You can type-hint | Example |
|---|---|
| a Zed facade, **by its interface** | `Spryker\Zed\Configuration\Business\ConfigurationFacadeInterface` |
| a client, **by its interface** | `Spryker\Client\Storage\StorageClientInterface` |
| a service, **by its interface** | `Spryker\Service\UtilEncoding\UtilEncodingServiceInterface` |
| a module config, by its class | `Spryker\Zed\Customer\CustomerConfig` |

| You cannot type-hint | Why |
|---|---|
| a **core** factory, repository, entity manager, reader, mapper | not a conventional entry point - `debug:container Business\CustomerBusinessFactory` answers *No services found* |
| a facade by its **concrete** class | the registered id is the interface; `ConfigurationFacade` is not a service |

Check any of it yourself - `debug:container` takes a fragment of the name:

```bash
docker/sdk cli vendor/bin/console debug:container 'Spryker\Zed\Configuration'
```

The whole core `Configuration` module contributes exactly two services, the facade interface and the
module config. Nothing behind the front door is reachable, which is the point: a module's internals
stay its own business.

> **You never bypass the class resolver.** The pass looks for a project override before the core
> class, so type-hinting the core name gives you the project class when one exists. On this shop
> `Spryker\Zed\Customer\CustomerConfig` resolves to `Class Pyz\Zed\Customer\CustomerConfig`.

Your own modules are the generous case: because `ApplicationServices.php` loads the whole directory,
even `ContactRequestPersistenceFactory` is a service. Injecting a factory still goes around Spryker's
pattern - the kernel creates factories and you reach dependencies through them - so do not, just
because you can.

#### 2.7 Clearing the Container Cache

The compiled container is generated PHP under `data/cache/<Application>/<environment>/Container*/`.
When a constructor change, a new service or a new `$services->set()` line seems to have no effect,
that directory is the first suspect.

```bash
docker/sdk console cache:clear
```

That is Symfony's own command, and it is the one that rebuilds the container.

> **`cache:empty-all` is not the command for this.** It clears `data/cache` broadly - the Propel
> table map, the configuration schema, generated Twig and navigation - but leaves the compiled
> container in place. Running it and seeing no change is what sends people looking for a bug in
> their code that is not there. It also means you have to run `propel:install` afterwards to get
> the table map back.

If the container is broken badly enough that the console itself will not boot, no command can help
you. Delete the directory and rebuild it:

```bash
rm -rf data/cache/Zed
docker/sdk console container:build
```

`container:build` compiles the container explicitly and answers *Container built successfully*.
Use `data/cache/Yves`, `data/cache/GlueStorefront` and so on for the other applications.

---

### 3. Visual in the Back Office

#### 3.1 Controller for the Back Office

Since Spryker 202602.0, controllers support **constructor dependency injection**. You can inject the Facade directly instead of using `$this->getFacade()`.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Communication/Controller/IndexController.php`. The facade is already injected via the constructor — use `$this->contactRequestFacade`. Complete `addAction()`:
1. Instantiate `ContactRequestCriteriaTransfer` and set the message from the query parameter
2. Call `$this->contactRequestFacade->findContactRequest()` to look it up
3. If not found, create a new `ContactRequestTransfer` with the message and persist it via `$this->contactRequestFacade->createContactRequest()`

##### When the page says "Too few arguments"

```
ArgumentCountError: Too few arguments to function
SprykerAcademy\Zed\ContactRequest\Communication\Controller\IndexController::__construct(),
0 passed and exactly 1 expected
```

Your constructor is fine. Read what Spryker does with a Zed route, in
`Spryker\Shared\Router\Resolver\ControllerResolver::getControllerFromArray()`:

```php
if ($container && is_string($controller[0]) && $container->has($controller[0])) {
    $controllerInstance = $container->get($controller[0]);   // your constructor runs here
}
...
$controllerInstance = new $controller[0]();                  // fallback: no arguments
```

A Zed route carries `_controller => [IndexController::class, 'indexAction']`. The resolver asks the
container for that class; if the container does not have it, it falls back to `new` with no
arguments, and a constructor that expects a facade gets nothing. **The message is always about the
container, never about your constructor.** Ask the container whether it knows your controller:

```bash
docker/sdk cli vendor/bin/console debug:container ContactRequest
```

If the controller is missing from that list, it is one of these, in order of likelihood:

1. **The autoloader is stale.** `$services->load()` cannot register a class PHP cannot autoload.
   `docker/sdk cli composer dump-autoload`, then `grep SprykerAcademy vendor/composer/autoload_psr4.php`.
2. **The compiled container is stale** - you added the constructor after it was built.
   `docker/sdk console cache:clear`, and see *Clearing the container cache* below. Note that
   `cache:empty-all` does **not** help here; it leaves the compiled container untouched.
3. **The class is not where the module finder looks.** It has to be
   `src/SprykerAcademy/Zed/<Module>/Communication/Controller/<Name>Controller.php` - the container is
   built by walking that structure, so a controller one directory off is invisible to it.
4. **The module is excluded** in `$excludedModuleConfiguration` at the top of
   `config/Zed/ApplicationServices.php`.

If you are stuck and want to keep moving, `$this->getFacade()` still works in any Zed controller: it
goes through Spryker's class resolver instead of the container, so it does not care whether the
controller is a service. Constructor injection is the newer, nicer way, not the only way.

> **In Yves there is no fix for this.** `config/Yves/ApplicationServices.php` is an empty stub, so no
> project class is ever in the Yves container and a Yves controller is never a service - a constructor
> with arguments there throws this error every time, no matter what you clear. Yves uses the Factory
> and the DependencyProvider, which is what [Exercise 5](05-module-layers-storefront.md) builds.

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

Every step of this exercise is covered: the two transfer definitions, the Persistence Factory, the Repository (including the `Criteria::LIKE` partial match), the EntityManager, the Writer, the Reader, the Facade, `addAction()` and `add.twig`. All tests should pass if your implementation is correct.

---

## Solution

```bash
./exercises/load.sh contact-request basics/module-layers/complete
```
