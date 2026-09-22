# Exercise 6c: Build the Same Feature Again, with the AI Dev SDK

In Exercises 1 to 6b you built the **ContactRequest** module by hand, step by step, from a guide that told you every class name and every file path. In this exercise you describe the same feature the way a product owner would, in seven sentences, and let your AI coding assistant design and build it - under a different name, **CustomerRequest**, right next to yours.

Nothing is reset and nothing is deleted. When you are done, `src/SprykerAcademy` holds two modules that do the same job, one written by you and one written by a machine, both running in the same shop. The exercise ends with a diff.

That is the point. The Spryker AI Dev SDK gives the assistant Spryker's architecture rules, skills and agents. Your job is to state *what* you want and to judge *what comes back* - and this time you have the perfect yardstick, because you wrote the other implementation yourself.

You will learn how to:
- Set up the **AI Dev SDK** in a project with `ai-dev:setup`
- Read what the SDK generates: the context file, the rules, the skills and the agents
- Write a **requirement-level prompt** and let the assistant derive schema, layers and routes
- Steer it to the **API Platform** for the Storefront API, and check the result in Swagger or Postman
- Review AI-generated Spryker code by diffing it, file by file, against your own

**Official documentation:**
- [AI Dev SDK](https://docs.spryker.com/docs/dg/dev/ai/ai-dev/ai-dev)
- [Install AI Dev](https://docs.spryker.com/docs/dg/dev/ai/ai-dev/ai-dev-installation)

## Prerequisites

- Exercises 1 to 6b completed and **still in place**. Your ContactRequest module is the reference implementation for this exercise - do not remove it.
- An AI coding assistant installed on your machine: Claude Code, Cursor, GitHub Copilot, Windsurf, OpenCode or Codex. The SDK generates files for all of them.
- The `spryker-sdk/ai-dev` package. The B2B Marketplace demo shop ships it out of the box (see `composer.json`).

---

## Part 1: Prepare (two minutes)

### Why a second module and not a reset

The obvious way to run this exercise is to throw your work away - reset the branch, clean the working tree, and let the assistant start on an empty shop. Building a *second* module under a *different* name is better, and cheaper:

- **Nothing can break.** No `git clean`, no branch juggling, no risk of deleting `vendor/` or your Docker SDK and spending the afternoon reinstalling the shop.
- **Both features run at once.** `CustomerRequest` gets its own table, its own transfers, its own Back Office route and its own API resource, so it never collides with `ContactRequest`. You can open both pages in two tabs.
- **The comparison is a diff, not a memory exercise.** The two implementations sit side by side in one working tree. You do not have to remember what your version looked like on another branch - you can read them next to each other.
- **Exercise 7 just continues.** It builds on your handmade module, and your handmade module never went anywhere.

### 1. Commit what you have

Not to undo anything - to get a clean baseline, so that everything the assistant writes shows up in `git status` as new:

```bash
printf 'exercises/\n' >> .git/info/exclude   # the exercises clone is a repo of its own
git add -A
git commit -m "Exercises 1-6b: ContactRequest by hand"
```

> Without the first line, `git add -A` warns `adding embedded git repository: exercises` and records the folder as a broken submodule reference. `.git/info/exclude` is a personal `.gitignore` that is not part of the repository, which is exactly right for a folder only you have.

The shop was cloned on a release tag, so `git status` may open with *HEAD detached at 202608.0*. Committing there works, but a detached commit is easy to lose. Put a branch on it:

```bash
git describe --tags          # the release you cloned, for example 202608.0
git switch -c exercises-1-6b # only if git status says "HEAD detached"
```

This commit is the whole trick of the exercise. From here on, `git status --short` **is** the assistant's change list - including everything it touches outside its own module.

### 2. Check the namespace is still registered

It is, if you did Exercises 1 to 6b - but everything the assistant writes lands in `src/SprykerAcademy`, and none of it autoloads without these two entries:

```bash
grep -n 'SprykerAcademy' composer.json config/Shared/config_default.php
```

`composer.json` must map the namespace to the folder and `config_default.php` must list it in `PROJECT_NAMESPACES`:

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

If either is missing, add it and run `docker/sdk cli composer dump-autoload`.

---

## Part 2: Set Up the AI Dev SDK

> Do this **after** the commit in Part 1. The SDK writes a lot of files (`CLAUDE.md`, `.claude/`, ...), and you want to be able to tell them apart from the code the assistant writes later.

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
I need a Customer Request module for this shop.

Customers can send a message to the shop owner. A customer request stores the message and
belongs to a customer, so the customer is a foreign key on the customer request.

In the storefront, a logged-in customer writes and sends the message from their customer
account area.

In the Back Office, an administrator opens a page that lists the customer requests in a table
they can read, sort, filter and page through.

The same messages are reachable through the Storefront API, so a customer can send one and
read their own without opening the storefront pages.

Put the code in the SprykerAcademy namespace (src/SprykerAcademy) and build it the way this
project does things.
```

That is the whole specification. Notice what is **not** in it: no class names, no file paths, no layer list, no routes, no console commands, no tests. Deriving all of that from a requirement is the assistant's job, and the rules and skills the SDK installed are where it gets the conventions from. You spent Exercises 1 to 6b learning those conventions so you can tell whether it got them right.

The namespace is the one exception, and it is worth understanding why. `SprykerAcademy` is not a design decision the assistant could derive from the requirement - it is a fact about this project, and every file it creates depends on it. Guess `Pyz` and the module works but lands in the wrong place; guess a vendor namespace and nothing resolves at all. State it, and state it in the context file as well, so the next task does not need the reminder.

> You are asking, in seven sentences, for roughly what Exercises 1 to 6b build by hand, plus the kind of API resource [Exercise 12](../intermediate/05-glue-storefront-api.md) builds in the intermediate course: a Propel table with a foreign key to `spy_customer`, transfers, the three Zed layers, a Back Office page with a table, a Client with a Zed stub, and a customer account page in Yves.

### Why "Customer Request" and not "Contact Request"

The name is the only thing that separates the assistant's module from yours, and it has to separate it everywhere:

| | Yours | The assistant's |
|---|---|---|
| Table | `pyz_contact_request` | `pyz_customer_request` |
| Transfer | `ContactRequestTransfer` | `CustomerRequestTransfer` |
| Back Office route | `/contact-request/index/index` | `/customer-request/index/index` |
| API resource | `/contact-requests` | `/customer-requests` |
| Navigation key | `contact-request` | `customer-request` |

Ask for "Contact Request" with your module still installed and every one of those collides: Propel refuses a duplicate table, `transfer:generate` merges two definitions of the same transfer, and the router gets two controllers on one route. Ask for `CustomerRequest` and the two live happily in the same shop - which is exactly what you want, because it is how you compare them in Part 5.

### What the assistant can see, and what that changes

`ContactRequest` is sitting in `src/SprykerAcademy`, and any competent assistant will find it and use it as the pattern. That is not cheating. It is what a developer joining your team does on day one, and following the conventions already in the codebase is precisely what you want from a coding assistant.

It does change the question you are asking. You are no longer testing *"can it derive Spryker's architecture from nothing"* - you are testing *"does it read this project and follow it"*, which is the question that actually matters on a real team. And it gives the review in Part 5 a sharper edge: did it **design** a module, or did it rename-and-paste yours? The diff answers that in one command.

If you want the cold-start version, add one line to the prompt:

```text
Do not read or copy src/SprykerAcademy/Zed/ContactRequest - design the module from
this requirement alone.
```

Treat that as a request, not a guarantee. Nothing stops the tool from reading the folder, and the diff in Part 5 will tell you whether it listened. Running a group? Give half the room the extra line and half without it, then compare the two results - that contrast is worth more than either run on its own.

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
| Should it reuse / extend the existing ContactRequest module? | No. A separate module, its own table, its own transfers. |

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
3. **Storefront API.** Open http://glue.eu.spryker.local/docs. That page is API Platform's own documentation of the running API - Swagger UI and ReDoc over the live OpenAPI spec - and the customer request resource the assistant added has to be in it, with the operations you asked for. Send a request from the page and read the response.

If you prefer Postman, import the spec instead of clicking:

```bash
curl -H 'Accept: application/vnd.openapi+json' http://glue.eu.spryker.local/docs -o glue-openapi.json
```

From a shell, remember that this API speaks JSON:API - without the `Accept` header every request answers `406 Not Acceptable`, which looks like a broken endpoint and is not:

```bash
curl -s -H 'Accept: application/vnd.api+json' http://glue.eu.spryker.local/customer-requests
```

The endpoint belongs to a logged-in customer, so you need a token. This is the whole handshake, and it is the same one Postman needs in its Authorization tab:

```bash
TOKEN=$(curl -s -X POST http://glue.eu.spryker.local/access-tokens \
  -H 'Content-Type: application/vnd.api+json' -H 'Accept: application/vnd.api+json' \
  -d '{"data":{"type":"access-tokens","attributes":{"username":"sonia@acme.com","password":"change123"}}}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["attributes"]["accessToken"])')

curl -s -H "Authorization: Bearer $TOKEN" -H 'Accept: application/vnd.api+json' \
  http://glue.eu.spryker.local/customer-requests
```

**This is the route for anyone who does not want to touch Yves.** A token, a POST and a GET exercise the whole feature - schema, persistence, business layer and API - without opening the storefront once. It is also the honest test of the requirement you wrote: you asked for messages a customer can send *and read their own*, so the GET must return that customer's messages and nobody else's.

### Check that your module still works

This is the part a reset version of the exercise cannot test. The assistant worked in a project that already had a feature in it, and the shared files are where it can quietly break somebody else's work:

```bash
git status --short     # everything it wrote, since you committed in Part 1
git diff --stat        # which tracked files it edited
```

Anything **outside** `src/SprykerAcademy/**/CustomerRequest*` is a shared file. Expect to see some of these, and read every one of them:

| File | What to check |
|---|---|
| `config/Zed/navigation.xml` | A new entry added - or your entry replaced? |
| `config/Shared/config_default.php` | Constants appended, nothing removed? |
| `config/Zed/ApplicationServices.php` | New bindings added next to yours? |
| `config/GlueStorefront/packages/spryker_api_platform.php` | `src/SprykerAcademy` registered? |
| `src/SprykerAcademy/Yves/Router/RouterDependencyProvider.php` | Both route providers, or only its own? |
| `src/Pyz/Yves/CustomerPage/...navigation-sidebar.twig` | Both account links, or only its own? |

Then open **your** pages again: `/contact-request/index/index` in the Back Office and your customer account page in Yves. An assistant that made its own feature work by breaking yours has failed the exercise, and you would never have noticed on an empty branch.

### Check the service container

This is where a Spryker assistant goes wrong quietly:

```bash
docker/sdk cli vendor/bin/console lint:container
docker/sdk cli vendor/bin/console debug:container SprykerAcademy
```

The lint must answer *The container was linted successfully*, and the listing shows every class of both modules that Symfony knows about. If a class the assistant just wrote is missing from the listing, rebuild the container before believing it - `docker/sdk console cache:clear` ([Exercise 4, section 2.7](04-module-layers-back-office.md)). Autowiring resolves a constructor that asks for an interface only while exactly one class implements it, so if the assistant wrote two implementations of the same interface, the binding has to be explicit in `config/Zed/ApplicationServices.php` - see [Exercise 4, section 2.5](04-module-layers-back-office.md).

If a page errors, do not fix it yourself yet. Hand the error to the assistant (the `spryker-issue-diagnoser` agent is built for this) and watch how it diagnoses. That is also part of the exercise.

---

## Part 5: Review It Like a Pull Request

Commit the result first, so the assistant's work is one reviewable change:

```bash
git add -A
git commit -m "CustomerRequest built by the AI Dev SDK"
git show --stat HEAD
```

### Diff the two modules

The two implementations are in the same working tree, so you can compare them directly - once you take the module name out of the way. This script does that: it maps every file of your module onto the matching file of the assistant's (`ContactRequest` -> `CustomerRequest`, `contact_request` -> `customer_request`, `contact-request` -> `customer-request`), normalises the name inside the files as well, and reports what is missing, what is extra and what genuinely differs:

```bash
./exercises/tools/compare-modules.sh
```

```text
Comparing ContactRequest (yours) with CustomerRequest

differs: ./Zed/ContactRequest/Business/ContactRequestFacade.php
differs: ./Zed/ContactRequest/Persistence/Propel/Schema/pyz_contact_request.schema.xml
only in ContactRequest: ./Zed/ContactRequest/Communication/Table/ContactRequestTable.php
...
only in CustomerRequest: ./Zed/CustomerRequest/Communication/Twig/CustomerRequestTwigExtension.php

identical after renaming: 9 of 31 files
differs: 17   only in ContactRequest: 3   only in CustomerRequest: 2
```

It takes the two module names as arguments and defaults to `ContactRequest CustomerRequest`, so a third implementation compares with `./exercises/tools/compare-modules.sh CustomerRequest MessageRequest`.

Read the summary before you read a single line of code:

- **`only in ContactRequest`** - what the assistant decided it did not need. Sometimes it is right (you wrote something the requirement never asked for). Sometimes it is the Back Office table class, and there is no table.
- **`only in CustomerRequest`** - what it added on its own. Ask whether you would keep it in a pull request.
- **`differs`** - the interesting files. `git diff --no-index` two of them and read the design decisions side by side.
- **`identical after renaming`** - files it copied from you. A handful is unremarkable: a `DependencyProvider` has one shape, and so does a `Factory`. If most of the module comes back identical the script says so, because then you did not ask an assistant to design - you asked it to run a find-and-replace, which is worth knowing and worth saying to it.

To read one pair in full:

```bash
git diff --no-index \
  src/SprykerAcademy/Zed/ContactRequest/Business/ContactRequestFacade.php \
  src/SprykerAcademy/Zed/CustomerRequest/Business/CustomerRequestFacade.php
```

### Then go through the code with the rules of Exercises 1 to 6b in hand

- **Persistence.** Is `fk_customer` a real Propel foreign key to `spy_customer`, or just an integer column? Is there an index? Does any Propel entity leave the Persistence layer, or does everything cross the boundary as a transfer?
- **Business.** Is there a Facade with an interface? Are Reader and Writer separate classes with interfaces? Any `new` inside business logic instead of a factory?
- **Communication.** Did it use Spryker's Back Office table (`AbstractTable` from the `Gui` module, with `configure()` and `prepareData()`), or did it hand-roll a Twig loop and call it a table? Sorting, filtering and paging come for free with the first and not at all with the second.
- **Yves.** Does the storefront go through the Client and the Zed gateway, or does it query the database directly from Yves? Does the page only ever show the messages of the logged-in customer - or can you change an ID in the URL and read someone else's?
- **Transfers.** `strict="true"`, or untyped accessors?
- **The API.** A `*.resource.yml` plus a Provider class, or the legacy GlueApplication plugin stack? Both run, and only one is what Spryker recommends for new APIs. Did it register `src/SprykerAcademy` in `config/GlueStorefront/packages/spryker_api_platform.php`, or did it quietly put the resource in `Pyz` where the default source directories already look?
- **Who can read what.** Change the id in the API request to a customer request belonging to another customer. If you get it back, the Provider is not scoping by the authenticated customer - the single most common mistake in a generated API, and the one a passing test suite will not catch.
- **Service wiring.** Did it register the interfaces it injects in `config/Zed/ApplicationServices.php`, or is the module standing on the single-implementation rule without knowing it? Ask the assistant which of its constructor arguments would stop resolving if you added a second implementation tomorrow.
- **Everything else.** Dependencies through the `DependencyProvider` and created in factories? Return types as interfaces? Did it add things you never asked for - extra fields, helper classes, commented-out code? Would you keep them?

Then ask the SDK's own reviewer and compare its list with yours:

```text
Use the spryker-code-reviewer agent to review the CustomerRequest module you just built.
```

**The best result of this exercise is a list of differences, not a perfect module.** Write the list down - it is the thing you take home about working with an assistant on a Spryker project.

---

## Cleanup

Exercise 7 continues from your handmade module, and its loader starts by deleting the whole namespace folder - this line is in `load.sh`:

```text
rm -rf "$PROJECT_DIR/src/SprykerAcademy"
```

So **both** modules go when you run it. You committed in Part 5, so nothing is lost - but be deliberate about it:

```bash
./exercises/load.sh contact-request basics/extending-core-modules/skeleton
docker/sdk console c:e
docker/sdk cli composer dump-autoload
docker/sdk console propel:install
docker/sdk console transfer:generate
```

Two things the loader does **not** clean up after the assistant, because it only ever adds to those files:

- **The navigation entry.** If `config/Zed/navigation.xml` still has a `customer-request` entry, the Back Office menu keeps a link to a controller that no longer exists. Remove the entry and run `docker/sdk console navigation:build-cache`.
- **Anything it wrote in `src/Pyz` or `config/`.** `git diff` after the load shows what survived. The table `pyz_customer_request` stays in the database too; it is harmless, so leave it unless you want a tidy schema.

To bring the assistant's module back later:

```bash
git log --oneline -- src/SprykerAcademy      # find the "CustomerRequest built by..." commit
git checkout <commit> -- src/SprykerAcademy/Zed/CustomerRequest
```

## Going Further

- Give the exact same seven sentences to a second assistant or a second model, asking this time for a **MessageRequest** module. Three implementations of one requirement in one shop, and `compare-modules.sh` diffs any pair of them. The differences between two AI runs are as instructive as the differences from your own code.
- Run the **cold-start variant**: the same prompt plus the "do not read ContactRequest" line, on a fourth name. Then diff the cold-start module against the one that could see yours, and you have measured what having a reference implementation in the project is actually worth.
- Add one sentence to the requirement - "the admin can reply to a message and the customer sees the reply" - and watch whether it extends the existing design or bolts on a parallel one.
- Start the MCP server (`docker/sdk console ai-dev:mcp-server -q`), connect it to your tool, and ask the assistant which transfers exist for `CustomerRequest`.
