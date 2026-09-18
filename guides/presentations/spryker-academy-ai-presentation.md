<!-- Generated from guides-html/spryker-academy-ai-presentation.html. Edit the HTML, then run: python3 tools/presentation_to_markdown.py <html> <md> -->

# Spryker Academy

## AI Foundation Exercises

LLM Prompts, Memory, Tools, Structured Answers, Back Office Assistant Agents

Namespace: `SprykerAcademy\` \| Modules: `HelloAi`, `CatalogAssistant`, `AiProductCreation`

---

## Agenda

| \#  | Topic                       | Key Concepts                                                  |
|-----|-----------------------------|---------------------------------------------------------------|
| —   | AI Foundation               | AI configurations, providers, prompt request, audit log       |
| —   | Back Office Assistant Setup | Intent router, agents, tool sets, SSE, configuration sync     |
| 19  | Hello AI                    | Storefront API + AiFoundation client + conversation memory    |
| 20  | Ask the Catalog             | Tool plugin, tool set, structured transfer answer, guardrails |
| 21  | Product Creation Agent      | Agent plugin, 9 tools, system prompt, SSE streaming           |

> **Prerequisites:** AI Commerce feature installed, OpenAI token in *Configuration &gt; AI Vendor*. Exercise 21 also needs the Back Office Assistant.

---

## AI Foundation

### One Door to Every LLM

> **Idea:** Application code never talks to OpenAI, Bedrock, or Anthropic directly. It sends a `PromptRequestTransfer` to AiFoundation and names a configuration.

-   `spryker/ai-foundation` — provider adapters (NeuronAI inside), tool execution, conversation history, audit log
-   `spryker-feature/ai-commerce` — features on top: Smart PIM, Back Office Assistant, Smart CMS
-   Zed: `AiFoundationFacade::prompt()`  \|  Glue/Yves: `AiFoundationClient::prompt()` (Zed request)

---

### AI Configuration

```php
// config/Shared/config_ai.php
$config[AiFoundationConstants::AI_CONFIGURATIONS][HelloAiConstants::AI_CONFIGURATION_HELLO_AI] = [
    'provider_name' => AiFoundationConstants::PROVIDER_OPENAI,
    'provider_config' => [
        // "configuration::" prefix: read at runtime from Back Office > Configuration
        'key'   => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_OPENAI_API_TOKEN,
        'model' => 'gpt-4.1-mini',                       // plain value
    ],
    'system_prompt' => 'You are a friendly assistant ...', // plain value or configuration:: reference
];
```

-   Code refers to a configuration **by name** — the provider can change without a code deployment
-   One configuration per feature or agent: each is tracked separately in the audit log
-   Secrets and admin-editable texts use the `configuration::` prefix

---

### The Prompt Request

```php
$promptRequest = (new PromptRequestTransfer())
    ->setAiConfigurationName(HelloAiConstants::AI_CONFIGURATION_HELLO_AI) // provider, model, system prompt
    ->setConversationReference('hello-ai-6aac7af26ec95')                  // memory: history is stored + replayed
    ->addToolSetName('catalog_tools')                                     // tools the model MAY call (Ex. 20)
    ->setStructuredMessage(new ProductAnswerTransfer())                   // shape the model MUST answer in (Ex. 20)
    ->setMaxRetries(2)                                                    // retry when the shape does not fit
    ->setPromptMessage((new PromptMessageTransfer())
        ->setType(AiFoundationConstants::MESSAGE_TYPE_USER)
        ->setContent('Hello world!'));

