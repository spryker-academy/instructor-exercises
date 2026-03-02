# Exercise 7: Extending Core Modules - Customer Messages

In this exercise, you will extend Spryker's out-of-the-box `CustomerPage` module to show a list of messages belonging to the logged-in customer, allow them to add new messages through a form, and delete existing ones.

You will learn how to:
- Modify an existing database schema (foreign keys, timestampable behavior)
- Update transfer definitions with new properties and collection types
- Apply SOLID principles: separate Reader, Writer, and Deleter classes
- Extend the GatewayController and Client layer for new Yves-Zed communication
- Extend a Spryker core Yves module (CustomerPage) at project level
- Work with Symfony forms backed by Transfer objects in Spryker Yves
- Use Spryker's AJAX component pattern for dynamic page updates (bonus)

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

Currently the `pyz_message` table stores messages without any link to who created them. We need to add a foreign key to the `spy_customer` table so each message can belong to a customer. We also add the `timestampable` behavior so Propel automatically manages `created_at` and `updated_at` columns.

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Persistence/Propel/Schema/pyz_message.schema.xml` and:
1. Add a new column `fk_customer` of type `INTEGER` (not required, since existing messages have no customer)
2. Add a `<foreign-key>` element that references the `spy_customer` table, mapping `fk_customer` to `id_customer` with `onDelete="CASCADE"`
3. Add `<behavior name="timestampable"/>` — Propel will auto-add `created_at` and `updated_at` TIMESTAMP columns

After modifying the schema, run:

```bash
docker/sdk console propel:install
```

This will generate a migration, update the database, and regenerate the ORM classes.

---

### Part 2: Update Transfer Definitions

We need to make the new `fkCustomer` and `createdAt` fields available in our DTOs, and also create a new transfer for collections of messages.

**Coding time:**

Open `src/SprykerAcademy/Shared/HelloWorld/Transfer/helloworld.transfer.xml` and:
1. Add a `fkCustomer` property of type `int` to the **Message** transfer
2. Add a `createdAt` property of type `string` to the **Message** transfer
3. Add a `fkCustomer` property of type `int` to the **MessageCriteria** transfer
4. Add a new transfer named **MessageCollection** with a property `messages` of type `Message[]`

Regenerate transfers:

```bash
docker/sdk console transfer:generate
```

> **Note:** The generated `MessageCollectionTransfer` will have an `addMessages()` method (plural, matching the property name). This is a Spryker convention — the adder method name matches the property name.

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

Propel provides magic `filterBy<ColumnName>()` methods on query objects.

#### 3.2 Update the MessageReader

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Business/Reader/MessageReader.php`. Implement `findMessagesByCustomer()`:
- Use the repository to get the messages
- Create a `MessageCollectionTransfer` and add each message to it using `addMessages()`

#### 3.3 Expose Through the Facade

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Business/HelloWorldFacade.php`. Implement `findMessagesByCustomer()` by delegating to the factory's MessageReader.

---

### Part 4: Expose via GatewayController

We need three new gateway actions: create, get by customer, and delete.

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Communication/Controller/GatewayController.php`:
1. In `createMessageAction()`, use the Facade to create and return the message
2. In `getMessagesByCustomerAction()`, use the Facade to find messages by customer and return the collection
3. In `deleteMessageAction()`, use the Facade to delete by ID and return a `MessageResponseTransfer` with the `isSuccessful` flag

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
2. In `getMessagesByCustomer()`, use the path `/hello-world/gateway/get-messages-by-customer`
3. In `deleteMessage()`, use the path `/hello-world/gateway/delete-message`

> **Gateway path convention:** `/module-name/gateway/action-name` where the action name is the controller method without the `Action` suffix, converted to kebab-case. For example, `deleteMessageAction()` becomes `/hello-world/gateway/delete-message`.

#### 5.2 Update the Client

**Coding time:**

Open `src/SprykerAcademy/Client/HelloWorld/HelloWorldClient.php`:
1. In `createMessage()`, delegate to the HelloWorldStub via the factory
2. In `getMessagesByCustomer()`, delegate to the HelloWorldStub via the factory
3. In `deleteMessage()`, delegate to the HelloWorldStub via the factory

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
2. In `createMessageForm()`, use the Spryker form factory chain to instantiate the form:
   ```php
   $this->createCustomerFormFactory()->getFormFactory()->create(MessageForm::class, $messageTransfer)
   ```

> **How Spryker forms work:** Spryker Yves doesn't expose Symfony's `FormFactory` directly on the module factory. Instead, each module that uses forms has a proxy `FormFactory` class (e.g., `SprykerShop\Yves\CustomerPage\Form\FormFactory`) that extends `AbstractFactory` and provides `getFormFactory()` through the application container. The chain is: `CustomerPageFactory::createCustomerFormFactory()` -> `FormFactory::getFormFactory()` -> Symfony's `FormFactory::create()`.

