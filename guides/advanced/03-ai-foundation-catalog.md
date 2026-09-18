# Exercise 20: Ask the Catalog - Tool Calling and Structured Answers

In this exercise, you extend the Hello AI pattern with the two ideas that make an LLM useful in a shop. A customer asks a question about a product. The LLM does not know your catalog, so it **calls a tool** that reads the product from the database. Then it answers in a **fixed structure** with typed fields instead of free text.

You will learn how to:
- Write a **tool plugin** that the LLM can call: name, description, typed parameters, and execution in Zed
- Group tools in a **tool set plugin** and register it with AiFoundation
- Define a **structured answer** as a transfer object and get typed getters back
- Request tools and the answer shape from a Storefront API processor
- Write a system prompt with a **guardrail** against invented facts

**Official documentation:**
- [Extend AI Commerce agents with custom toolsets](https://docs.spryker.com/docs/dg/dev/ai/ai-commerce/extend-ai-commerce-agents-with-toolsets.html)
- [AI Foundation module](https://docs.spryker.com/docs/dg/dev/ai/ai-foundation/ai-foundation-module.html)

## Prerequisites

- Completed [Exercise 19: Hello AI](02-ai-foundation-hello.md). The endpoint, the processor, and the AI configuration follow the same pattern.
- An OpenAI API token in the Back Office. The Back Office Assistant is not required.

## Loading the Exercise

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-catalog/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console cache:empty-all
```

---

## Background: One Request, Several Round Trips

```
POST /product-questions {sku, question}
   |
ProductQuestionsStorefrontProcessor   builds a PromptRequestTransfer with
   |                                  tool set name + structured message + conversation reference
   v  AiFoundationClient::prompt()
Zed: AiFoundation
   |  1. sends system prompt, question, and the TOOL DEFINITIONS to the provider
   |  2. the model answers "call get_product_details(sku=...)"
   |  3. AiFoundation runs GetProductDetailsToolPlugin::execute() in Zed and sends the JSON result back
   |  4. the model answers in the JSON shape of ProductAnswerTransfer
   |  5. AiFoundation validates the shape, retries when it does not fit
   v
typed ProductAnswerTransfer  -->  processor maps it  -->  JSON:API response
```

| Piece | Class | What the model sees |
|-------|-------|---------------------|
| **Tool** | `GetProductDetailsToolPlugin` | Only `getName()`, `getDescription()`, and `getParameters()`. It never sees `execute()` |
| **Tool set** | `CatalogToolSetPlugin` | Nothing. It is the name the processor requests |
| **Structured answer** | `ProductAnswerTransfer` | A JSON schema built from the transfer. The property descriptions are the field instructions |
| **Business logic** | `ProductDetailsReader` | Nothing. Tools are thin, the reader does the work with facades |

> **Tools run in Zed.** The Storefront API only names the tool set. AiFoundation looks the tool set up in the Zed `AiFoundationDependencyProvider` and executes tools there, with full access to facades. That is why the tool plugin lives in `src/SprykerAcademy/Zed` while the endpoint lives in `Glue`.

The business layer is provided. Open `ProductDetailsReader` once: it resolves an abstract or concrete SKU, collects name, description, attributes, and every variant with availability and price, and returns one JSON string. When nothing is found, it returns a JSON error. The tool passes that string to the model unchanged.

---

## Working on the Exercise

### Part 1: The Tool

Open `src/SprykerAcademy/Zed/CatalogAssistant/Communication/Plugin/AiFoundation/Tool/GetProductDetailsToolPlugin.php`. Complete **TODO-1** to **TODO-4**:

1. `getName()` returns `'get_product_details'`.
2. `getDescription()` says what comes back, what the tool needs, and when to call it. Write it for a reader who has never seen your code: "Call it before answering any question about a product."
3. `getParameters()` returns one required `ToolParameter` named `sku` of type `string`.
4. `execute()` delegates to `ProductDetailsReader::getProductDetailsJson()` with the `sku` argument.

> **The parameter name is a contract.** AiFoundation passes the model's arguments to `execute(...$arguments)` as a named array. The reader is called with `$arguments['sku']`. Rename the parameter and the value is lost.

### Part 2: The Tool Set

Open `CatalogToolSetPlugin.php` in the parent directory. **TODO-5** returns `CatalogAssistantConstants::TOOL_SET_CATALOG`. **TODO-6** returns the tool from the factory.

### Part 3: The Structured Answer

Open `src/SprykerAcademy/Shared/CatalogAssistant/Transfer/catalog_assistant.transfer.xml`. The `ProductAnswer` transfer has only `answer`. **TODO-7:** add `isInStock` (bool), `confidence` (string), and `relatedSkus` (string[]) with descriptions.

Then regenerate the transfer:

```bash
docker/sdk console transfer:generate
```

> **Never null.** AiFoundation validates the model's JSON against the transfer and rejects an answer with a null property. A description like "null when unknown" therefore causes failures. Say instead what to return when the value is unknown: `false`, `'low'`, or an empty list. The tests check for the words "never null" in the two descriptions where this matters.

### Part 4: The Processor

Open `src/SprykerAcademy/Glue/CatalogAssistant/Api/Storefront/Processor/ProductQuestionsStorefrontProcessor.php`. The prompt request already carries the configuration name, the conversation reference, and the message. **TODO-8** adds three calls:

| Call | Effect |
|------|--------|
| `addToolSetName(CatalogAssistantConstants::TOOL_SET_CATALOG)` | The model may call every tool in that set |
| `setStructuredMessage(new ProductAnswerTransfer())` | The model must answer in that shape |
| `setMaxRetries(2)` | AiFoundation retries when the answer does not fit the shape |

**TODO-9:** copy `answer`, `isInStock`, `confidence`, and `relatedSkus` from the typed transfer into the resource.

The resource schema `product-questions.resource.yml` is complete. Read it to see how the four answer fields are declared read-only.

### Verify Parts 1 to 4

```bash
docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate
docker/sdk cli vendor/bin/codecept build -c tests/SprykerAcademyTest/Zed/CatalogAssistant/
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/CatalogAssistant/ Exercise20
```

All 15 tests must pass. The client is mocked, so no token is spent.

### Part 5: Wire It Into the Project

**1. Register the tool set.** In `src/Pyz/Zed/AiFoundation/AiFoundationDependencyProvider.php`, add `new CatalogToolSetPlugin()` to `getAiToolSetPlugins()`. If the file does not exist yet, create it:

```php
<?php

declare(strict_types = 1);

namespace Pyz\Zed\AiFoundation;

use Spryker\Zed\AiFoundation\AiFoundationDependencyProvider as SprykerAiFoundationDependencyProvider;
use SprykerAcademy\Zed\CatalogAssistant\Communication\Plugin\AiFoundation\CatalogToolSetPlugin;

class AiFoundationDependencyProvider extends SprykerAiFoundationDependencyProvider
{
    /**
     * @return array<\Spryker\Zed\AiFoundation\Dependency\Tools\ToolSetPluginInterface>
     */
    protected function getAiToolSetPlugins(): array
    {
        return [
            new CatalogToolSetPlugin(),
        ];
    }
}
```

**2. Add the AI configuration with a guardrail prompt** to `config/Shared/config_ai.php`:

```php
use SprykerAcademy\Shared\CatalogAssistant\CatalogAssistantConstants;

$config[AiFoundationConstants::AI_CONFIGURATIONS][CatalogAssistantConstants::AI_CONFIGURATION_CATALOG_ASSISTANT] = [
    'provider_name' => AiFoundationConstants::PROVIDER_OPENAI,
    'provider_config' => [
        'key' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_OPENAI_API_TOKEN,
        'model' => 'gpt-4.1-mini',
    ],
    'system_prompt' => 'You are a product advisor for an online shop. You answer questions about one product at a time. '
        . 'ALWAYS call get_product_details with the given SKU before answering, even for follow-up questions. '
        . 'Answer only with facts from the tool result. If the tool returns an error or the details do not cover the question, '
        . 'say so and set confidence to low. Prices in the tool result are gross amounts in cents; show them in major units. '
        . 'Keep the answer under 80 words.',
];
```

> **The guardrail.** Without "answer only with facts from the tool result", the model happily describes a product it has never seen. Test it later with a SKU that does not exist.

**3. Apply:**

```bash
docker/sdk console cache:empty-all
docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear
docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue cache:clear
```

---

## Testing

Ask about a real product from the demo data:

```bash
curl -s -X POST http://glue.eu.spryker.local/product-questions \
  -H 'Content-Type: application/vnd.api+json' \
  -d '{"data":{"type":"product-questions","attributes":{"sku":"M1000785","question":"What is this product, is it in stock, and how much does it cost?"}}}'
```

```json
{"data":{"type":"product-questions","attributes":{"sku":"M1000785","question":"...","conversationReference":"catalog-6aac80f1d0217","answer":"This product is a set of 4 wood stackable chairs ... It is currently in stock with 20 pieces available. The price for the package of 4 chairs is 482.69 euros.","isInStock":true,"confidence":"high","relatedSkus":["212427"]}}}
```

1. **Tool call:** the answer contains the real name, stock, and price. The model can only know them from the tool.
2. **Structure:** `isInStock` is a boolean, `relatedSkus` is a list, `confidence` is one of three words. No parsing on the client side.
3. **Guardrail:** ask about SKU `DOES-NOT-EXIST`. The answer says the product was not found, `isInStock` is `false`, and `confidence` is `low`.
4. **Memory:** send the `conversationReference` back with "And how many can I order at most?". The model still answers about the same product.
5. **Validation:** an empty `question` returns HTTP 422.

> **Where did the model go wrong?** When the shape does not fit, the API returns HTTP 503 with *The AI provider did not return a structured answer* followed by AiFoundation's reason, for example *Failed to map structured response to transfer. Missing or empty properties: is_in_stock*. Fix the description of that property, not the code.

## Solution

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-catalog/complete
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console cache:empty-all
docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate
docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear
docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue cache:clear
```

For the `complete` branch the loader does Part 5 for you, marked with `ai-foundation exercise`, and removes it again when you load a skeleton or another package.

## Going Further

- Add a second tool `list_similar_products` that searches the catalog by the product's category, and let the model fill `relatedSkus` from it.
- Add a `language` property to the answer and ask in German.
- Exercise 21 wraps the same tool mechanics into a Back Office Assistant agent with an intent router and streaming.