$promptResponse = $this->aiFoundationClient->prompt($promptRequest);
$promptResponse->getIsSuccessful();          // false + getErrors() on failure
$promptResponse->getMessage()->getContent(); // free text answer
$promptResponse->getStructuredMessage();     // typed transfer when requested
```

The three exercises add one line at a time: 19 = configuration + memory, 20 = tools + structure, 21 = the same request inside an agent.

---

### What the Model Sees

| Concept           | Class                    | Visible to the model                                                              |
|-------------------|--------------------------|-----------------------------------------------------------------------------------|
| Tool              | `ToolPluginInterface`    | Only `getName()`, `getDescription()`, `getParameters()`. Never `execute()`        |
| Tool set          | `ToolSetPluginInterface` | Nothing. A named group the request asks for                                       |
| Structured answer | any transfer             | A JSON schema built from the transfer. Property descriptions = field instructions |
| System prompt     | configuration            | The full text. Defines behavior and guardrails                                    |
| Business logic    | Facades, readers         | Nothing                                                                           |

> **The description is the interface.** A vague tool description is never called or called at the wrong time. Write it for a reader who has never seen your code.

---

## Back Office Assistant Setup

### Prerequisite for Exercise 21

> **Goal:** An AI chat widget in the Back Office that routes each message to an agent, which may call tools.

Guide: `guides/advanced/01-back-office-assistant-setup.md` — follows the official *Install Back Office Assistant* page.

---

### Request Flow

```text
  Chat widget (Twig partial, marked + dompurify)
        |
  Intent router  --- reads every agent's getDescription() ---> picks ONE agent
        |
  Agent plugin::executeAgent()   builds a PromptRequestTransfer, names its tool set
        |
  AiFoundation   system prompt + tool definitions --> provider --> tool calls run in Zed
        |                    SSE pre/post tool call plugins stream progress to the widget
  Structured answer --> BackofficeAssistantPromptResponseTransfer --> widget
```

---

### Seven Steps

1.  `Pyz\Shared\AiCommerce\AiCommerceConstants` — model key + 5 configuration names (router, 4 agents)
2.  `config_ai.php` — 5 OpenAI entries, agents reference their system prompt setting
3.  `Pyz\Zed\AiCommerce\AiCommerceConfig` — `get*AiConfigurationName()` overrides (default is `null`)
4.  Plugins: agents in `AiCommerceDependencyProvider`; tool sets, SSE, audit log in `AiFoundationDependencyProvider`; `AiCommerceTwigPlugin`
5.  `data/configuration/ai_commerce.configuration.yml` — AI Vendor tab, then `configuration:sync`
6.  Back Office: *AI Commerce &gt; Back Office Assistant &gt; General &gt; Enable* (off by default)
7.  `npm install marked dompurify` + `frontend:zed:build`

---

### Registering Agents and Tool Sets

```php
// src/Pyz/Zed/AiCommerce/AiCommerceDependencyProvider.php
protected function getBackofficeAssistantAgentPlugins(): array
{
    return [
        new GeneralAgentPlugin(),
        new OrderManagementAgentPlugin(),
        new DiscountManagementAgentPlugin(),
        new FormFillAgentPlugin(),
    ];
}

// src/Pyz/Zed/AiFoundation/AiFoundationDependencyProvider.php
protected function getAiToolSetPlugins(): array          { /* NavigationToolSetPlugin, ... */ }
protected function getPreToolCallPlugins(): array        { return [new BackofficeAssistantSsePreToolCallPlugin()]; }
protected function getPostToolCallPlugins(): array       { return [new BackofficeAssistantSsePostToolCallPlugin(), new AuditLogPostToolCallPlugin()]; }
protected function getPostPromptPlugins(): array         { return [new AuditLogPostPromptPlugin()]; }
```

> **Verify:** chat icon bottom-right on every Back Office page. Ask *"Where can I create a discount?"*

---

## Exercise 19: Hello AI

### A Storefront API Backed by an LLM

> **Goal:** `POST /ai-chats` sends a message to the LLM through the AiFoundation *client* and returns the answer. A conversation reference gives the LLM memory.

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-hello/skeleton
```

---

### Who Talks to Whom

```text
  curl --POST /ai-chats--> Glue (API Platform)
                              |
                    AiChatsStorefrontProcessor
                              |  AiFoundationClient::prompt()      <- Client layer, Zed request
                              v
                            Zed: AiFoundation facade
                              |  resolves the AI configuration by name
                              |  loads the history of the conversation reference
                              |  calls the provider, stores the new messages
                              v
                            answer --> back to Glue --> JSON:API response
```

<span class="accent">Never NeuronAI directly.</span> Token in Back Office config, audit log, switchable provider: all of it only works through AiFoundation. A test fails if the processor references the `NeuronAI\` namespace.

---

### The Resource Schema

```yaml
resource:
    name: AiChats
    shortName: ai-chats
    processor: SprykerAcademy\Glue\HelloAi\Api\Storefront\Processor\AiChatsStorefrontProcessor
    operations:
        - type: Post
          uriTemplate: '/ai-chats'
          normalizationContext: { gen_id: false }
    properties:
        message:               { type: string, writable: true,  readable: true, required: true }
        conversationReference: { type: string, writable: true,  readable: true, required: false }
        answer:                { type: string, writable: false, readable: true }
