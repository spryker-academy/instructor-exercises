# Exercise 9b: Configure AI Commerce in the Back Office

In Exercise 9 you built Back Office pages by hand. Spryker also generates Back Office pages from YAML: the **Configuration** module turns setting schemas into the **Configuration** menu, stores the values in the database and hands them to the code at runtime. The AI Commerce feature of the demo shop is configured entirely this way. In this exercise you connect the shop to OpenAI, try the Smart PIM features on a product, and add a setting of your own.

You will learn how to:
- Read a **configuration schema** (`*.configuration.yml`): features, tabs, groups, settings, scopes, secrets
- Publish schemas with `configuration:sync` and edit values in **Back Office > Configuration**
- Understand the **AI configurations** in `config/Shared/config_ai.php` and the `configuration::` references
- Use the **Smart PIM** features of AI Commerce from the product form
- Read a configuration value from code

**Official documentation:**
- [AI Foundation module](https://docs.spryker.com/docs/dg/dev/ai/ai-foundation/ai-foundation-module.html)
- [Configuration module](https://docs.spryker.com/docs/dg/dev/backend-development/configuration/configuration-module.html)

## Prerequisites

- Exercise 9 completed.
- An OpenAI API token. The instructor provides one per participant. Every call to OpenAI costs money, so use the small model named below.

No exercise branch is needed. Everything happens in the demo shop.

---

## Background: Three Files, One Menu

| File | Owner | What it is |
|------|-------|------------|
| `data/configuration/ai_vendor.configuration.yml` | project | Schema of **Configuration > AI Vendor**: the API tokens of OpenAI, Anthropic and AWS Bedrock. Tokens are `secret: true`, so they are encrypted in the database and never shown again |
| `data/configuration/ai_commerce.configuration.yml` | project | Schema of **Configuration > AI Commerce**: which AI configuration and which model the **Smart PIM** features and the **Back Office Assistant** use |
| `config/Shared/config_ai.php` | project | The **AI configurations** of AiFoundation: named entries with `provider_name`, `provider_config` (`key`, `model`) and optionally `system_prompt` |

A schema is a tree `feature > tab > group > setting`. A setting has a `type` (`string`, `boolean`, `radio`, `color`, `regex`, ...), a `default_value`, `scopes` (`global` or per store) and `secret`. The key of a setting is the path through the tree with colons, for example `ai_vendor:openai:general:api_token`.

`docker/sdk console configuration:sync` reads every `*.configuration.yml` of the project and of the vendor modules, merges them and writes the schema to the database. The Back Office renders the menu from that schema. Values are edited in the Back Office, without a deployment.

The AI configurations connect the two worlds. Look at `config/Shared/config_ai.php`:

```php
AiCommerceConstants::AI_CONFIGURATION_SMART_PIM_OPENAI => [
    'provider_name' => AiFoundationConstants::PROVIDER_OPENAI,
    'provider_config' => [
        'key' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_OPENAI_API_TOKEN,
        'model' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_SMART_PIM_OPENAI_MODEL,
    ],
],
```

`CONFIGURATION_REFERENCE_PREFIX` is the string `configuration::`. A value with that prefix is not a value but a **reference to a setting key**: AiFoundation reads `ai_vendor:openai:general:api_token` from the Configuration module at the moment of the call. A plain string (`'model' => 'gpt-4.1-mini'`) is fixed in code. Use references for secrets and for everything an admin should be able to change.

> **Where is the cache?** `cache:empty-all` deletes `data/cache/configuration`, the synced schema. After every cache clear run `configuration:sync` again, otherwise AI calls fail with an unknown setting.

---

## Part 1: Connect the Shop to OpenAI (5 minutes)

1. Log in to the Back Office (`admin@spryker.com` / `change123`).
2. Open **Configuration > AI Vendor > OpenAI** and enter your API token. Save. The token is stored encrypted, because the setting is `secret: true`.
3. Open **Configuration > AI Commerce > Smart PIM**. Keep **AI Configuration** on *OpenAI* and set **OpenAI Model** to `gpt-4.1-mini`. Save.

Where did those pages come from? Open `data/configuration/ai_vendor.configuration.yml` and find the `api_token` setting. Note `secret: true` and `scopes: [global]`. Other possible scopes are `store`, `locale`, `customer_group` and `customer`. Then open `ai_commerce.configuration.yml` and find the `smart_pim` tab with the `ai_configuration` radio and the `openai_model` string.

---

## Part 2: Try Smart PIM (10 minutes)

Smart PIM is the group of AI helpers in the product form. Open **Catalog > Products**, edit any abstract product, and try:

- **Category suggestion**: the AI proposes categories from the product name and description.
- **Translate**: fills the other locale from the one you wrote.
- **Content improver**: rewrites a description.
- **Image alt text**: generates alt texts for the product images.

Each button sends a prompt through AiFoundation with the `SMART_PIM_OPENAI` configuration, so it uses the token and the model you just saved. Change the model to a name that does not exist, save, and try again: the error shows you that the configuration is read at call time, not at deployment.

Set the model back to `gpt-4.1-mini`.

---

## Part 3: Add a Setting of Your Own (15 minutes)

Add a **tone of voice** setting that a content manager can change. Open `data/configuration/ai_commerce.configuration.yml` and add a group to the `smart_pim` tab, after the `ai_vendor` group:

```yaml
                - key: content_style
                  name: Content Style
                  description: How Smart PIM should write product content.
                  enabled: true
                  order: 2
                  scopes:
                      - global
                  settings:
                      - key: tone
                        name: Tone of voice
                        description: Adjective the AI uses when it rewrites descriptions, for example "friendly" or "technical".
                        type: string
                        default_value: 'friendly'
                        enabled: true
                        secret: false
                        storefront: false
                        order: 1
                        scopes:
                            - global
```

Indentation matters: `- key: content_style` sits at the same depth as `- key: ai_vendor`. Then publish the schema:

```bash
docker/sdk console configuration:sync
```

The command reports the number of processed settings. It is one higher than before. Open **Configuration > AI Commerce > Smart PIM** and find your group. Set the value to `technical` and save.

Read it from code. The key is `ai_commerce:smart_pim:content_style:tone`. In Zed:

```php
use Generated\Shared\Transfer\ConfigurationValueRequestTransfer;

$tone = $this->getFactory()->getConfigurationFacade()->getConfigurationValue(
    (new ConfigurationValueRequestTransfer())->setKey('ai_commerce:smart_pim:content_style:tone'),
);
```

The facade resolves the scope, decrypts secrets and casts the value to the type of the setting. Try it in a quick way: add the three lines to `indexAction()` of your `SupplierGui` `IndexController` from Exercise 9, inject the Configuration facade through the DependencyProvider as you learned, and dump the value with `dd($tone)`. Remove it again.

**Bonus.** Reference the setting from an AI configuration. In `config/Shared/config_ai.php` add to the Smart PIM OpenAI entry:

```php
'system_prompt' => 'Write in a ' . AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . 'ai_commerce:smart_pim:content_style:tone' . ' tone.',
```

This does not work: a reference must be the whole value, not part of a string. Replace it with a reference to a new `system_prompt` setting of type `string` that holds the complete sentence, sync, and try the content improver again. That is the pattern the Back Office Assistant uses for all its system prompts (see `guides/advanced/01-back-office-assistant-setup.md`).

---

## Testing

1. **Configuration > AI Vendor > OpenAI** shows the token field empty after saving; a Smart PIM action returns a result.
2. A wrong model name makes the Smart PIM action fail with a provider error; the correct name fixes it without a deployment.
3. After `configuration:sync`, the **Content Style** group appears under Smart PIM and its value survives a page reload.
4. The dumped value in the controller is the string you saved, or `friendly` if you saved nothing.

## Cleanup

Remove the `dd()` from the controller and, if you did the bonus, keep or remove the `system_prompt` entry as you prefer. Leave your token in place: the AI Development course uses it.

## Going Further

- Give the `tone` setting `scopes: [store]` and see how the Back Office lets you set it per store.
- Look at how the Back Office Assistant guide (advanced, Exercise 21 prerequisites) adds a whole tab with the same mechanics.
- Exercise 19 of the AI Development course registers an AI configuration of your own with a `configuration::` reference for the key and a plain string for the model.
