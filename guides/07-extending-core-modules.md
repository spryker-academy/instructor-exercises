# Exercise 7: Extending Core Modules - Customer Messages

In this exercise, you will extend Spryker's out-of-the-box `CustomerPage` module to show a list of messages belonging to the logged-in customer and allow them to add new messages through a form.

You will learn how to:
- Modify an existing database schema to add a foreign key
- Update transfer definitions with new properties
- Extend the GatewayController and Client layer for new Yves-Zed communication
- Extend a Spryker core Yves module (CustomerPage) at project level
- Work with Symfony forms in Spryker Yves

## Prerequisites

- You must have completed Exercises 1-5 (Module Layers)
- Understanding of the Client/Stub pattern for Yves-Zed communication

## Loading the Exercise

```bash
./exercises/load.sh hello-world basics/extending-core-modules/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console propel:install
```

---

## Working on the Exercise

### Part 1: Adjust the Database Schema

Currently the `pyz_message` table stores messages without any link to who created them. We need to add a foreign key to the `spy_customer` table so each message can belong to a customer.

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Persistence/Propel/Schema/pyz_message.schema.xml` and:
1. Add a new column `fk_customer` of type `INTEGER` (not required, since existing messages have no customer)
2. Add a `<foreign-key>` element that references the `spy_customer` table, mapping `fk_customer` to `id_customer` with `onDelete="CASCADE"`

After modifying the schema, run:

```bash
docker/sdk console propel:install
```

This will update the database and regenerate the ORM classes with the new column.

---

### Part 2: Update Transfer Definitions

We need to make the new `fkCustomer` field available in our DTOs and also create a new transfer for collections of messages.

**Coding time:**

Open `src/SprykerAcademy/Shared/HelloWorld/Transfer/helloworld.transfer.xml` and:
1. Add a `fkCustomer` property of type `int` to the **Message** transfer
2. Add a `fkCustomer` property of type `int` to the **MessageCriteria** transfer
3. Add a new transfer named **MessageCollection** with a property `messages` of type `Message[]`

Regenerate transfers:

```bash
docker/sdk console transfer:generate
```

---

### Part 3: Update Persistence and Business Layers

#### 3.1 Add a Repository Method

We need a way to fetch all messages belonging to a specific customer.

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Persistence/HelloWorldRepository.php`. Implement `findMessagesByCustomer()`:
1. Get the message query from the factory
2. Filter by `fk_customer` if the criteria has a `fkCustomer` set
3. Execute the query with `find()` to get all matching entities
4. Map each entity to a `MessageTransfer` using the MessageMapper
5. Return the array of `MessageTransfer` objects

Propel provides a `filterByFkCustomer()` magic method on the query object.

#### 3.2 Update the MessageReader

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Business/Reader/MessageReader.php`. Implement `findMessagesByCustomer()`:
- Use the repository to get the messages
- Create a `MessageCollectionTransfer` and add each message to it

#### 3.3 Expose Through the Facade

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Business/HelloWorldFacade.php`. Implement `findMessagesByCustomer()` by delegating to the factory's MessageReader.

---

### Part 4: Expose via GatewayController

