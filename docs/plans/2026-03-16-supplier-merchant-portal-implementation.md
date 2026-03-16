# Supplier Merchant Portal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build three progressive exercises teaching the Merchant Portal architecture: supplier table (GuiTable), create/edit form (drawer), and nested locations table.

**Architecture:** New `SupplierMerchantPortalGui` module in the supplier package following the Spryker Merchant Portal patterns: PHP controllers return GuiTable configurations as JSON, Angular web components render the UI. Data is scoped to the current merchant via `pyz_merchant_to_supplier`. ACL plugins and navigation XML are provided.

**Tech Stack:** PHP 8.1+ (Symfony Forms, Propel ORM), Angular 15+ (Web Components), Spryker GuiTable Framework, Twig

**Reference module:** `vendor/spryker/product-offer-merchant-portal-gui/src/Spryker/Zed/ProductOfferMerchantPortalGui/`

---

## Phase 1: Exercise 15 — Supplier Table (complete branch)

Build the full working implementation first, then create the skeleton by removing key code.

### Task 1: Transfer XML and navigation config

**Files:**
- Create: `src/SprykerAcademy/Shared/SupplierMerchantPortalGui/Transfer/supplier_merchant_portal_gui.transfer.xml`
- Create: `config/Zed/navigation-main-merchant-portal.xml`

**Step 1:** Create the transfer XML with `SupplierMerchantPortalTableCriteria` transfer (properties: merchantReference string, filterStatus int, orderBy string, orderDirection string, page int, pageSize int, searchTerm string).

**Step 2:** Create the merchant portal navigation XML with `<supplier-merchant-portal-gui>` entry pointing to bundle `supplier-merchant-portal-gui`, controller `supplier`, action `index`, icon `handshake`.

**Step 3:** Commit: `Add transfer XML and navigation for merchant portal supplier table`

---

### Task 2: ACL plugin

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Plugin/AclMerchantPortal/SupplierMerchantPortalGuiMerchantAclRuleExpanderPlugin.php`

**Step 1:** Create the ACL plugin implementing `MerchantAclRuleExpanderPluginInterface`. The `expand()` method adds a `RuleTransfer` allowing all controllers/actions for bundle `supplier-merchant-portal-gui`.

Follow the exact pattern from `ProductOfferMerchantPortalGuiMerchantAclRuleExpanderPlugin`.

**Step 2:** Commit: `Add ACL rule plugin for supplier merchant portal`

---

### Task 3: DependencyProvider

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/SupplierMerchantPortalGuiDependencyProvider.php`

**Step 1:** Create the DependencyProvider extending `AbstractBundleDependencyProvider`. Register these dependencies in `provideCommunicationLayerDependencies()`:
- `FACADE_MERCHANT_USER` — `MerchantUserFacadeInterface` via locator
- `FACADE_SUPPLIER` — `SupplierFacadeInterface` via locator
- `SERVICE_GUI_TABLE_FACTORY` — `GuiTableFactoryInterface`
- `SERVICE_GUI_TABLE_HTTP_DATA_REQUEST_EXECUTOR` — `GuiTableHttpDataRequestExecutorInterface`
- `SERVICE_ZED_UI_FACTORY` — `ZedUiFactoryInterface`

And `providePersistenceLayerDependencies()`:
- Propel query for `PyzSupplierQuery` and `PyzMerchantToSupplierQuery`

**Step 2:** Commit: `Add SupplierMerchantPortalGui DependencyProvider`

---

### Task 4: Repository (merchant-scoped supplier query)

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Persistence/SupplierMerchantPortalGuiRepository.php`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Persistence/SupplierMerchantPortalGuiRepositoryInterface.php`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Persistence/SupplierMerchantPortalGuiPersistenceFactory.php`

**Step 1:** Create the repository interface with method `getSupplierTableData(SupplierMerchantPortalTableCriteriaTransfer): GuiTableDataResponseTransfer`.

**Step 2:** Implement the repository. Build a Propel query that:
- Joins `PyzSupplierQuery` with `PyzMerchantToSupplier` via `useSpyMerchantToSupplierQuery()`
- Filters by `merchantReference` from the criteria
- Applies search term filter on name/description/email
- Applies status filter if set
- Applies sorting (orderBy + direction)
- Applies pagination (page + pageSize)
- Maps results to `GuiTableDataResponseTransfer` with rows containing: idSupplier, name, description, status, email, phone

**Step 3:** Create the PersistenceFactory providing `PyzSupplierQuery` and `PyzMerchantToSupplierQuery`.

**Step 4:** Commit: `Add merchant-scoped supplier repository for GuiTable`

---

### Task 5: GuiTable Configuration Provider

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/ConfigurationProvider/SupplierGuiTableConfigurationProvider.php`

