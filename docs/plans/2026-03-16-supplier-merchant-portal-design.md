# Supplier Merchant Portal — Design Document

## Overview

Three new exercises (15-17) teaching the Merchant Portal architecture through the supplier module. Merchants manage their own suppliers and supplier locations via GuiTable-driven pages with Angular web components.

## Exercise Progression

| Exercise | Branch | Topic |
|----------|--------|-------|
| 15 | `intermediate/merchant-portal-table/*` | Supplier list table in Merchant Portal |
| 16 | `intermediate/merchant-portal-form/*` | Supplier create/edit via drawer form |
| 17 | `intermediate/merchant-portal-locations/*` | Supplier locations as nested editable table |

**Prerequisites:** Exercise 9 (Back Office) — students need the supplier facade, repository, and entity manager.

---

## Architecture

### Module: `SprykerAcademy\Zed\SupplierMerchantPortalGui`

```
src/SprykerAcademy/Zed/SupplierMerchantPortalGui/
├── Communication/
│   ├── Controller/
│   │   ├── SupplierController.php                    # List + table data
│   │   ├── CreateSupplierController.php              # Create form (drawer)
│   │   └── UpdateSupplierController.php              # Edit form (drawer)
│   ├── ConfigurationProvider/
│   │   ├── SupplierGuiTableConfigurationProvider.php
│   │   └── SupplierLocationGuiTableConfigurationProvider.php
│   ├── DataProvider/
│   │   ├── SupplierGuiTableDataProvider.php
│   │   └── SupplierLocationGuiTableDataProvider.php
│   ├── Form/
│   │   ├── SupplierForm.php
│   │   ├── DataProvider/SupplierFormDataProvider.php
│   │   └── Transformer/SupplierLocationTransformer.php
│   ├── Plugin/
│   │   └── AclMerchantPortal/
│   │       └── SupplierMerchantPortalGuiMerchantAclRuleExpanderPlugin.php
│   └── SupplierMerchantPortalGuiCommunicationFactory.php
├── Persistence/
│   ├── SupplierMerchantPortalGuiRepository.php
│   ├── SupplierMerchantPortalGuiRepositoryInterface.php
│   └── SupplierMerchantPortalGuiPersistenceFactory.php
├── Presentation/
│   ├── Components/app/
│   │   ├── supplier-list/                 # Given to students
│   │   │   ├── supplier-list.component.ts
│   │   │   ├── supplier-list.component.html
│   │   │   └── supplier-list.module.ts
│   │   ├── edit-supplier/                 # Given to students
│   │   │   ├── edit-supplier.component.ts
│   │   │   ├── edit-supplier.component.html
│   │   │   └── edit-supplier.module.ts
│   │   ├── supplier-locations-table/      # Given to students
│   │   │   ├── supplier-locations-table.component.ts
│   │   │   ├── supplier-locations-table.component.html
│   │   │   └── supplier-locations-table.module.ts
│   │   └── components.module.ts           # Student wires components here
│   ├── Supplier/
│   │   └── index.twig                     # List page
│   └── Partials/
│       └── _supplier_form.twig            # Form layout
├── SupplierMerchantPortalGuiConfig.php
└── SupplierMerchantPortalGuiDependencyProvider.php
```

---

## Navigation Registration (202602)

In Spryker 202602, the Merchant Portal has its own navigation file, separate from the back office `navigation.xml`:

**File:** `config/Zed/navigation-main-merchant-portal.xml`

The supplier entry to add:

```xml
<supplier-merchant-portal-gui>
    <label>Suppliers</label>
    <title>Suppliers</title>
    <icon>handshake</icon>
    <bundle>supplier-merchant-portal-gui</bundle>
    <controller>supplier</controller>
    <action>index</action>
</supplier-merchant-portal-gui>
```

**How load.sh handles it:**
- The supplier package provides `config/Zed/navigation-main-merchant-portal.xml` with the supplier entry
- `load.sh` merges it into the project's `config/Zed/navigation-main-merchant-portal.xml` (same merge pattern as back office navigation, extended to support the merchant portal file)

**What students learn:**
- Merchant Portal navigation is separate from back office navigation
- Each module contributes entries via its own navigation XML
- The navigation file is `navigation-main-merchant-portal.xml` (not `navigation.xml`)

---

## ACL Configuration

The Merchant Portal uses ACL (Access Control List) to control access. Two types of rules are needed:

### 1. Route ACL Rules

Each module must register its bundle with the ACL system so merchant users can access its controllers.

