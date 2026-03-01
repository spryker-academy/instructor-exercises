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

Open `src/SprykerAcademy/Zed/HelloWorld/Communication/Controller/GatewayController.php`. Complete `findMessageAction()` by finding a message through the Facade using the `MessageCriteriaTransfer`.

Clear cache:

```bash
docker/sdk console cache:empty-all
```

---

### 2. Build the Client

#### 2.1 Create a Stub for Calling BackendGateway

The Stub uses `ZedRequestClient` to call Zed from the Storefront.

**Coding time:**

Open `src/SprykerAcademy/Client/HelloWorld/Stub/HelloWorldStub.php`. In the `findMessage()` method, fill in the correct path to the GatewayController action.

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

Open `src/SprykerAcademy/Client/HelloWorld/HelloWorldDependencyProvider.php`. In the `addZedRequestClient()` method, make the `ZedRequestClient` available using the locator and the constant `CLIENT_ZED_REQUEST`.

#### 2.3 Instantiate the HelloWorldStub

Note the naming conventions: `create*()` for instantiation (using `new`), `get*()` for retrieving provided dependencies.

**Coding time:**

Open `src/SprykerAcademy/Client/HelloWorld/HelloWorldFactory.php`. In `createHelloWorldStub()`, instantiate and return a `HelloWorldStub` with the correct dependency injected.

#### 2.4 Create the Client (Internal API)

The `*Client` class is what gets provided to other clients, Yves, or Glue through their DependencyProviders.

**Coding time:**

Open `src/SprykerAcademy/Client/HelloWorld/HelloWorldClient.php`. Complete `findMessage()` by using the factory to create a `HelloWorldStub` and return the found message.

Update IDE auto-completion:

```bash
docker/sdk console dev:ide-auto-completion:generate
```

---

### 3. Build Yves

#### 3.1 DependencyProvider and Factory

Make the `HelloWorldClient` available in the Yves application layer.

**Coding time:**

Open `src/SprykerAcademy/Yves/HelloWorldPage/HelloWorldPageDependencyProvider.php`. In the `addHelloWorldClient()` method, make the `HelloWorldClient` available.

**Coding time:**

Open `src/SprykerAcademy/Yves/HelloWorldPage/HelloWorldPageFactory.php`. Complete `getHelloWorldClient()` by returning the provided dependency using `HelloWorldPageDependencyProvider::CLIENT_HELLOWORLD`.

#### 3.2 Controller

The template is already provided at `src/SprykerAcademy/Yves/HelloWorldPage/Theme/default/views/message/get.twig` and expects a variable named `message`.

**Coding time:**

Open `src/SprykerAcademy/Yves/HelloWorldPage/Controller/MessageController.php`. Complete `getAction()`:
1. Instantiate a `MessageCriteriaTransfer` and set the message ID from the route parameter
2. Use `getFactory()` to access the `HelloWorldClient`
3. Find a message by the criteria and assign the result to `$messageResponseTransfer`

#### 3.3 Routing

Unlike the Back Office, Yves requires explicit route definitions via a `*RouteProviderPlugin`.

**Coding time:**

Open `src/SprykerAcademy/Yves/HelloWorldPage/Plugin/Router/HelloWorldPageRouteProviderPlugin.php`. In `addHelloWorldMessageGetRoute()`, fill in the correct **module name** and **controller name** for the placeholders.

**Coding time:**

Open `src/SprykerAcademy/Yves/Router/RouterDependencyProvider.php`. Add an instance of `HelloWorldPageRouteProviderPlugin` at the end of the router plugins in `getRouteProvider()`.

---

## Testing

1. Create a message via Back Office: http://backoffice.eu.spryker.local/hello-world/message/add
2. View the message in Yves using its ID: http://yves.eu.spryker.local/hello-world/message/1

---

## Verify Your Work

Run the automated tests for this exercise:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise5
```

Or run all exercise tests at once:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/
```

All tests should pass if your implementation is correct.

---

## Solution

```bash
./exercises/load.sh hello-world basics/module-layers/complete
```
