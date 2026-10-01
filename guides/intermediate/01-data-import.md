# Exercise 8: Data Import - Supplier

In this exercise, you will create a data import pipeline to populate the database with suppliers from a CSV file. You will learn how Spryker's `DataImport` module works: reading CSV files, processing data through steps, and persisting entities.

You will learn how to:
- Create and configure CSV data sources
- Map import types to YAML configuration
- Implement `DataImportStepInterface` for data processing and writing
- Chain steps through the `DataSetStepBroker`
- Expose the import through a Facade and Plugin
- Register the plugin in Spryker's data import stack
- Understand how a related supplier-location import is wired (the location writer is provided as supporting code)

## Prerequisites

- Completed the basics exercises (1-7)
- The exercise branch includes the Propel schemas for `pyz_supplier`, `pyz_supplier_location`, and `pyz_merchant_to_supplier`. Loading the branch copies the schemas into the project; running `propel:install` is still required to generate the Propel classes and create/update the database tables.

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/data-import/skeleton --run
```

`--run` also runs the commands the loader lists after loading (cache, Propel, transfers and whatever this exercise needs, such as queues or Glue resources) and stops at the first one that fails. Leave it out to run them yourself.

`propel:install` creates the supplier tables. If you run the commands yourself, keep the order the loader prints: `c:e` deletes Propel's generated database map, which `propel:install` writes again.

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

The exercise provides the schema files:
- `src/SprykerAcademy/Zed/Supplier/Persistence/Propel/Schema/pyz_supplier.schema.xml` (also defines `pyz_merchant_to_supplier`)
- `src/SprykerAcademy/Zed/SupplierLocation/Persistence/Propel/Schema/pyz_supplier_location.schema.xml`

They define `pyz_supplier` (id_supplier, name, description, status, email, phone) and `pyz_supplier_location` (with a foreign key to `pyz_supplier`). `propel:install`, which the loader ran, created the tables. If you change a schema, run it again:

```bash
docker/sdk console propel:install
```

---

### Part 2: Data Source

#### 2.1 Review the CSV Files

The exercise ships `data/import/supplier.csv` (4 suppliers) and `data/import/supplier_location.csv` (their locations); the loader copies them into the project. Open them and look at the column headers - they become the keys of the `DataSet` object during import. Locations refer to suppliers by name, so suppliers must be imported first.

#### 2.2 Configure the Import YAML

An import configuration tells Spryker which CSV file to read for which importer. The demo shop's full import is `data/import/local/full_EU.yml`; the exercise brings its own, `data/import/local/supplier_import.yml`, so it never has to change a project file.

**Coding time:**

Open `data/import/local/supplier_import.yml` and add two entries to `actions:`, suppliers first:

- `data_entity` must match the value of `SupplierDataImportConfig::IMPORT_TYPE_SUPPLIER`, `source` is the supplier CSV (path relative to the project root)
- `data_entity` must match `SupplierDataImportConfig::IMPORT_TYPE_SUPPLIER_LOCATION`, pointing to the location CSV

Look at `data/import/local/full_EU.yml` for the format. Be careful with YAML indentation (spaces, not tabs).

> **How it works:** `docker/sdk console data:import --config=data/import/local/supplier_import.yml` runs every action of the file in order; `data:import supplier --config=...` only the one with `data_entity: supplier`. For each action Spryker passes the CSV path to the `DataImportPlugin` whose `getImportType()` equals the `data_entity`, inside a `DataImporterConfigurationTransfer`. In a real project you would add the two entries to `full_EU.yml` instead.

---

### Part 3: The SupplierDataImport Module

The module `SprykerAcademy\Zed\SupplierDataImport` follows Spryker's naming convention: `<ModuleName>DataImport`. The exercise focuses on completing the supplier import; the location importer is included as working supporting code so you can compare a second import pipeline.

#### 3.1 Constants for Column Mapping

Review the provided file `src/SprykerAcademy/Zed/SupplierDataImport/Business/DataSet/SupplierDataSetInterface.php`. It defines constants that map to the CSV column names.

Compare the constants with the CSV header row. In the supplied file, `COLUMN_NAME` should be `name`; keep constants aligned with the actual headers if you customize the CSV.

> **Best practice:** Always use constants for column names. Never use literal strings like `$dataSet['name']` directly — use `$dataSet[SupplierDataSetInterface::COLUMN_NAME]` instead.

#### 3.2 Implement the SupplierWriterStep

The `SupplierWriterStep` is where each CSV row gets persisted to the database. It receives a `DataSet` for each row.

**Coding time:**

Open `src/SprykerAcademy/Zed/SupplierDataImport/Business/DataImportStep/SupplierWriterStep.php` and implement the `execute()` method following the TODO steps:

1. **Find or create** the supplier entity. Propel query classes have a static `create()` method that returns a query builder. You can chain `filterBy<ColumnName>()` to build your query, then call `findOneOrCreate()` to either fetch an existing record or create a fresh (unsaved) entity.

2. **Assign fields** from the dataset to the entity. Use the entity's setter methods (`setDescription()`, `setStatus()`, etc.) and read values from `$dataSet` using the constants from `SupplierDataSetInterface`.

3. **Save conditionally.** Only persist the entity if it's actually new or has been modified. Propel entities provide `isNew()` and `isModified()` methods for this check.

4. **Optional extension — merchant relations.** The supplied `supplier.csv` does **not** contain a `merchant_ids` column, so this is not part of the standard import exercise. If you add that column and provide valid existing merchant IDs, you can extend the writer to parse the IDs, avoid duplicate relations, and create only missing records.

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

The `DataImport` module collects the importers from its dependency provider. The project's is `src/Pyz/Zed/DataImport/DataImportDependencyProvider.php`.

**Coding time:**

Open `src/SprykerAcademy/Zed/DataImport/DataImportDependencyProvider.php`. It extends the project's provider, and because `SprykerAcademy` comes before `Pyz` in `KernelConstants::PROJECT_NAMESPACES`, the kernel uses it instead of the `Pyz` one. In `getDataImporterPlugins()`, add a `SupplierDataImportPlugin` and a `SupplierLocationDataImportPlugin` to the plugins returned by `parent::getDataImporterPlugins()`.

> In a real project you would add the two plugins to `src/Pyz/Zed/DataImport/DataImportDependencyProvider.php` directly. The exercises extend the `Pyz` classes from `src/SprykerAcademy` instead, so that loading a solution never changes a project file - you will see the same pattern for the publisher, queue and OMS providers later.

---

### Part 5: Run the Import

```bash
docker/sdk console data:import --config=data/import/local/supplier_import.yml
```

This will, for every action of the file:
1. Read the CSV file (`supplier.csv` first)
2. For each row: run `DescriptionToLowercaseStep` (lowercase description), then `SupplierWriterStep` (persist to DB)
3. Output a report with the number of imported rows

The location import uses the provided `SupplierLocationWriterStep` and its factory, facade and plugin. To run one importer only:

```bash
docker/sdk console data:import supplier --config=data/import/local/supplier_import.yml
```

> **Always pass `--config`.** Without it, `data:import` reads the shop's default list `data/import/local/full_EU.yml`, which has no `supplier` entry, and stops with *Requested import type "supplier" was not found in /data/data/import/local/full_EU.yml*. The supplier import is defined only in the exercise's own `data/import/local/supplier_import.yml`.

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

From Exercise 10 on, `SupplierWriterStep` extends `PublishAwareStep` instead of implementing `DataImportStepInterface` directly. This enables triggering publish events after saving, which feeds the **Publish & Synchronize** pipeline (next exercise). This is how imported data flows through the entire Spryker architecture:

```
CSV → DataImport → Database → Event → Publisher → Search/Storage Table → Queue → Elasticsearch/Redis
```

We will explore this in detail in the Publish & Synchronize exercise.

### DependencyProvider Inheritance

Two dependency providers take part, with different jobs:

- `SupplierDataImportDependencyProvider` extends the core `DataImportDependencyProvider` to inherit what every importer module needs (data reader, step broker, ...). It does not register anything.
- The importers are registered in the `DataImport` module's provider. The project's is `src/Pyz/Zed/DataImport/DataImportDependencyProvider.php`; the exercise extends it in `src/SprykerAcademy/Zed/DataImport/DataImportDependencyProvider.php`, which the kernel resolves first.

---

## Verify Your Work

After importing, check:
1. `pyz_supplier` has 4 rows and the descriptions are lowercase (the `DescriptionToLowercaseStep` transformed them).
2. `pyz_supplier_location` has 6 rows, each pointing to one of the suppliers.
3. Run the import again - it must not create duplicates (idempotent import).
4. Run the tests: `docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/Supplier/`

Use any database client (DBeaver, TablePlus, CLI) to connect and verify. Connection credentials are in `deploy.dev.yml` (typically host: `localhost`, port: `3306` or `5432`, user: `spryker`, password: `secret`).

---

## Solution

```bash
./exercises/load.sh supplier intermediate/data-import/complete --run
```
