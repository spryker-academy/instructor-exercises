# Exercise 6c: Build the Contact Request Module with the AI Dev SDK

In Exercises 1 to 6b you built the **ContactRequest** module by hand, step by step, from a guide that told you every class name and every file path. In this exercise you throw all of that away - the code, the wiring and the tests - and start from the pristine demo shop on a fresh branch. Then you describe the feature the way a product owner would, in seven sentences, and let your AI coding assistant design and build it.

That is the point of the exercise. The Spryker AI Dev SDK gives the assistant Spryker's architecture rules, skills and agents. Your job is to state *what* you want and to judge *what comes back* - because this time there is no test suite to hide behind.

You will learn how to:
- Get to a genuinely clean branch before you let an assistant loose on a project
- Set up the **AI Dev SDK** in a project with `ai-dev:setup`
- Read what the SDK generates: the context file, the rules, the skills and the agents
- Write a **requirement-level prompt** and let the assistant derive schema, layers and routes
- Steer it to the **API Platform** for the Storefront API, and check the result in Swagger or Postman
- Review AI-generated Spryker code against the rules you learned in Exercises 1 to 6b

**Official documentation:**
- [AI Dev SDK](https://docs.spryker.com/docs/dg/dev/ai/ai-dev/ai-dev)
- [Install AI Dev](https://docs.spryker.com/docs/dg/dev/ai/ai-dev/ai-dev-installation)

## Prerequisites

- Exercises 1 to 6b completed, so you know what "correct" looks like.
- An AI coding assistant installed on your machine: Claude Code, Cursor, GitHub Copilot, Windsurf, OpenCode or Codex. The SDK generates files for all of them.
- The `spryker-sdk/ai-dev` package. The B2B Marketplace demo shop ships it out of the box (see `composer.json`).

---

## Part 1: Get to a Clean Branch

Everything you built in Exercises 1 to 6b has to go: the module in `src/SprykerAcademy`, the tests in `tests/SprykerAcademyTest`, the configuration schema in `data/configuration/`, and the wiring the loader added (the navigation entry, the config value, the Yves router plugin). If any of it stays, you are not testing the assistant, you are testing your own scaffolding.

Work in the **project root** (the `b2b-demo-marketplace` clone), not in the `exercises` folder.

**1. Mark where the shop started.** The clone sits on a release tag rather than on a branch, so `git status` opens with *HEAD detached at 202608.0*. Put a name on that commit before you touch anything:

```bash
git describe --tags     # the release you cloned, for example 202608.0
git branch pristine-shop
```

> `git branch` here only writes a label at the current commit, it does not switch anything. From now on `pristine-shop` means "the demo shop exactly as I cloned it", whichever release that is.

**2. Keep your handmade work.** Move onto a branch of your own and commit, so you can come back to it and compare later:

```bash
printf 'exercises/\n' >> .git/info/exclude   # the exercises clone is a repo of its own
git checkout -b exercises-1-6
git add -A
git commit -m "Exercises 1-6: ContactRequest by hand"
```

> Without the first line, `git add -A` warns `adding embedded git repository: exercises` and records the folder as a broken submodule reference. `.git/info/exclude` is a personal `.gitignore` that is not part of the repository, which is exactly right for a folder only you have.

**3. Branch off the pristine shop:**

```bash
git checkout -B ai-dev-exercise pristine-shop
```

Switching branches removes every file you just committed, so `src/SprykerAcademy` and `tests/SprykerAcademyTest` are gone, and `composer.json`, `config/Shared/config_default.php` and the navigation are back to their original content.

> **Not `origin/master`.** The master branch has moved on since your release tag. Your `vendor/` was installed from the `composer.lock` of the tag, so branching off master would give you a lock file that does not match what is actually installed, and the first `composer` command would start rewriting your environment. Branch off the tag you cloned - that is what `pristine-shop` points at.

**4. Sweep up what was never committed.** Look first, delete second:

```bash
git clean -nd        # dry run: prints what would be removed
git clean -df        # remove it
```

> Your environment survives this, for three different reasons. `vendor/`, `src/Generated/` and `docker/` are listed in the shop's `.gitignore`, and `git clean` leaves ignored files alone. `exercises/` is a Git repository of its own, and `git clean` refuses to delete those. `.env` is a tracked file of the demo shop, so it was never a candidate - the branch switch restored it. Do **not** add `-x` or `-ff`: that would wipe your installed dependencies, the Docker SDK and the exercises clone, and you would be reinstalling the shop instead of doing the exercise.

**5. Register the `SprykerAcademy` namespace again.** The reset reverted it, and the assistant needs a project namespace to write into. This is Step 4 of the Student Setup Guide:

```json
"autoload": {
    "psr-4": {
        "Pyz\\": "src/Pyz/",
        "SprykerAcademy\\": "src/SprykerAcademy/"
    }
}
```

```php
$config[KernelConstants::PROJECT_NAMESPACES] = [
    'Pyz',
    'SprykerAcademy',
];
```

```bash
docker/sdk cli composer dump-autoload
docker/sdk console cache:empty-all
docker/sdk console propel:install
docker/sdk console transfer:generate
```

> Keep that order. `cache:empty-all` deletes the generated Propel configuration, so every console command fails with *Database map was not initialized* until `propel:install` rebuilds it. Clear the cache first, never last.

**6. Check that the page really is blank:**

```bash
ls src/SprykerAcademy 2>/dev/null        # must not exist
grep -rn ContactRequest config/ src/Pyz/ # must find nothing
```

The Back Office has no *Contact Request* entry in the navigation any more, and `http://backoffice.eu.spryker.local/contact-request/index/index` is a 404. That is the starting point.

> **One leftover you cannot see.** The `pyz_contact_request` table from Exercise 3 is still in the database - a branch switch does not touch data. Leave it there. If the assistant designs a different table and `propel:install` complains, that is a real migration conflict and a good thing to hand to the `spryker-issue-diagnoser` agent.

---

## Part 2: Set Up the AI Dev SDK

> Do this **after** Part 1. The SDK writes untracked files (`CLAUDE.md`, `.claude/`, ...), and `git clean -df` would have deleted them.

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
| Windsurf | `.windsurfrules` | `.windsurf/rules/` | `.windsurf/skills/` | - |
| OpenCode / Codex | `AGENTS.md` | `.opencode/rules/` | `.agents/skills/` | - |

> **GitHub Copilot on Docker sync.** The shop's `.dockersyncignore` starts with `.git*`, and that pattern catches `.github` along with `.gitignore` and `.gitattributes`. The files the SDK generates for Copilot then never cross between the host and the container. Add an exception right after that entry:
>
> ```text
> .git*
> !/.github
> ```
>
> Only Copilot is affected - `.claude`, `.cursor` and `.windsurf` do not match `.git*`. See [Generated files per AI tool](https://docs.spryker.com/docs/dg/dev/ai/ai-dev/ai-dev-installation#generated-files-per-ai-tool).

The other commands of the module generate single artifacts (`ai-dev:generate-agents-file`, `ai-dev:generate-skills`) and start the MCP server (`ai-dev:mcp-server`) that lets the assistant query transfers, interfaces and OMS information of the running application. You do not need them for this exercise.

### What to look at (5 minutes, no coding)

- **The context file** (`CLAUDE.md` or `AGENTS.md`). It is the architecture brief for the assistant: the console commands, the architectural rules (single responsibility, dependencies through the constructor, no `new` in business logic, transfers are never modified in place), and the project organization.
- **The rules folder**: one Markdown file per convention. Open `dependency-provider.md`, `factory-pattern.md`, `layer-communication.md`, `transfer-object.md`, `persistence.md`, `controller.md` and `naming-conventions.md`. These are the same rules you applied by hand in Exercises 4 to 6.
- **The skills folder**: task recipes the assistant follows, for example `propel-schema`, `data-import`, `spryker-customization`, `codecept-functional`, `code-review`, `static-validation`, `spryker-docs-research`, `spryker-runtime`.
- **The agents folder**: specialised roles such as `spryker-feature-expert`, `spryker-code-reviewer`, `spryker-verifier`, `spryker-issue-diagnoser` and `spryker-data-seeder`.

### Add the project facts the SDK cannot know

Check whether the context file names the project namespace. If it only talks about `Pyz`, add a line to it:

```text
Project code goes into the `SprykerAcademy` namespace (`src/SprykerAcademy`), which is
registered in composer.json and before `Pyz` in `PROJECT_NAMESPACES`.
```

Add the API convention as well. Spryker has two ways to build a Storefront API, the older GlueApplication plugins and the **API Platform**, and both work - so an assistant trained on older material will happily pick the one you do not want:

```text
New APIs use the Spryker API Platform: a `*.resource.yml` under
resources/api/storefront/ plus a Provider class implementing
ApiPlatform\State\ProviderInterface. Do not use the legacy GlueApplication
resource plugins. For resources in this namespace to be found, `src/SprykerAcademy`
must be listed in config/GlueStorefront/packages/spryker_api_platform.php, and
resources are generated with
`GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate`.
```

> Project facts belong in the **context file**, because it describes the project and stays, while the prompt describes one feature and changes every time. The prompt in Part 3 names the namespace anyway - belt and braces for the one fact everything else hangs off - but it is the context file that makes the assistant remember it on the task after this one.

---

## Part 3: The Prompt

Open your AI tool in the project root and give it this - and nothing else:

```text
I need a Contact Request module for this shop.

Customers can send a message to the shop owner. A contact request stores the message and
belongs to a customer, so the customer is a foreign key on the contact request.

In the storefront, a logged-in customer writes and sends the message from their customer
account area.

In the Back Office, an administrator opens a page that lists the contact requests in a table
they can read, sort, filter and page through.

The same messages are reachable through the Storefront API, so a customer can send one and
read their own without opening the storefront pages.

Put the code in the SprykerAcademy namespace (src/SprykerAcademy) and build it the way this
project does things.
```

That is the whole specification. Notice what is **not** in it: no class names, no file paths, no layer list, no routes, no console commands, no tests. Deriving all of that from a requirement is the assistant's job, and the rules and skills the SDK installed are where it gets the conventions from. You spent Exercises 1 to 6b learning those conventions so you can tell whether it got them right.

The namespace is the one exception, and it is worth understanding why. `SprykerAcademy` is not a design decision the assistant could derive from the requirement - it is a fact about this project, and every file it creates depends on it. Guess `Pyz` and the module works but lands in the wrong place; guess a vendor namespace and nothing resolves at all. State it, and state it in the context file as well, so the next task does not need the reminder.

> You are asking, in seven sentences, for roughly what Exercises 1 to 7 build by hand, plus the kind of API resource [Exercise 12](../intermediate/05-glue-storefront-api.md) builds in the intermediate course: a Propel table with a foreign key to `spy_customer`, transfers, the three Zed layers, a Back Office page with a table, a Client with a Zed stub, and a customer account page in Yves.

### Answer its questions

A good assistant will come back with questions before it writes code. Answer them; do not let it guess. Decisions that are yours to make for this exercise:

| Question you are likely to get | Answer for this exercise |
|---|---|
| Guests too, or only logged-in customers? | Only logged-in customers. |
| Should the customer see the messages they already sent? | Yes, list them on the same account page. |
| Can the customer edit or delete a message? | No. Sending is enough. |
| Does the admin reply, or is there a status / read flag? | No. Reading is enough. |
| Email notification to the shop owner? | No. |
| Extra fields (subject, category, created date)? | A creation timestamp is fine, nothing else. |
| Is the API public, or only for the logged-in customer? | Only the logged-in customer, authenticated like the rest of the Storefront API. |
| Which operations on the API? | Send a message, and list the ones that customer sent. Nothing else. |
| Should it write tests? | Yes, if it offers - but you review the code yourself either way. |

### While it works

Watch **which rules and skills it picks up** (`propel-schema` for the schema, `yves-atomic-frontend` for the storefront template, `static-validation` before it declares victory) and whether it runs the console commands itself: `transfer:generate`, `propel:install`, `cache:empty-all`, `navigation:build-cache`. An assistant that writes a schema file and never runs `propel:install` has not finished, whatever it says.

---

## Part 4: Verify It Actually Works

There is no test suite this time. You verify the way you would verify a colleague's branch: by running it.

```bash
docker/sdk console cache:empty-all
docker/sdk console propel:install
docker/sdk console transfer:generate
docker/sdk console navigation:build-cache
docker/sdk cli GLUE_APPLICATION=GLUE_STOREFRONT glue api:generate
```

> The last command is the one people forget. A `*.resource.yml` does nothing until `glue api:generate` has turned it into a generated resource class, and it needs `GLUE_APPLICATION` in the environment - every `glue` command does.

Then walk the three flows:

1. **Storefront.** Log in at http://yves.eu.spryker.local/en/login as `sonia@acme.com` / `change123`, open the customer account area, send a message.
2. **Back Office.** Log in at http://backoffice.eu.spryker.local as `admin@spryker.com` / `change123`, find the new navigation entry, and check that the message you just sent is in the table - with the right customer next to it. Sort a column, type something in the filter, page through.
3. **Storefront API.** Open http://glue.eu.spryker.local/docs. That page is API Platform's own documentation of the running API - Swagger UI and ReDoc over the live OpenAPI spec - and the contact request resource the assistant added has to be in it, with the operations you asked for. Send a request from the page and read the response.

If you prefer Postman, import the spec instead of clicking:

```bash
curl -H 'Accept: application/vnd.openapi+json' http://glue.eu.spryker.local/docs -o glue-openapi.json
```

From a shell, remember that this API speaks JSON:API - without the `Accept` header every request answers `406 Not Acceptable`, which looks like a broken endpoint and is not:

```bash
curl -s -H 'Accept: application/vnd.api+json' http://glue.eu.spryker.local/contact-requests
```

The endpoint belongs to a logged-in customer, so you need a token. This is the whole handshake, and it is the same one Postman needs in its Authorization tab:

```bash
TOKEN=$(curl -s -X POST http://glue.eu.spryker.local/access-tokens \
  -H 'Content-Type: application/vnd.api+json' -H 'Accept: application/vnd.api+json' \
  -d '{"data":{"type":"access-tokens","attributes":{"username":"sonia@acme.com","password":"change123"}}}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["attributes"]["accessToken"])')

curl -s -H "Authorization: Bearer $TOKEN" -H 'Accept: application/vnd.api+json' \
  http://glue.eu.spryker.local/contact-requests
```

**This is the route for anyone who does not want to touch Yves.** A token, a POST and a GET exercise the whole feature - schema, persistence, business layer and API - without opening the storefront once. It is also the honest test of the requirement you wrote: you asked for messages a customer can send *and read their own*, so the GET must return that customer's messages and nobody else's.

Then check the service container, which is where a Spryker assistant goes wrong quietly:

```bash
docker/sdk cli vendor/bin/console lint:container
docker/sdk cli vendor/bin/console debug:container SprykerAcademy
```

The lint must answer *The container was linted successfully*, and the listing shows every class of the new module that Symfony knows about. Autowiring resolves a constructor that asks for an interface only while exactly one class implements it, so if the assistant wrote two implementations of the same interface, the binding has to be explicit in `config/Zed/ApplicationServices.php` - see [Exercise 4, section 2.5](04-module-layers-back-office.md).

If a page errors, do not fix it yourself yet. Hand the error to the assistant (the `spryker-issue-diagnoser` agent is built for this) and watch how it diagnoses. That is also part of the exercise.

---

## Part 5: Review It Like a Pull Request

Commit the result first, so you can diff it against your own work:

```bash
git add -A
git commit -m "ContactRequest built by the AI Dev SDK"
git diff exercises-1-6 --stat -- src/SprykerAcademy
```

Now go through the code with the rules of Exercises 1 to 6b in hand:

- **Persistence.** Is `fk_customer` a real Propel foreign key to `spy_customer`, or just an integer column? Is there an index? Does any Propel entity leave the Persistence layer, or does everything cross the boundary as a transfer?
- **Business.** Is there a Facade with an interface? Are Reader and Writer separate classes with interfaces? Any `new` inside business logic instead of a factory?
- **Communication.** Did it use Spryker's Back Office table (`AbstractTable` from the `Gui` module, with `configure()` and `prepareData()`), or did it hand-roll a Twig loop and call it a table? Sorting, filtering and paging come for free with the first and not at all with the second.
- **Yves.** Does the storefront go through the Client and the Zed gateway, or does it query the database directly from Yves? Does the page only ever show the messages of the logged-in customer - or can you change an ID in the URL and read someone else's?
- **Transfers.** `strict="true"`, or untyped accessors?
- **The API.** A `*.resource.yml` plus a Provider class, or the legacy GlueApplication plugin stack? Both run, and only one is what Spryker recommends for new APIs. Did it register `src/SprykerAcademy` in `config/GlueStorefront/packages/spryker_api_platform.php`, or did it quietly put the resource in `Pyz` where the default source directories already look?
- **Who can read what.** Change the id in the API request to a contact request belonging to another customer. If you get it back, the Provider is not scoping by the authenticated customer - the single most common mistake in a generated API, and the one a passing test suite will not catch.
- **Service wiring.** Did it register the interfaces it injects in `config/Zed/ApplicationServices.php`, or is the module standing on the single-implementation rule without knowing it? Ask the assistant which of its constructor arguments would stop resolving if you added a second implementation tomorrow.
- **Everything else.** Dependencies through the `DependencyProvider` and created in factories? Return types as interfaces? Did it add things you never asked for - extra fields, helper classes, commented-out code? Would you keep them?

Then ask the SDK's own reviewer and compare:

```text
Use the spryker-code-reviewer agent to review the ContactRequest module you just built.
```

**The best result of this exercise is a list of differences, not a perfect module.** Write the list down - it is the thing you take home about working with an assistant on a Spryker project.

---

## Cleanup

Exercise 7 continues from the handmade module, so switch back and load its skeleton:

```bash
git checkout exercises-1-6
./exercises/load.sh contact-request basics/extending-core-modules/skeleton
docker/sdk console c:e
docker/sdk cli composer dump-autoload
docker/sdk console propel:install
docker/sdk console transfer:generate
```

The `ai-dev-exercise` branch stays in your repository. Keep it - it is worth rereading after Exercise 7, when you know what the core-module extension actually costs.

## Going Further

- Give the exact same seven sentences to a second assistant or a second model, on a second branch off `pristine-shop`, and diff the two modules. The differences between two AI runs are as instructive as the differences from your own code.
- Add one sentence to the requirement - "the admin can reply to a message and the customer sees the reply" - and watch whether it extends the existing design or bolts on a parallel one.
- Start the MCP server (`docker/sdk console ai-dev:mcp-server -q`), connect it to your tool, and ask the assistant which transfers exist for `ContactRequest`.