**Step 1:** Create the configuration provider. Use `GuiTableFactory::createConfigurationBuilder()` to build:

**Columns:**
- `name` — `addColumnText('name', 'Name')`
- `description` — `addColumnText('description', 'Description')`
- `status` — `addColumnChip('status', 'Status', ...)` with color map (1=green/Active, 0=gray/Inactive)
- `email` — `addColumnText('email', 'Email')`
- `phone` — `addColumnText('phone', 'Phone')`

**Filters:**
- `addFilterSelect('status', 'Status', false, [1 => 'Active', 0 => 'Inactive'])`

**Row actions:**
- `addRowActionDrawerAjaxForm('edit', 'Edit', '/supplier-merchant-portal-gui/update-supplier?id-supplier=${row.idSupplier}')`

**Data source:** `/supplier-merchant-portal-gui/supplier/table-data`

**Page size:** 25

**Step 2:** Commit: `Add supplier GuiTable configuration provider`

---

### Task 6: GuiTable Data Provider

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/DataProvider/SupplierGuiTableDataProvider.php`

**Step 1:** Create the data provider extending `AbstractGuiTableDataProvider`.

- `createCriteria()` — create `SupplierMerchantPortalTableCriteriaTransfer` with `merchantReference` from `MerchantUserFacade::getCurrentMerchantUser()->getMerchant()->getMerchantReference()`
- `fetchData()` — delegate to `SupplierMerchantPortalGuiRepository::getSupplierTableData()`

**Step 2:** Commit: `Add supplier GuiTable data provider`

---

### Task 7: Communication Factory

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/SupplierMerchantPortalGuiCommunicationFactory.php`

**Step 1:** Create the factory with methods:
- `createSupplierGuiTableConfigurationProvider()` — returns new provider with `GuiTableFactory`
- `createSupplierGuiTableDataProvider()` — returns new provider with `MerchantUserFacade` and repository
- `getGuiTableHttpDataRequestExecutor()` — returns service from container
- `getMerchantUserFacade()` — returns facade from container
- `getSupplierFacade()` — returns facade from container

**Step 2:** Commit: `Add SupplierMerchantPortalGui CommunicationFactory`

---

### Task 8: Controller

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Controller/SupplierController.php`

**Step 1:** Create the controller extending `AbstractController` with:
- `indexAction()` — returns `$this->viewResponse(['supplierTableConfiguration' => $this->getFactory()->createSupplierGuiTableConfigurationProvider()->getConfiguration()])`
- `tableDataAction(Request $request)` — returns `$this->getFactory()->getGuiTableHttpDataRequestExecutor()->execute($request, $this->getFactory()->createSupplierGuiTableDataProvider(), $this->getFactory()->createSupplierGuiTableConfigurationProvider()->getConfiguration())`

**Step 2:** Commit: `Add supplier list controller for merchant portal`

---

### Task 9: Angular components (given to students)

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Components/app/supplier-list/supplier-list.component.ts`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Components/app/supplier-list/supplier-list.component.html`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Components/app/supplier-list/supplier-list.module.ts`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Components/app/components.module.ts`

**Step 1:** Create the Angular supplier-list component following `OffersListComponent` pattern:
- Selector: `mp-supplier-list`
- Inputs: `@Input() tableConfig: TableConfig`, `@Input() tableId?: string`
- Template: `<spy-headline>` with `<ng-content>` slots for title and action button, then `<spy-table>` with config binding

**Step 2:** Create `supplier-list.module.ts` importing `CommonModule`, `HeadlineModule`, `TableModule`.

**Step 3:** Create `components.module.ts` importing `WebComponentsModule.withComponents([SupplierListComponent])` and `SupplierListModule`.

**Step 4:** Commit: `Add Angular supplier list component`

---

### Task 10: Twig template

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Supplier/index.twig`

