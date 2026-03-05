# Exercise 9: Back Office - Supplier CRUD

In this exercise, you will build a complete Back Office interface for managing suppliers: a sortable/searchable table to list them, a form to create new suppliers, and edit/delete functionality. You will use Spryker's `Gui` module framework for tables and Symfony forms for data entry.

You will learn how to:
- Create a Back Office table extending `AbstractTable` with sorting, searching, and AJAX loading
- Build Symfony forms with validation for the Back Office
- Wire dependencies through the `DependencyProvider` and `CommunicationFactory`
- Implement full CRUD controllers (Index, Create, Edit, Delete)
- Register navigation items for the Back Office sidebar
- Use the `castId()` pattern for safe ID handling

## Prerequisites

- Completed Exercise 8 (Data Import) — you should have suppliers in the database
- Understanding of the Facade pattern and DependencyProvider

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/back-office/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console propel:install
docker/sdk console cache:empty-all
```

---

## Background: Spryker Back Office Architecture

Back Office modules in Spryker follow the naming convention `<ModuleName>Gui` (e.g., `SupplierGui`). They live in the Communication layer and depend on the core module's Facade for business logic.

```
SupplierGui (Communication)  →  Supplier (Business)  →  Supplier (Persistence)
  Controllers                      Facade                   Repository
  Tables                           Reader/Writer            EntityManager
  Forms                            Deleter
  Factory
```

**Key classes:**

| Class | Role |
|-------|------|
| `AbstractTable` | Base for sortable/searchable Back Office tables |
| `AbstractController` | Provides `viewResponse()`, `jsonResponse()`, `castId()`, `redirectResponse()` |
| `AbstractType` | Symfony form base for Back Office forms |
| `CommunicationFactory` | Creates tables, forms; accesses provided dependencies |
| `DependencyProvider` | Injects Facade and Propel queries into the module |

---

## Working on the Exercise

### Part 1: Database Structure

The exercise skeleton provides the Supplier module with the schema for `pyz_supplier` (columns: id_supplier, name, description, status, email, phone). A `SupplierTransfer` DTO is also provided.

If you haven't already, create the tables and generate transfers:

```bash
docker/sdk console propel:install
docker/sdk console transfer:generate
```

If you have no supplier data, import it first:

```bash
docker/sdk console data:import supplier
```

---

### Part 2: Create the Supplier Table

The table displays suppliers in the Back Office with sorting, searching, and action buttons (Edit/Delete).

#### 2.1 Configure the Table

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierGui/Communication/Table/SupplierTable.php`. The class extends `AbstractTable` and has two methods to implement:

In `configure()`:
1. **TODO-1:** Set the table headers using `$config->setHeader()` — pass an associative array mapping column constants to display labels. Include `COL_ACTIONS => 'Actions'` for the action buttons column.
2. **TODO-2:** Set sortable columns using `$config->setSortable()` — pass an array of column constants (all data columns except Actions)
3. **TODO-3:** Set searchable columns using `$config->setSearchable()` — same pattern, but only text columns that make sense to search (name, description, email, phone)
4. **TODO-4:** Mark the Actions column as a raw column using `$config->setRawColumns()` — this allows HTML content (buttons) to render instead of being escaped

> **Hint:** The class already has constants like `COL_ID_SUPPLIER`, `COL_NAME`, `COL_ACTIONS`, etc. Use these as array keys.

In `prepareData()`:
5. **TODO-5:** Fetch the supplier data using `$this->runQuery()`. This method accepts the Propel query (injected via constructor), the `$config`, and a boolean `true` to get raw results. Then map the results using the provided `mapReturns()` method.

In `mapReturns()`:
6. **TODO-6:** Add an actions column entry to each row's array that calls `$this->buildActionButtons()` with the supplier ID. Use `static::COL_ACTIONS` as the key.

In `buildActionButtons()`:
7. **TODO-7:** Build the Edit and Delete action buttons. Spryker's `AbstractTable` provides built-in helper methods for generating table row buttons:

> ```php
> // Available in any class extending AbstractTable:
> $this->generateEditButton($url, 'Edit')
> $this->generateRemoveButton($url, 'Delete')
> $this->generateViewButton($url, 'View')
> $this->generateCreateButton($url, 'Create')
> ```
> Use `Url::generate()` from `Spryker\Service\UtilText\Model\Url\Url` to build URLs with query parameters:
> ```php
> $url = Url::generate('/supplier-gui/edit', [
>     EditController::REQUEST_PARAM_ID_SUPPLIER => $idSupplier,
> ]);
> ```
> Combine multiple buttons with `implode(' ', [...])` and assign to the Actions column. The skeleton already provides the constants `URL_SUPPLIER_EDIT` and `URL_SUPPLIER_DELETE` as well as imports for `EditController` and `DeleteController`.

