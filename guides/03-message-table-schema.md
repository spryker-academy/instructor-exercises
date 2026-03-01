# Exercise 3: Create a Table and Entity Representation

In this exercise you will create a database table to store messages and an entity representation for a message using Propel ORM.

## Loading the Exercise

```bash
./exercises/load.sh hello-world basics/message-table-schema/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
```

---

## Working on the Exercise

### 1. The Propel Schema File

Here is an example Propel schema definition for a `pyz_human` table:

```xml
<?xml version="1.0"?>
<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    name="zed"
    xsi:noNamespaceSchemaLocation="http://static.spryker.com/schema-01.xsd"
    namespace="Orm\Zed\Human\Persistence"
    package="src.Orm.Zed.Human.Persistence">

    <table name="pyz_human" idMethod="native" allowPkInsert="true" phpName="PyzHuman">
        <column name="id_human" required="true" type="INTEGER" primaryKey="true" autoIncrement="true"/>
        <column name="genetic_code" required="true" type="VARCHAR" size="255"/>
        <column name="height" required="true" type="INTEGER"/>

        <unique name="pyz_human-genetic_code">
            <unique-column name="genetic_code"/>
        </unique>
    </table>

</database>
```

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Persistence/Propel/Schema/pyz_message.schema.xml` and add the definition for the **PyzMessage** table:

- Column `id_message`: type `INTEGER`, primary key, auto-increment, required
- Column `message`: type `VARCHAR`, size `255`, required, **unique**

Then generate the entity and run migrations:

```bash
docker/sdk console propel:install
```

**Coding time:**

Verify the `pyz_message` table was created in the database (using a tool of your choice). Locate the generated entity in `src/Orm/Zed/Message/Persistence/` and its subfolders.

---

## Verify Your Work

Run the automated tests for this exercise:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise3
```

All tests should pass if your schema definition is correct.

---

## Solution

```bash
./exercises/load.sh hello-world basics/message-table-schema/complete
```
