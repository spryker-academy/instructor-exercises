<!-- Generated from guides-html/spryker-academy-exercises-presentation.html. Edit the HTML, then run: python3 tools/presentation_to_markdown.py <html> <md> -->

# Spryker Academy

## ILT Exercises - Theory & Practice

Instructor-Led Training \| 7 Progressive Exercises

Namespace: `SprykerAcademy\` \| Module: `ContactRequest`

---

## Agenda

| \#  | Exercise                    | Key Concepts                         |
|-----|-----------------------------|--------------------------------------|
| 1   | Contact Request Back Office | Controllers, Twig, Navigation        |
| 2   | Data Transfer Objects       | Transfer XML, Code Generation        |
| 3   | Database Schema             | Propel ORM, Schema XML               |
| 4   | Module Layers - Back Office | Persistence, Business, Communication |
| 5   | Module Layers - Storefront  | Client/Stub, BackendGateway          |
| 6   | Configuration               | Config class, Constants, DI          |
| 7   | Extending Core Modules      | CustomerPage, Forms, AJAX, SOLID     |

---

## Spryker Architecture Overview

```text
  ┌─────────────────────────────────────────┐
  │           APPLICATION LAYERS            │
  ├──────────┬──────────┬─────────┬─────────┤
  │   Yves   │   Zed    │  Glue   │ Client  │
  │Storefront│Back Office│REST API│Yves↔Zed │
  ├──────────┴──────────┴─────────┴─────────┤
  │             SHARED LAYER                │
  │     Transfers, Constants, Interfaces    │
  └─────────────────────────────────────────┘
```

-   <span class="accent">Yves</span> — Storefront (customer-facing, stateless, fast)
-   <span class="accent">Zed</span> — Back Office (business logic, database access)
-   <span class="accent">Client</span> — Bridge for Yves-to-Zed communication
-   <span class="accent">Shared</span> — DTOs and interfaces shared across all layers

---

## Zed Module Layers

```text
  ┌────────────────────────────────────┐
  │      Communication Layer           │
  │  Controllers, Plugins, Forms       │
  ├────────────────────────────────────┤
  │        Business Layer              │
  │  Facade ← Factory ← R / W / D     │
  ├────────────────────────────────────┤
  │       Persistence Layer            │
  │  Repository (R) / EntityManager(W) │
  │       ↕ Propel ORM ↕              │
  └────────────────────────────────────┘
```

-   <span class="accent">Communication</span> — HTTP entry point (controllers), no business logic
-   <span class="accent">Business</span> — All logic lives here, exposed via **Facade** (public API)
-   <span class="accent">Persistence</span> — Data access. **Repository** reads, **EntityManager** writes

---

## Exercise 1: Contact Request Back Office

### Creating Your First Zed Controller

> **Goal:** Display "Contact Request!" in the Spryker Back Office

---

### Zed Controllers

-   Extend `AbstractController`
-   Route: `/module-name/controller-name/action-name`
-   Return `viewResponse()` with data for the Twig template

```php
namespace SprykerAcademy\Zed\ContactRequest\Communication\Controller;

use Spryker\Zed\Kernel\Communication\Controller\AbstractController;