> **About Propel in the Communication layer:** Tables are an exception to the "no Propel outside Persistence" rule. The `AbstractTable` class handles pagination, sorting, and filtering internally through the Propel query.

#### 2.2 Wire the DependencyProvider

Every external dependency must be provided through the `DependencyProvider`.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierGui/SupplierGuiDependencyProvider.php`:

1. Implement `addSupplierPropelQuery()` — use `$container->set()` with the `PROPEL_QUERY_SUPPLIER` constant. For Propel queries, use `$container->factory()` to ensure a **fresh instance** on every request (not a singleton).

> **Important:** Always use `$container->factory(fn () => PyzSupplierQuery::create())` for Propel queries. A shared query instance would carry state between requests.

2. Call `addSupplierPropelQuery()` in `provideCommunicationLayerDependencies()`.

#### 2.3 Wire the Factory

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierGui/Communication/SupplierGuiCommunicationFactory.php`:

1. Implement `getSupplierQuery()` — use `getProvidedDependency()` with the appropriate constant to retrieve the Propel query
2. Implement `createSupplierTable()` — instantiate `SupplierTable` passing the Propel query as constructor argument

> **Naming convention:** `get*()` for retrieving provided dependencies, `create*()` for instantiating new objects.

#### 2.4 Implement the IndexController

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierGui/Communication/Controller/IndexController.php`:

The controller needs two actions:

- `indexAction()` — Gets the table from the factory, calls `render()` on it, and returns a `viewResponse()` with the rendered HTML. The template variable should be `supplierTable`.
- `tableAction()` — Gets the table from the factory, calls `fetchData()` on it, and returns a `jsonResponse()`. This is called via AJAX by the table's built-in JavaScript.

> **Two-action pattern:** Every Back Office table needs both: `indexAction()` renders the HTML container, `tableAction()` returns JSON data via AJAX. The `AbstractTable` handles the AJAX logic automatically.

#### 2.5 Add the Twig Template

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierGui/Presentation/Index/index.twig`:
1. Add a "Create Supplier" button linking to `/supplier-gui/create`
2. Render the `supplierTable` variable using the `raw` filter

> **Buttons in Spryker Back Office Twig templates:** Spryker registers Twig helper functions for consistent button rendering. Use these instead of raw HTML:
> ```twig
> {# Action buttons (page-level) — rendered above forms/tables #}
> {{ createActionButton('/supplier-gui/create', 'Create Supplier') }}
> {{ editActionButton('/supplier-gui/edit?id-supplier=' ~ id, 'Edit') }}
> {{ backActionButton(backUrl, 'Back') }}
> {{ removeActionButton('/supplier-gui/delete?id-supplier=' ~ id, 'Delete') }}
> ```
> These functions are provided by the Gui module's Twig plugins (`CreateActionButtonTwigPlugin`, etc.) and automatically apply the correct CSS classes and styling.
>
> **Rendering raw HTML:** The controller passes pre-rendered HTML from `$table->render()`. Use the `raw` filter to prevent Twig from escaping it:
> ```twig
> {{ supplierTable | raw }}
> ```
> Without `| raw`, Twig would escape the HTML tags and you'd see raw `<table>` markup as text.

Clear cache:

```bash
docker/sdk console cache:empty-all
```

Visit http://backoffice.eu.spryker.local/supplier-gui to see the table.

---

### Part 3: Create the Supplier Form

#### 3.1 Build the Form Class

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierGui/Communication/Form/SupplierCreateForm.php`. The class extends `AbstractType`. In the `buildForm()` method, add fields for:

- `name` — `TextType` with a `NotBlank` constraint
- `description` — `TextType` with a `NotBlank` constraint
- `isActive` — `CheckboxType`, unmapped (`'mapped' => false`), not required, with default value from form options
- `email` — `TextType` with a `NotBlank` constraint
- `phone` — `TextType` (optional)

> **Unmapped fields:** The `isActive` checkbox doesn't map directly to the `SupplierTransfer` (which has a numeric `status` field). Use `'mapped' => false` to exclude it from automatic data binding. The controller will manually convert the boolean to a status integer.

> **Form options:** Override `configureOptions()` to set `data_class` to the `SupplierTransfer` class and define defaults for custom options like `isActive`.

#### 3.2 Provide the Supplier Facade

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierGui/SupplierGuiDependencyProvider.php`:

1. Implement `addSupplierFacade()` — use `$container->set()` with the `FACADE_SUPPLIER` constant and the locator to retrieve the Supplier facade
2. Call it in `provideCommunicationLayerDependencies()`