**Step 1:** Create the template extending `@ZedUi/Layout/merchant-layout-main.twig`:

```twig
{% block headTitle %}{{ 'Suppliers' | trans }}{% endblock %}

{% block content %}
    <web-mp-supplier-list
        cloak
        table-id="web-mp-supplier-list"
        table-config='{{ guiTableConfiguration(supplierTableConfiguration) }}'>
        <h1 title>{{ 'Suppliers' | trans }}</h1>
        <web-spy-button-link
            action
            url="/supplier-merchant-portal-gui/create-supplier"
            size="lg"
            variant="primary">
            {{ 'Add Supplier' | trans }}
        </web-spy-button-link>
    </web-mp-supplier-list>
{% endblock %}
```

**Step 2:** Commit: `Add supplier list Twig template for merchant portal`

---

### Task 11: AclMerchantPortal override for load.sh

**Files:**
- Create: `src/SprykerAcademy/Zed/AclMerchantPortal/AclMerchantPortalDependencyProvider.php`

**Step 1:** Create the SprykerAcademy override extending `Pyz\Zed\AclMerchantPortal\AclMerchantPortalDependencyProvider`. Override `getMerchantAclRuleExpanderPlugins()` to merge parent plugins with the new `SupplierMerchantPortalGuiMerchantAclRuleExpanderPlugin`.

**Step 2:** Commit: `Add AclMerchantPortal override for supplier merchant portal`

---

### Task 12: Update load.sh for merchant portal navigation

**Files:**
- Modify: `packages/instructor-exercises/load.sh`

**Step 1:** Add navigation merge logic for `navigation-main-merchant-portal.xml` — same pattern as the existing `navigation.xml` merge but targeting the merchant portal file.

**Step 2:** Commit: `Add merchant portal navigation merge to load.sh`

---

### Task 13: Create skeleton branch

**Step 1:** From the complete branch, create the skeleton by removing implementation from:
- `SupplierGuiTableConfigurationProvider` — leave empty `getConfiguration()` with TODOs
- `SupplierGuiTableDataProvider` — leave empty `createCriteria()` and `fetchData()` with TODOs
- `SupplierMerchantPortalGuiRepository` — leave empty `getSupplierTableData()` with TODOs
- `SupplierController` — leave empty `indexAction()` and `tableDataAction()` with TODOs
- `components.module.ts` — leave empty `withComponents([])` — student registers the component

Keep intact: DependencyProvider, Factory, ACL plugin, Angular components, Twig template, transfers, navigation.

**Step 2:** Commit on skeleton branch: `Supplier merchant portal table skeleton`

---

## Phase 2: Exercise 16 — Supplier Create/Edit Form (complete branch)

Build on top of Exercise 15 complete.

### Task 14: SupplierForm (Symfony form type)

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Form/SupplierForm.php`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Form/DataProvider/SupplierFormDataProvider.php`

**Step 1:** Create `SupplierForm` extending `AbstractType`:
- `FIELD_NAME = 'name'`, `FIELD_DESCRIPTION = 'description'`, `FIELD_EMAIL = 'email'`, `FIELD_PHONE = 'phone'`, `FIELD_IS_ACTIVE = 'isActive'`
- `configureOptions()` — set `data_class` to `SupplierTransfer::class`
- `buildForm()` — add TextType for name (required), TextareaType for description, EmailType for email (required), TextType for phone, CheckboxType for isActive (required=false)
- `getBlockPrefix()` — return `'supplierForm'`

**Step 2:** Create `SupplierFormDataProvider` with:
- `getData(?int $idSupplier)` — returns existing SupplierTransfer (via facade) or new empty one
- `getOptions()` — returns form options array

**Step 3:** Commit: `Add SupplierForm and form data provider`

---

### Task 15: Create and Update controllers

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Controller/CreateSupplierController.php`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Controller/UpdateSupplierController.php`

**Step 1:** Create `CreateSupplierController` extending `AbstractController`:
- `indexAction(Request $request): Response`
- Creates form via factory
- Handles request
- On valid submit: create supplier via facade, then create `PyzMerchantToSupplier` entry linking to current merchant
- Returns `JsonResponse` using `ZedUiFormResponseBuilder` with: `addSuccessNotification('Supplier created')`, `addActionCloseDrawer()`, `addActionRefreshTable()`
- On GET or invalid: render form view

