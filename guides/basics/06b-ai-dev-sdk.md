# Exercise 6b: Build the Contact Request Module with the AI Dev SDK

In Exercises 1 to 6 you built the **ContactRequest** module by hand: a Back Office page, a transfer object, a Propel table, the Persistence, Business and Communication layers, the Client, a Yves page and a module config. In this exercise you build the same module again, this time by giving one prompt to your AI coding assistant. The Spryker AI Dev SDK provides the assistant with Spryker's architecture rules, skills and agents, and the automated tests of Exercises 1 to 6 are the acceptance criteria.

You will learn how to:
- Set up the **AI Dev SDK** in a project with `ai-dev:setup`
- Read what the SDK generates: the agents file, the rules, the skills and the agents
- Write a prompt that uses **existing tests as the specification**
- Review AI-generated Spryker code against the rules you learned in Exercises 1 to 6

**Official documentation:**
- [AI Dev SDK](https://docs.spryker.com/docs/dg/dev/ai/ai-dev/ai-dev)
- [Install AI Dev](https://docs.spryker.com/docs/dg/dev/ai/ai-dev/ai-dev-installation)

## Prerequisites

- Exercises 1 to 6 completed, so you know what "correct" looks like.
- An AI coding assistant installed on your machine: Claude Code, Cursor, GitHub Copilot, Windsurf, OpenCode or Codex. The SDK generates files for all of them.
- The `spryker-sdk/ai-dev` package. The B2B Marketplace demo shop ships it out of the box (see `composer.json`).

---

## Part 1: Set Up the AI Dev SDK

The SDK is a Composer package with console commands. Run the setup once per project:

```bash
docker/sdk console ai-dev:setup
```

The command is interactive:

1. It detects your AI tool from the folders in the project (`.claude`, `.cursor`, `.github`, ...) and asks you to confirm, or lets you pick one.
2. It asks whether to generate the files **ready to use** or as **examples** (`example.CLAUDE.md`, `.claude/skills/propel-schema-example`, ...). Choose *ready to use* for this training.
3. For each step it asks for confirmation: **Generate rules**, **Generate agents/context file**, **Generate skills**, **Generate agents**. Say yes to all. Existing files are never overwritten unless you agree.

What lands in the project depends on the tool:

| Tool | Context file | Rules | Skills | Agents |
|------|-------------|-------|--------|--------|
| Claude Code | `CLAUDE.md` | `.claude/rules/` | `.claude/skills/` | `.claude/agents/` |
| Cursor | `AGENTS.md` | `.cursor/rules/` | `.cursor/skills/` | `.cursor/agents/` |
| GitHub Copilot | `.github/copilot-instructions.md` | `.github/instructions/` | `.github/skills/` | `.github/agents/` |
| Windsurf | `.windsurfrules` | `.windsurf/rules/` | `.windsurf/skills/` | — |
| OpenCode / Codex | `AGENTS.md` | `.opencode/rules/` | `.agents/skills/` | — |

The other commands of the module generate single artifacts (`ai-dev:generate-agents-file`, `ai-dev:generate-skills`) and start the MCP server (`ai-dev:mcp-server`) that lets the assistant query transfers, interfaces and OMS information of the running application. You do not need them for this exercise.

### What to look at (5 minutes, no coding)

- **The context file** (`CLAUDE.md` or `AGENTS.md`). It is the architecture brief for the assistant: the console commands, the architectural rules (single responsibility, dependencies through the constructor, no `new` in business logic, transfers are never modified in place), and the project organization. Note the rule about the custom namespace: the assistant must write into `src/SprykerAcademy`, because that namespace is registered before `Pyz` in `PROJECT_NAMESPACES`.
- **The rules folder**: one Markdown file per convention. Open `dependency-provider.md`, `factory-pattern.md`, `layer-communication.md`, `transfer-object.md`, `persistence.md`, `controller.md` and `naming-conventions.md`. These are the same rules you applied by hand in Exercises 4 to 6.
- **The skills folder**: task recipes the assistant follows, for example `propel-schema`, `data-import`, `spryker-customization`, `codecept-functional`, `code-review`, `static-validation`, `spryker-docs-research`, `spryker-runtime`.
- **The agents folder**: specialised roles such as `spryker-feature-expert`, `spryker-code-reviewer`, `spryker-verifier`, `spryker-issue-diagnoser` and `spryker-data-seeder`.

> Do not study every file now. The point is to know that the assistant reads the same conventions you learned, and where to look when it produces something odd.

---

## Part 2: Prepare a Clean Start

Load the reference solution of Exercise 6. This installs the wiring the loader manages (navigation entry, the config value in `config_default.php`, the Yves router) and the automated tests of Exercises 1 to 6:

```bash
./exercises/load.sh contact-request basics/configuration/complete
docker/sdk cli composer dump-autoload
```

Now delete the module code and keep the wiring and the tests. This is your empty page:

```bash
rm -rf src/SprykerAcademy/Zed/ContactRequest \
       src/SprykerAcademy/Client/ContactRequest \
       src/SprykerAcademy/Shared/ContactRequest/Transfer \
       src/SprykerAcademy/Yves/ContactRequestPage
docker/sdk console transfer:generate
```

Two files stay on purpose, because the wiring references them:

- `src/SprykerAcademy/Shared/ContactRequest/ContactRequestConstants.php`: `config/Shared/config_default.php` reads `ContactRequestConstants::MY_CONFIG_VALUE`. Without the class every console command fails.
- `src/SprykerAcademy/Yves/Router/RouterDependencyProvider.php`: it registers `ContactRequestPageRouteProviderPlugin`, a class the assistant has to create with exactly that name. Until it exists, the Yves storefront answers with an error. That is expected.

Both are part of the specification the assistant gets.

Confirm that the tests fail now:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/
```

---

## Part 3: The Prompt

Open your AI tool in the project root and give it this prompt. Adjust nothing except, if you like, the wording.

```text
Build the ContactRequest module in the SprykerAcademy namespace of this Spryker project.

The specification is the test suite in tests/SprykerAcademyTest/Zed/ContactRequest/
(folders Exercise1 to Exercise6 plus codeception.yml). Read every test first and derive
the class names, namespaces, file paths, method names, routes and values from them.
Do not modify the tests.

Scope, in this order:
1. Zed Back Office page: IndexController with indexAction() at /contact-request/index/index,
   Twig template in Presentation/Index/index.twig. The navigation entry already exists.
2. Transfer definition src/SprykerAcademy/Shared/ContactRequest/Transfer/contact_request.transfer.xml
   with the ContactRequest transfer (idContactRequest, message) plus ContactRequestCriteria and
   ContactRequestResponse (isSuccessful, contactRequest). Every transfer carries strict="true".
   Run docker/sdk console transfer:generate.
3. Propel schema src/SprykerAcademy/Zed/ContactRequest/Persistence/Propel/Schema/pyz_contact_request.schema.xml
   (table pyz_contact_request, namespace Orm\Zed\ContactRequest\Persistence). Run docker/sdk console propel:install.
4. Persistence layer (PersistenceFactory, Repository + interface, EntityManager + interface, Mapper),
   Business layer (Facade + interface, BusinessFactory, Reader/ContactRequestReader, Writer/ContactRequestWriter)
   and Communication layer (CommunicationFactory, IndexController with indexAction() and an
   addAction() add form page at /contact-request/index/add, GatewayController).
5. Client layer src/SprykerAcademy/Client/ContactRequest (Client + interface, Factory, DependencyProvider,
   Stub/ContactRequestStub using the ZedRequestClient and the gateway path
   /contact-request/gateway/find-contact-request).
6. Yves module src/SprykerAcademy/Yves/ContactRequestPage with a ContactRequestController, a
   ContactRequestPageRouteProviderPlugin (already registered in
   src/SprykerAcademy/Yves/Router/RouterDependencyProvider.php) and the template
   Theme/default/views/contact-request/get.twig that shows one contact request by id at
   /contact-request/{idContactRequest} (route parameter `idContactRequest`).
7. Module config: ContactRequestConfig with getMyConfigValue() reading
   SprykerAcademy\Shared\ContactRequest\ContactRequestConstants::MY_CONFIG_VALUE (the constants interface
   exists and the value is set in config/Shared/config_default.php) and a ConfigController at /contact-request/config/index that
   renders the value.

Follow the Spryker rules and skills of the AI Dev SDK in this project: all dependencies through
DependencyProvider and factories, no `new` in business logic, entities never leave the
Persistence layer, transfers between layers, interfaces for every business model.

After each step run docker/sdk console cache:empty-all, docker/sdk console propel:model:build and
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/
and fix failures before continuing. Finish when every test passes and report what you built.
```

While the assistant works, watch **which rules and skills it picks up** (for example `propel-schema` for step 3) and whether it runs the console commands itself.

---

## Part 4: Verify

Automated:

```bash
docker/sdk cli vendor/bin/codecept run -c tests/SprykerAcademyTest/Zed/ContactRequest/
```

All tests of Exercises 1 to 6 must pass. Then check the application:

```bash
docker/sdk console cache:empty-all
docker/sdk console propel:model:build
docker/sdk console navigation:build-cache
```

- http://backoffice.eu.spryker.local/contact-request/index/index shows the greeting.
- http://backoffice.eu.spryker.local/contact-request/index/add creates a contact request.
- http://backoffice.eu.spryker.local/contact-request/config/index shows *Hello from config!*.
- http://yves.eu.spryker.local/en/contact-request/1 shows the first contact request.

Now review the code the way you would review a colleague's pull request. Compare it with what you wrote by hand in Exercises 4 to 6:

- Are all dependencies provided through the DependencyProvider and created in factories?
- Does any entity leave the Persistence layer?
- Are return types interfaces?
- Did it put `strict="true"` on the transfers, or did it fall back to untyped accessors?
- Did the assistant add anything you did not ask for (extra methods, comments, helper classes)? Would you keep it?

The best result of this exercise is a list of differences, not a perfect module.

---

## Cleanup

Before Exercise 7, restore the reference module so everyone starts from the same code:

```bash
./exercises/load.sh contact-request basics/extending-core-modules/skeleton
docker/sdk console c:e
docker/sdk cli composer dump-autoload
docker/sdk console propel:install
docker/sdk console transfer:generate
```

## Going Further

- Ask the `spryker-code-reviewer` agent to review the generated module and compare its findings with yours.
- Give the assistant a smaller prompt: only step 6, and see whether it finds the Client and the gateway path on its own.
- Start the MCP server (`docker/sdk console ai-dev:mcp-server -q`) and connect it to your tool, then ask the assistant which transfers exist for `ContactRequest`.
