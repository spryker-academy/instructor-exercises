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
./exercises/load.sh supplier intermediate/merchant-portal-form/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console cache:empty-all
```

---

## Background: Merchant Portal Form Pattern

Unlike the Back Office (which uses full page reloads), the Merchant Portal uses **drawer forms** that open as side panels over the table:

```
Table row action "Edit" clicked
    → AJAX GET /supplier-merchant-portal-gui/update-supplier?id-supplier=5
    → Controller renders form HTML as JsonResponse
    → Angular opens drawer with the HTML content

Form submitted
    → AJAX POST to same URL
    → Controller validates form
    → If valid: returns ZedUiFormResponse with actions
        → addSuccessNotification("Supplier updated")
        → addActionCloseDrawer()
        → addActionRefreshTable()
    → Angular executes actions: closes drawer, refreshes table, shows toast
    → If invalid: returns re-rendered form HTML with errors
```

**Key difference from Back Office:** Controllers return `JsonResponse` (not `viewResponse`), and the response contains either rendered HTML (for the form) or a ZedUI action payload (after successful submit).

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
     $this->getFactory()->getZedUiFactory()
         ->createZedUiFormResponseBuilder()
         ->addSuccessNotification('Supplier created successfully.')
         ->addActionCloseDrawer()
         ->addActionRefreshTable()
         ->createResponse();
     ```
5. Otherwise: render the form template as `JsonResponse`

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
```

1. In the Merchant Portal supplier table, click "Add Supplier" → the create form should open
2. Fill in the form and submit → supplier should be created and table refreshed
3. Click "Edit" on a table row → the edit drawer should open with pre-filled data
4. Update and submit → changes should be saved

---

## Solution

```bash
./exercises/load.sh supplier intermediate/merchant-portal-form/complete
```