**Step 2:** Create `UpdateSupplierController` — same pattern but loads existing supplier by `id-supplier` request param, calls `updateSupplier()` on facade.

**Step 3:** Update the CommunicationFactory with form creation methods:
- `createSupplierForm(?SupplierTransfer $data, array $options)` — creates and returns the form
- `createSupplierFormDataProvider()` — returns the data provider
- `getZedUiFactory()` — returns ZedUi service

**Step 4:** Commit: `Add create and update supplier controllers for merchant portal`

---

### Task 16: Angular edit component and Twig form template

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Components/app/edit-supplier/edit-supplier.component.ts`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Components/app/edit-supplier/edit-supplier.component.html`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Components/app/edit-supplier/edit-supplier.module.ts`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Partials/_supplier_form.twig`
- Update: `components.module.ts` — add `EditSupplierComponent`

**Step 1:** Create the Angular edit-supplier component following the `EditOfferComponent` pattern:
- Selector: `mp-edit-supplier`
- Named content slots: `[title]`, `[action]`
- Simple wrapper component

**Step 2:** Create `_supplier_form.twig` extending `@ZedUi/Layout/merchant-layout-centered.twig`:
- Use `@ZedUi/Form/form-webcomponent-layout.twig` form theme
- Wrap in `<web-mp-edit-supplier>`
- Card sections for: Supplier Details (name, description), Contact Info (email, phone), Status (isActive)
- Each field uses `{{ form_row(form.children.fieldName) }}`

**Step 3:** Update `components.module.ts` to register `EditSupplierComponent` in `withComponents([...])`.

**Step 4:** Commit: `Add edit supplier Angular component and form template`

---

### Task 17: Create skeleton branch for Exercise 16

**Step 1:** From Exercise 16 complete, create skeleton by removing:
- `SupplierForm::buildForm()` — leave empty with TODOs for each field
- `CreateSupplierController::indexAction()` — leave stub with TODO for form handling
- `UpdateSupplierController::indexAction()` — leave stub with TODO
- `components.module.ts` — remove `EditSupplierComponent` from `withComponents()` — student adds it

Keep intact: Form data provider, Angular components, Twig template, factory methods.

**Step 2:** Commit on skeleton branch: `Supplier merchant portal form skeleton`

---

## Phase 3: Exercise 17 — Supplier Locations Nested Table (complete branch)

Build on top of Exercise 16 complete.

### Task 18: Location GuiTable configuration and data provider

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/ConfigurationProvider/SupplierLocationGuiTableConfigurationProvider.php`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/DataProvider/SupplierLocationGuiTableDataProvider.php`

**Step 1:** Create the location configuration provider with:
- Editable columns: city (text input), country (text input), address (text input), zip_code (text input), is_default (checkbox)
- `enableAddingNewRows()` with form input name `supplierForm[locations]`
- Add/Cancel button configuration

**Step 2:** Create the location data provider that:
- Receives `idSupplier` in criteria
- Queries `PyzSupplierLocationQuery` filtered by `fkSupplier`
- Maps results to `GuiTableDataResponseTransfer`

**Step 3:** Commit: `Add supplier location GuiTable configuration and data provider`

---

### Task 19: Location form transformer and form extension

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Form/Transformer/SupplierLocationTransformer.php`
- Modify: `SupplierForm.php` — add locations field

**Step 1:** Create `SupplierLocationTransformer` implementing `DataTransformerInterface`:
- `transform()` — converts `SupplierLocationTransfer[]` to array for the editable table
- `reverseTransform()` — converts submitted table data back to `SupplierLocationTransfer[]`

**Step 2:** Extend `SupplierForm::buildForm()` to add a `HiddenType` field for locations with the model transformer attached.

**Step 3:** Update `UpdateSupplierController` to:
- Pass location table configuration to the form view
- Save locations alongside supplier on submit (create/update/delete)

**Step 4:** Commit: `Add supplier location form transformer and nested table`

---

### Task 20: Angular locations table component

**Files:**
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Components/app/supplier-locations-table/supplier-locations-table.component.ts`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Components/app/supplier-locations-table/supplier-locations-table.component.html`
- Create: `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Presentation/Components/app/supplier-locations-table/supplier-locations-table.module.ts`
- Update: `_supplier_form.twig` — add locations table section
- Update: `components.module.ts` — add `SupplierLocationsTableComponent`

**Step 1:** Create the locations table component:
- Selector: `mp-supplier-locations-table`
- Inputs: `@Input() tableConfig: TableConfig`, `@Input() tableId?: string`
- Template: `<spy-table>` with config binding

**Step 2:** Update `_supplier_form.twig` to include a card section for locations:
```twig
<web-spy-card spy-title="{{ 'Locations' | trans }}">
    <web-mp-supplier-locations-table
        table-id="web-mp-supplier-locations"
        config='{{ guiTableConfiguration(supplierLocationTableConfiguration) }}'>
    </web-mp-supplier-locations-table>