```

-   POST resource = **processor** (Exercise 12 GET resources used a provider)
-   `writable` / `readable` describe the direction of each field

---

### The Processor

```php
class AiChatsStorefrontProcessor extends AbstractStorefrontProcessor
{
    public function __construct(protected AiFoundationClientInterface $aiFoundationClient) {} // autowired

    protected function processPost(mixed $data): mixed
    {
        $conversationReference = $data->conversationReference ?: uniqid('hello-ai-');

        $promptResponse = $this->aiFoundationClient->prompt((new PromptRequestTransfer())
            ->setAiConfigurationName(HelloAiConstants::AI_CONFIGURATION_HELLO_AI)
            ->setConversationReference($conversationReference)
            ->setPromptMessage((new PromptMessageTransfer())
                ->setType(AiFoundationConstants::MESSAGE_TYPE_USER)->setContent($data->message)));

        if (!$promptResponse->getIsSuccessful()) {
            throw new ServiceUnavailableHttpException(null, 'The AI provider did not return an answer.');
        }
        $data->conversationReference = $conversationReference;
        $data->answer = $promptResponse->getMessageOrFail()->getContent();
        return $data;
    }
}
```

---

### Memory in Action

```bash
# 1st message: no reference -> a new one comes back
curl -s -X POST http://glue.eu.spryker.local/ai-chats -H 'Content-Type: application/vnd.api+json' \
  -d '{"data":{"type":"ai-chats","attributes":{"message":"Hello world! My name is Hidran."}}}'
# {"conversationReference":"hello-ai-6aac7af26ec95","answer":"Hello Hidran! How can I assist you ..."}

# 2nd message: send the reference back
#   "What is my name?"  ->  "Your name is Hidran."
# same question without the reference  ->  "I don't know your name yet."
```

> **Apply:** `glue api:generate`, then `GLUE_APPLICATION=GLUE glue cache:clear` and the same for `GLUE_STOREFRONT`. The compiled Glue kernels cache API Platform source directories and routes — `cache:empty-all` does not touch them.

Tests: `codecept run -c tests/SprykerAcademyTest/Glue/HelloAi/ Exercise19` — 11 tests, client mocked, no tokens spent.

---

## Exercise 20: Ask the Catalog

### Tool Calling and Structured Answers

> **Goal:** `POST /product-questions` with a SKU and a question. The LLM reads the product through a *tool in Zed* and answers in a *typed transfer*: answer, isInStock, confidence, relatedSkus.

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-catalog/skeleton
```

---

### One Request, Several Round Trips

```text
  POST /product-questions {sku, question}
     |
  ProductQuestionsStorefrontProcessor   tool set name + structured message + conversation reference
     v  AiFoundationClient::prompt()
  Zed: AiFoundation
     |  1. system prompt, question, TOOL DEFINITIONS --> provider
     |  2. model: "call get_product_details(sku=M1000785)"
     |  3. AiFoundation runs GetProductDetailsToolPlugin::execute() in Zed, sends JSON back
     |  4. model answers in the JSON shape of ProductAnswerTransfer
     |  5. AiFoundation validates the shape, retries when it does not fit
     v
  typed ProductAnswerTransfer --> processor maps it --> JSON:API response
```

<span class="accent">Tools run in Zed.</span> Glue only names the tool set. AiFoundation looks it up in the Zed `AiFoundationDependencyProvider` and executes tools with full facade access.

---

### The Tool

```php
class GetProductDetailsToolPlugin extends AbstractPlugin implements ToolPluginInterface
{
    public function getName(): string { return 'get_product_details'; }

    public function getDescription(): string
    {
        return 'Returns the details of one catalog product by SKU: name, attributes, every variant with '
            . 'availability and gross price in cents. Call it before answering any question about a product.';
    }

    public function getParameters(): array
    {
        return [new ToolParameter(name: 'sku', type: 'string', description: 'Abstract or concrete SKU.', isRequired: true)];
    }

    public function execute(...$arguments): mixed   // thin: delegate, return JSON, never throw
    {
        return $this->getBusinessFactory()->createProductDetailsReader()
            ->getProductDetailsJson((string)($arguments['sku'] ?? ''));
    }
}
```