class IndexController extends AbstractController
{
    public function indexAction(): array
    {
        return $this->viewResponse([
            'contactRequestText' => 'Contact Request!',
        ]);
    }
}
```

Route: `/contact-request/hello/index`

---

### Twig Templates in Zed

-   Located in `Presentation/<ControllerName>/<action>.twig`
-   Access data from controller via variable names

```twig
{# Presentation/Hello/index.twig #}
{% extends '@Gui/Layout/layout.twig' %}

{% block content %}
    <h1>{{ contactRequestText }}</h1>
{% endblock %}
```

---

## Exercise 2: Data Transfer Objects

### Spryker's Code Generation System

> **Goal:** Define a `ContactRequestTransfer` DTO via XML and generate PHP classes

---

### Transfer XML Definition

```xml
<!-- src/SprykerAcademy/Shared/ContactRequest/Transfer/contact_request.transfer.xml -->
<transfers>
    <transfer name="ContactRequest">
        <property name="idContactRequest" type="int"/>
        <property name="message" type="string"/>
        <property name="fkCustomer" type="int"/>
        <property name="createdAt" type="string"/>
    </transfer>

    <transfer name="ContactRequestCriteria">
        <property name="idContactRequest" type="int"/>
        <property name="fkCustomer" type="int"/>
    </transfer>

    <transfer name="ContactRequestCollection">
        <property name="contactRequests" type="ContactRequest[]"/>
    </transfer>
</transfers>
```

---

### What Gets Generated

```bash
docker/sdk console transfer:generate
```

Generates `Generated\Shared\Transfer\ContactRequestTransfer` with:

-   Typed getters/setters: `getMessage()`, `setMessage(string $message)`
-   Strict variants: `getMessageOrFail()`, `setFkCustomerOrFail()`
-   Array conversion: `toArray()`, `fromArray()`, `modifiedToArray()`
-   Collection adders: `addContactRequests(ContactRequestTransfer $contactRequest)`
-   Implements `ArrayAccess` — works with Symfony forms

> **Convention:** Collection property `contactRequests` (plural) generates adder `addContactRequests()` matching the property name.

---

## Exercise 3: Database Schema

### Propel ORM & Schema XML

> **Goal:** Define the `pyz_contact_request` table with columns, foreign keys, and behaviors

---

### Propel Schema XML

```xml
<table name="pyz_contact_request" phpName="PyzContactRequest">
    <column name="id_contact_request" type="INTEGER"
            primaryKey="true" autoIncrement="true"/>
    <column name="message" type="VARCHAR" size="255"
            required="true"/>
    <column name="fk_customer" type="INTEGER"
            required="false"/>

    <unique name="pyz_contact_request-message">
        <unique-column name="message"/>
        <unique-column name="fk_customer"/>
    </unique>

    <foreign-key foreignTable="spy_customer"
                 onDelete="CASCADE">
        <reference local="fk_customer"
                   foreign="id_customer"/>
    </foreign-key>

    <behavior name="timestampable"/>
</table>
```

---

### Key Propel Concepts

```bash
docker/sdk console propel:install
# = propel:schema:copy + propel:model:build + propel:diff + propel:migrate
```

-   **phpName** — PHP class name: `PyzContactRequest`, `PyzContactRequestQuery`
-   **Magic methods** — `findOneByIdContactRequest()`, `filterByFkCustomer()`
-   **Timestampable behavior** — Auto-manages `created_at` / `updated_at`
-   **Foreign keys** — `onDelete="CASCADE"` = delete messages when customer is deleted
-   **Composite unique** — Same customer can't post duplicate text, different customers can

---

## Exercise 4: Module Layers - Back Office

### Persistence, Business, Communication

> **Goal:** Create, read, and delete messages through the three-layer architecture

---

### Persistence Layer: Repository (Read)

```php
class ContactRequestRepository extends AbstractRepository
{
    public function findContactRequest(ContactRequestCriteriaTransfer $criteria): ?ContactRequestTransfer
    {
        $query = $this->getFactory()->createContactRequestQuery();

        if ($criteria->getIdContactRequest()) {
            $entity = $query->findOneByIdContactRequest($criteria->getIdContactRequest());
        }

        return $entity
            ? $this->getFactory()->createContactRequestMapper()
                ->mapEntityToContactRequestTransfer($entity)
            : null;
    }
}
```

> **Rule:** Repository = read-only. Never call `save()` or `delete()` here.

---

### Persistence Layer: EntityManager (Write)

```php
class ContactRequestEntityManager extends AbstractEntityManager
{
    public function createContactRequest(ContactRequestTransfer $transfer): ContactRequestTransfer
    {
        $entity = new PyzContactRequest();
        $entity->fromArray($transfer->modifiedToArray());
        $entity->save();

        return $this->getFactory()->createContactRequestMapper()
            ->mapEntityToContactRequestTransfer($entity);
    }

    public function deleteContactRequest(int $idContactRequest): bool
    {
        $entity = $this->getFactory()->createContactRequestQuery()
            ->findOneByIdContactRequest($idContactRequest);

        if (!$entity) { return false; }

        $entity->delete();
        return true;
    }
}
```

---

### Business Layer: SOLID Separation

| Class                   | Dependency             | Methods                                                   | Responsibility |
|-------------------------|------------------------|-----------------------------------------------------------|----------------|
| `ContactRequestReader`  | RepositoryInterface    | `findContactRequest()`, `findContactRequestsByCustomer()` | Read only      |
| `ContactRequestWriter`  | EntityManagerInterface | `create()`                                                | Write only     |
| `ContactRequestDeleter` | EntityManagerInterface | `delete()`                                                | Delete only    |

```php
// Each business model has ONE constructor dependency and ONE responsibility
class ContactRequestDeleter
{
    public function __construct(
        protected ContactRequestEntityManagerInterface $entityManager,
    ) {}

    public function delete(int $idContactRequest): bool
    {
        return $this->entityManager->deleteContactRequest($idContactRequest);
    }
}
```

> **Single Responsibility:** Writer does NOT have `delete()`. Deleter does NOT have `create()`. Each class has one reason to change. The Facade orchestrates all three via the Factory.

---

### Business Layer: Facade & Factory

**Facade** = Module's public API (one method per use case):

```php
class ContactRequestFacade extends AbstractFacade
{
    public function createContactRequest(ContactRequestTransfer $t): ContactRequestTransfer {
        return $this->getFactory()->createContactRequestWriter()->create($t);
    }
    public function findContactRequestsByCustomer(ContactRequestCriteriaTransfer $c): ContactRequestCollectionTransfer {
        return $this->getFactory()->createContactRequestReader()->findContactRequestsByCustomer($c);
    }
    public function deleteContactRequest(int $id): bool {
        return $this->getFactory()->createContactRequestDeleter()->delete($id);
    }
}
```

**Factory** = Wiring (each `create*` instantiates with the right dependency):

```php
class ContactRequestBusinessFactory extends AbstractBusinessFactory
{
    public function createContactRequestReader(): ContactRequestReader {
        return new ContactRequestReader($this->getRepository());
    }
    public function createContactRequestWriter(): ContactRequestWriter {
        return new ContactRequestWriter($this->getEntityManager());
    }
    public function createContactRequestDeleter(): ContactRequestDeleter {
        return new ContactRequestDeleter($this->getEntityManager());
    }
}
```

---

### Mapper Pattern

```php
class ContactRequestMapper
{
    public function mapEntityToContactRequestTransfer(
        PyzContactRequest $entity,
        ContactRequestTransfer $transfer = new ContactRequestTransfer(),
    ): ContactRequestTransfer {
        return $transfer->fromArray($entity->toArray(), true);
    }
}
```

-   Converts between ORM entities and Transfer objects
-   Lives in the Persistence layer (next to Repository/EntityManager)
-   Default parameter = fresh transfer if none provided

---

## Exercise 5: Module Layers - Storefront

### Yves-Zed Communication via Client/Stub

> **Goal:** Display messages in Yves by calling Zed through the BackendGateway

---

### Communication Flow

```text
  Yves             BackendGateway          Zed
  ┌──────────┐    ┌─────────────┐    ┌───────────┐
  │Controller │    │             │    │ Gateway   │
  │    ↓      │    │  HTTP/JSON  │    │ Controller│
  │ Factory   │───→│  Serialize  │───→│    ↓      │
  │    ↓      │    │ Deserialize │    │  Facade   │
  │  Client   │←───│             │←───│    ↓      │
  │    ↓      │    │             │    │ Business  │
  │   Stub    │    │             │    │    ↓      │
  └──────────┘    └─────────────┘    │Persistence │
                                      └───────────┘
```

---

### The Stub: Calling Zed from Yves

```php
class ContactRequestStub
{
    public function __construct(
        protected ZedRequestClientInterface $zedRequestClient,
    ) {}

    public function findContactRequest(ContactRequestCriteriaTransfer $criteria): ContactRequestResponseTransfer
    {
        /** @var ContactRequestResponseTransfer $response */
        $response = $this->zedRequestClient->call(
            '/contact-request/gateway/find-contact-request',
            $criteria,
        );
        return $response;
    }
}
```

> **Gateway path convention:**
> `/module-name/gateway/action-name`
> `deleteContactRequestAction()` → `/contact-request/gateway/delete-contact-request`

---

### GatewayController in Zed

```php
class GatewayController extends AbstractGatewayController
{
    public function findContactRequestAction(
        ContactRequestCriteriaTransfer $criteria
    ): ContactRequestResponseTransfer {
        return $this->getFacade()->findContactRequest($criteria);
    }

    public function deleteContactRequestAction(
        ContactRequestCriteriaTransfer $criteria
    ): ContactRequestResponseTransfer {
        $response = new ContactRequestResponseTransfer();
        $deleted = $this->getFacade()
            ->deleteContactRequest($criteria->getIdContactRequest());
        $response->setIsSuccessful($deleted);
        return $response;
    }
}
```

-   Extends `AbstractGatewayController` (not `AbstractController`)
-   Transfer parameter = auto-deserialized from request
-   Return transfer = auto-serialized in response

---

### DependencyProvider Pattern

Every external dependency goes through the **DependencyProvider**:

```php
class ContactRequestPageDependencyProvider extends AbstractBundleDependencyProvider
{
    public const string CLIENT_CONTACT_REQUEST = 'CLIENT_CONTACT_REQUEST';

    public function provideDependencies(Container $container): Container
    {
        $container->set(
            static::CLIENT_CONTACT_REQUEST,
            fn () => $container->getLocator()->contactRequest()->client(),
        );
        return $container;
    }
}
```

The **Factory** retrieves it:

```php
class ContactRequestPageFactory extends AbstractFactory
{
    public function getContactRequestClient(): ContactRequestClientInterface
    {
        return $this->getProvidedDependency(
            ContactRequestPageDependencyProvider::CLIENT_CONTACT_REQUEST,
        );
    }
}
```

---

## Exercise 6: Configuration

### Config Classes, Constants & Constructor Injection

> **Goal:** Read a config value from `config_default.php` and display it

---

### Configuration Stack

**1.** Constants interface (Shared layer):

```php
interface ContactRequestConstants
{
    public const string MY_CONFIG_VALUE = 'CONTACT_REQUEST:MY_CONFIG_VALUE';
}
```

**2.** Set the value in `config_default.php`:

```php
$config[ContactRequestConstants::MY_CONFIG_VALUE] = 'Hello from config!';
```

**3.** Config class reads it (Zed module root):

```php
class ContactRequestConfig extends AbstractBundleConfig
{
    public function getMyConfigValue(): string
    {
        return $this->get(ContactRequestConstants::MY_CONFIG_VALUE, 'default value');
    }
}
```

---

### Constructor Injection (Spryker 202512.0+)

```php
// Zed controllers now support constructor DI
class ConfigController extends AbstractController
{
    public function __construct(
        private readonly ContactRequestConfig $config,
    ) {}

    public function indexAction(): array
    {
        return $this->viewResponse([
            'configValue' => $this->config->getMyConfigValue(),
        ]);
    }
}
```

> **Alternative:** Traditional factory pattern still works:
> `$this->getFactory()->getConfig()->getMyConfigValue()`

---

## Exercise 7: Extending Core Modules

### CustomerPage, Forms, Delete, AJAX

> **Goal:** Add customer messages to the Yves profile area by extending Spryker's `CustomerPage` module

---

### Extending Core Modules: The Pattern

Extend the core class in your namespace, override what you need:

**DependencyProvider** — add your dependencies alongside core ones:

```php
class CustomerPageDependencyProvider extends SprykerCustomerPageDependencyProvider
{
    public function provideDependencies(Container $container): Container
    {
        $container = parent::provideDependencies($container); // Keep core deps
        $container = $this->addContactRequestClient($container);  // Add ours
        return $container;
    }
}
```

**Factory** — add factory methods for your new features:

```php
class CustomerPageFactory extends SprykerCustomerPageFactory
{
    public function getContactRequestClient(): ContactRequestClientInterface { ... }
    public function createContactRequestForm(ContactRequestTransfer $t): FormInterface { ... }
}
```

**RouteProviderPlugin** — add routes alongside core ones:

```php
class CustomerPageRouteProviderPlugin extends SprykerCustomerPageRouteProviderPlugin
{
    public function addRoutes(RouteCollection $c): RouteCollection
    {
        $c = parent::addRoutes($c);                    // Keep all core routes
        $c = $this->addCustomerMessagesRoute($c);      // Add ours
        $c = $this->addCustomerMessagesDeleteRoute($c); // Add delete route
        return $c;
    }
}
```

---

### Symfony Forms in Spryker Yves

```php
// Form class — defines fields and validation only (no SubmitType)
class ContactRequestForm extends AbstractType
{
    public const string FIELD_MESSAGE = 'message';

    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder->add(static::FIELD_MESSAGE, TextType::class, [
            'label' => 'Your message',
            'constraints' => [new NotBlank()],
        ]);
    }
}
```

```php
// Usage in controller — data-mapped to a Transfer object
$form = $this->getFactory()->createContactRequestForm(new ContactRequestTransfer());
$form->handleRequest($request);

