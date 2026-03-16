# Exercise 5: Module Layers - Storefront Step

In this exercise, you will display a persisted message in Yves (the Storefront). You will learn how to communicate between Yves and Zed using the Client layer and the BackendGateway.

**Part 2 of 2** - This guide focuses on showing the message in Yves.

## Prerequisites

- You must have completed [Exercise 4: Module Layers - Back Office Step](04-module-layers-back-office.md)

We continue on the code from Part 1.

---

## Working on the Exercise

### 1. Expose Message to Storefronts

#### 1.1 GatewayController for Communication with Yves

The `GatewayController` exposes an endpoint from Zed to Yves via the BackendGateway.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Communication/Controller/GatewayController.php`. Complete `findContactRequestAction()` by finding a message through the Facade using the `ContactRequestCriteriaTransfer`.

Clear cache:

```bash
docker/sdk console cache:empty-all
```

---

### 2. Build the Client

#### 2.1 Create a Stub for Calling BackendGateway

The Stub uses `ZedRequestClient` to call Zed from the Storefront.

**Coding time:**

Open `src/SprykerAcademy/Client/ContactRequest/Stub/ContactRequestStub.php`. In the `findContactRequest()` method, fill in the correct path to the GatewayController action.

The DTO is serialized on one side and deserialized on the other side of the request.

#### 2.2 Provide ZedRequestClient as a Dependency

Every external dependency must be provided through the DependencyProvider. The pattern:

```php
protected function addStoreClient(Container $container)
{
    $container->set(static::CLIENT_STORE, function (Container $container) {
        return $container->getLocator()->store()->client();
    });

    return $container;
}
```

The locator works as: `$container->getLocator()-><moduleName>()-><what>()`.

**Coding time:**

Open `src/SprykerAcademy/Client/ContactRequest/ContactRequestDependencyProvider.php`. In the `addZedRequestClient()` method, make the `ZedRequestClient` available using the locator and the constant `CLIENT_ZED_REQUEST`.

#### 2.3 Instantiate the ContactRequestStub

Note the naming conventions: `create*()` for instantiation (using `new`), `get*()` for retrieving provided dependencies.

**Coding time:**

Open `src/SprykerAcademy/Client/ContactRequest/ContactRequestFactory.php`. In `createContactRequestStub()`, instantiate and return a `ContactRequestStub` with the correct dependency injected.

#### 2.4 Create the Client (Internal API)

The `*Client` class is what gets provided to other clients, Yves, or Glue through their DependencyProviders.

**Coding time:**

Open `src/SprykerAcademy/Client/ContactRequest/ContactRequestClient.php`. Complete `findContactRequest()` by using the factory to create a `ContactRequestStub` and return the found message.

Update IDE auto-completion:

```bash
docker/sdk console dev:ide-auto-completion:generate
```

---

### 3. Build Yves

#### 3.1 DependencyProvider and Factory

Make the `ContactRequestClient` available in the Yves application layer.

**Coding time:**

Open `src/SprykerAcademy/Yves/ContactRequestPage/ContactRequestPageDependencyProvider.php`. In the `addContactRequestClient()` method, make the `ContactRequestClient` available.

**Coding time:**

Open `src/SprykerAcademy/Yves/ContactRequestPage/ContactRequestPageFactory.php`. Complete `getContactRequestClient()` by returning the provided dependency using `ContactRequestPageDependencyProvider::CLIENT_HELLOWORLD`.

#### 3.2 Controller

The template is already provided at `src/SprykerAcademy/Yves/ContactRequestPage/Theme/default/views/message/get.twig` and expects a variable named `message`.

**Coding time:**

Open `src/SprykerAcademy/Yves/ContactRequestPage/Controller/ContactRequestController.php`. Complete `getAction()`:
1. Instantiate a `ContactRequestCriteriaTransfer` and set the message ID from the route parameter
2. Use `getFactory()` to access the `ContactRequestClient`
3. Find a message by the criteria and assign the result to `$contactRequestResponseTransfer`

#### 3.3 Routing

Unlike the Back Office, Yves requires explicit route definitions via a `*RouteProviderPlugin`.

**Coding time:**

Open `src/SprykerAcademy/Yves/ContactRequestPage/Plugin/Router/ContactRequestPageRouteProviderPlugin.php`. In `addContactRequestMessageGetRoute()`, fill in the correct **module name** and **controller name** for the placeholders.

**Coding time:**

Open `src/SprykerAcademy/Yves/Router/RouterDependencyProvider.php`. Add an instance of `ContactRequestPageRouteProviderPlugin` at the end of the router plugins in `getRouteProvider()`.

---

## Testing

1. Create a message via Back Office: http://backoffice.eu.spryker.local/contact-request/message/add
2. View the message in Yves using its ID: http://yves.eu.spryker.local/contact-request/message/1

---

## Verify Your Work

Run the automated tests for this exercise:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise5
```

Or run all exercise tests at once:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/
```

All tests should pass if your implementation is correct.

---

## Solution

```bash
./exercises/load.sh contact-request basics/module-layers/complete
```
