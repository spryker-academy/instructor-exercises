# Exercise 6: Define and Use a Config Value

In this exercise you will define a config value in the default config file and cascade it through the module's Config class into a controller, displaying it in a Twig template.

## Prerequisites

- You must have completed all previous exercises (1 through 5)

## Loading the Exercise

```bash
./exercises/load.sh contact-request basics/configuration/skeleton
docker/sdk cli composer dump-autoload
```

The branch brings **no new source files** - you write all four classes by hand with what you have learned so far. What it does bring is the Exercise 6 test suite, so you can check your own work before you look at the solution:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise6
```

It is red until you finish the exercise. That is the point.

---

## Working on the Exercise

Your task is to create a Back Office page accessible at:

http://backoffice.eu.spryker.local/contact-request/config/index

that displays a config value defined in `config_default.php`.

We continue working in the **ContactRequest** module at `src/SprykerAcademy/Zed/ContactRequest/`.

### 1. Create a Constants Interface

Constants interfaces live in the **Shared** namespace so they can be used across all application layers (Zed, Yves, Client).

**Coding time:**

Create `src/SprykerAcademy/Shared/ContactRequest/ContactRequestConstants.php`:

```php
<?php

namespace SprykerAcademy\Shared\ContactRequest;

interface ContactRequestConstants
{
    public const string MY_CONFIG_VALUE = 'CONTACT_REQUEST:MY_CONFIG_VALUE';
}
```

The string `'CONTACT_REQUEST:MY_CONFIG_VALUE'` is the key used in config files. The convention is `MODULE_NAME:CONFIG_KEY`.

### 2. Set the Config Value

Open `config/Shared/config_default.php` and add your config value at the end of the file (before the closing `?>`  or end of file):

```php
use SprykerAcademy\Shared\ContactRequest\ContactRequestConstants;

$config[ContactRequestConstants::MY_CONFIG_VALUE] = 'Hello from config!';
```

You can use any string you like as the value.

### 3. Create the Config Class

Each module can have a Config class that provides typed access to global config values. The naming convention is `<Module>Config.php` at the module root.

A Zed Config class extends `Spryker\Zed\Kernel\AbstractBundleConfig`, which provides the `$this->get()` helper method to read values from the global config.

**Coding time:**

Create `src/SprykerAcademy/Zed/ContactRequest/ContactRequestConfig.php`:

- Extend `Spryker\Zed\Kernel\AbstractBundleConfig`
- Add a `getMyConfigValue(): string` method that uses `$this->get(ContactRequestConstants::MY_CONFIG_VALUE)` to return the config value
- Optionally pass a second argument to `$this->get()` as a default fallback value

### 4. Create the Communication Factory

To access the Config class from a controller, you need a CommunicationFactory. The factory extends `Spryker\Zed\Kernel\Communication\AbstractCommunicationFactory`, which provides the `getConfig()` helper method.

**Coding time:**

Create `src/SprykerAcademy/Zed/ContactRequest/Communication/ContactRequestCommunicationFactory.php`:

- Extend `Spryker\Zed\Kernel\Communication\AbstractCommunicationFactory`
- The class body can be empty — the `getConfig()` method is inherited
- Add the following annotation for IDE support:

```php
/**
 * @method \SprykerAcademy\Zed\ContactRequest\ContactRequestConfig getConfig()
 */
```

### 5. Create the Template

**Coding time:**

Create `src/SprykerAcademy/Zed/ContactRequest/Presentation/Config/index.twig`:

```twig
{% extends '@Gui/Layout/layout.twig' %}

{% block content %}
    {{ configValue }}
{% endblock %}
```

The folder `Config` matches the controller name, and `index.twig` matches the action name.

### 6. Create the Controller

**Coding time:**

Create `src/SprykerAcademy/Zed/ContactRequest/Communication/Controller/ConfigController.php`:

- Extend `Spryker\Zed\Kernel\Communication\Controller\AbstractController`
- Implement `indexAction()`:
  1. Get the config value from the Config class
  2. Return `$this->viewResponse(['configValue' => $configValue])`

Starting with Spryker **202512.0**, Zed controllers support **constructor dependency injection**. This means you can inject the Config class directly into the controller instead of going through the factory chain:

```php
use SprykerAcademy\Zed\ContactRequest\ContactRequestConfig;

class ConfigController extends AbstractController
{
    public function __construct(private readonly ContactRequestConfig $config)
    {
    }

    public function indexAction(): array
    {
        $configValue = $this->config->getMyConfigValue();

        return $this->viewResponse([
            'configValue' => $configValue,
        ]);
    }
}
```

Alternatively, you can use the traditional factory approach (which still works and is the pattern you will find in older codebases):

```php
/**
 * @method \SprykerAcademy\Zed\ContactRequest\Communication\ContactRequestCommunicationFactory getFactory()
 */
class ConfigController extends AbstractController
{
    public function indexAction(): array
    {
        $configValue = $this->getFactory()->getConfig()->getMyConfigValue();

        return $this->viewResponse([
            'configValue' => $configValue,
        ]);
    }
}
```

Choose either approach for your implementation.

Clear the cache:

```bash
docker/sdk console cache:empty-all
docker/sdk console propel:model:build
```

Visit: http://backoffice.eu.spryker.local/contact-request/config/index
(Credentials: `admin@spryker.com` / `change123`)

You should see your config value displayed on the page.

---

## Verify Your Work

Run the automated tests for this exercise:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/ Exercise6
```

All tests should pass if your implementation is correct.

> **`Cannot redeclare class ContactRequestConfig` and the whole suite dies.** Not a test problem: one of your new files is missing its `namespace` line. Composer maps `SprykerAcademy\Zed\ContactRequest\ContactRequestConfig` to the file, includes it, does not find that class in it (the file declared a class in the global namespace instead), and on the next lookup includes the same file again - which is a redeclaration. A PHP file under `src/SprykerAcademy/` always starts with its `namespace`. One file without it takes down every test in the run, not just its own.

---

## Solution

```bash
./exercises/load.sh contact-request basics/configuration/complete
```