**Plugin:** `SupplierMerchantPortalGuiMerchantAclRuleExpanderPlugin`

```php
class SupplierMerchantPortalGuiMerchantAclRuleExpanderPlugin extends AbstractPlugin
    implements MerchantAclRuleExpanderPluginInterface
{
    public function expand(array $ruleTransfers): array
    {
        $ruleTransfers[] = (new RuleTransfer())
            ->setBundle('supplier-merchant-portal-gui')
            ->setController(static::RULE_VALIDATOR_WILDCARD)
            ->setAction(static::RULE_VALIDATOR_WILDCARD)
            ->setType(static::RULE_TYPE_ALLOW);

        return $ruleTransfers;
    }
}
```

**Registration:** In `AclMerchantPortalDependencyProvider::getMerchantAclRuleExpanderPlugins()`:
```php
new SupplierMerchantPortalGuiMerchantAclRuleExpanderPlugin(),
```

### 2. ACL Entity Rules

Propel entity access must be configured so merchant users can query `pyz_supplier`, `pyz_supplier_location`, and `pyz_merchant_to_supplier` tables.

**Plugin:** `SupplierMerchantPortalGuiAclEntityConfigurationExpanderPlugin`

Configures entity metadata for:
- `PyzSupplier` — accessible via `PyzMerchantToSupplier` relationship
- `PyzSupplierLocation` — accessible via `PyzSupplier` parent
- `PyzMerchantToSupplier` — scoped to current merchant

### Approach for Training

