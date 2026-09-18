# Setup: Install the Back Office Assistant

The Back Office Assistant is an AI chat widget in the Spryker Back Office. It routes each message to an **agent**, and each agent can call **tools** to read or change shop data. Exercise 21 adds a new agent to it, so the assistant must work first. Exercises 19 and 20 do not need it.

This guide follows the official Spryker documentation and was verified against `b2b-demo-marketplace` with `spryker-feature/ai-commerce` 202608.0 and `spryker/ai-foundation` 0.8.4.

You will:
- Register AI configurations for the intent router and the built-in agents
- Register the built-in agent, tool set, SSE, and audit log plugins
- Add the assistant settings to the Configuration Management UI
- Build the chat widget frontend

**Official documentation:**
- [Install Back Office Assistant](https://docs.spryker.com/docs/dg/dev/ai/ai-commerce/backoffice-assistant/install-backoffice-assistant.html)
- [Install AI Commerce](https://docs.spryker.com/docs/dg/dev/ai/ai-commerce/install-ai-commerce.html)
- [Configure multiple AI providers](https://docs.spryker.com/docs/dg/dev/ai/ai-commerce/configure-multiple-ai-providers.html)

## Prerequisites

- A running `b2b-demo-marketplace` with the AI Commerce feature installed. Check with:

```bash
docker/sdk cli composer show spryker-feature/ai-commerce spryker/ai-foundation | grep -E "^name|^versions"
```

- An OpenAI API token. You enter it in the Back Office in step 6. This guide sets up OpenAI only. For AWS Bedrock or Anthropic see *Configure multiple AI providers*.

---

## Background: How the Pieces Fit Together

| Piece | Module | Role |
|-------|--------|------|
| **AI configuration** | AiFoundation | A named entry in `config/Shared/config_ai.php`: provider, API key, model, and optional system prompt |
| **Agent plugin** | AiCommerce | Handles one domain, for example orders or discounts. Sends a prompt to AiFoundation |
| **Intent router** | AiCommerce | Reads every agent's description and picks the agent for a user message |
| **Tool set plugin** | AiFoundation | A named group of tools an agent may call |
| **SSE plugins** | AiCommerce | Stream tool call progress to the chat widget with Server-Sent Events |
| **Audit log plugins** | AiFoundation | Record every prompt and tool call |

> **Why one AI configuration per agent?** Each named configuration is tracked separately in the AiFoundation audit log. You can review the AI calls of one agent without the noise of the others.

The values `key` and `model` are not hard-coded. The prefix `CONFIGURATION_REFERENCE_PREFIX` tells AiFoundation to read them at runtime from the Configuration Management UI in the Back Office.

---

## Step 1: Define the Constants

Open `src/Pyz/Shared/AiCommerce/AiCommerceConstants.php`. The interface already exists in the demo shop and holds the Smart PIM constants. Add the Back Office Assistant constants to it:

```php
    public const string CONFIGURATION_KEY_BACKOFFICE_ASSISTANT_OPENAI_MODEL = 'ai_commerce:backoffice_assistant:ai_vendor:openai_model';

    public const string AI_CONFIGURATION_INTENT_ROUTER_OPENAI = 'AI_COMMERCE:AI_CONFIGURATION_INTENT_ROUTER_OPENAI';

    public const string AI_CONFIGURATION_GENERAL_AGENT_OPENAI = 'AI_COMMERCE:AI_CONFIGURATION_GENERAL_AGENT_OPENAI';

    public const string AI_CONFIGURATION_ORDER_MANAGEMENT_OPENAI = 'AI_COMMERCE:AI_CONFIGURATION_ORDER_MANAGEMENT_OPENAI';

    public const string AI_CONFIGURATION_DISCOUNT_MANAGEMENT_OPENAI = 'AI_COMMERCE:AI_CONFIGURATION_DISCOUNT_MANAGEMENT_OPENAI';

    public const string AI_CONFIGURATION_FORM_FILL_OPENAI = 'AI_COMMERCE:AI_CONFIGURATION_FORM_FILL_OPENAI';
```

`CONFIGURATION_KEY_OPENAI_API_TOKEN` must also exist in this interface. The demo shop already defines it as `'ai_vendor:openai:general:api_token'`.

## Step 2: Register the AI Configurations

Append five entries to `config/Shared/config_ai.php`. The intent router has no system prompt. Each agent references its own prompt setting:

```php
$config[AiFoundationConstants::AI_CONFIGURATIONS][AiCommerceConstants::AI_CONFIGURATION_INTENT_ROUTER_OPENAI] = [
    'provider_name' => AiFoundationConstants::PROVIDER_OPENAI,
    'provider_config' => [
        'key' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_OPENAI_API_TOKEN,
        'model' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_BACKOFFICE_ASSISTANT_OPENAI_MODEL,
    ],
];

$config[AiFoundationConstants::AI_CONFIGURATIONS][AiCommerceConstants::AI_CONFIGURATION_GENERAL_AGENT_OPENAI] = [
    'provider_name' => AiFoundationConstants::PROVIDER_OPENAI,
    'provider_config' => [
        'key' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_OPENAI_API_TOKEN,
        'model' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_BACKOFFICE_ASSISTANT_OPENAI_MODEL,
    ],
    'system_prompt' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_GENERAL_PURPOSE_SYSTEM_PROMPT,
];
```

Repeat the second block three more times with these pairs:

| Configuration constant | System prompt constant |
|------------------------|------------------------|
| `AI_CONFIGURATION_ORDER_MANAGEMENT_OPENAI` | `CONFIGURATION_KEY_ORDER_MANAGEMENT_SYSTEM_PROMPT` |
| `AI_CONFIGURATION_DISCOUNT_MANAGEMENT_OPENAI` | `CONFIGURATION_KEY_DISCOUNT_MANAGEMENT_SYSTEM_PROMPT` |
| `AI_CONFIGURATION_FORM_FILL_OPENAI` | `CONFIGURATION_KEY_FORM_FILL_SYSTEM_PROMPT` |

> **Array style:** The demo shop file starts with one big `$config[AiFoundationConstants::AI_CONFIGURATIONS] = [...]` assignment for Smart PIM. Add the new entries **below** it with the `$config[...][...] = [...]` form shown here, so you do not overwrite the existing entries.

## Step 3: Point the Router and the Agents at Their Configuration

By default every `get*AiConfigurationName()` method in the feature returns `null`. Override them in `src/Pyz/Zed/AiCommerce/AiCommerceConfig.php`. Add these methods to the existing class:

```php
    public function getIntentRouterAiConfigurationName(): ?string
    {
        return AiCommerceConstants::AI_CONFIGURATION_INTENT_ROUTER_OPENAI;
    }

    public function getGeneralAgentAiConfigurationName(): ?string
    {
        return AiCommerceConstants::AI_CONFIGURATION_GENERAL_AGENT_OPENAI;
    }

    public function getOrderManagementAgentAiConfigurationName(): ?string
    {
        return AiCommerceConstants::AI_CONFIGURATION_ORDER_MANAGEMENT_OPENAI;
    }

    public function getDiscountManagementAgentAiConfigurationName(): ?string
    {
        return AiCommerceConstants::AI_CONFIGURATION_DISCOUNT_MANAGEMENT_OPENAI;
    }

    public function getFormFillAgentAiConfigurationName(): ?string
    {
        return AiCommerceConstants::AI_CONFIGURATION_FORM_FILL_OPENAI;
    }
```

## Step 4: Register the Plugins

### Agents

Create `src/Pyz/Zed/AiCommerce/AiCommerceDependencyProvider.php`:

```php
<?php

declare(strict_types = 1);

namespace Pyz\Zed\AiCommerce;

use SprykerFeature\Zed\AiCommerce\AiCommerceDependencyProvider as SprykerFeatureAiCommerceDependencyProvider;
use SprykerFeature\Zed\AiCommerce\Communication\Plugin\Agent\DiscountManagementAgentPlugin;
use SprykerFeature\Zed\AiCommerce\Communication\Plugin\Agent\FormFillAgentPlugin;
use SprykerFeature\Zed\AiCommerce\Communication\Plugin\Agent\GeneralAgentPlugin;
use SprykerFeature\Zed\AiCommerce\Communication\Plugin\Agent\OrderManagementAgentPlugin;

class AiCommerceDependencyProvider extends SprykerFeatureAiCommerceDependencyProvider
{
    /**
     * @return array<\SprykerFeature\Zed\AiCommerce\Dependency\BackofficeAssistant\BackofficeAssistantAgentPluginInterface>
     */
    protected function getBackofficeAssistantAgentPlugins(): array
    {
        return [
            new GeneralAgentPlugin(),
            new OrderManagementAgentPlugin(),
            new DiscountManagementAgentPlugin(),
            new FormFillAgentPlugin(),
        ];
    }
}
```

### Tool sets, SSE streaming, and audit log

Create `src/Pyz/Zed/AiFoundation/AiFoundationDependencyProvider.php`:

```php
<?php

declare(strict_types = 1);

namespace Pyz\Zed\AiFoundation;

use Spryker\Zed\AiFoundation\AiFoundationDependencyProvider as SprykerAiFoundationDependencyProvider;
use Spryker\Zed\AiFoundation\Communication\Plugin\AuditLogPostPromptPlugin;
use Spryker\Zed\AiFoundation\Communication\Plugin\AuditLogPostToolCallPlugin;
use Spryker\Zed\AiFoundation\Communication\Plugin\Log\AiInteractionHandlerPlugin;
use SprykerFeature\Zed\AiCommerce\Communication\Plugin\AiFoundation\BackofficeAssistantSsePostToolCallPlugin;
use SprykerFeature\Zed\AiCommerce\Communication\Plugin\AiFoundation\BackofficeAssistantSsePreToolCallPlugin;
use SprykerFeature\Zed\AiCommerce\Communication\Plugin\AiFoundation\DiscountManagementToolSetPlugin;
use SprykerFeature\Zed\AiCommerce\Communication\Plugin\AiFoundation\FormFillToolSetPlugin;
use SprykerFeature\Zed\AiCommerce\Communication\Plugin\AiFoundation\NavigationToolSetPlugin;
use SprykerFeature\Zed\AiCommerce\Communication\Plugin\AiFoundation\OrderDetailsToolSetPlugin;
use SprykerFeature\Zed\AiCommerce\Communication\Plugin\AiFoundation\OrderManagementToolSetPlugin;

class AiFoundationDependencyProvider extends SprykerAiFoundationDependencyProvider
{
    /**
     * @return array<\Spryker\Zed\AiFoundation\Dependency\Plugin\PostPromptPluginInterface>
     */
    protected function getPostPromptPlugins(): array
    {
        return [
            new AuditLogPostPromptPlugin(),
        ];
    }

    /**
     * @return array<\Spryker\Zed\AiFoundation\Dependency\Plugin\PreToolCallPluginInterface>
     */
    protected function getPreToolCallPlugins(): array
    {
        return [
            new BackofficeAssistantSsePreToolCallPlugin(),
        ];
    }

    /**
     * @return array<\Spryker\Zed\AiFoundation\Dependency\Plugin\PostToolCallPluginInterface>
     */
    protected function getPostToolCallPlugins(): array
    {
        return [
            new BackofficeAssistantSsePostToolCallPlugin(),
            new AuditLogPostToolCallPlugin(),
        ];
    }

    /**
     * @return array<\Spryker\Shared\Log\Dependency\Plugin\LogHandlerPluginInterface>
     */
    protected function getAiInteractionLogHandlerPlugins(): array
    {
        return [
            new AiInteractionHandlerPlugin(),
        ];
    }

    /**
     * @return array<\Spryker\Zed\AiFoundation\Dependency\Tools\ToolSetPluginInterface>
     */
    protected function getAiToolSetPlugins(): array
    {
        return [
            new NavigationToolSetPlugin(),
            new OrderManagementToolSetPlugin(),
            new OrderDetailsToolSetPlugin(),
            new DiscountManagementToolSetPlugin(),
            new FormFillToolSetPlugin(),
        ];
    }
}
```

### Twig plugin

Open `src/Pyz/Zed/Twig/TwigDependencyProvider.php` and make sure `getTwigPlugins()` contains `new AiCommerceTwigPlugin()`. The current demo shop already registers it. It provides the Twig variables the chat widget needs.

> **Project-level layout override:** If your project overrides `src/Pyz/Zed/Gui/Presentation/Layout/layout.twig`, include `@AiCommerce/Partials/chat-widget.twig` in the `footer_js` block as described in the official guide. The stock demo shop has no such override, so you can skip this.

## Step 5: Add the Assistant Settings

Project-level setting schemas live in `data/configuration/`. The feature package already ships the **General** and **System Prompts** groups of the assistant. You add the **AI Vendor** group, which backs the `openai_model` reference from step 2.

Open `data/configuration/ai_commerce.configuration.yml` and add this tab as the first item under `tabs:`:

```yaml
          - key: backoffice_assistant
            enabled: true
            groups:
                - key: ai_vendor
                  name: AI Vendor
                  description: AI configuration and vendor model used for the Backoffice Assistant.
                  enabled: true
                  order: 1
                  scopes:
                      - global
                  settings:
                      - key: ai_configuration
                        name: AI Configuration
                        description: AI configuration used for all Backoffice Assistant agents.
                        type: radio
                        default_value: 'AI_COMMERCE:AI_CONFIGURATION_BACKOFFICE_ASSISTANT_OPENAI'
                        enabled: true
                        secret: false
                        storefront: false
                        order: 1
                        scopes:
                            - global
                        options:
                            - value: 'AI_COMMERCE:AI_CONFIGURATION_BACKOFFICE_ASSISTANT_OPENAI'
                              label: OpenAI
                      - key: openai_model
                        name: OpenAI Model
                        description: The OpenAI model used for the Backoffice Assistant. Model must support image input and structured output.
                        type: string
                        default_value: 'gpt-4.1'
                        enabled: true
                        secret: false
                        storefront: false
                        order: 2
                        scopes:
                            - global
```

> **Indentation matters.** The tab sits at the same depth as the existing `- key: smart_pim` tab. The official guide also lists AWS Bedrock and Anthropic options. Add them when you configure those providers.

## Step 6: Generate, Sync, and Enable

```bash
docker/sdk console transfer:generate
docker/sdk console propel:install
docker/sdk console configuration:sync
docker/sdk console cache:empty-all
docker/sdk console router:cache:warm-up:backoffice
```

`configuration:sync` reports the number of processed settings. The number grows after you add the tab.

Then in the Back Office:

1. Go to **Configuration > AI Vendor > OpenAI** and enter your API token, if it is not set yet.
2. Go to **Configuration > AI Commerce > Back Office Assistant > General**.
3. Turn on **Enable Back Office Assistant** and save. The feature is **off** by default.

## Step 7: Build the Chat Widget

The widget renders Markdown answers with two npm packages:

```bash
docker/sdk cli npm install marked@^15.0.0 dompurify@^3.2.0
docker/sdk console frontend:project:install-dependencies
docker/sdk console frontend:zed:build
```

---

## Testing

1. Reload any Back Office page. A chat icon appears in the bottom-right corner.
2. Ask: *"Where can I create a discount?"* The General agent answers with a navigation path.
3. Ask: *"Show me the latest orders."* The Order Management agent answers, and you see tool call progress while it works.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| No chat icon | The assistant is not enabled in step 6, the Zed frontend was not built, or the Twig cache is stale. Run `cache:empty-all`. |
| Icon visible, every answer fails | Missing or invalid OpenAI token, or an AI configuration name returns `null`. Recheck steps 2 and 3. |
| `configuration:sync` fails | YAML indentation in step 5. |
| Tool progress never streams | The SSE plugins from step 4 are missing. |
| Where do I see what the AI did? | The audit log plugins record every prompt and tool call of each AI configuration. |

You are now ready for Exercise 21.
