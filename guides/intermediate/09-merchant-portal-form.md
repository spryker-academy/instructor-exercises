# Exercise 16: Merchant Portal — Supplier Create/Edit Form

In this exercise, you will add create and edit functionality for suppliers in the Merchant Portal using drawer forms. You will learn the Merchant Portal form pattern: Symfony forms rendered in Angular drawers, with JSON responses controlling the UI lifecycle (close drawer, refresh table, show notifications).

You will learn how to:
- Create a Symfony form type for the Merchant Portal
- Build create and update controllers that return `JsonResponse`
- Use `ZedUiFormResponseBuilder` for drawer actions (close, refresh, notify)
- Auto-link new suppliers to the current merchant
- Register an Angular edit component as a web component

## Prerequisites

- Completed Exercise 15 (Merchant Portal Table)

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/merchant-portal-form/skeleton --run
```

`--run` also runs the commands the loader lists after loading (cache, Propel, transfers and whatever this exercise needs, such as queues or Glue resources) and stops at the first one that fails. Leave it out to run them yourself.

---

## Background: Merchant Portal Form Pattern

Unlike the Back Office (which uses full page reloads), the Merchant Portal uses **drawer forms** that open as side panels over the table:

```
Table row action "Edit" clicked
    → AJAX GET /supplier-merchant-portal-gui/update-supplier?id-supplier=5
    → Controller answers {"form": "<rendered form HTML>"}
    → Angular opens the drawer with that HTML

Form submitted
    → AJAX POST to same URL
    → Controller validates form
    → If valid: returns ZedUiFormResponse with actions
        → addSuccessNotification("Supplier updated")
        → addActionCloseDrawer()
        → addActionRefreshTable()
    → Angular executes actions: closes drawer, refreshes table, shows toast
    → If invalid: returns {"form": ...} again, re-rendered with the errors
```

**Key difference from Back Office:** Controllers return `JsonResponse` (not `viewResponse`). The drawer's ajax form reads two things from it: `form`, the HTML it shows, and the ZedUi actions and notifications after a successful submit.

The provided template `Presentation/Partials/_supplier_form.twig` is drawer content, not a page: it extends no layout, and `form_start(form, { attr: { excludeFormTag: true } })` leaves the `<form>` tag out, because the drawer's ajax form wraps the content in its own. The "Add Supplier" button of the supplier list (`<web-spy-button-action>`) opens `/supplier-merchant-portal-gui/create-supplier` in such a drawer; a table row's "Edit" action opens `update-supplier`.

---

## Working on the Exercise

### Part 1: Supplier Form

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Form/SupplierForm.php`:

In `buildForm()`, add these fields:

| Field | Type | Options |
|-------|------|---------|
| `name` | `TextType` | required, `NotBlank` constraint |
| `description` | `TextareaType` | optional |
| `email` | `EmailType` | required, `NotBlank` constraint |
| `phone` | `TextType` | optional |
| `isActive` | `CheckboxType` | `property_path: 'status'`, not required |

> **`property_path`:** The `isActive` checkbox maps to the `status` field on `SupplierTransfer` via `property_path`. This lets the form display a friendly checkbox while the transfer uses an integer status.

A `CheckboxType` only accepts booleans as model data, but `status` is an integer (`1`/`0`). Without a transformer, opening the form fails with *"Unable to transform value for property path "status": Expected a Boolean"*. Add a model transformer to the field after the `add()` chain:

```php
$builder->get(static::FIELD_IS_ACTIVE)->addModelTransformer(new CallbackTransformer(
    fn (?int $status): bool => (bool)$status,
    fn (?bool $isActive): int => $isActive ? 1 : 0,
));
```

> **`getBlockPrefix()`:** Returns `'supplierForm'` — this determines the HTML form field name prefix (e.g., `supplierForm[name]`).

---

### Part 2: Create Supplier Controller

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Controller/CreateSupplierController.php`:

In `indexAction()`:

1. Get form data provider, create empty `SupplierTransfer`
2. Create the form via factory
3. Handle the request: `$form->handleRequest($request)`
4. If submitted and valid:
   - Create supplier via facade: `$this->getFactory()->getSupplierFacade()->createSupplier($supplierTransfer)`
   - Link to current merchant: create a `PyzMerchantToSupplier` entity
   - Return `JsonResponse` with ZedUI actions:
     ```php
     $zedUiFormResponseTransfer = $this->getFactory()->getZedUiFactory()
         ->createZedUiFormResponseBuilder()
         ->addSuccessNotification(static::MESSAGE_SUPPLIER_CREATED)
         ->addActionCloseDrawer()
         ->addActionRefreshTable(static::ID_TABLE_SUPPLIER_LIST) // the table-id of <web-mp-supplier-list>
         ->createResponse();

     return new JsonResponse($zedUiFormResponseTransfer->toArray(true, true));
     ```
5. Otherwise: render the form template and return it as `new JsonResponse(['form' => $html])` (the skeleton already does this part)

> **Merchant linking:** When a merchant creates a supplier, it must be automatically linked via `pyz_merchant_to_supplier`. Get the current merchant from `MerchantUserFacade::getCurrentMerchantUser()->getMerchantOrFail()`.

---

### Part 3: Update Supplier Controller

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Controller/UpdateSupplierController.php`:

Same pattern as create, but:
1. Read `id-supplier` from the request
2. Load existing supplier via form data provider
3. Throw `NotFoundHttpException` if supplier doesn't exist
4. On valid submit: call `updateSupplier()` instead of `createSupplier()`

---

### Part 4: Angular Component Wiring

**Coding time:**

Open `components.module.ts` and add `EditSupplierComponent` and `CardComponent` to `WebComponentsModule.withComponents([...])`.

The edit component (`<web-mp-edit-supplier>`) wraps the form content with named slots for title and action buttons.

The card component (`<web-spy-card>`) provides the card layout used in the form template to group related fields.

---

## Testing

```bash
docker/sdk console cache:empty-all
docker/sdk console propel:model:build
```

Part 4 changed a component, so rebuild the frontend first:

```bash
docker/sdk console frontend:mp:build
```

1. In the Merchant Portal supplier table, click "Add Supplier" → the create form should open
2. Fill in the form and submit → supplier should be created and table refreshed
3. Click "Edit" on a table row → the edit drawer should open with pre-filled data
4. Update and submit → changes should be saved

---

## Solution

```bash
./exercises/load.sh supplier intermediate/merchant-portal-form/complete --run
```