> **Data-mapped forms:** Notice we pass `$messageTransfer` as the second argument to `create()`. This tells Symfony to bind the form directly to the transfer object. When the form is submitted, `$form->getData()` returns the hydrated `MessageTransfer` directly — no manual field mapping needed.

#### 6.3 MessageForm

This is a standard Symfony form with a text field for the message.

**Coding time:**

Open `src/SprykerAcademy/Yves/CustomerPage/Form/MessageForm.php`. In `addMessageField()`, add a `TextType` field using the `FIELD_MESSAGE` constant, with a label and a `NotBlank` constraint.

> **Symfony form + Spryker transfers:** Spryker transfer objects implement `ArrayAccess`, so Symfony's `PropertyAccessor` can read/write properties by name. When the form field name matches a transfer property (e.g., `message` maps to `getMessage()`/`setMessage()`), data binding works automatically. No need for `configureOptions()` with `data_class` — though adding it would be more explicit.

> **No SubmitType in the form class:** The submit button is rendered directly in the Twig template with Spryker's button CSS classes. This keeps the form class focused on data fields and validation, and gives the template full control over button styling.

#### 6.4 MessageController

The controller handles listing messages, creating new ones, and deleting. It extends `AbstractCustomerController` from SprykerShop which provides `getLoggedInCustomerTransfer()`.

**Coding time:**

Open `src/SprykerAcademy/Yves/CustomerPage/Controller/MessageController.php`:

In `listAction()`:
1. Get the logged-in customer using `$this->getLoggedInCustomerTransfer()`
2. Create a `MessageCriteriaTransfer` and set the `fkCustomer` using `setFkCustomerOrFail()` for strict validation
3. Fetch messages using the `HelloWorldClient` through the factory
4. Create the message form with `$this->getFactory()->createMessageForm(new MessageTransfer())` — pass a fresh transfer as the data object
5. Handle the request with `$messageForm->handleRequest($request)`
6. If the form is submitted and valid, get the hydrated transfer with `$messageForm->getData()`, set the `fkCustomer`, and create the message
7. Return a view with the `messages` and `messageForm` variables, using the template `@CustomerPage/views/message/list.twig`

In `deleteAction()`:
1. Use `$this->castId($request->request->get('idMessage'))` to safely extract and validate the message ID
2. Create a `MessageCriteriaTransfer`, set the `idMessage`, and call `deleteMessage()` on the client
3. Redirect back to the messages list

> **`castId()` pattern:** Spryker's Zed `AbstractController` provides `castId()` which validates that an ID is numeric and non-zero, throwing an exception otherwise. Since this method isn't available in Yves controllers, we add a `protected castId()` method following the same pattern. This prevents silently passing `0` or non-numeric values to the persistence layer.

> **`setFkCustomerOrFail()` vs `setFkCustomer()`:** The `OrFail` variant throws an exception if the value is null. Use it when the value is required for the operation to make sense — it fails fast with a clear error instead of silently proceeding with null.

#### 6.5 Route Provider Plugin

**Coding time:**

Open `src/SprykerAcademy/Yves/CustomerPage/Plugin/Router/CustomerPageRouteProviderPlugin.php`:
1. In `addCustomerMessagesRoute()`, build a route for `/customer/messages` pointing to `Message` controller, `listAction` (GET + POST)
2. Add a `addCustomerMessagesDeleteRoute()` for `POST /customer/messages/delete` pointing to `Message` controller, `deleteAction`

#### 6.6 Provided Scaffolding (no coding needed)

The following files are already provided by the exercise skeleton:

- **`src/Pyz/Yves/Router/RouterDependencyProvider.php`** — Replaces the core `CustomerPageRouteProviderPlugin` with your extended version
- **`src/Pyz/Yves/CustomerPage/Theme/.../navigation-sidebar/navigation-sidebar.twig`** — Adds a "My Messages" link to the customer account sidebar menu
- **`src/SprykerAcademy/Yves/CustomerPage/Theme/.../views/message/list.twig`** — The Twig template showing the message table with delete buttons and the add form

Take a moment to review these files to understand:
- How Spryker's **template override** mechanism works (project-level Twig overrides vendor templates by matching the file path)
- How the **navigation sidebar** uses a data-driven items array
- How the **form** is rendered with `form_start`/`form_widget`/`form_end` (Symfony form rendering helpers)
- How each table row has a **mini POST form** for the delete button (no link — delete is always POST)

Clear cache:

```bash
docker/sdk console cache:empty-all
```

---

## Best Practices Applied in This Exercise

### SOLID: Single Responsibility for Business Models

The business layer separates concerns into dedicated classes:

| Class | Responsibility |
|-------|---------------|
| `MessageReader` | Reading/querying messages (uses Repository) |
| `MessageWriter` | Creating/persisting messages (uses EntityManager) |
| `MessageDeleter` | Deleting messages (uses EntityManager) |

Each class has **one reason to change**. The Writer does not know how to delete. The Deleter does not know how to create. The Facade orchestrates all three through the BusinessFactory.

### Form Data Binding with Transfer Objects

Instead of extracting form data from arrays:
```php
// Avoid this
$formData = $messageForm->getData();
$messageTransfer = new MessageTransfer();
$messageTransfer->setMessage($formData['message']);
```

Bind the form directly to a transfer:
```php
// Preferred
$messageForm = $factory->createMessageForm(new MessageTransfer());
$messageForm->handleRequest($request);
$messageTransfer = $messageForm->getData(); // Already a MessageTransfer
```

### Safe ID Handling with castId()

Always validate IDs from user input before passing them to the persistence layer:
```php
$idMessage = $this->castId($request->request->get('idMessage'));
// Throws InvalidArgumentException if not numeric or zero
```

---

## Testing

1. Log in to Yves: http://yves.eu.spryker.local/en/login (use `sonia@spryker.com` / `change123`)
2. Visit: http://yves.eu.spryker.local/en/customer/messages
3. You should see a message list (empty initially) and a form to add messages
4. Add a message and verify it appears in the list with a created timestamp
5. Click "Delete" on a message and verify it disappears

---

## Verify Your Work

Run the automated tests for this exercise:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise7
```

The test suite covers:
- **Schema XML:** `fk_customer` column, foreign key, timestampable behavior
- **Transfer XML:** `fkCustomer`, `createdAt` properties, `MessageCollection` transfer
- **Structural:** All classes and methods exist across the full stack
- **Mock-based:** Stub calls the correct gateway paths for create, get, and delete
- **Unit:** `MessageDeleter` delegates to `EntityManager` correctly
- **SOLID:** `MessageWriter` does NOT have a `delete()` method

Or run all exercise tests at once:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/
```

---

## Solution

```bash
./exercises/load.sh hello-world basics/extending-core-modules/complete
```

---

## Bonus: AJAX Version

An extended solution is available that uses Spryker's built-in AJAX component pattern to add and delete messages without a full page reload. The message table refreshes dynamically.

### How Spryker AJAX Works

Spryker provides a component-based AJAX pattern using four Twig molecules from `ShopUi`:

| Component | Role |
|-----------|------|
| `ajax-provider` | XMLHttpRequest wrapper — sends requests and dispatches `fetching`/`fetched` events |
| `ajax-form-submitter` | Intercepts form submit (via `data-*` trigger attribute) and delegates to the provider |
| `ajax-renderer` | Listens for the `fetched` event, parses JSON response, and inserts `content` into a target DOM element |
| `ajax-loader` | Shows/hides a spinner during the request |

### The JSON Response Contract

Async controllers return `JsonResponse` with this structure:

```json
{
    "messages": "<rendered flash message HTML>",
    "content": "<rendered HTML fragment to replace in the DOM>"
}
```

- `messages` — Rendered via `@ShopUi/components/organisms/flash-message-list/flash-message-list.twig`. Dispatched as a DOM event for the flash message component to pick up.
- `content` — The re-rendered page fragment. The `ajax-renderer` inserts this into the target element.

### Twig Integration

The template includes the AJAX trio after the content wrapper:

```twig
{# Content area that gets replaced #}
<div class="{{ ajaxContentClass }}">
    {# ... table, form, loader ... #}
</div>

{# AJAX components #}
{% include molecule('ajax-provider') with { class: ajaxProviderClass, attributes: { method: 'POST' } } only %}
{% include molecule('ajax-renderer') with { attributes: { 'provider-class-name': ajaxProviderClass, 'target-class-name': ajaxContentClass, 'mount-after-render': true } } only %}
{% include molecule('ajax-form-submitter') with { attributes: { 'trigger-attribute': 'data-message-ajax-submit', 'provider-class-name': ajaxProviderClass } } only %}
```

Form buttons use `data-message-ajax-submit` and `formaction` to point to the async endpoint:

```html
<button data-message-ajax-submit formaction="/customer/messages/async/add">Add Message</button>
<button data-message-ajax-submit formaction="/customer/messages/async/delete">Delete</button>
```

### Key Additions in the AJAX Version

- `MessageAsyncController` — `addAction()` and `deleteAction()` return `JsonResponse` instead of redirects
- Async routes: `POST /customer/messages/async/add` and `POST /customer/messages/async/delete`
- `message-async.twig` — Content fragment re-rendered server-side after each operation
- `list.twig` — Includes the AJAX component trio; uses `mount-after-render: true` so JS components in new content get re-initialized

```bash
./exercises/load.sh hello-world basics/extending-core-modules/complete-ajax
```
