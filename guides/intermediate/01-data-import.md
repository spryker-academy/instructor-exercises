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

The `DataSet` is an `ArrayAccess` object where keys match the CSV column headers. For example, if your CSV has columns `name,description,status`, then inside a step you access them as `$dataSet['name']`, `$dataSet['description']`, etc. — but you should use constants instead of literal strings.

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

The exercise skeleton provides `data/import/supplier.csv` with 4 supplier rows. Open it and examine the column headers — these will become the keys in the `DataSet` object during import.

A `data/import/supplier_location.csv` is also provided for the location import.

#### 2.2 Configure the Import YAML

The import YAML (`data/import/local/full_EU.yml`) maps an import type to a CSV file path. Verify that:
- The `data_entity` value matches the constant `SupplierDataImportConfig::IMPORT_TYPE_SUPPLIER`
- The `source` points to the correct CSV file path

Look at how other entities are configured in the same file for reference.

---

### Part 3: The SupplierDataImport Module

The module `SprykerAcademy\Zed\SupplierDataImport` follows Spryker's naming convention: `<ModuleName>DataImport`.

#### 3.1 Constants for Column Mapping

Review the provided file `src/SprykerAcademy/Zed/SupplierDataImport/Business/DataSet/SupplierDataSetInterface.php`. It defines constants that map to the CSV column names.

**Verify** that the constant `COLUMN_NAME` matches the actual CSV column header. The skeleton may have a mismatch — compare the constant value with the first row of `supplier.csv` and fix it if needed.

> **Best practice:** Always use constants for column names. Never use literal strings like `$dataSet['name']` directly — use `$dataSet[SupplierDataSetInterface::COLUMN_NAME]` instead.

#### 3.2 Implement the SupplierWriterStep

The `SupplierWriterStep` is where each CSV row gets persisted to the database. It receives a `DataSet` for each row.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierDataImport/Business/DataImportStep/SupplierWriterStep.php` and implement the `execute()` method following the TODO steps:

1. **Find or create** the supplier entity. Propel query classes have a static `create()` method that returns a query builder. You can chain `filterBy<ColumnName>()` to build your query, then call `findOneOrCreate()` to either fetch an existing record or create a fresh (unsaved) entity.

2. **Assign fields** from the dataset to the entity. Use the entity's setter methods (`setDescription()`, `setStatus()`, etc.) and read values from `$dataSet` using the constants from `SupplierDataSetInterface`.

3. **Save conditionally.** Only persist the entity if it's actually new or has been modified. Propel entities provide `isNew()` and `isModified()` methods for this check.

4. **Handle merchant relations** (bonus). The CSV may contain a `merchant_ids` column with comma-separated IDs. Think about how to:
   - Parse the comma-separated string into an array of IDs
   - Query existing relations to avoid duplicates
   - Create only the missing relation records

> **Why Propel in the Business Layer?** Data importers are one exception to the "no Propel in Business Layer" rule. Imports often process thousands of rows, so direct ORM access avoids the overhead of going through Repository/EntityManager for each row.

> **Hint:** Look at the generated class `src/Orm/Zed/Supplier/Persistence/Base/PyzSupplierQuery.php` to see all available filter and finder methods.

#### 3.3 Implement the DescriptionToLowercaseStep

Before writing data to the database, we often need to normalize or transform it. The `DescriptionToLowercaseStep` is a **data processor step** — it transforms data without writing to the database.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierDataImport/Business/DataImportStep/DescriptionToLowercaseStep.php`. The class implements `DataImportStepInterface` and its `execute()` method receives a `DataSet` for each CSV row. Your task:

- Read the description value from the dataset using the appropriate constant
- Transform it to lowercase
- Write the result back to the same dataset key

This is a one-liner, but it demonstrates the processor step pattern: modify the `DataSet` in-place so the next step receives the transformed data.

> This step runs **before** the WriterStep. Steps are executed in the order they're added to the broker.

