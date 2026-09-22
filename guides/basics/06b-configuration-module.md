# Exercise 6b: Let an Admin Change the Value in the Back Office

In [Exercise 6](06-configuration.md) you put a value in `config/Shared/config_default.php` and read it through a module config class. That value is part of the code: changing the greeting means editing a PHP file, committing it and deploying.

The **Configuration** module is the other half of the story. You describe settings in a YAML schema, Spryker renders a Back Office page from it, stores the values in the database and hands them to your code at runtime. Same page, same greeting - but now a shop administrator changes it, and nobody deploys anything.

You will learn how to:
- Write a **configuration schema**: `feature > tab > group > setting`
- Publish it with `configuration:sync` and find it in **Back Office > Configuration**
- Read a value in Zed through the **Configuration facade**
- Know which settings reach the storefront, and what has to happen first
- Tell the two mechanisms apart, and choose the right one

**Official documentation:**
- [Configuration module](https://docs.spryker.com/docs/dg/dev/backend-development/configuration/configuration-module.html)

## Prerequisites

- Exercise 6 completed: the `ConfigController` at `/contact-request/config/index` renders a value.

No exercise branch. You continue in the module you already have.

---

## Part 1: Two Ways to Configure a Shop

| | `config_default.php` (Exercise 6) | Configuration module (this exercise) |
|---|---|---|
| Who changes it | a developer | a shop administrator |
| How | edit PHP, commit, deploy | Back Office form, Save |
| When it takes effect | next deployment | next request |
| Where the value lives | in the repository | in the database |
| Good for | infrastructure, endpoints, feature toggles tied to code | texts, thresholds, keys, anything the business owns |

Both exist on purpose. A queue host belongs in `config_default.php`. A greeting on a page does not.

A schema is a tree with four levels, and the **key of a setting is its path through that tree**:

```
feature        contact_request
  tab          general
    group      config_page
      setting  greeting        ->  contact_request:general:config_page:greeting
```

Schemas are plain YAML files, and Spryker looks for `*.configuration.yml` in two places:

| Location | Owner |
|---|---|
| `data/configuration/` | the project - this is where yours goes |
| `<module root>/resources/configuration/` | modules, scanned under `vendor/*/*` and `src/*/*` |

Look at what the demo shop already ships in `data/configuration/`: `ai_vendor`, `ai_commerce`, `shop_ui`, `availability_widget`. Every page under **Back Office > Configuration** comes from one of these files or from a module's own.

---

## Part 2: Write the Schema

**Coding time:**

Create `data/configuration/contact_request.configuration.yml`:

```yaml
# yaml-language-server: $schema=../../vendor/spryker/configuration/resources/configuration/configuration-schema-v1.json
features:
    - key: contact_request
      name: Contact Request
      description: Settings of the Contact Request module.
      enabled: true
      order: 10
      tabs:
          - key: general
            name: General
            description: General settings of the Contact Request pages.
            enabled: true
            order: 0
            groups:
                - key: config_page
                  name: Config Page
                  description: The page at /contact-request/config/index.
                  enabled: true
                  order: 0
                  scopes:
                      - global
                  settings:
                      - key: greeting
                        name: Greeting
                        description: The text shown on the Contact Request config page.
                        type: string
                        default_value: 'Hello from the Back Office!'
                        enabled: true
                        secret: false
                        storefront: true
                        order: 0
                        scopes:
                            - global
```

Every level carries `key`, `name`, `description`, `enabled` and `order`; `key` is what code uses, `name` is what the administrator reads. On the setting itself:

- **`type`** - `string`, `boolean`, `integer`, `radio`, `color`, `regex` and others. It decides which form field the Back Office renders and how the value is cast when you read it.
- **`default_value`** - used until somebody saves something. A setting nobody has touched still answers.
- **`secret`** - `true` encrypts the value and never shows it again. Use it for tokens, never for texts.
- **`storefront`** - whether the value is published to Yves. See Part 5.
- **`scopes`** - `global`, or `store`, `locale`, `customer_group`, `customer` for values that differ per store or per customer group. Start with `global`.

The first line is not decoration: it points your editor at the JSON schema of this file format, so you get completion and an error on a typo instead of a silent miss.

---

## Part 3: Publish and Edit

```bash
docker/sdk console configuration:sync
```

The command reads every `*.configuration.yml` of the project and of the modules, merges them and writes the result to `data/cache/configuration/`. It reports how many settings it processed - one more than the last run.

Now open the Back Office at http://backoffice.eu.spryker.local/configuration/manage (**Configuration** in the main menu). In the left sidebar you find **Contact Request**, and under it the **General** tab. Hovering the entry shows the `description` you wrote.

Open it, and there is your **Config Page** group with the **Greeting** field, filled with the default. Change it to something you will recognise, and Save.

> **After every `cache:empty-all`, run `configuration:sync` again.** Clearing the cache deletes `data/cache/configuration`, and until you sync, the Back Office has no schema to render and reads fail with an unknown setting.

---

## Part 4: Read the Value in Zed

The Back Office now holds a value your code ignores. Wiring it in takes one constructor argument, because the core `Configuration` module registers its facade as a service in the Zed container. Check for yourself:

```bash
docker/sdk cli vendor/bin/console debug:container ConfigurationFacadeInterface
```

```
Service ID   Spryker\Zed\Configuration\Business\ConfigurationFacadeInterface
Class        Spryker\Zed\Configuration\Business\ConfigurationFacade
Public       yes
```

That is the same mechanism you used in [Exercise 4](04-module-layers-back-office.md) when the Back Office controller received its facade through the constructor - it works here without you registering anything, because the core module ships its own service definitions.

**Coding time:**

Open `src/SprykerAcademy/Zed/ContactRequest/Communication/Controller/ConfigController.php` and take the Configuration facade as a second constructor argument:

```php
use Generated\Shared\Transfer\ConfigurationValueRequestTransfer;
use Spryker\Zed\Configuration\Business\ConfigurationFacadeInterface;

class ConfigController extends AbstractController
{
    public function __construct(
        private readonly ContactRequestConfig $config,
        private readonly ConfigurationFacadeInterface $configurationFacade,
    ) {
    }

    public function indexAction(): array
    {
        return $this->viewResponse([
            'configValue' => $this->config->getMyConfigValue(),
            'greeting' => $this->configurationFacade->getConfigurationValue(
                (new ConfigurationValueRequestTransfer())->setKey('contact_request:general:config_page:greeting'),
            ),
        ]);
    }
}
```

Add the second value to `src/SprykerAcademy/Zed/ContactRequest/Presentation/Config/index.twig`:

```twig
{{ configValue }}
{{ greeting }}
```

Reload http://backoffice.eu.spryker.local/contact-request/config/index. Two values, two mechanisms: one you can only change by deploying, one you just changed in a form.

`getConfigurationValue()` resolves the scope, decrypts the value if the setting is `secret`, and casts it to the `type` from the schema - so a `boolean` setting comes back as a bool, not as the string `"true"`.

**Now change the greeting in the Back Office again and reload the page.** No cache clear, no deployment. That is the whole point of the exercise.

> If the page dies with *Too few arguments to function ConfigController::__construct()*, the controller is not coming out of the container - see the troubleshooting block in [Exercise 4](04-module-layers-back-office.md).

---

## Part 5: What `storefront: true` Really Means

Yves does not read the database. A setting marked `storefront: true` travels the same road as products and prices - **publish & sync** - and Yves reads the result from Redis through the Configuration **client**:

```php
use Generated\Shared\Transfer\ConfigurationValueRequestTransfer;

$greeting = $this->getFactory()->getConfigurationClient()->getConfigurationValue(
    (new ConfigurationValueRequestTransfer())->setKey('contact_request:general:config_page:greeting'),
);
```

The client is `Spryker\Client\Configuration\ConfigurationClientInterface`. In Yves you provide it through your module's `DependencyProvider` and expose it on the factory, exactly like the `ContactRequestClient` in [Exercise 5](05-module-layers-storefront.md) - Yves has no service container of its own, so there is no constructor injection here (see the note in Exercise 5).

The part that surprises people is the delay. Pressing **Save** in the Back Office writes two things immediately: the value in `spy_configuration_value` and a published copy in `spy_configuration_storage`. That second table carries Spryker's `synchronization` behavior, so its rows are queued to Redis under keys that start with `configuration:` - and until the queue workers have processed that queue, **Yves still answers with the old value while the Back Office already shows the new one**.

```bash
docker/sdk console queue:worker:start
```

If you want to see the mechanism rather than trust it, look at `spy_configuration_storage` right after a save, and at the `configuration:*` keys in the Redis GUI. [Exercise 10](../intermediate/03-publish-synchronize.md) of the intermediate course is publish & sync end to end.

A setting with `storefront: false` never leaves Zed, which is what you want for anything an unauthenticated visitor should not be able to read.

---

## Testing

1. `docker/sdk console configuration:sync` reports one more setting than before your file existed.
2. **Back Office > Configuration** has a **Contact Request** entry with a **General** tab.
3. The **Greeting** field shows `Hello from the Back Office!` before you save anything - the `default_value` answers even with an empty database.
4. `/contact-request/config/index` shows the text you saved, and shows a new one after you save again, without any console command.
5. Delete `data/cache/configuration` (or run `cache:empty-all`), reload the Back Office, watch it break, run `configuration:sync`, watch it work.

## Cleanup

Keep the schema and the wiring - the exercise leaves the module in a good state. If you want the page back to its Exercise 6 shape, drop the `greeting` variable from the controller and the template; the schema does no harm.

## Going Further

- Change `scopes` on the setting to `[global, store]`, sync, and watch the Back Office grow a per-store column. Read it with `->setScope('store')->setScopeIdentifier('DE')`.
- Add a second setting with `secret: true`, save a value, and reopen the form: the field is empty, because the value is encrypted and never sent back to the browser.
- A value can be referenced from other configuration with the `configuration::` prefix instead of being read in code. [Exercise 9b](../intermediate/02b-ai-commerce-configuration.md) uses that to point the AI features at an API token an administrator manages.
- Ship the schema inside a module instead of the project: `resources/configuration/` in the module root, which is how `spryker/gui` and the other core modules do it.