</web-spy-card>
```

**Step 3:** Update `components.module.ts` to register `SupplierLocationsTableComponent`.

**Step 4:** Commit: `Add supplier locations table Angular component and template`

---

### Task 21: Create skeleton branch for Exercise 17

**Step 1:** From Exercise 17 complete, create skeleton by removing:
- `SupplierLocationGuiTableConfigurationProvider::getConfiguration()` — leave empty with TODOs
- `SupplierLocationGuiTableDataProvider::fetchData()` — leave empty with TODOs
- `SupplierLocationTransformer` — leave stubs with TODOs
- `components.module.ts` — remove `SupplierLocationsTableComponent` from `withComponents()`

Keep intact: Angular components, updated Twig template, factory methods.

**Step 2:** Commit on skeleton branch: `Supplier merchant portal locations skeleton`

---

## Phase 4: Guides and Presentation

### Task 22: Write exercise guides

**Files:**
- Create: `guides/intermediate/09-merchant-portal-table.md`
- Create: `guides/intermediate/10-merchant-portal-form.md`
- Create: `guides/intermediate/11-merchant-portal-locations.md`

**Step 1:** Write guide for Exercise 15 covering:
- Merchant Portal architecture overview (GuiTable, Angular web components, data providers)
- Navigation registration in `navigation-main-merchant-portal.xml`
- ACL setup explanation
- Step-by-step: configuration provider, data provider, repository, controller
- Angular component wiring in `components.module.ts`
- Testing instructions

**Step 2:** Write guide for Exercise 16 covering:
- Merchant Portal form pattern (drawer forms, JSON responses, ZedUI actions)
- Symfony form type creation
- Create vs Update controller pattern
- Angular component wiring
- Testing: create and edit via merchant portal

**Step 3:** Write guide for Exercise 17 covering:
- Editable GuiTable pattern
- Nested tables in forms
- Form data transformers
- Parent-child entity persistence
- Testing: add/edit/remove locations

**Step 4:** Commit: `Add merchant portal exercise guides`

---

### Task 23: Update presentation slides

**Files:**
- Modify: `guides-html/spryker-academy-intermediate-presentation.html`

**Step 1:** Add slides for exercises 15-17 covering:
- Merchant Portal architecture diagram
- GuiTable pattern
- Data provider flow
- Form drawer lifecycle
- Nested table pattern

**Step 2:** Update the agenda slide to include exercises 15-17.

**Step 3:** Commit: `Add merchant portal slides to intermediate presentation`

---

### Task 24: Update load.sh

**Files:**
- Modify: `packages/instructor-exercises/load.sh`

**Step 1:** Add `navigation-main-merchant-portal.xml` merge logic (same pattern as existing navigation merge, targeting the MP navigation file).

**Step 2:** Update the usage section with the new branch names.

**Step 3:** Update the test command section for the new exercises.

**Step 4:** Commit: `Update load.sh for merchant portal exercises`

---

## Verification Checklist

After all tasks, verify:

1. `./exercises/load.sh supplier intermediate/merchant-portal-table/complete` loads correctly
2. `docker/sdk console c:e` runs without errors
3. Merchant Portal at `mp.eu.spryker.local` shows "Suppliers" in navigation
4. Supplier table shows only the current merchant's suppliers
5. Create/edit drawer works with form submission
6. Locations nested table saves correctly
7. Skeleton branches have appropriate TODOs
8. All branches pushed to remote