if ($form->isSubmitted() && $form->isValid()) {
    $contactRequestTransfer = $form->getData();   // Already a ContactRequestTransfer!
    $contactRequestTransfer->getMessage();         // Contains the form input
}
```

-   **Data binding:** Pass `ContactRequestTransfer` as form data — `getData()` returns the hydrated transfer
-   **ArrayAccess:** Transfers implement it, so Symfony maps fields to properties automatically
-   **No SubmitType:** Button rendered in Twig for Spryker CSS control

---

### Form Factory Chain in Spryker

```text
  CustomerPageFactory
      │
      ├─ createCustomerFormFactory()
      │     └─ FormFactory (extends AbstractFactory)
      │          └─ getFormFactory()
      │               └─ Symfony FormFactory
      │                    └─ create(ContactRequestForm::class, $transfer)
      │
      └─ Returns: FormInterface (CSRF + validation + data binding)
```

> Spryker doesn't expose Symfony's `FormFactory` directly on module factories. Use the proxy chain: `createCustomerFormFactory()->getFormFactory()->create()`

---

### Rendering Forms in Twig

```twig
{# Render the form with Symfony helpers #}
{{ form_start(data.messageForm) }}
    <div class="form spacing-bottom">
        {{ form_widget(data.messageForm.message) }}
    </div>
    <button type="submit" class="button button--success">
        Add Message
    </button>
{{ form_end(data.messageForm) }}
{# form_end renders remaining fields including the CSRF _token #}
```

-   `form_start` — Opens `<form>` tag with action and method
-   `form_widget` — Renders the input field (applies Spryker's form theme)
-   `form_end` — Renders hidden fields (`_token`) and closes `<form>`
-   Never use `render_rest: false` on `form_end` — it skips the CSRF token!

---

### Controller Best Practices

**listAction** — strict validation + data-mapped form:

```php
public function listAction(Request $request): View|RedirectResponse
{
    $customer = $this->getLoggedInCustomerTransfer();
    $contactRequestCriteria = new ContactRequestCriteriaTransfer();
    $contactRequestCriteria->setFkCustomerOrFail($customer?->getIdCustomer()); // Fails fast

    $form = $this->getFactory()->createContactRequestForm(new ContactRequestTransfer());
    $form->handleRequest($request);

    if ($form->isSubmitted() && $form->isValid()) {
        $transfer = $form->getData(); // Already a ContactRequestTransfer!
        $transfer->setFkCustomer($customer->getIdCustomer());
        $this->getFactory()->getContactRequestClient()->createContactRequest($transfer);
        return $this->redirectResponseInternal(static::ROUTE_CUSTOMER_MESSAGES);
    }
    // ... return view
}
```

**deleteAction** — safe ID casting with `castId()`:

```php
public function deleteAction(Request $request): RedirectResponse
{
    $idContactRequest = $this->castId($request->request->get('idContactRequest'));
    // Throws InvalidArgumentException if not numeric or zero
    $contactRequestCriteria = new ContactRequestCriteriaTransfer();
    $contactRequestCriteria->setIdContactRequest($idContactRequest);
    $this->getFactory()->getContactRequestClient()->deleteContactRequest($contactRequestCriteria);
    return $this->redirectResponseInternal(static::ROUTE_CUSTOMER_MESSAGES);
}
```

---

### Template Override Mechanism

Spryker resolves Twig templates in priority order:

1.  `src/Pyz/Yves/CustomerPage/Theme/...` <span class="accent">(project level — highest priority)</span>
2.  `src/SprykerAcademy/Yves/CustomerPage/Theme/...`
3.  `vendor/spryker-shop/customer-page/.../Theme/...` (core — lowest priority)

To override a core template, create a file at the same relative path in your project namespace.

> **Example:** Override the customer navigation sidebar by creating
> `src/Pyz/Yves/CustomerPage/Theme/default/components/molecules/navigation-sidebar/navigation-sidebar.twig`

---

## Bonus: AJAX in Spryker Yves

### The Component Trio Pattern

> No jQuery. No custom JS. Pure Spryker components from `ShopUi`.

---

### The Four AJAX Components

| Component             | Role                                        | Events                             |
|-----------------------|---------------------------------------------|------------------------------------|
| `ajax-provider`       | XMLHttpRequest wrapper                      | Dispatches `fetching` / `fetched`  |
| `ajax-form-submitter` | Intercepts form submit via `data-*` trigger | Listens for `click` / `change`     |
| `ajax-renderer`       | Parses JSON response, updates DOM           | Listens for `fetched`              |
| `ajax-loader`         | Shows/hides spinner                         | Listens for `fetching` / `fetched` |

---

### AJAX Flow

```text
  User clicks [Add Message]
      │ (data-contact-request-ajax-submit + formaction)
      ▼
  AjaxFormSubmitter → preventDefault, collect FormData
      ▼
  AjaxProvider.fetch(formData)
      │ dispatches "fetching" → Loader shows spinner
      │ POST /customer/contact-requests/async/add
      ▼
  ContactRequestAsyncController::addAction()
      │ Creates message, re-renders table
      │ Returns JSON: { messages, content }
      ▼
  AjaxProvider → dispatches "fetched" → Loader hides
      ▼
  AjaxRenderer.render()
      │ content → replaces target innerHTML
      │ messages → UPDATE_DYNAMIC_MESSAGES event
      │ mount() → re-init JS in new HTML
      ▼
  Table updated. No page reload!
```

---

### Async Controller Response

```php
class ContactRequestAsyncController extends AbstractCustomerController
{
    public function addAction(Request $request): JsonResponse
    {
        // ... validate form, create message ...

        return $this->jsonResponse([
            'messages' => $this->renderView(
                '@ShopUi/.../flash-message-list.twig'
            )->getContent(),
            'content' => $this->getTwig()->render(
                '@CustomerPage/views/contact-request/contact-request-async.twig',
                ['messages' => $collection, 'messageForm' => $form],
            ),
        ]);
    }
}
```

> **JSON contract:**
> `messages` → rendered flash message HTML (success/error)
> `content` → rendered HTML fragment to replace in the DOM

---

### Twig: Wiring the Components

```twig
{% set providerClass = 'js-message-provider' %}
{% set contentClass = 'js-message-content' %}

{# Target area that gets replaced #}
<div class="{{ contentClass }}">
    {# table + form + loader #}
    <button data-contact-request-ajax-submit
            formaction="{{ path('customer/contact-requests/async/add') }}">
        Add Message
    </button>
    {% include molecule('ajax-loader') with {
        attributes: { 'provider-class-name': providerClass }
    } only %}
</div>

{# AJAX components (outside the target!) #}
{% include molecule('ajax-provider') with {
    class: providerClass,
    attributes: { method: 'POST' }
} only %}

{% include molecule('ajax-renderer') with {
    attributes: {
        'provider-class-name': providerClass,
        'target-class-name': contentClass,
        'mount-after-render': true,
    }
} only %}

{% include molecule('ajax-form-submitter') with {
    attributes: {
        'trigger-attribute': 'data-contact-request-ajax-submit',
        'provider-class-name': providerClass,
    }
} only %}
```

---

## Testing Strategy

### 53 Tests, No Spryker Kernel Needed

---

### Test Types Used

| Type          | What                                    | How                               |
|---------------|-----------------------------------------|-----------------------------------|
| Structural    | Class/method exists, extends correctly  | Reflection, `class_exists()`      |
| XML Parsing   | Transfer/schema definitions correct     | SimpleXML + XPath                 |
| Unit (mocked) | Business logic with mocked dependencies | `createMock()`                    |
| SOLID         | Writer does NOT have delete()           | `assertFalse(method_exists(...))` |

```php
// Example: Mock-based stub test
$zedRequestMock = $this->createMock(ZedRequestClientInterface::class);
$zedRequestMock->expects($this->once())
    ->method('call')
    ->with('/contact-request/gateway/delete-contact-request', $criteria)
    ->willReturn($expectedResponse);

$stub = new ContactRequestStub($zedRequestMock);
$result = $stub->deleteContactRequest($criteria);
$this->assertTrue($result->getIsSuccessful());
```

---

### Running Tests

```bash
# Single exercise
docker/sdk cli vendor/bin/codecept run \
    -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise7

# All exercises
docker/sdk cli vendor/bin/codecept run \
    -c tests/SprykerAcademyTest/Zed/ContactRequest/
```

Framework: **Codeception + PHPUnit** (`Codeception\Test\Unit`)

No Spryker kernel bootstrap — tests are fast and isolated.

---

## Key Takeaways

-   <span class="accent">Layered Architecture</span> — Communication → Business → Persistence
-   <span class="accent">Facade Pattern</span> — Module's public API, single entry point
-   <span class="accent">Factory Pattern</span> — All instantiation goes through factories
-   <span class="accent">DependencyProvider</span> — External dependencies injected via container
-   <span class="accent">Transfer Objects</span> — Generated DTOs for type-safe data passing
-   <span class="accent">Client/Stub</span> — Yves talks to Zed through BackendGateway
-   <span class="accent">SOLID</span> — Reader/Writer/Deleter separation, single responsibility
-   <span class="accent">Module Extension</span> — Extend core classes at project level, call `parent::`
-   <span class="accent">Forms</span> — Data-mapped to transfers, form factory chain, CSRF built-in
-   <span class="accent">AJAX</span> — Component trio: Provider + FormSubmitter + Renderer

---

# Questions?

Spryker Academy \| ILT Exercises