Parameter names are a contract: `$arguments['sku']`. Tools return JSON strings, errors as `{"error": "..."}` so the model can explain them.

---

### Tool Set and Registration

```php
class CatalogToolSetPlugin extends AbstractPlugin implements ToolSetPluginInterface
{
    public function getName(): string { return CatalogAssistantConstants::TOOL_SET_CATALOG; } // 'catalog_tools'

    public function getTools(): array
    {
        return [$this->getFactory()->createGetProductDetailsToolPlugin()];
    }
}

// src/Pyz/Zed/AiFoundation/AiFoundationDependencyProvider.php
protected function getAiToolSetPlugins(): array
{
    return [/* ... */ new CatalogToolSetPlugin()];
}
```

> A tool that is not in a registered tool set **does not exist** for the model, even if its class is complete.

---

### The Structured Answer

```xml
<transfer name="ProductAnswer" strict="true">
    <property name="answer"      type="string"   description="The answer, based only on the product details returned by the tools."/>
    <property name="isInStock"   type="bool"     description="True when at least one variant is available. False otherwise,
                                                              and also when the product was not found. Never null."/>
    <property name="confidence"  type="string"   description="'high', 'medium', or 'low'. 'low' when the tools returned nothing useful."/>
    <property name="relatedSkus" type="string[]" singular="relatedSku"
                                                 description="Concrete SKUs that match the question best. An empty list when none apply, never null."/>
</transfer>
```

-   AiFoundation turns the transfer into a JSON schema; **descriptions are the field instructions**
-   <span class="warning">Never null:</span> an answer with a null property is rejected. Say what to return when unknown
-   Processor: `setStructuredMessage(new ProductAnswerTransfer())` + `setMaxRetries(2)`, then typed getters

---

### Guardrail and Result

```php
'system_prompt' => 'You are a product advisor for an online shop. ALWAYS call get_product_details with the given SKU '
    . 'before answering, even for follow-up questions. Answer only with facts from the tool result. If the tool '
    . 'returns an error or the details do not cover the question, say so and set confidence to low. '
    . 'Prices in the tool result are gross amounts in cents; show them in major units.',
```

```json
// SKU M1000785, "What is this product, is it in stock, and how much does it cost?"
{"answer":"This product is a set of 4 wood stackable chairs ... in stock with 20 pieces available ... 482.69 euros.",
 "isInStock":true,"confidence":"high","relatedSkus":["212427"]}

// SKU DOES-NOT-EXIST
{"answer":"There is no product found with the SKU \"DOES-NOT-EXIST\" ...","isInStock":false,"confidence":"low","relatedSkus":[]}
```

HTTP 503 with the AiFoundation reason when the shape does not fit, e.g. *Missing or empty properties: is\_in\_stock* — fix the description, not the code. Tests: 15, client mocked.

---

## Exercise 21: Product Creation Agent

### A Custom Back Office Assistant Agent

