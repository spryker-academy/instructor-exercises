# Exercise 1: Contact Request Page in Back Office

In this exercise you will create a simple Spryker Back Office page and add an entry for it in the main navigation.

## Prerequisites

- Demo shop started on your local machine
- Exercises repository cloned (see [Student Setup Guide](../STUDENT_SETUP_GUIDE.md))

## Loading the Exercise

```bash
./exercises/load.sh contact-request basics/contact-request-back-office/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
```

---

## Working on the Exercise

Back Office is the product name for the administration interface. From the code perspective, we refer to the **Zed** namespace. Code related to the Back Office is placed inside `src/Pyz/Zed/*` or `src/SprykerAcademy/Zed/`.

We will work in a module named **ContactRequest** located at `src/SprykerAcademy/Zed/ContactRequest/`.

### 1. The Controller

The Controller class is in the **Communication** layer inside the `Controller` subdirectory:

`src/SprykerAcademy/Zed/ContactRequest/Communication/Controller/IndexController.php`

```php
<?php

namespace SprykerAcademy\Zed\ContactRequest\Communication\Controller;

use Spryker\Zed\Kernel\Communication\Controller\AbstractController;

class IndexController extends AbstractController
{
    public function indexAction(): array
    {
        // TODO
    }
}
```

We extend from Spryker's `AbstractController` which provides helper methods, and implement a basic `indexAction()` that returns an array passed to the template.

**Coding time:**

Use `$this->viewResponse()` and return the result. Pass a key-value array where the key will be the variable name accessible in the template. The value should be the string `'Contact Request!'`.

### 2. The Template

In the module folder `ContactRequest`, the **Presentation** layer follows the same naming as the Controller prefix. Create a folder called `Hello` and inside it a twig file named `index.twig` (matching the action name without the `Action` suffix).

`src/SprykerAcademy/Zed/ContactRequest/Presentation/Hello/index.twig`

```twig
{% extends '@Gui/Layout/layout.twig' %}

{% block content %}
    {# TODO #}
{% endblock %}
```

**Coding time:**

Use the string you returned in the Controller action inside the template. The syntax is `{{ yourKeyFromTheArray }}`.

After editing, run:

```bash
docker/sdk console cache:empty-all
```

Visit: http://backoffice.eu.spryker.local/contact-request/hello/index
(Credentials: `admin@spryker.com` / `change123`)

Note the URL pattern: **module** / **controller** / **action** (`contact-request/hello/index`). Back Office routing is resolved automatically from these names.

### 3. The Navigation

Make your new page accessible through the Back Office navigation.

**Coding time:**

Open `config/Zed/navigation.xml`. Copy an existing navigation entry and adjust it to point to your Contact Request page. The keyword `bundle` refers to the module name.

Rebuild the navigation cache:

```bash
docker/sdk console application:build-navigation-cache
```

Validate the result in the Back Office.

---

## Verify Your Work

Run the automated tests for this exercise:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise1
```

All tests should pass if your implementation is correct.

---

## Solution

```bash
./exercises/load.sh contact-request basics/contact-request-back-office/complete
```
