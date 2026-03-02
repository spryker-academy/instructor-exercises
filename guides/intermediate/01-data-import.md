# Exercise 8: Data Import - Supplier

In this exercise, you will create a data import pipeline to populate the database with suppliers from a CSV file. You will learn how Spryker's `DataImport` module works: reading CSV files, processing data through steps, and persisting entities.

You will learn how to:
- Create and configure CSV data sources
- Map import types to YAML configuration
- Implement `DataImportStepInterface` for data processing and writing
- Chain steps through the `DataSetStepBroker`
- Expose the import through a Facade and Plugin
- Register the plugin in Spryker's data import stack
- Handle entity relationships (many-to-many) during import

## Prerequisites

- Completed the basics exercises (1-7)
- The Supplier module schema is provided (tables `pyz_supplier`, `pyz_supplier_location`, `pyz_merchant_to_supplier`)

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/data-import/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console propel:install
```

---

## Background: Spryker Data Import Architecture

Spryker's data import system processes external data (typically CSV files) through a pipeline of steps:

```
CSV File → DataImporter → DataSetStepBroker → [Step1] → [Step2] → [WriterStep] → Database
```

**Key components:**

| Component | Role |
|-----------|------|
| `DataImporterConfigurationTransfer` | Holds the CSV file path and import type |
| `DataImporter` | Reads CSV rows into `DataSet` objects |
| `DataSetStepBroker` | Orchestrates the execution of steps in order |
| `DataImportStepInterface` | Each step processes or writes one `DataSet` row |
| `DataImportPluginInterface` | Registers the import in Spryker's plugin stack |

The `DataSet` is an `ArrayAccess` object where keys match the CSV column headers:

```php
// For a CSV row: name,description,status
$dataSet['name'];        // "Acme Supplies"
$dataSet['description']; // "Leading supplier of industrial equipment"
$dataSet['status'];      // "active"
```

---

## Working on the Exercise

### Part 1: Database Structure

The exercise skeleton provides the Supplier module with the schema files:
- `src/SprykerAcademy/Zed/Supplier/Persistence/Propel/Schema/pyz_supplier.schema.xml`
- `src/SprykerAcademy/Zed/SupplierLocation/Persistence/Propel/Schema/pyz_supplier_location.schema.xml`

These define the tables `pyz_supplier` (with columns: id_supplier, name, description, status, email, phone) and `pyz_supplier_location` (with a FK to supplier).

Run propel to create the tables:

```bash
docker/sdk console propel:install
```

---

### Part 2: Data Source

#### 2.1 Review the CSV File

The exercise skeleton provides `data/import/supplier.csv`:

```csv
id_supplier,name,description,status,email,phone
1,Acme Supplies,Leading supplier of industrial equipment,active,contact@acmesupplies.com,+1-555-1234
2,Global Trade Partners,International trading company,active,info@globaltradepartners.com,+1-555-5678
3,TechSource Inc,Technology products supplier,active,sales@techsource.com,+1-555-9012
4,Green Earth Supply,Eco-friendly product supplier,active,hello@greenearth.com,+1-555-3456
```

The first row defines the column names — these become the keys in the `DataSet` object.

#### 2.2 Configure the Import YAML

The import YAML maps an import type to a CSV file path. This is already configured in the project's `data/import/local/full_EU.yml`.

Verify that the `data_entity` value matches the constant `SupplierDataImportConfig::IMPORT_TYPE_SUPPLIER` (`'supplier'`) and that the `source` points to the CSV file.

---

### Part 3: The SupplierDataImport Module

The module `SprykerAcademy\Zed\SupplierDataImport` follows Spryker's naming convention: `<ModuleName>DataImport`.

#### 3.1 Constants for Column Mapping

Review the provided file `src/SprykerAcademy/Zed/SupplierDataImport/Business/DataSet/SupplierDataSetInterface.php`. It defines constants that map to the CSV column names:

```php
interface SupplierDataSetInterface
{
    public const string COLUMN_NAME = 'name';
    public const string COLUMN_DESCRIPTION = 'description';
    public const string COLUMN_STATUS = 'status';
    public const string COLUMN_EMAIL = 'email';
    public const string COLUMN_PHONE = 'phone';
    public const string COLUMN_MERCHANT_IDS = 'merchant_ids';
}
```

**Verify** that the constant `COLUMN_NAME` matches the actual CSV column header. In the skeleton, it may be set to `'supplier_name'` instead of `'name'` — fix it if needed.

> **Best practice:** Always use constants for column names. Never use "magic strings" like `$dataSet['name']` directly — use `$dataSet[SupplierDataSetInterface::COLUMN_NAME]` instead.

#### 3.2 Implement the SupplierWriterStep

The `SupplierWriterStep` is where each CSV row gets persisted to the database. It receives a `DataSet` for each row.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierDataImport/Business/DataImportStep/SupplierWriterStep.php` and implement the `execute()` method:

1. **Find or create** the supplier entity:
   ```php
   $supplierEntity = PyzSupplierQuery::create()
       ->filterByName($dataSet[SupplierDataSetInterface::COLUMN_NAME])
       ->findOneOrCreate();
   ```
   `findOneOrCreate()` queries the database by name — if found, returns the existing entity; if not, creates a new (unsaved) entity with that name.

2. **Assign fields** from the dataset to the entity using setters:
   ```php
   $supplierEntity->setDescription($dataSet[SupplierDataSetInterface::COLUMN_DESCRIPTION]);
   $supplierEntity->setStatus($dataSet[SupplierDataSetInterface::COLUMN_STATUS]);
   $supplierEntity->setEmail($dataSet[SupplierDataSetInterface::COLUMN_EMAIL]);
   $supplierEntity->setPhone($dataSet[SupplierDataSetInterface::COLUMN_PHONE]);
   ```

3. **Save only if new or modified** — avoid unnecessary writes:
   ```php
   if ($supplierEntity->isNew() || $supplierEntity->isModified()) {
       $supplierEntity->save();
   }
   ```

4. **Handle merchant relations** (bonus): The CSV may contain a `merchant_ids` column with comma-separated IDs. Use `PyzMerchantToSupplierQuery` to check existing relations and only create missing ones. This demonstrates handling many-to-many relationships during import.

> **Why Propel in the Business Layer?** Data importers are one exception to the "no Propel in Business Layer" rule. Imports often process thousands of rows, so direct ORM access avoids the overhead of going through Repository/EntityManager for each row.

#### 3.3 Review the DescriptionToLowercaseStep

The skeleton provides `DescriptionToLowercaseStep` as an example of a **data processor step** — a step that transforms data without writing to the database:

```php
class DescriptionToLowercaseStep implements DataImportStepInterface
{
    public function execute(DataSetInterface $dataSet): void
    {
        $dataSet[SupplierDataSetInterface::COLUMN_DESCRIPTION] =
            strtolower($dataSet[SupplierDataSetInterface::COLUMN_DESCRIPTION]);
    }
}
```

This step runs **before** the WriterStep, so the writer receives already-transformed data. Steps are executed in the order they're added to the broker.

#### 3.4 Wire Steps in the BusinessFactory

The `SupplierDataImportBusinessFactory` creates the `DataImporter` and wires all steps together.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierDataImport/Business/SupplierDataImportBusinessFactory.php`. In the `getSupplierDataImport()` method:

1. Add the `DescriptionToLowercaseStep` to the `$dataSetStepBroker` (processor steps first)
2. Add the `SupplierWriterStep` to the `$dataSetStepBroker` (writer steps always last)
3. Add the `$dataSetStepBroker` to the `$dataImporter`

```php
$dataSetStepBroker->addStep($this->createDescriptionToLowercaseStep());
$dataSetStepBroker->addStep($this->createSupplierWriterStep());
$dataImporter->addDataSetStepBroker($dataSetStepBroker);
```

> **Step ordering matters:** Processor steps (lowercase, validation, etc.) run first. The WriterStep must be last — it persists the final, transformed data.

#### 3.5 Implement the Facade

The Facade exposes the import functionality to other modules and plugins.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierDataImport/Business/SupplierDataImportFacade.php`. In `importSupplier()`:

1. Use `$this->getFactory()` to get the `SupplierDataImportBusinessFactory`
2. Call `getSupplierDataImport($dataImporterConfigurationTransfer)` to get the configured DataImporter
3. Call `import($dataImporterConfigurationTransfer)` on it and return the result

```php
return $this->getFactory()
    ->getSupplierDataImport($dataImporterConfigurationTransfer)
    ->import($dataImporterConfigurationTransfer);
```

---

### Part 4: Pluginization

The plugin makes the import available through Spryker's standard `data:import` console command.

#### 4.1 Review the DataImportPlugin

The exercise provides `SupplierDataImportPlugin` which implements `DataImportPluginInterface`. It has two methods:

- `import()` — delegates to the Facade's `importSupplier()` method
- `getImportType()` — returns `SupplierDataImportConfig::IMPORT_TYPE_SUPPLIER`

The plugin extends `AbstractPlugin` which provides `getFacade()` — giving it access to the `SupplierDataImportFacade`.

#### 4.2 Register the Plugin

**Coding time:**

Open `src/Pyz/Zed/DataImport/DataImportDependencyProvider.php` in the project. Add an instance of `SupplierDataImportPlugin` to the array returned by `getDataImporterPlugins()`.

Also add `SupplierLocationDataImportPlugin` for the location import.

---

### Part 5: Run the Import

```bash
docker/sdk console data:import supplier
```

This will:
1. Read `supplier.csv`
2. For each row: run `DescriptionToLowercaseStep` (lowercase description) → `SupplierWriterStep` (persist to DB)
3. Output a report with the number of imported rows

You can also import supplier locations:

```bash
docker/sdk console data:import supplier-location
```

**Verify** the data exists in the database:
```bash
docker/sdk console propel:console
> SELECT * FROM pyz_supplier;
```

---

## Key Concepts Summary

### Step Pipeline

```
CSV Row → DescriptionToLowercaseStep → SupplierWriterStep → Database
            (processor: transforms)      (writer: persists)
```

- **Processor steps** modify the `DataSet` in-place (lowercase, trim, validate, enrich)
- **Writer steps** persist the `DataSet` to the database (Propel entities)
- Steps are chained via `DataSetStepBroker::addStep()` in the Factory

### PublishAwareStep (Preview of Publish & Synchronize)

In the complete solution, `SupplierWriterStep` extends `PublishAwareStep` instead of implementing `DataImportStepInterface` directly. This enables triggering publish events after saving:

```php
class SupplierWriterStep extends PublishAwareStep implements DataImportStepInterface
{
    public function execute(DataSetInterface $dataSet): void
    {
        // ... save entity ...
        $this->addPublishEvents(SupplierSearchConfig::SUPPLIER_PUBLISH, $supplierEntity->getIdSupplier());
        $this->addPublishEvents(SupplierStorageConfig::SUPPLIER_PUBLISH, $supplierEntity->getIdSupplier());
    }
}
```

These events trigger the **Publish & Synchronize** pipeline (next exercise) which pushes supplier data to Elasticsearch and Redis. This is how imported data flows through the entire Spryker architecture:

```
CSV → DataImport → Database → Event → Publisher → Search/Storage Table → Queue → Elasticsearch/Redis
```

### DependencyProvider Inheritance

The `SupplierDataImportDependencyProvider` extends `DataImportDependencyProvider` to inherit all dependencies the DataImport module needs (data reader, data set step broker, etc.). This is a common pattern when creating a module that extends a core module's functionality.

---

## Verify Your Work

After importing, check:
1. `pyz_supplier` table has 4 rows
2. Descriptions are lowercase (the `DescriptionToLowercaseStep` transformed them)
3. Run `data:import supplier` again — it should NOT create duplicates (the `findOneOrCreate()` pattern handles idempotency)

---

## Solution

```bash
./exercises/load.sh supplier intermediate/data-import/complete
```
