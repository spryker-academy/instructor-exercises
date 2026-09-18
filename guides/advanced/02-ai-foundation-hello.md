# Exercise 19: Hello AI - A Storefront API Backed by an LLM

In this exercise, you will build a Storefront API endpoint with API Platform. A client posts a message, the endpoint sends it to a large language model (LLM) through AiFoundation, and returns the answer. The LLM remembers the conversation: send the returned conversation reference with the next message, and it knows what was said before.

You will learn how to:
- Register an **AI configuration** in `config_ai.php`: provider, API key, model, and system prompt
- Send a prompt from the Glue application through the **AiFoundation client**, never through the provider library directly
- Give the LLM **memory** with a conversation reference
- Define an API Platform **POST resource** with a processor

**Official documentation:**
- [AI Foundation module](https://docs.spryker.com/docs/dg/dev/ai/ai-foundation/ai-foundation-module.html)
- [API Platform: resource schemas](https://docs.spryker.com/docs/integrations/spryker-api/api-platform/resource-schemas.html)
- [API Platform: cache warming](https://docs.spryker.com/docs/integrations/spryker-api/api-platform/api-platform.html#cache-warming)

## Prerequisites

- The AI Commerce feature is installed and an OpenAI API token is saved in the Back Office under **Configuration > AI Vendor > OpenAI**. The Back Office Assistant is not required.
- Completed Exercise 12 (Glue Storefront API). You know resource schemas, providers, and `glue api:generate`.

## Loading the Exercise

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-hello/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console cache:empty-all
docker/sdk console propel:model:build
docker/sdk console configuration:sync
```

The loader copies the module to `src/SprykerAcademy/`, registers `src/SprykerAcademy` as an API Platform source directory in `config/Glue`, `config/GlueStorefront`, and `config/GlueBackend`, and installs the tests.

---

## Background: Who Talks to Whom

```
curl  --POST /ai-chats-->  Glue (API Platform)
                              |
                    AiChatsStorefrontProcessor
                              |  AiFoundationClient::prompt()      <- Client layer, Zed request
                              v
                            Zed: AiFoundation facade
                              |  resolves the AI configuration by name
                              |  loads the history of the conversation reference
                              |  calls the provider (OpenAI, Bedrock, Anthropic)
                              |  stores the new messages under the reference
                              v
                            answer  -->  back to Glue  -->  JSON:API response
```

| Concept | Where | Why it matters |
|---------|-------|----------------|
| **AI configuration** | `config/Shared/config_ai.php` | A named bundle of provider, key, model, and system prompt. Code refers to it by name only, so the provider can change without a deployment of the code |
| **AiFoundation client** | `Spryker\Client\AiFoundation\AiFoundationClientInterface` | The only door from Glue or Yves to the LLM. It forwards the prompt to Zed |
| **Conversation reference** | `PromptRequestTransfer::conversationReference` | AiFoundation stores every message under this string and replays the history on the next prompt. No reference, no memory |
| **NeuronAI** | vendor library | AiFoundation uses it internally. Your code never does |

> **Why not call OpenAI directly?** The API token lives in the Back Office configuration, the audit log records every prompt, and the provider can be switched per configuration. All of that only works when every call goes through AiFoundation.

---

## Working on the Exercise

### Part 1: The Resource Schema

Open `src/SprykerAcademy/Glue/HelloAi/resources/api/storefront/ai-chats.resource.yml`. Complete **TODO-1** to **TODO-4**:

1. Set `processor` to `SprykerAcademy\Glue\HelloAi\Api\Storefront\Processor\AiChatsStorefrontProcessor`. A POST resource has a processor. The GET resources of Exercise 12 had a provider.
2. Declare one operation of type `Post` with `uriTemplate: '/ai-chats'` and `normalizationContext: { gen_id: false }`.
3. Declare `conversationReference`: type string, writable, readable, not required.
4. Declare `answer`: type string, readable, not writable.

The `message` property is already there. Look at how `writable`, `readable`, and `required` describe the direction of each field.

> **Reference:** `vendor/spryker/agent-auth-rest-api/resources/api/storefront/agent-customer-impersonation-access-tokens.resource.yml` is a complete POST resource from the core.

### Part 2: The Processor

Open `src/SprykerAcademy/Glue/HelloAi/Api/Storefront/Processor/AiChatsStorefrontProcessor.php`. The class extends `AbstractStorefrontProcessor`, which routes a POST request to `processPost()`.

**TODO-5:** add a constructor that receives `AiFoundationClientInterface` and stores it. Symfony autowires the client.

**TODO-6:** decide the conversation reference. Reuse the one from the request, or generate a new one with `uniqid(static::CONVERSATION_REFERENCE_PREFIX)`.

**TODO-7:** build the prompt request and send it:

| Setter | Value |
|--------|-------|
| `setAiConfigurationName()` | `HelloAiConstants::AI_CONFIGURATION_HELLO_AI` |
| `setConversationReference()` | the reference from TODO-6 |
| `setPromptMessage()` | a `PromptMessageTransfer` with type `AiFoundationConstants::MESSAGE_TYPE_USER` and the message as content |

Then call `$this->aiFoundationClient->prompt($promptRequestTransfer)`.

**TODO-8:** if the response is not successful or has no message, throw a `ServiceUnavailableHttpException`. Otherwise copy the conversation reference and the answer into the resource and return it.

> **Where is the answer?** `PromptResponseTransfer::getMessage()` returns a `PromptMessageTransfer`. Its `getContent()` is the text of the LLM.

### Verify Parts 1 and 2

```bash
docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate
docker/sdk cli vendor/bin/codecept build -c tests/SprykerAcademyTest/Glue/HelloAi/
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Glue/HelloAi/ Exercise19
```

`api:generate` creates `Generated\Api\Storefront\AiChatsStorefrontResource`, which the tests need. All 11 tests must pass. The AiFoundation client is mocked, so no token is spent. One test fails if your processor references the `NeuronAI` namespace.

### Part 3: The AI Configuration

Your code names a configuration that does not exist yet. Add it to `config/Shared/config_ai.php`:

```php
use SprykerAcademy\Shared\HelloAi\HelloAiConstants;

$config[AiFoundationConstants::AI_CONFIGURATIONS][HelloAiConstants::AI_CONFIGURATION_HELLO_AI] = [
    'provider_name' => AiFoundationConstants::PROVIDER_OPENAI,
    'provider_config' => [
        'key' => AiFoundationConstants::CONFIGURATION_REFERENCE_PREFIX . AiCommerceConstants::CONFIGURATION_KEY_OPENAI_API_TOKEN,
        'model' => 'gpt-4.1-mini',
    ],
    'system_prompt' => 'You are a friendly assistant for a Spryker developer training. Answer in one or two short sentences.',
];
```

Put the `use` line at the top with the other imports. `AiCommerceConstants` here is `Pyz\Shared\AiCommerce\AiCommerceConstants`, which the demo shop already imports in this file.

> **Two ways to set a value.** `key` uses the prefix `configuration::` and is read at runtime from the Back Office configuration. `model` and `system_prompt` are plain strings. Both forms are valid for every field. Use the prefix for secrets and for anything an admin should change without a deployment.

### Part 4: Apply and Call the API

```bash
docker/sdk console cache:empty-all
docker/sdk console propel:model:build
docker/sdk console configuration:sync
docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear
docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue cache:clear
```

> **Why two cache commands?** The Glue applications compile a Symfony container that caches the API Platform source directories and routes. `cache:empty-all` does not touch it. In the demo shop, `glue.eu.spryker.local` is served by the `GLUE` application, and `GLUE_STOREFRONT` is the dedicated storefront application. Clear both. This is the documented step, see *API Platform: cache warming* above.

Send the first message:

```bash
curl -s -X POST http://glue.eu.spryker.local/ai-chats \
  -H 'Content-Type: application/vnd.api+json' \
  -d '{"data":{"type":"ai-chats","attributes":{"message":"Hello world! My name is Hidran."}}}'
```

```json
{"data":{"id":null,"type":"ai-chats","attributes":{"message":"Hello world! My name is Hidran.","conversationReference":"hello-ai-6aac7af26ec95","answer":"Hello Hidran! How can I assist you with Spryker development today?"}}}
```

Now send the `conversationReference` back with a second message:

```bash
curl -s -X POST http://glue.eu.spryker.local/ai-chats \
  -H 'Content-Type: application/vnd.api+json' \
  -d '{"data":{"type":"ai-chats","attributes":{"message":"What is my name?","conversationReference":"hello-ai-6aac7af26ec95"}}}'
```

The answer names you. Send the same question without the reference, and the LLM does not know you. That is the memory.

---

## Testing

1. First message without a reference returns an answer and a new `conversationReference`.
2. Second message with that reference gets an answer that uses the earlier context.
3. Same question without the reference gets an answer without that context.
4. An empty `message` returns HTTP 422 with the message *The attribute "message" must not be empty.*
5. AiFoundation records every prompt of the `SPRYKER_ACADEMY:AI_CONFIGURATION_HELLO_AI` configuration in its audit log, separate from the other AI features.

## Solution

```bash
./exercises/load.sh ai-foundation advanced/ai-foundation-hello/complete
docker/sdk cli composer dump-autoload
docker/sdk console transfer:generate
docker/sdk console cache:empty-all
docker/sdk console propel:model:build
docker/sdk console configuration:sync
docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate
docker/sdk cli GLUE_APPLICATION=GLUE glue cache:clear
docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue cache:clear
```

For the `complete` branch the loader adds the AI configuration of Part 3 for you, marked with `ai-foundation exercise`. It removes it again when you load the skeleton or another package.

## Going Further

- Change the system prompt to answer only in German, and clear the caches. No code changed.
- Switch the model to `gpt-4.1` and compare answers.
- Add a `GET /ai-chats/{conversationReference}` operation with a provider that returns the history through `AiFoundationClientInterface::getConversationHistoryCollection()`.
- Exercise 20 builds on this: the same `PromptRequestTransfer`, plus a tool and a structured answer.
