# Exercise 17: Merchant Portal — Supplier Locations (Nested Table)

In this exercise, you will add an editable locations table inside the supplier edit drawer. This teaches the pattern for nested tables within forms — similar to how Spryker's ProductOffer module embeds a price table inside the offer edit form.

You will learn how to:
- Build an editable GuiTable with inline add/edit capabilities
- Configure `enableAddingNewRows()` for adding rows to the table
- Implement a Symfony form data transformer for nested table data
- Embed a GuiTable inside a form template
- Register a nested Angular table component

## Prerequisites

- Completed Exercise 16 (Merchant Portal Form)

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/merchant-portal-locations/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console cache:empty-all
```

---

## Background: Editable GuiTable Pattern

A regular GuiTable displays read-only data. An **editable GuiTable** allows inline editing and adding of rows, with the data submitted as part of a parent form.

```
Edit Supplier drawer
├── Supplier Details card (name, description)
├── Contact Info card (email, phone)
├── Status card (isActive)
└── Locations card
    └── Editable GuiTable
        ├── Existing location rows (editable)
        ├── "Add Location" button → new empty row
        └── Hidden form inputs: supplierForm[locations][0][city], etc.
```

When the form is submitted, the table data is sent as nested form fields. A **data transformer** converts between the transfer objects and the array format the table uses.

---

## Working on the Exercise

### Part 1: Location GuiTable Configuration

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/ConfigurationProvider/SupplierLocationGuiTableConfigurationProvider.php`:

1. Add editable columns using `addEditableColumnInput()`:
   - `city` → text input
   - `country` → text input
   - `address` → text input
   - `zipCode` → text input
   - `isDefault` → checkbox input

2. Enable adding new rows:
   ```php
   $guiTableConfigurationBuilder->enableAddingNewRows(
       static::FORM_INPUT_NAME,  // 'supplierForm[locations]'
       $initialData,
       ['title' => 'Add Location', 'variant' => 'outline'],  // Add button
       ['title' => 'Cancel', 'variant' => 'outline'],        // Cancel button
   );
   ```

> **`enableAddingNewRows()`** tells the GuiTable to render an "Add" button that creates empty editable rows. The `FORM_INPUT_NAME` determines how the data is submitted as form fields.

> **`addEditableColumnInput()`** vs `addColumnText()`: Editable columns render as form inputs (text, checkbox, select) instead of plain text.

---

### Part 2: Location Data Provider

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/DataProvider/SupplierLocationGuiTableDataProvider.php`:

In `getData($idSupplier)`:
1. Query `PyzSupplierLocationQuery` filtered by `fkSupplier`
2. Map each location entity to a `GuiTableRowDataResponseTransfer` with: `idSupplierLocation`, `city`, `country`, `address`, `zipCode`, `isDefault`

---

### Part 3: Location Form Transformer

The transformer converts between `SupplierLocationTransfer[]` (PHP) and the array format (editable table rows).

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierMerchantPortalGui/Communication/Form/Transformer/SupplierLocationTransformer.php`:

1. `transform()` — convert `ArrayObject<SupplierLocationTransfer>` to array of arrays. Each array has: `idSupplierLocation`, `city`, `country`, `address`, `zipCode`, `isDefault`.

2. `reverseTransform()` — convert submitted array data back to `ArrayObject<SupplierLocationTransfer>`. Create a `SupplierLocationTransfer` for each row.

> **DataTransformerInterface:** Symfony's form component calls `transform()` when rendering the form (PHP → view) and `reverseTransform()` when handling submission (view → PHP).

---

### Part 4: Angular Component Wiring

**Coding time:**

Open `components.module.ts` and add `SupplierLocationsTableComponent` to `WebComponentsModule.withComponents([...])`.

The template already includes the locations card with `<web-mp-supplier-locations-table>` — it renders conditionally when `supplierLocationTableConfiguration` is present (only in the edit drawer, not create).

---

## Testing

```bash
docker/sdk console cache:empty-all
```

1. Edit an existing supplier in the Merchant Portal
2. The "Locations" card should appear with existing locations
3. Click "Add Location" → a new editable row should appear
4. Fill in the location fields and save
5. Re-open the edit drawer → the new location should be listed

---

## Solution

```bash
./exercises/load.sh supplier intermediate/merchant-portal-locations/complete
```