We need two new gateway actions: one to create messages from Yves and one to get messages by customer.

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Communication/Controller/GatewayController.php`:
1. In `createMessageAction()`, use the Facade to create and return the message
2. In `getMessagesByCustomerAction()`, use the Facade to find messages by customer and return the collection

Clear cache after adding new controller actions:

```bash
docker/sdk console cache:empty-all
```

---

### Part 5: Build the Client

#### 5.1 Update the Stub

**Coding time:**

Open `src/SprykerAcademy/Client/HelloWorld/Stub/HelloWorldStub.php`:
1. In `createMessage()`, use `$this->zedRequestClient->call()` with the path `/hello-world/gateway/create-message`
2. In `getMessagesByCustomer()`, use `$this->zedRequestClient->call()` with the path `/hello-world/gateway/get-messages-by-customer`

Remember: the gateway path format is `/module-name/gateway/action-name` where the action name is the method name without the `Action` suffix, converted to kebab-case.

#### 5.2 Update the Client

**Coding time:**

Open `src/SprykerAcademy/Client/HelloWorld/HelloWorldClient.php`:
1. In `createMessage()`, delegate to the HelloWorldStub via the factory
2. In `getMessagesByCustomer()`, delegate to the HelloWorldStub via the factory

Update IDE auto-completion:

```bash
docker/sdk console dev:ide-auto-completion:generate
```

---

### Part 6: Extend the CustomerPage Module

Now we extend Spryker's core `CustomerPage` module to add our message functionality. This is the key part of the exercise that demonstrates how to extend core Spryker modules at project level.

The pattern: extend the core class in your project namespace, and override or add the methods you need.

#### 6.1 DependencyProvider

We need to inject our `HelloWorldClient` into the extended `CustomerPage` module.

**Coding time:**

Open `src/SprykerAcademy/Yves/CustomerPage/CustomerPageDependencyProvider.php`. In `addHelloWorldClient()`, use `$container->set()` with the `CLIENT_HELLO_WORLD` constant to provide the `HelloWorldClient` through the locator.

The locator pattern: `$container->getLocator()->helloWorld()->client()`.

#### 6.2 Factory

**Coding time:**

Open `src/SprykerAcademy/Yves/CustomerPage/CustomerPageFactory.php`:
1. In `getHelloWorldClient()`, return the provided dependency using the `CLIENT_HELLO_WORLD` constant
2. In `createMessageForm()`, use `$this->getFormFactory()->create()` to instantiate and return the `MessageForm`

#### 6.3 MessageForm

This is a standard Symfony form with a text field for the message.

**Coding time:**

Open `src/SprykerAcademy/Yves/CustomerPage/Form/MessageForm.php`:
1. In `addMessageField()`, add a `TextType` field using the `FIELD_MESSAGE` constant, with a label and a `NotBlank` constraint
2. In `addSubmitButton()`, add a `SubmitType` button with label "Add Message"

#### 6.4 MessageController

The controller handles both listing messages and creating new ones. It extends `AbstractCustomerController` from SprykerShop which provides `getLoggedInCustomerTransfer()`.

**Coding time:**

Open `src/SprykerAcademy/Yves/CustomerPage/Controller/MessageController.php`:

In `listAction()`:
1. Get the logged-in customer using `$this->getLoggedInCustomerTransfer()`
2. Create a `MessageCriteriaTransfer` and set the `fkCustomer` from the customer's ID
3. Fetch messages using the `HelloWorldClient` through the factory
4. Create the message form and handle the request
5. If the form is submitted and valid, call `handleMessageFormSubmit()`
6. Return a view with the `messages` and `messageForm` variables, using the template `@CustomerPage/views/message/list.twig`

In `handleMessageFormSubmit()`:
1. Get the form data and create a `MessageTransfer` with the message text and customer ID
2. Use the `HelloWorldClient` to create the message
3. Redirect back to the messages list

#### 6.5 Route Provider Plugin

**Coding time:**

Open `src/SprykerAcademy/Yves/CustomerPage/Plugin/Router/CustomerPageRouteProviderPlugin.php`. In `addCustomerMessagesRoute()`:
1. Build a route for `/customer/messages` pointing to the `CustomerPage` module, `Message` controller, `listAction`
2. Set allowed methods to `GET` and `POST` (GET for viewing, POST for form submission)
3. Add the route to the collection

#### 6.6 Provided Scaffolding (no coding needed)

The following files are already provided by the exercise skeleton:

- **`src/Pyz/Yves/Router/RouterDependencyProvider.php`** — Replaces the core `CustomerPageRouteProviderPlugin` with your extended version. This ensures your new `/customer/messages` route is registered.
- **`src/Pyz/Yves/CustomerPage/Theme/.../customer-navigation/customer-navigation.twig`** — Adds a "My Messages" link to the customer account sidebar menu.
- **`src/SprykerAcademy/Yves/CustomerPage/Theme/.../views/message/list.twig`** — The Twig template for the messages page, showing a table of messages and the form.

Take a moment to review these files so you understand how Spryker's template override mechanism and route registration work.

Clear cache:

```bash
docker/sdk console cache:empty-all
```

---

## Testing

1. Log in to Yves: http://yves.eu.spryker.local/en/login (use `sonia@spryker.com` / `change123`)
2. Visit: http://yves.eu.spryker.local/en/customer/messages
3. You should see a message list (empty initially) and a form to add messages
4. Add a message and verify it appears in the list

---

## Verify Your Work

Run the automated tests for this exercise:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise7
```

Or run all exercise tests at once:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/
```

All tests should pass if your implementation is correct.

---

## Solution

```bash
./exercises/load.sh hello-world basics/extending-core-modules/complete
```
