# Exercise 2: Create a Data Transfer Object

In Spryker, data transfer objects (DTOs) are used to pass data across layers and services. In this exercise you will create a message DTO from scratch and use it in the Contact Request page.

## Loading the Exercise

```bash
./exercises/load.sh contact-request basics/data-transfer-object/skeleton
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

    <transfer name="Human" strict="true">
        <property name="height" type="int" />
    </transfer>

</transfers>
```

This generates a `HumanTransfer` class with a `height` property of type `int`.

### 1.1 Always Add `strict="true"`

The `strict` attribute decides whether the generated accessors carry **native PHP types**.
Without it the generator emits methods that accept and return anything:

```php
// strict is off - the type only lives in a docblock
public function setMessage($message) { ... }

/** @return string|null */
public function getMessage() { ... }
```

With `strict="true"` on the `<transfer>` element, every property of that transfer gets typed
accessors:

```php
public function setMessage(?string $message = null) { ... }
public function getMessage(): ?string { ... }

public function setMessageOrFail(string $message) { ... }
public function getMessageOrFail(): string { ... }
```

**Why this matters:**

- **Errors surface where they are caused.** A transfer travels from a controller through the
  Client, over the BackendGateway, into a Repository and finally into Propel. Without types,
  `setMessage($someArray)` is accepted silently and blows up five layers later - or worse, gets
  written to the database. With types, PHP throws a `TypeError` on the line that is actually
  wrong.
- **`*OrFail()` becomes genuinely non-nullable.** `getMessageOrFail(): string` tells PHPStan and
  your IDE that the value is there, so the `?? ''` fallbacks disappear from your code.
- **Collections are never null.** A strict collection property returns `ArrayObject` instead of
  `ArrayObject|null`, so you can `foreach` it without a null check, and its adder only accepts
  the right transfer type.
- **It is what Spryker core does.** Look at any recent core transfer definition, for example
  `vendor/spryker/acl-entity/src/Spryker/Shared/AclEntity/Transfer/acl_entity.transfer.xml` -
  the newer transfers all carry `strict="true"`.

Strict mode is opt-in per transfer, not a global switch, because turning it on can break existing
callers that were passing a loose type. On a new transfer there is no such legacy, so turn it on
from the start.

> `strict="true"` also works on a single `<property>` if you ever need to migrate an old transfer
> one property at a time.

**Coding time:**

Open `src/SprykerAcademy/Shared/ContactRequest/Transfer/contact_request.transfer.xml` and add a DTO named **ContactRequest** with `strict="true"` and:
- Property `idContactRequest` of type `int`
- Property `message` of type `string`

Then generate the transfers:

```bash
docker/sdk console transfer:generate
```

Check the auto-generated file at `src/Generated/Shared/Transfer/ContactRequestTransfer.php` and review the helper methods. Note the native types on `setMessage()` and `getMessage()` - remove `strict="true"`, regenerate and compare if you want to see the difference.

### 2. The Controller

You instantiate DTOs like normal objects:

```php
$myTransfer = new MyTransfer();
```

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Communication/Controller/IndexController.php`. Initialize a `Generated\Shared\Transfer\ContactRequestTransfer` object, set `idContactRequest` to `1` and `message` to `'Contact Request!'`, and pass the object to the template under the key `contactRequest`.

### 3. The Template

Access object properties in Twig using dot notation:

```twig
{{ myVar.property }}
```

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Presentation/Index/index.twig` and display the transfer's `message` property using dot notation.

Visit: http://backoffice.eu.spryker.local/contact-request/index/index
(Credentials: `admin@spryker.com` / `change123`)

> **Tip:** `http://backoffice.eu.spryker.local/contact-request` resolves to the same page.

---

## Verify Your Work

Run the automated tests for this exercise:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise2
```

All tests should pass if your transfer definition is correct.

---

## Solution

```bash
./exercises/load.sh contact-request basics/data-transfer-object/complete
```
