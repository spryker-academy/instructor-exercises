# Exercise 2: Create a Data Transfer Object

In Spryker, data transfer objects (DTOs) are used to pass data across layers and services. In this exercise you will create a message DTO from scratch and use it in the Hello World page.

## Loading the Exercise

```bash
./exercises/load.sh hello-world basics/data-transfer-object/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
```

---

## Working on the Exercise

DTOs are defined in XML files in the **Shared** namespace:
`src/SprykerAcademy/Shared/<Module>/Transfer/<module>.transfer.xml`

Spryker's DTO generator finds all transfer files, merges them, and auto-generates PHP classes.

### 1. The Transfer Definition

A DTO is defined by the `<transfer>` element with a `name` attribute. For example:

```xml
<?xml version="1.0"?>
<transfers xmlns="spryker:transfer-01"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="spryker:transfer-01 http://static.spryker.com/transfer-01.xsd">

    <transfer name="Human">
        <property name="height" type="int" />
    </transfer>

</transfers>
```

This generates a `HumanTransfer` class with a `height` property of type `int`.

**Coding time:**

Open `src/SprykerAcademy/Shared/HelloWorld/Transfer/helloworld.transfer.xml` and add a DTO named **Message** with:
- Property `idMessage` of type `int`
- Property `message` of type `string`

Then generate the transfers:

```bash
docker/sdk console transfer:generate
```

Check the auto-generated file at `src/Generated/Shared/Transfer/MessageTransfer.php` and review the helper methods.

### 2. The Controller

You instantiate DTOs like normal objects:

```php
$myTransfer = new MyTransfer();
```

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Communication/Controller/HelloController.php`. Initialize a `Generated\Shared\Transfer\MessageTransfer` object, assign a name to the message, and pass the object to the template.

### 3. The Template

Access object properties in Twig using dot notation:

```twig
{{ myVar.property }}
```

**Coding time:**

Open `src/SprykerAcademy/Zed/HelloWorld/Presentation/Hello/index.twig` and use the passed object to greet the message by its name instead of greeting the whole world.

Visit: http://backoffice.eu.spryker.local/hello-world/hello/index
(Credentials: `admin@spryker.com` / `change123`)

---

## Verify Your Work

Run the automated tests for this exercise:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/HelloWorld/ Exercise2
```

All tests should pass if your transfer definition is correct.

---

## Solution

```bash
./exercises/load.sh hello-world basics/data-transfer-object/complete
```