The ACL plugins are **provided pre-built** in the skeleton. Students register them in the dependency provider (one line each). The guide explains:
- WHY ACL rules are needed (merchant portal is multi-tenant)
- WHAT the route rules do (allow all controllers/actions in the bundle)
- WHAT entity rules do (scope database queries to the merchant's data)
- HOW to register new plugins when adding new modules

The `load.sh` script will handle registering the plugins in the project's `AclMerchantPortalDependencyProvider` via a SprykerAcademy override (same pattern as other dependency providers).

---

## Back Office Preparation

For the merchant portal to show suppliers, the data must exist:

1. **Suppliers exist** — from data import exercise (CSV) or back office creation
2. **Merchant-supplier links exist** — the `pyz_merchant_to_supplier` table must have entries for the logged-in merchant
3. **Demo merchant user** — students log in as a demo merchant (e.g., from b2b-demo-marketplace data)

The `SupplierWriterStep` in data import already supports a `merchant_ids` column that creates `pyz_merchant_to_supplier` entries. The supplier CSV should include merchant IDs for the demo merchants.

---

## Exercise 15: Merchant Portal — Supplier Table

### Goal
Display suppliers belonging to the current merchant using the GuiTable framework.

### What Students Build (PHP)

1. **SupplierGuiTableConfigurationProvider**
   - Columns: name, description, status (chip), email, phone
   - Filters: status (select: active/inactive)
   - Row actions: edit (drawer, AJAX form)
   - Data source URL: `/supplier-merchant-portal-gui/supplier/table-data`
   - Page size: 25

2. **SupplierGuiTableDataProvider** (extends `AbstractGuiTableDataProvider`)
   - `createCriteria()` — builds criteria with current merchant reference from `MerchantUserFacade`
   - `fetchData()` — queries repository for merchant-scoped suppliers, maps to `GuiTableRowDataResponseTransfer`

3. **SupplierMerchantPortalGuiRepository**
   - `getSupplierTableData(SupplierMerchantPortalTableCriteriaTransfer)` — Propel query joining `pyz_supplier` with `pyz_merchant_to_supplier`, filtered by merchant ID, with pagination and sorting

4. **SupplierController**
   - `indexAction()` — returns view with table configuration
   - `tableDataAction(Request)` — AJAX endpoint using `GuiTableHttpDataRequestExecutor`

### What Students Wire (Angular)

1. Register `SupplierListComponent` in `components.module.ts` using `WebComponentsModule.withComponents([...])`
2. Understand how the Twig template uses `<web-mp-supplier-list>` with `guiTableConfiguration()`
3. Review available Spryker Angular modules: `TableModule`, `HeadlineModule`, `ButtonLinkModule`

### Given in Skeleton
- Angular component files (`supplier-list.component.ts/html`, `supplier-list.module.ts`)
- Twig template `Supplier/index.twig`
- `DependencyProvider` with facade bridges
- ACL plugins (pre-built)
- Navigation XML entry

---

## Exercise 16: Merchant Portal — Supplier Create/Edit Form

### Goal
Add create and edit forms via drawer overlays.

### What Students Build (PHP)

1. **SupplierForm** (Symfony form type)
   - Fields: name (TextType), description (TextareaType), email (EmailType), phone (TextType), isActive (CheckboxType)
   - Data class: `SupplierTransfer`
   - Validation: NotBlank on required fields

2. **SupplierFormDataProvider**
   - `getData()` — returns empty or existing `SupplierTransfer`
   - `getOptions()` — provides form options

3. **CreateSupplierController**
   - GET: render form in drawer
   - POST: validate, create supplier via facade, link to current merchant via `pyz_merchant_to_supplier`
   - Returns `JsonResponse` with ZedUI actions: close drawer, refresh table, success notification

4. **UpdateSupplierController**
   - GET: render pre-filled form in drawer
   - POST: validate, update via facade
   - Returns `JsonResponse` with ZedUI actions

### What Students Wire (Angular)
1. Register `EditSupplierComponent` in `components.module.ts`
2. Use Spryker's Angular components in the template: `<web-spy-card>`, `<web-spy-form-item>`, `<web-spy-button>`
3. Understand the drawer lifecycle: row action → AJAX load → form submit → JSON response → drawer close + table refresh

### Given in Skeleton
- Angular edit component files
- Twig partial `_supplier_form.twig` with form layout using `<web-spy-card>` components
- Controller stubs with form creation boilerplate

---

## Exercise 17: Merchant Portal — Supplier Locations (Nested Table)

### Goal
Add an editable locations table inside the supplier edit drawer.

### What Students Build (PHP)

1. **SupplierLocationGuiTableConfigurationProvider**
   - Columns: city, country, address, zip_code, is_default
   - `enableAddingNewRows()` — allows inline adding of locations
   - Editable columns: all fields as text inputs, is_default as checkbox
   - Form input name integration: `supplierForm[locations][]`

2. **SupplierLocationGuiTableDataProvider**
   - Fetches locations for a specific supplier ID
   - Returns `GuiTableDataResponseTransfer` with location rows

3. **SupplierLocationTransformer** (form data transformer)
   - Transforms nested form array data to `SupplierLocationTransfer[]`
   - Handles add/edit/remove of locations

4. **Extend SupplierForm**
   - Add locations field backed by the editable GuiTable
   - Controller saves locations alongside supplier

### What Students Wire (Angular)
1. Register `SupplierLocationsTableComponent` in `components.module.ts`
2. Embed `<web-mp-supplier-locations-table>` inside the edit drawer template
3. Pass nested table config via `guiTableConfiguration()`

### Given in Skeleton
- Angular locations table component
- Updated `_supplier_form.twig` with slot for locations table
- SupplierLocation facade/persistence from earlier exercises

---

## Transfer Objects (New)

```xml
<transfer name="SupplierMerchantPortalTableCriteria">
    <property name="merchantReference" type="string"/>
    <property name="filterStatus" type="int"/>
    <property name="orderBy" type="string"/>
    <property name="orderDirection" type="string"/>
    <property name="page" type="int"/>
    <property name="pageSize" type="int"/>
    <property name="searchTerm" type="string"/>
</transfer>
```

---

## Dependencies

| Dependency | Used For |
|-----------|----------|
| `MerchantUserFacade` | Get current merchant context |
| `SupplierFacade` | CRUD operations on suppliers |
| `LocaleFacade` | Current locale |
| `TranslatorFacade` | Status label translation |
| `RouterFacade` | URL generation |
| `GuiTableFactory` (service) | Build table configurations |
| `ZedUiFactory` (service) | Build form responses |
| `GuiTableHttpDataRequestExecutor` (service) | Execute table data AJAX requests |

---

## Load.sh Changes

1. **Merchant Portal navigation merge** — extend `load.sh` to merge `navigation-main-merchant-portal.xml` (in addition to existing `navigation.xml` merge)
2. **ACL plugin registration** — create `SprykerAcademy\Zed\AclMerchantPortal\AclMerchantPortalDependencyProvider` extending Pyz, adding the supplier ACL plugins
3. **Supplier CSV merchant_ids** — ensure demo merchants are linked to imported suppliers

---

## What's NOT in Scope

- Writing Angular components from scratch (provided pre-built)
- Delete from merchant portal (stays in back office)
- ACL permission granularity beyond bundle-level allow
- Multi-store supplier management
- Supplier approval workflow