> **Goal:** "Create a red cotton t-shirt in sizes S and M for 19.99 EUR" — the agent interviews, confirms, then calls tools to create the product, price, stock, category, approval, and image.

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-agent/skeleton
```

Requires the Back Office Assistant. Business logic (ProductCreationWriter, image generation) is provided; you build the AI Foundation layer.

---

### Module Layout

| Piece             | Class / file                                                | Your task                                                                  |
|-------------------|-------------------------------------------------------------|----------------------------------------------------------------------------|
| 9 tools           | `Plugin/AiFoundation/Tool/*ToolPlugin`                      | Complete `ListTaxSetsToolPlugin`, parameters of `ApproveProductToolPlugin` |
| Tool set          | `ProductCreationToolSetPlugin`                              | Name + all nine tools from the factory                                     |
| Agent             | `Plugin/Agent/ProductCreationAgentPlugin`                   | Build the prompt request, map the structured answer                        |
| Structured answer | `ProductCreationAgentResponse` transfer                     | `agent` lets the model answer *Guardrail*                                  |
| System prompt     | `ai_product_creation.configuration.yml`                     | 5 phases; editable in the Back Office after `configuration:sync`           |
| Wiring            | 2 dependency providers, `config_ai.php`, `AiCommerceConfig` | Register, configure, enable SSE                                            |

---

### The Agent Plugin

```php
class ProductCreationAgentPlugin extends AbstractPlugin implements BackofficeAssistantAgentPluginInterface
{
    // getName() 'Product Creation' is matched against the router's answer; getDescription() drives the routing;
    // isApplicable() gates the agent behind the Back Office toggle.

    public function executeAgent(BackofficeAssistantPromptRequestTransfer $request): BackofficeAssistantPromptResponseTransfer
    {
        $promptRequest = (new PromptRequestTransfer())
            ->setAiConfigurationName($this->getConfig()->getProductCreationAgentAiConfigurationName())
            ->setConversationReference($request->getConversationReference())
            ->setStructuredMessage(new ProductCreationAgentResponseTransfer())
            ->addToolSetName(AiProductCreationConstants::TOOL_SET_PRODUCT_CREATION)
            ->setPromptMessage((new PromptMessageTransfer())
                ->setType(AiFoundationConstants::MESSAGE_TYPE_USER)
                ->setContent($request->getPrompt())
                ->setAttachments($request->getAttachments()));

        $answer = $this->getFactory()->getAiFoundationFacade()->prompt($promptRequest)->getStructuredMessage();

        return (new BackofficeAssistantPromptResponseTransfer())
            ->setAgent($answer->getAgent())
            ->setMessage($answer->getMessage())
            ->setReasoningMessage($answer->getReasoningMessage());
    }
}
```

Same `PromptRequestTransfer` as Exercises 19 and 20 — now inside an agent that the intent router selects by its description.

---

### Wiring the Agent

1.  `AiCommerceDependencyProvider::getBackofficeAssistantAgentPlugins()` += `new ProductCreationAgentPlugin()`
2.  `AiFoundationDependencyProvider::getAiToolSetPlugins()` += `new ProductCreationToolSetPlugin()`
3.  `config_ai.php`: `AI_CONFIGURATION_PRODUCT_CREATION_OPENAI` reusing the assistant's token and model, own system prompt via `configuration::`
4.  `AiCommerceConfig::getBackofficeAssistantSseAiConfigurationNames()` += the configuration name (tool progress streams only for listed names)
5.  `configuration:sync` loads the enable toggle and the system prompt into the Back Office

> **Order matters:** `composer dump-autoload` first — `config_ai.php` references a `SprykerAcademy` class. The loader wires the `complete` branch itself and marks every line with `ai-foundation exercise`.

---

### A Real Conversation

```text
  User:  Create ILT-TEE-01, "ILT Test T-Shirt", one variant size M, 19.99 EUR, 50 in stock, approve it.
  Agent: [summary of everything it will create]  "Shall I create this product?"
  User:  Yes.
         list_tax_sets      --> {"taxSets":[{"idTaxSet":1,"name":"Standard Taxes"}, ...]}
         create_product     --> {"idProductAbstract":469,"concretes":[{"sku":"ILT-TEE-01-M",...}]}
         set_product_price  --> {"message":"Price 1999 EUR set for ..."}
         set_product_stock  --> {"message":"Stock 50 set for ... in Warehouse1"}
         approve_product    --> {"message":"Approval status changed from draft to approved."}
  Agent: [final summary + link to edit the product]
```

Every tool call streams into the chat widget through the SSE plugins. Tests: 12, facade mocked — `codecept run -c tests/SprykerAcademyTest/Zed/AiProductCreation/ Exercise21`.

---

## Key Takeaways

-   <span class="accent">AI configuration</span> — named bundle of provider, key, model, system prompt; code names it, admins change it
-   <span class="accent">One door</span> — Zed facade or Client `prompt()`, never the provider library
-   <span class="accent">Memory</span> — a conversation reference; AiFoundation stores and replays the history
-   <span class="accent">Tools</span> — name, description, typed parameters are the contract; thin `execute()`, JSON in and out, run in Zed; unregistered tools do not exist
-   <span class="accent">Structured answers</span> — a transfer becomes the JSON schema; descriptions instruct the model; never null; retries
-   <span class="accent">Guardrails</span> — "answer only with facts from the tool result", confidence field, Guardrail agent value
-   <span class="accent">Agents</span> — description drives the intent router; SSE streams tool progress for listed configurations
-   <span class="accent">Apply and test</span> — `glue cache:clear` per Glue app, `configuration:sync` for settings; mock the client, spend no tokens

---

# Questions?

Spryker Academy \| AI Foundation Exercises
