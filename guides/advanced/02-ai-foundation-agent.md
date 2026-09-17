# Exercise 19: AI Foundation - Product Creation Agent

In this exercise, you will build a custom agent for the Back Office Assistant. The agent creates catalog products from a plain-language description such as *"Create a red cotton t-shirt in sizes S, M and L for 19.99 EUR"*. It interviews the user for missing data, asks for confirmation, and then calls your tools to create the product.

You will learn how to:
- Write an AI **tool** plugin: name, description, parameters, and execution
- Group tools into a **tool set** plugin
- Write an **agent** plugin that sends a prompt request to AiFoundation and maps the structured answer
- Register a dedicated **AI configuration** with a system prompt
- Wire the agent into the Back Office Assistant, including SSE streaming

The business logic that creates products, prices, stock, and images is provided. You focus on the AI Foundation layer.

**Official documentation:**
- [Add a custom Back Office Assistant agent](https://docs.spryker.com/docs/dg/dev/ai/ai-commerce/backoffice-assistant/add-custom-backoffice-assistant-agent.html)
- [Extend AI Commerce agents with custom toolsets](https://docs.spryker.com/docs/dg/dev/ai/ai-commerce/extend-ai-commerce-agents-with-toolsets.html)

## Prerequisites

- The Back Office Assistant is installed and answers questions. See [Setup: Install the Back Office Assistant](01-back-office-assistant-setup.md)
- An OpenAI API token is configured in the Back Office
- Access to the private `spryker-academy/ai-product-creation` repository on GitHub

## Loading the Exercise

```bash
./exercises/load.sh ai-product-creation advanced/ai-foundation-agent/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console configuration:sync
docker/sdk console cache:empty-all
```

> **Order matters.** Run `composer dump-autoload` first. Later in this exercise `config_ai.php` references a `SprykerAcademy` class, and every console command fails until the class can be autoloaded.

The loader copies the module to `src/SprykerAcademy/`, the agent settings to `data/configuration/ai_product_creation.configuration.yml`, and the tests to `tests/SprykerAcademyTest/`.

---

## Background: How an Agent Talks to the AI Model

```
User message
   |
Intent router --- reads every agent's getDescription() and picks one
   |
ProductCreationAgentPlugin::executeAgent()
   |   builds a PromptRequestTransfer:
   |   AI configuration name + conversation reference + tool set name + structured message
   |
AiFoundationFacade::prompt()
   |   sends system prompt, user message, and tool definitions to the AI provider
   |
AI model <----> your ToolPlugins (the model asks, AiFoundation executes, the result goes back)
   |
Structured answer (ProductCreationAgentResponseTransfer) --> chat widget
```

| Concept | Class or file | What the AI model sees |
|---------|---------------|------------------------|
| **Tool** | `ToolPluginInterface` | Only `getName()`, `getDescription()`, and `getParameters()`. Never your PHP code |
| **Tool set** | `ToolSetPluginInterface` | Nothing. It is a named group the agent requests |
| **Agent** | `BackofficeAssistantAgentPluginInterface` | `getDescription()` is read by the intent router |
| **System prompt** | `ai_product_creation.configuration.yml` | The full text. It defines the behavior and conversation flow |
| **Structured message** | `ai_product_creation.transfer.xml` | The property descriptions. The model must answer in this shape |

> **The description is the interface.** A tool with a vague description is never called, or is called at the wrong time. Write descriptions for a reader who knows nothing about your code.

The module has nine tools. Seven are complete. Look at `CreateProductToolPlugin` and `SetProductStockToolPlugin` before you start. They show the full pattern.

---

## Working on the Exercise

### Part 1: Your First Tool

Open `src/SprykerAcademy/Zed/AiProductCreation/Communication/Plugin/AiFoundation/Tool/ListTaxSetsToolPlugin.php`.

The model needs a valid tax set name before it can call `create_product`. This tool lists the tax sets. Complete **TODO-1** to **TODO-4**:

1. `getName()` returns `'list_tax_sets'`. The system prompt refers to the tool by this exact name.
2. `getDescription()` explains what the tool returns and why that is useful.
3. `getParameters()` returns an empty array, because the tool needs no input.
4. `execute()` delegates to the business layer: `$this->getBusinessFactory()->createProductCreationReader()->listTaxSets($arguments)`.

> **Tools return JSON strings.** Open `ProductCreationReader::listTaxSets()`. It returns `json_encode([...])`. The model reads that text. On failure, a tool returns a JSON error message instead of throwing, so the model can explain the problem to the user.

### Part 2: Tool Parameters

Open `ApproveProductToolPlugin.php` in the same directory. New products are created as `draft` and stay invisible in the storefront until approved.

Complete **TODO-5**. Return two `ToolParameter` objects from `getParameters()`:

| name | type | required | description |
|------|------|----------|-------------|
| `sku` | `string` | yes | Abstract or concrete product SKU |
| `status` | `string` | no | `approved`, `draft`, `waiting_for_approval`, or `denied`. Defaults to `approved` |

```php
new ToolParameter(
    name: 'sku',
    type: 'string',
    description: '...',
    isRequired: true,
),
```

> **Parameter names are a contract.** AiFoundation passes the model's arguments to `execute(...$arguments)` as a named array. `ProductCreationWriter::approveProduct()` reads `$arguments['sku']` and `$arguments['status']`. If the names differ, the value is lost.

### Part 3: The Tool Set

Open `src/SprykerAcademy/Zed/AiProductCreation/Communication/Plugin/AiFoundation/ProductCreationToolSetPlugin.php`.

- **TODO-6:** `getName()` returns `AiProductCreationConstants::TOOL_SET_PRODUCT_CREATION`.
- **TODO-7:** `getTools()` returns all nine tools. Create each one through the factory, for example `$this->getFactory()->createListCategoriesToolPlugin()`. `AiProductCreationCommunicationFactory` lists all nine `create*ToolPlugin()` methods.

> **A tool that is not in a tool set does not exist for the model**, even if its class is fully implemented.

### Part 4: The Agent

Open `src/SprykerAcademy/Zed/AiProductCreation/Communication/Plugin/Agent/ProductCreationAgentPlugin.php`. Read `getDescription()` first. The intent router uses this text to decide whether a user message belongs to your agent.

**TODO-8:** build the `PromptRequestTransfer` in `executeAgent()`:

| Setter | Value | Purpose |
|--------|-------|---------|
| `setAiConfigurationName()` | `$this->getConfig()->getProductCreationAgentAiConfigurationName()` | Provider, model, and system prompt |
| `setConversationReference()` | From the assistant request | Conversation memory across messages |
| `setStructuredMessage()` | `new ProductCreationAgentResponseTransfer()` | Forces the answer into this shape |
| `addToolSetName()` | `AiProductCreationConstants::TOOL_SET_PRODUCT_CREATION` | The tools the model may call |
| `setPromptMessage()` | A `PromptMessageTransfer` with type `AiFoundationConstants::MESSAGE_TYPE_USER`, the prompt as content, and the attachments | The user's message |

**TODO-9:** copy `agent`, `message`, and `reasoningMessage` from the structured answer to the `BackofficeAssistantPromptResponseTransfer`.

> **Why a structured message?** Without it the model answers with free text. With it, AiFoundation asks the provider for JSON that matches the transfer, and you get typed getters. Open `ai_product_creation.transfer.xml`: the property descriptions are instructions for the model. The `agent` property lets the model answer `Guardrail` when the request is off-topic.

### Verify Parts 1 to 4

```bash
docker/sdk cli vendor/bin/codecept build -c tests/SprykerAcademyTest/Zed/AiProductCreation/
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/AiProductCreation/ Exercise19
```

All 12 tests must pass. They use mocks, so no AI call is made and no token is spent. An error like `getName(): Return value must be of type string, none returned` points at a TODO you have not completed yet.

---

### Part 5: Wire the Agent into the Project

Your plugins exist, but the project does not know them yet.

**1. Register the agent.** In `src/Pyz/Zed/AiCommerce/AiCommerceDependencyProvider.php`, add `new ProductCreationAgentPlugin()` to `getBackofficeAssistantAgentPlugins()`.

**2. Register the tool set.** In `src/Pyz/Zed/AiFoundation/AiFoundationDependencyProvider.php`, add `new ProductCreationToolSetPlugin()` to `getAiToolSetPlugins()`.

Both classes need an import:

```php
use SprykerAcademy\Zed\AiProductCreation\Communication\Plugin\Agent\ProductCreationAgentPlugin;
use SprykerAcademy\Zed\AiProductCreation\Communication\Plugin\AiFoundation\ProductCreationToolSetPlugin;
```

**3. Add the AI configuration.** Append to `config/Shared/config_ai.php`:

```php
use SprykerAcademy\Shared\AiProductCreation\AiProductCreationConstants;

$config[AiFoundationConstants::AI_CONFIGURATIONS][AiProductCreationConstants::AI_CONFIGURATION_PRODUCT_CREATION_OPENAI] = [
    'provider_name' => AiFoundationConstants::PROVIDER_OPENAI,
    'provider_config' => [
        'key' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_OPENAI_API_TOKEN,
        'model' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_BACKOFFICE_ASSISTANT_OPENAI_MODEL,
    ],
    'system_prompt' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiProductCreationConstants::CONFIGURATION_KEY_SYSTEM_PROMPT,
];
```

Put the `use` line at the top of the file with the other imports. The agent reuses the assistant's token and model settings and brings its own system prompt.

**4. Enable SSE streaming.** Tool call progress is only streamed for AI configuration names the assistant knows. Add to `src/Pyz/Zed/AiCommerce/AiCommerceConfig.php`:

```php
    /**
     * @return array<string>
     */
    public function getBackofficeAssistantSseAiConfigurationNames(): array
    {
        return array_values(array_filter([
            ...parent::getBackofficeAssistantSseAiConfigurationNames(),
            AiProductCreationConstants::AI_CONFIGURATION_PRODUCT_CREATION_OPENAI,
        ]));
    }
```

Import the constants interface here as well: `use SprykerAcademy\Shared\AiProductCreation\AiProductCreationConstants;`

**5. Apply.**

```bash
docker/sdk console configuration:sync
docker/sdk console cache:empty-all
```

> **Where does the system prompt come from?** `configuration:sync` loaded it from `data/configuration/ai_product_creation.configuration.yml`. You can now edit it live under **Configuration > AI Commerce > Back Office Assistant > System Prompts**, next to a toggle that enables or disables the agent. Read the prompt: it defines the five conversation phases, including the mandatory confirmation before anything is created.

---

## Testing

1. Open the Back Office Assistant and select **Product Creation**, or leave it on Auto.
2. Ask: *"Which tax sets can I use for a new product?"* You see the `list_tax_sets` tool call stream in, followed by the list. This proves Parts 1, 3, 4, and 5.
3. Ask: *"Create a red cotton t-shirt in sizes S and M for 19.99 EUR, 50 in stock each."* Answer the agent's questions and confirm the summary.
4. Open the edit link from the final answer. Check the variants, the price, the stock, and the approval status. Approval proves Part 2.
5. Optional: let the agent generate a product image. This uses the OpenAI image model and costs more than a chat message.

> **Searchability:** the product appears in storefront search only after Publish and Synchronize ran, as in Exercise 10.

## Solution

```bash
./exercises/load.sh ai-product-creation advanced/ai-foundation-agent/complete
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console configuration:sync
docker/sdk console cache:empty-all
```

For the `complete` branch the loader also does the wiring of Part 5 for you. It marks every line it adds with `ai-product-creation exercise` and removes those lines again when you load the skeleton or another package.

> **Switching packages:** if you wired Part 5 by hand, remove those lines before you load `contact-request` or `supplier`. The loader replaces `src/SprykerAcademy/`, and the Back Office fails when a registered plugin class no longer exists. The loader warns you about this.

## Going Further

- Change the system prompt so the agent always proposes a SKU prefix, and watch the behavior change without a deployment.
- Add a tenth tool, for example `get_product` to look up an existing product by SKU. Remember the three places: the tool class, the factory, and the tool set.
- Read the audit log to see every prompt and tool call your agent made.
