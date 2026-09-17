# Exercise 15: Merchant Portal — Supplier Table

In this exercise, you will build a supplier list page in the Merchant Portal using Spryker's GuiTable framework. The table displays only suppliers belonging to the current merchant and supports pagination, sorting, searching, and filtering.

You will learn how to:
- Create a Merchant Portal GUI module (`SupplierMerchantPortalGui`)
- Build a GuiTable configuration (columns, filters, row actions)
- Implement a data provider that fetches merchant-scoped data
- Write a repository query that joins suppliers with merchant assignments
- Register an Angular web component in the module
- Configure ACL rules and Merchant Portal navigation

## Prerequisites

- Completed Exercise 9 (Back Office) — supplier facade, repository, and entity manager must exist
- Suppliers assigned to a merchant via `pyz_merchant_to_supplier`
- Logged in as a demo merchant user

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/merchant-portal-table/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console cache:empty-all
```

---

## Background: Merchant Portal Architecture

The Merchant Portal uses a different architecture from the Back Office:

| Aspect | Back Office | Merchant Portal |
|--------|-------------|-----------------|
| Frontend | Twig + jQuery | Angular Web Components |
| Tables | `AbstractTable` (server-rendered HTML) | GuiTable (JSON config + Angular) |
| Data flow | Controller renders full page | Controller returns JSON, Angular renders UI |
| Layout | `@Gui/Layout/layout.twig` | `@ZedUi/Layout/merchant-layout-main.twig` |
| Navigation | `navigation.xml` | `navigation-main-merchant-portal.xml` |
| Access control | Back Office ACL | Merchant Portal ACL plugins |

**GuiTable flow:**

```
GET /supplier-merchant-portal-gui/supplier (page load)
├── SupplierController::indexAction()
├── Returns GuiTable configuration as JSON in Twig
└── Angular <web-mp-supplier-list> renders the table shell

GET /supplier-merchant-portal-gui/supplier/table-data (AJAX)
├── SupplierController::tableDataAction()
├── GuiTableHttpDataRequestExecutor executes the request
├── SupplierGuiTableDataProvider creates merchant-scoped criteria
├── Repository fetches paginated data
└── Returns JSON rows to Angular table
```

---

## Setup: Navigation and ACL

The exercise skeleton provides these pre-built:

### Navigation

The Merchant Portal navigation is in `config/Zed/navigation-main-merchant-portal.xml` (separate from the Back Office `navigation.xml`). The supplier entry is automatically merged by `load.sh`.

### ACL (Access Control)

Every Merchant Portal module must register ACL rules so merchant users can access its controllers. The skeleton includes:

- `SupplierMerchantPortalGuiMerchantAclRuleExpanderPlugin` — allows all routes in the `supplier-merchant-portal-gui` bundle
- `AclMerchantPortalDependencyProvider` override — registers the plugin via SprykerAcademy namespace

> **Why ACL?** The Merchant Portal is multi-tenant. Each merchant user can only access modules explicitly allowed by ACL rules. Without the ACL plugin, all routes return 403 Forbidden.

---

## Working on the Exercise

### Part 1: GuiTable Configuration Provider

The configuration provider defines the table structure: columns, filters, sorting, row actions, and data source URL.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/ConfigurationProvider/SupplierGuiTableConfigurationProvider.php`:

1. Get a configuration builder from `$this->guiTableFactory->createConfigurationBuilder()`

2. Add columns:
   - `addColumnText('name', 'Name', sortable: true, searchable: true)`
   - `addColumnText('description', 'Description', sortable: true, searchable: false)`
   - `addColumnChip('status', 'Status', ...)` with color map: `1 => green/Active`, `0 => gray/Inactive`
   - `addColumnText('email', 'Email', ...)`
   - `addColumnText('phone', 'Phone', ...)`

3. Add a status filter: `addFilterSelect('status', 'Status', false, [1 => 'Active', 0 => 'Inactive'])`

4. Add a row action for editing: `addRowActionDrawerAjaxForm('edit', 'Edit', '/supplier-merchant-portal-gui/update-supplier?id-supplier=${row.idSupplier}')`

5. Set data source URL, page size, and enable search

> **Column types:** `addColumnText()` for plain text, `addColumnChip()` for status badges with color coding, `addColumnDate()` for dates.

> **Row action:** `addRowActionDrawerAjaxForm()` opens a drawer overlay that loads a form via AJAX — you'll build this in Exercise 16.

---

### Part 2: GuiTable Data Provider

The data provider bridges the GuiTable framework with your repository.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/DataProvider/SupplierGuiTableDataProvider.php`:

1. In `createCriteria()`, build a `SupplierMerchantPortalTableCriteriaTransfer` with the current merchant's reference:
   ```php
   $this->merchantUserFacade->getCurrentMerchantUser()->getMerchantOrFail()->getMerchantReference()
   ```

2. In `fetchData()`, delegate to the repository: `$this->repository->getSupplierTableData($criteriaTransfer)`

> **AbstractGuiTableDataProvider:** The base class handles extracting pagination, sorting, filtering, and search parameters from the HTTP request and passing them to your criteria transfer.

---

### Part 3: Repository (Merchant-Scoped Query)

The repository builds a Propel query that only returns suppliers assigned to the current merchant.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Persistence/SupplierMerchantPortalGuiRepository.php`:

In `getSupplierTableData()`:

1. Get a fresh `PyzSupplierQuery` from the factory
2. Join with `PyzMerchantToSupplier` and filter by merchant reference:
   ```php
   $supplierQuery
       ->usePyzMerchantToSupplierQuery()
           ->useSpyMerchantQuery()
               ->filterByMerchantReference($criteriaTransfer->getMerchantReference())
           ->endUse()
       ->endUse();
   ```
3. Apply search filter on name/description/email if `searchTerm` is set
4. Apply status filter if `filterStatus` is set
5. Count total before pagination
6. Apply sorting and pagination
7. Map each `PyzSupplier` entity to a `GuiTableRowDataResponseTransfer` with keys matching the column IDs

> **Propel nested joins:** `usePyzMerchantToSupplierQuery()` creates a JOIN with the bridge table. `useSpyMerchantQuery()` then joins with the merchant table to filter by reference.

---

### Part 4: Controller

The controller has two actions: one for the page and one for AJAX table data.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Controller/SupplierController.php`:

1. `indexAction()` — return `viewResponse` with `supplierTableConfiguration` from the configuration provider
2. `tableDataAction()` — use `GuiTableHttpDataRequestExecutor::execute()` with the data provider and configuration

---

### Part 5: Angular Component Wiring

The Angular components are provided. You need to register them as web components.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Components/app/components.module.ts`:

Add `SupplierListComponent` to the `WebComponentsModule.withComponents([...])` array. This transforms the Angular component into a custom HTML element (`<web-mp-supplier-list>`) that Twig can use.

> **Web Components pattern:** Spryker uses `@spryker/web-components` to bridge Angular components with server-rendered Twig. The `withComponents([...])` call registers each Angular component as a custom element with the `web-` prefix added to its selector.

---

## Testing

After completing all parts:

```bash
docker/sdk console cache:empty-all
```

1. Log in to the Merchant Portal (e.g., `mp.eu.spryker.local`)
2. You should see "Suppliers" in the navigation
3. The table should show only suppliers assigned to your merchant
4. Try the search, status filter, and column sorting

---

## Solution

```bash
./exercises/load.sh supplier intermediate/merchant-portal-table/complete
```
