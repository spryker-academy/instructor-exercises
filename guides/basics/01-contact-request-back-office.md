# Exercise 1: Contact Request Page in Back Office

In this exercise you will create a simple Spryker Back Office page and add an entry for it in the main navigation.

## Prerequisites

- Demo shop started on your local machine
- Exercises repository cloned (see [Student Setup Guide](../STUDENT_SETUP_GUIDE.md))

## Loading the Exercise

```bash
./exercises/load.sh contact-request basics/contact-request-back-office/skeleton
docker/sdk console transfer:generate
```

The loader registers the `SprykerAcademy` namespace in two places - `autoload.psr-4` in `composer.json`
and `PROJECT_NAMESPACES` in `config/Shared/config_default.php` - and then runs `composer dump-autoload`
itself. If it cannot reach the container it says so and prints the command for you to run.

> **If the page fails with `Expected class "SprykerAcademy\Zed\ContactRequest\Communication\Controller\IndexController" not found!`**
>
> The file is there and the `namespace` line is correct. PHP simply has no rule for loading it.
>
> The Zed router scans the project namespace folders for `*Controller.php`, builds the class name from
> the file path and calls `class_exists()` on it. That lookup goes through the **generated** map in
> `vendor/composer/autoload_psr4.php`, not through `composer.json`. Adding
> `"SprykerAcademy\\": "src/SprykerAcademy/"` to `composer.json` changes nothing until the map is rebuilt:
>
> ```bash
> docker/sdk cli composer dump-autoload
> docker/sdk console cache:empty-all
> ```
>
> One-line diagnosis: `grep SprykerAcademy vendor/composer/autoload_psr4.php` - no output means the
> autoloader is stale, whatever `composer.json` says.

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

In the module folder `ContactRequest`, the **Presentation** layer follows the same naming as the Controller prefix. Create a folder called `Index` and inside it a twig file named `index.twig` (matching the action name without the `Action` suffix).

`src/SprykerAcademy/Zed/ContactRequest/Presentation/Index/index.twig`

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
docker/sdk console propel:model:build
```

Visit: http://backoffice.eu.spryker.local/contact-request/index/index
(Credentials: `admin@spryker.com` / `change123`)

If the page answers with *Expected class ... not found!*, see the note in [Loading the Exercise](#loading-the-exercise)
- the class is fine, the composer autoloader is stale.

Note the URL pattern: **module** / **controller** / **action** (`contact-request/index/index`). Back Office routing is resolved automatically from these names.

> **Tip:** When both the controller and action are named `index`, Spryker allows you to omit them from the URL. So `http://backoffice.eu.spryker.local/contact-request` resolves to the same page.

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