Then open `src/SprykerAcademy/Zed/SupplierGui/Communication/SupplierGuiCommunicationFactory.php`:

3. Implement `getSupplierFacade()` — retrieve using `getProvidedDependency()`

> **Locator pattern:** `$container->getLocator()->supplier()->facade()` auto-resolves the Supplier module's Facade.

#### 3.3 Implement the CreateController

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierGui/Communication/Controller/CreateController.php`. The `indexAction()` handles both GET (show form) and POST (process submission):

1. Create the form via the factory, passing a new `SupplierTransfer` and default options
2. Handle the request with `$form->handleRequest($request)`
3. If submitted and valid, get the transfer from `$form->getData()`, set the status from the checkbox value, persist via the Facade, and redirect to the overview
4. If not submitted or invalid, return a `viewResponse()` with the form view

> **Duplicate name handling:** Before creating, consider checking if a supplier with the same name already exists. You can add a form error with `$form->get('name')->addError(new FormError('message'))`.

> **Status conversion:** The checkbox gives a boolean, but the database expects an integer. Convert in the controller: `$supplierTransfer->setStatus($isActive ? 1 : 0)`.

> **Exception handling:** Wrap the Facade `createSupplier()` call in a `try/catch (Throwable)` block. Database operations can fail (e.g. duplicate entries, constraint violations). On failure, use `$this->addErrorMessage()` to show the error on the overview page, then redirect. The error message constants are already provided in the skeleton (`MESSAGE_SUPPLIER_CREATE_FAILED`). Spryker's `AbstractController` flash messages (`addErrorMessage()`, `addSuccessMessage()`) persist through redirects, so errors will appear on the index page after redirect.

#### 3.4 Implement the EditController

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierGui/Communication/Controller/EditController.php`:

1. Extract the supplier ID from the request using `$this->castId()`
2. Fetch the existing supplier via the Facade's `findSupplierById()`
3. Handle the "not found" case with an error message and redirect
4. Create the form pre-filled with the fetched `SupplierTransfer`, passing the current status as the `isActive` option
5. On valid submission, update via the Facade and redirect

> **Exception handling:** Same pattern as Create — wrap `updateSupplier()` in `try/catch (Throwable)`. On failure, use `$this->addErrorMessage(static::MESSAGE_SUPPLIER_UPDATE_FAILED)` and redirect to the overview. The error will be displayed as a flash message on the index page.

#### 3.5 Implement the DeleteController

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierGui/Communication/Controller/DeleteController.php`:

1. Extract and validate the supplier ID using `$this->castId()`
2. Call the Facade's `deleteSupplier()` passing a `SupplierTransfer` with the ID set
3. Add a success message and redirect to the overview

> **Exception handling:** Wrap `deleteSupplier()` in `try/catch (Throwable)` — deletion can fail due to foreign key constraints (e.g. if the supplier is referenced by other tables). On failure, use `$this->addErrorMessage(static::MESSAGE_SUPPLIER_DELETE_FAILED)` and redirect to the overview.

---

### Part 4: Navigation

The navigation XML (`config/Zed/navigation.xml`) is provided by the exercise skeleton. It registers the "Suppliers" menu item in the Back Office sidebar with sub-pages for Overview, Create, Edit, and Delete.

After loading the exercise, clear cache to see the navigation:

```bash
docker/sdk console cache:empty-all
```

---

## Key Concepts Summary

### Back Office Table Pattern

```
IndexController::indexAction()  →  render() → HTML page with table container
IndexController::tableAction()  →  fetchData() → JSON data via AJAX
```

The `AbstractTable` handles pagination, sorting, and search automatically through the Propel query.

### Form Lifecycle

```
GET  → Create form → Pass to viewResponse() → Twig renders form
POST → Create form → handleRequest() → isSubmitted() + isValid() → getData() → Facade → redirect
```

### DependencyProvider → Factory → Controller Chain

```
DependencyProvider: $container->set(FACADE_SUPPLIER, locator)
                    $container->factory(fn() => PyzSupplierQuery::create())
                           ↓
Factory: getSupplierFacade() → getProvidedDependency(FACADE_SUPPLIER)
         createSupplierTable() → new SupplierTable(getSupplierQuery())
                           ↓
Controller: getFactory()->createSupplierTable()
            getFactory()->getSupplierFacade()->createSupplier(...)
```

---

## Testing

Visit the Back Office:
1. http://backoffice.eu.spryker.local/supplier-gui — Table with suppliers
2. Click "Create Supplier" — Fill the form and submit
3. Click "Edit" on a row — Modify and save
4. Click "Delete" on a row — Confirm removal

Run the automated tests:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/Supplier/ BackOffice
```

---

## Solution

```bash
./exercises/load.sh supplier intermediate/back-office/complete
```