#### 3.4 Wire Steps in the BusinessFactory

The `SupplierDataImportBusinessFactory` creates the `DataImporter` and wires all steps together.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierDataImport/Business/SupplierDataImportBusinessFactory.php`. In the `getSupplierDataImport()` method, you need to:

1. Add the processor step to the `$dataSetStepBroker`
2. Add the writer step to the `$dataSetStepBroker`
3. Add the step broker to the `$dataImporter`

The broker has an `addStep()` method. The importer has an `addDataSetStepBroker()` method. The factory already has `create*Step()` methods you can call.

> **Step ordering matters:** Processor steps (lowercase, validation, enrichment) must be added first. The WriterStep must be last — it persists the final, transformed data.

#### 3.5 Implement the Facade

The Facade exposes the import functionality to other modules and plugins.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierDataImport/Business/SupplierDataImportFacade.php`. In `importSupplier()`:

- Use `$this->getFactory()` to access the Business Factory
- The factory has a method that returns a configured DataImporter for suppliers
- The DataImporter has an `import()` method that accepts the configuration transfer and returns a report

Remember to pass the `$dataImporterConfigurationTransfer` parameter through the chain.

---

### Part 4: Pluginization

The plugin makes the import available through Spryker's standard `data:import` console command.

#### 4.1 Implement the DataImportPlugin

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierDataImport/Communication/Plugin/DataImport/SupplierDataImportPlugin.php`. This class implements `DataImportPluginInterface` which requires two methods:

- `import()` — should delegate to the module's Facade. The plugin extends `AbstractPlugin` which provides `getFacade()` to access `SupplierDataImportFacade`.
- `getImportType()` — should return the import type string. Look at `SupplierDataImportConfig` for the right constant.

> **Plugin pattern:** Plugins are the "glue" between modules. They live in the Communication layer and bridge the module's Facade to another module's plugin stack. They should contain no business logic — only delegation.

#### 4.2 Register the Plugin

**Coding time:**

Open `src/Pyz/Zed/DataImport/DataImportDependencyProvider.php` in the project. Find the `getDataImporterPlugins()` method and add instances of both `SupplierDataImportPlugin` and `SupplierLocationDataImportPlugin` to the returned array.

---

### Part 5: Run the Import

```bash
docker/sdk console data:import supplier
```

This will:
1. Read `supplier.csv`
2. For each row: run `DescriptionToLowercaseStep` (lowercase description) then `SupplierWriterStep` (persist to DB)
3. Output a report with the number of imported rows

You can also import supplier locations:

```bash
docker/sdk console data:import supplier-location
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

In the complete solution, `SupplierWriterStep` extends `PublishAwareStep` instead of implementing `DataImportStepInterface` directly. This enables triggering publish events after saving, which feeds the **Publish & Synchronize** pipeline (next exercise). This is how imported data flows through the entire Spryker architecture:

```
CSV → DataImport → Database → Event → Publisher → Search/Storage Table → Queue → Elasticsearch/Redis
```

We will explore this in detail in the Publish & Synchronize exercise.

### DependencyProvider Inheritance

The `SupplierDataImportDependencyProvider` extends `DataImportDependencyProvider` to inherit all dependencies the DataImport module needs (data reader, data set step broker, etc.). This is a common pattern when creating a module that extends a core module's functionality.

---

## Verify Your Work

After importing, check:
1. `pyz_supplier` table has 4 rows
2. Descriptions are lowercase (the `DescriptionToLowercaseStep` transformed them)
3. Run `data:import supplier` again — it should NOT create duplicates (idempotent import)

Use any database client (DBeaver, TablePlus, CLI) to connect and verify. Connection credentials are in `deploy.dev.yml` (typically host: `localhost`, port: `3306` or `5432`, user: `spryker`, password: `secret`).

---

## Solution

```bash
./exercises/load.sh supplier intermediate/data-import/complete
```
