# Exercise 6c: Build the Module Again, with the AI Dev SDK

In Exercises 1 to 6b you built the **ContactRequest** module by hand, step by step, from a guide that told you every class name and every file path. In this exercise you throw all of it away, describe the same feature the way a product owner would - six sentences, plus a short list of how this project builds things - and let your AI coding assistant design and build it on an empty shop.

That is the point. The Spryker AI Dev SDK gives the assistant Spryker's architecture rules, skills and agents. Your job is to state *what* you want and to judge *what comes back* - because this time there is no skeleton, no wiring and no test suite to hide behind. You have the perfect yardstick anyway: you wrote the other implementation yourself, and it is one `load.sh` away.

You will learn how to:
- Reset a project so an assistant gets a genuine cold start
- Set up the **AI Dev SDK** in a project with `ai-dev:setup`
- Read what the SDK generates: the context file, the rules, the skills and the agents
- Tell the assistant to actually **use** those skills and agents rather than improvising
- Write a **requirement-level prompt** and let the assistant derive schema, layers and routes
- Steer it to the **API Platform** for the Storefront API, and check the result in Swagger or Postman
- Review AI-generated Spryker code against your own implementation, file by file

**Official documentation:**
- [AI Dev SDK](https://docs.spryker.com/docs/dg/dev/ai/ai-dev/ai-dev)
- [Install AI Dev](https://docs.spryker.com/docs/dg/dev/ai/ai-dev/ai-dev-installation)

## Prerequisites

- Exercises 1 to 6b completed, so you know what "correct" looks like. The code itself is about to go - that is fine, `load.sh` brings it back.
- An AI coding assistant installed on your machine: Claude Code, Cursor, GitHub Copilot, Windsurf, OpenCode or Codex. The SDK generates files for all of them.
- The `spryker-sdk/ai-dev` package. The B2B Marketplace demo shop ships it out of the box (see `composer.json`).

---

## Part 1: Start from a Clean Shop

The exercise only works as a cold start. If `src/SprykerAcademy` still holds your ContactRequest module, the assistant will find it, follow it, and you will have tested your own scaffolding rather than the assistant.

**Nothing you delete here is precious.** Every exercise in this course is one command away:

```bash
./exercises/load.sh contact-request basics/module-layers/complete
```

That is what makes a reset cheap, and it is why this exercise does not ask you to juggle branches, stash anything or keep a copy of your work.

### Option A: a second shop

Clone the demo shop into a folder of its own and boot it there. You get a genuinely untouched project and the shop you have been working in stays as it is. It costs a full install, so do it if you have the time or an instructor-provided image.

### Option B: reset the shop you have

Look before you delete. Work in the **project root** (the `b2b-demo-marketplace` clone), not in the `exercises` folder:

```bash
git describe --tags     # the release you cloned, for example 202608.0
git status --short      # everything the exercises added or changed
```

Then reset:

```bash
git reset --hard                                      # tracked files back to the release
rm -rf src/SprykerAcademy tests/SprykerAcademyTest    # the exercise code itself
git clean -nd                                         # dry run: read this list first
git clean -df                                         # remove what is left
```

> **Your environment survives this**, for three different reasons. `vendor/`, `src/Generated/` and `docker/` are listed in the shop's `.gitignore`, and `git clean` leaves ignored files alone. `exercises/` is a Git repository of its own, and `git clean` refuses to delete those. `.env` is a tracked file of the demo shop, so `git reset --hard` restored it rather than removing it. Do **not** add `-x` or `-ff`: that would wipe your installed dependencies, the Docker SDK and the exercises clone, and you would be reinstalling the shop instead of doing the exercise.

> `git reset --hard` discards uncommitted changes to tracked files; it does not delete commits. If you committed your exercise work, those commits are still in the branch and `git log` still finds them - the working tree is what matters here.

### Register the `SprykerAcademy` namespace again

The reset reverted it, and the assistant needs a project namespace to write into. This is Step 4 of the Student Setup Guide:

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

### Check that the page really is blank

```bash
ls src/SprykerAcademy 2>/dev/null        # must not exist
grep -rn ContactRequest config/ src/Pyz/ # must find nothing
```

The Back Office has no *Contact Request* entry in the navigation any more, and `http://backoffice.eu.spryker.local/contact-request/index/index` is a 404. That is the starting point.

> **One leftover you cannot see.** The `pyz_contact_request` table from Exercise 3 is still in the database - resetting files does not touch data. Leave it there. If the assistant designs a different table and `propel:install` complains, that is a real migration conflict and a good thing to hand to the `spryker-issue-diagnoser` agent.

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
- **The skills folder**: task recipes the assistant follows, for example `propel-schema`, `spryker-customization`, `spryker-refresher`, `static-validation`, `codecept-functional`, `spryker-runtime`, `spryker-qa-coverage`, `spryker-docs-research`, `yves-atomic-frontend`, `data-import`, `code-review`.
- **The agents folder**: specialised roles, six of them - `spryker-feature-expert`, `spryker-code-reviewer`, `spryker-verifier`, `spryker-issue-diagnoser`, `spryker-data-seeder` and `spryker-screenshot-collector`.

### Make the assistant actually use them

Generating skills and agents does not mean they get used. Assistants improvise: they write a Propel schema from memory instead of following `propel-schema`, they declare a feature finished without running `static-validation`, and they never spawn a subagent unless told they may. Append this to the context file (`CLAUDE.md`, `AGENTS.md` or `.github/copilot-instructions.md`), right after the project facts below:

```markdown
# AI Workflow - Agents and Skills

This project ships Spryker-specific **skills** in `.claude/skills/` and **subagents** in
`.claude/agents/`. They encode how this project works. Use them instead of hand-rolling
what they cover.

## Before you start any task
List the available skills and name which ones apply to this task before writing any code.
If none apply, say so explicitly. Never skip this step silently.

## Mandatory skills, by trigger
| When you are about to... | Invoke |
|---|---|
| Implement a feature from a PRD or acceptance criteria | `spryker-customization` |
| Create or change a Propel `*.schema.xml` | `propel-schema` |
| Apply code, schema, frontend or config changes | `spryker-refresher` (afterwards) |
| Report work as complete | `static-validation` (diff-scoped, before reporting) |
| Write or run Codeception tests | `codecept-functional` |
| Drive the running app (Back Office, storefront, Glue, console) | `spryker-runtime` |
| Verify a feature end-to-end against the running app | `spryker-qa-coverage` |
| Describe how a Spryker feature behaves | `spryker-docs-research` |
| Build or change a Yves Twig component | `yves-atomic-frontend` |
| Create or change data import files | `data-import` |

## Subagents - explicitly authorised
You ARE authorised to use the Agent tool for the `spryker-*` subagents in `.claude/agents/`
without asking first. This context file is the authorisation. Prefer:

- `spryker-feature-expert` - "how does X work in Spryker", design questions, before custom design
- `spryker-verifier` - independent PASS/FAIL verification of acceptance criteria
- `spryker-issue-diagnoser` - root-causing a failure
- `spryker-data-seeder` - creating test data through the data-import path
- `spryker-code-reviewer` - review against Spryker standards before commit
- `spryker-screenshot-collector` - demo captures

Run independent agents in parallel in a single message.

## Definition of done
A task is not done until `static-validation` is clean on the diff and `spryker-verifier`
(or `spryker-qa-coverage`) has confirmed the acceptance criteria against the running app.
```

Three things worth understanding about that block, because you will write one for your own projects:

- **"List the skills that apply before writing code"** turns an invisible decision into a visible one. You can see in the transcript whether it picked `propel-schema` or decided to wing it, and you can stop it before it has written thirty files.
- **The explicit authorisation matters.** An assistant that is unsure whether it may spawn subagents will simply not spawn them. Saying "this file is the authorisation" removes the doubt - and naming which agent for which job stops it from asking a code reviewer to diagnose a 500.
- **`spryker-docs-research` is a skill, not an agent.** It lives in `.claude/skills/`, so it belongs in the table above and not in the subagent list. The same goes for `spryker-qa-coverage`. Check your own `.claude/agents/` folder before naming something as an agent - there are exactly six.

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

And the wiring conventions, which are the ones an assistant gets wrong most often because the older Spryker style is what it has read most of:

```text
Zed wires dependencies with Symfony constructor injection. config/Zed/ApplicationServices.php
loads every project module into the container, so a project class type-hints what it needs
instead of being assembled in a factory. In a Zed facade, reach the business classes with
$this->getService(MyReader::class) - AbstractFacade uses
Spryker\Service\Container\ContainerTrait. Do not write a business factory or a dependency
provider for something the container already provides.

Two exceptions. config/Yves/ApplicationServices.php is an empty stub, so Yves keeps the
factory and the dependency provider. And a project-namespace Client used from Glue must be
registered by hand in config/GlueStorefront/ApplicationServices.php with
$services->set(Interface::class, Class::class), because SprykerDefaultsPass only
auto-registers core namespaces.
```

> Project facts belong in the **context file**, because it describes the project and stays, while the prompt describes one feature and changes every time. The prompt in Part 3 repeats them anyway - belt and braces for the facts everything else hangs off - but it is the context file that makes the assistant remember them on the task after this one.

---

## Part 3: The Prompt

Open your AI tool in the project root and give it this - and nothing else:

```text
I need a Contact Request module for this shop.

Customers can send a message to the shop owner. A contact request stores the message and
belongs to a customer, so the customer is a foreign key on the contact request.

In the Back Office, an administrator opens a page that lists the contact requests in a table
they can read, sort, filter and page through.

The same messages are reachable through the Storefront API, so a customer can send one and
read their own without opening the storefront pages.

A logged-in customer can also write and send the message from the customer account area in
the storefront - but ask me whether I want that part before you build it.

How we build things in this project:

- Put the code in the SprykerAcademy namespace (src/SprykerAcademy).
- Build the API with the Spryker API Platform: a *.resource.yml plus a state provider and a
  processor. Do not use the legacy GlueApplication resource plugins.
- In Zed, wire dependencies with Symfony constructor injection. Project classes are already
  in the container, so a class type-hints what it needs. Do not add a business factory or a
  dependency provider for something the container can give you.
- In the facade, reach your business classes with $this->getService(ContactRequestReader::class).
  AbstractFacade has the container trait, so no getFactory() and no business factory at all.
- Yves is the exception: its container is empty, so a Yves page keeps the usual factory and
  dependency provider.
- A project Client that an API Platform provider injects has to be registered by hand in
  config/GlueStorefront/ApplicationServices.php with $services->set(Interface::class, Class::class).

Ask me whatever you need before you start.
```

The first half is the specification, and notice what is **not** in it: no class names, no file paths, no layer list, no routes, no console commands, no tests. Deriving all of that from a requirement is the assistant's job, and the rules and skills the SDK installed are where it gets the conventions from. You spent Exercises 1 to 6b learning those conventions so you can tell whether it got them right.

The second half is different in kind. Those are not design decisions the assistant could derive from the requirement - they are **facts about this project**, and it has no way to know any of them:

| House rule | Why it has to be said |
|---|---|
| Ask before building Yves | The storefront is the largest part of the job and the part many students skip - they test in Swagger or Postman instead. An assistant that asks first can save you half the run, but only if you tell it that the question is open. |
| API Platform, not GlueApplication plugins | Both exist in this Spryker version and both work. Most training material out there is about the older one, so that is what an assistant reaches for. |
| Symfony DI in Zed | `config/Zed/ApplicationServices.php` loads every project module into the container, so a class written under `src/SprykerAcademy` is a public, autowired service ([Exercise 4, section 2.6](04-module-layers-back-office.md)). An assistant that does not know this writes the older stack instead: a business factory, a dependency provider, and `getFactory()` everywhere. |
| `getService()` in the facade | `AbstractFacade` uses `Spryker\Service\Container\ContainerTrait`, so `$this->getService(ContactRequestReader::class)` reads straight from the container - the style you wrote yourself in [Exercise 4, section 2.4](04-module-layers-back-office.md). The second argument of `getService()` is a factory method name to fall back on, which is how a legacy module migrates gradually; a new module does not need it. |
| Yves keeps the factory | `config/Yves/ApplicationServices.php` is an empty stub in the demo shop, so nothing of yours is in the Yves container. The rule above would be wrong there, and an assistant applying it consistently would break the storefront. |
| The Glue Storefront client registration | `SprykerDefaultsPass` auto-registers Spryker's conventional entry points, but `findResolvableClassForInterface()` returns `null` for anything outside the core namespaces. A project-namespace Client therefore falls through to a proxy that fails at runtime with *Could not find ... in any of the attached containers*, and the only fix is the explicit `$services->set()`. |

> **This list is the difference between a module and *your* module.** Without it, a real run of this exercise came back with a business factory, a Zed dependency provider, a Client factory and dependency provider of its own, and a facade whose every method reads `$this->getFactory()->create...()`. Perfectly ordinary Spryker code - just not the style you spent Exercises 4 to 6 teaching, and a diff full of noise rather than of decisions.

The same facts belong in the **context file** from Part 2, because it describes the project and stays, while the prompt describes one feature and changes every time. Repeat them here anyway: a context file is one more thing an assistant can skim past, and these are the facts everything else hangs off.

> You are asking, in a page, for roughly what Exercises 1 to 6b build by hand, plus the kind of API resource [Exercise 12](../intermediate/05-glue-storefront-api.md) builds in the intermediate course: a Propel table with a foreign key to `spy_customer`, transfers, the three Zed layers, a Back Office page with a table, a Client with a Zed stub, and - if you say yes - a customer account page in Yves.

### It gets to choose the names

The shop is empty, so nothing collides and nothing is reserved. The module does not have to be called `ContactRequest`, the table does not have to be `pyz_contact_request`, and the Back Office route is whatever the assistant decides. Let it choose. What it picks, and whether it picks consistently across the schema, the transfers, the routes and the navigation, is one of the things you are here to judge.

Write down the names it chose before you go on - Part 5 needs them.

### Answer its questions

A good assistant will come back with questions before it writes code. Answer them; do not let it guess. Decisions that are yours to make for this exercise:

| Question you are likely to get | Answer for this exercise |
|---|---|
| Do you want the storefront pages in Yves? | Your call, and the prompt tells it to ask. Say no if you are testing in Swagger or Postman - the Back Office and the API already exercise the whole stack, and you halve the run. Say yes if you want to compare its Yves code with yours. |
| Guests too, or only logged-in customers? | Only logged-in customers. |
| Should the customer see the messages they already sent? | Yes - on the account page if you asked for Yves, through the API either way. |
| Can the customer edit or delete a message? | No. Sending is enough. |
| Does the admin reply, or is there a status / read flag? | No. Reading is enough. |
| Email notification to the shop owner? | No. |
| Extra fields (subject, category, created date)? | A creation timestamp is fine, nothing else. |
| Is the API public, or only for the logged-in customer? | Only the logged-in customer, authenticated like the rest of the Storefront API. |
| Which operations on the API? | Send a message, and list the ones that customer sent. Nothing else. |
| Should it write tests? | Yes, if it offers - but you review the code yourself either way. |

### While it works

Watch **which rules and skills it picks up**. With the workflow block from Part 2 in place it should name them before it starts: `propel-schema` for the schema, `yves-atomic-frontend` for the storefront template, `spryker-refresher` after it changes code, `static-validation` before it declares victory. An assistant that writes a schema file and never runs `propel:install` has not finished, whatever it says - and an assistant that never mentions a skill is improvising.

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

Then walk the three flows. Substitute the names the assistant actually chose:

1. **Storefront** - only if you said yes to Yves. Log in at http://yves.eu.spryker.local/en/login as `sonia@acme.com` / `change123`, open the customer account area, send a message. If you said no, start at the API in step 3 and use it to create the message the Back Office table has to show.
2. **Back Office.** Log in at http://backoffice.eu.spryker.local as `admin@spryker.com` / `change123`, find the new navigation entry, and check that the message is in the table - with the right customer next to it. Sort a column, type something in the filter, page through.
3. **Storefront API.** Open http://glue.eu.spryker.local/docs. That page is API Platform's own documentation of the running API - Swagger UI and ReDoc over the live OpenAPI spec - and the new resource has to be in it, with the operations you asked for. Send a request from the page and read the response.

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

### See everything it touched

You started from a clean shop, so Git is an exact record of the assistant's work:

```bash
git status --short     # every file it created
git diff --stat        # every tracked file it edited
```

Anything **outside** `src/SprykerAcademy` is a shared file. Expect to see some of these, and read every one of them:

| File | What to check |
|---|---|
| `config/Zed/navigation.xml` | The Back Office entry, pointing at a controller that exists |
| `config/Shared/config_default.php` | Constants appended, nothing else disturbed |
| `config/Zed/ApplicationServices.php` | Bindings, if it wrote two implementations of an interface |
| `config/GlueStorefront/ApplicationServices.php` | The project Client registration the API needs |
| `config/GlueStorefront/packages/spryker_api_platform.php` | `src/SprykerAcademy` in the source directories |
| `src/Pyz/Yves/CustomerPage/...navigation-sidebar.twig` | If you asked for Yves: the account link |
| `composer.json` | Did it add a dependency? Which, and why? |

### Check the service container

This is where a Spryker assistant goes wrong quietly:

```bash
docker/sdk cli vendor/bin/console lint:container
docker/sdk cli vendor/bin/console debug:container SprykerAcademy
```

The lint must answer *The container was linted successfully*, and the listing shows every class of the new module that Symfony knows about. If a class the assistant just wrote is missing from the listing, rebuild the container before believing it - `docker/sdk console cache:clear` ([Exercise 4, section 2.7](04-module-layers-back-office.md)). Autowiring resolves a constructor that asks for an interface only while exactly one class implements it, so if the assistant wrote two implementations of the same interface, the binding has to be explicit in `config/Zed/ApplicationServices.php` - see [Exercise 4, section 2.5](04-module-layers-back-office.md).

If a page errors, do not fix it yourself yet. Hand the error to the assistant (the `spryker-issue-diagnoser` agent is built for this) and watch how it diagnoses. That is also part of the exercise.

---

## Part 5: Review It Like a Pull Request

Commit the result first. This is the only copy of it, and the next step overwrites the folder:

```bash
printf 'exercises/\n' >> .git/info/exclude   # the exercises clone is a repo of its own
git add -A
git commit -m "ContactRequest built by the AI Dev SDK"
git show --stat HEAD
```

> Without the first line, `git add -A` warns `adding embedded git repository: exercises` and records the folder as a broken submodule reference. `.git/info/exclude` is a personal `.gitignore` that is not part of the repository, which is exactly right for a folder only you have.

### Bring your own implementation back and diff the two

Now load the handmade module on top of the assistant's. The loader deletes `src/SprykerAcademy` and writes Exercise 6's version in its place - and because the assistant's version is committed, that turns the whole comparison into one `git diff`:

```bash
./exercises/load.sh contact-request basics/module-layers/complete

git status --short     # what the two implementations disagree about
git diff               # the assistant's version (HEAD) against yours (working tree)
```

> The loader registers the namespace and runs `composer dump-autoload` itself, so there is nothing to do after it apart from reading the diff.

Read `git status` first, because the file names alone tell you most of the story:

- **Deleted files** are things the assistant wrote that your module does not have. Sometimes they are genuinely better; sometimes they are a `Validator`, a `Creator` and an `ExceptionFactory` where a Writer would have done.
- **New files** are what it left out. If `Communication/Table/...` shows up here, it did not use Spryker's table and your sorting and filtering came from somewhere else.
- **Modified files** are the interesting ones: same name, same job, two designs. `git diff` them one by one.

If the assistant chose different class names - likely, and fine - Git sees no pairs at all and everything looks added or deleted. Compare the two by shape instead. The script reads the assistant's module straight out of the commit, so the working tree stays exactly as the loader left it:

```bash
./exercises/tools/compare-modules.sh ContactRequest <TheNameItChose> --ref HEAD
```

It maps every file of one module onto the other in all three spellings (`ContactRequest`, `contact_request`, `contact-request`), normalises the name inside the files too, and reports what is missing, extra and genuinely different:

```text
Comparing ContactRequest (working tree) with CustomerRequest (HEAD)

differs: ./Zed/ContactRequest/Business/ContactRequestFacade.php
differs: ./Zed/ContactRequest/Persistence/Propel/Schema/pyz_contact_request.schema.xml
only in ContactRequest: ./Zed/ContactRequest/Business/Writer/ContactRequestWriter.php
only in CustomerRequest: ./Zed/CustomerRequest/Business/Creator/CustomerRequestCreator.php
only in CustomerRequest: ./Zed/CustomerRequest/Business/Validator/CustomerRequestValidator.php
only in CustomerRequest: ./Zed/CustomerRequest/Business/CustomerRequestBusinessFactory.php
only in CustomerRequest: ./Zed/CustomerRequest/Communication/Table/CustomerRequestTable.php
...

identical after renaming: 0 of 43 files
differs: 12   only in ContactRequest: 13   only in CustomerRequest: 18
```

That output is from a real run, and it is already a review: the assistant split writing into a `Creator` and a `Validator` where you had one `Writer`, it kept the business factory the house rules told it not to write, and it did use Spryker's `AbstractTable` - which your Exercise 4 module never had. Nothing identical after renaming means it designed rather than copied.

If most of it comes back identical, the opposite happened: the assistant reproduced the tutorial it was trained on, and the script says so.

### Then go through the code with the rules of Exercises 1 to 6b in hand

- **Persistence.** Is `fk_customer` a real Propel foreign key to `spy_customer`, or just an integer column? Is there an index? Does any Propel entity leave the Persistence layer, or does everything cross the boundary as a transfer?
- **Business.** Is there a Facade with an interface? Are Reader and Writer separate classes with interfaces? Any `new` inside business logic instead of a factory?
- **Communication.** Did it use Spryker's Back Office table (`AbstractTable` from the `Gui` module, with `configure()` and `prepareData()`), or did it hand-roll a Twig loop and call it a table? Sorting, filtering and paging come for free with the first and not at all with the second.
- **Wiring.** Count the classes that exist only to assemble other classes. A business factory, a Zed dependency provider and a facade full of `$this->getFactory()->create...()` mean it ignored the house rules and wrote the older Spryker style - which runs, and which is exactly the noise that makes the diff against your module unreadable. In Yves it is the other way round: a factory and a dependency provider are correct there, and constructor injection is not.
- **Yves** - if you asked for it. Does the storefront go through the Client and the Zed gateway, or does it query the database directly from Yves? Does the page only ever show the messages of the logged-in customer - or can you change an ID in the URL and read someone else's?
- **Transfers.** `strict="true"`, or untyped accessors?
- **The API.** A `*.resource.yml` plus a Provider class, or the legacy GlueApplication plugin stack? Both run, and only one is what Spryker recommends for new APIs. Did it register `src/SprykerAcademy` in `config/GlueStorefront/packages/spryker_api_platform.php`, or did it quietly put the resource in `Pyz` where the default source directories already look?
- **Who can read what.** Change the id in the API request to a contact request belonging to another customer. If you get it back, the Provider is not scoping by the authenticated customer - the single most common mistake in a generated API, and the one a passing test suite will not catch.
- **Service wiring.** Did it register the interfaces it injects in `config/Zed/ApplicationServices.php`, or is the module standing on the single-implementation rule without knowing it? Ask the assistant which of its constructor arguments would stop resolving if you added a second implementation tomorrow. And if an API Platform provider injects its Client, is that Client registered in `config/GlueStorefront/ApplicationServices.php` - or did it only work because you told it to put the line there?
- **Everything else.** Dependencies through the `DependencyProvider` and created in factories? Return types as interfaces? Did it add things you never asked for - extra fields, helper classes, commented-out code? Would you keep them?

Then ask the SDK's own reviewer and compare its list with yours:

```text
Use the spryker-code-reviewer agent to review the ContactRequest module in the last commit.
```

**The best result of this exercise is a list of differences, not a perfect module.** Write the list down - it is the thing you take home about working with an assistant on a Spryker project.

---

## Cleanup

You are already most of the way there: the loader in Part 5 put the handmade module back. For Exercise 7, load its skeleton and rebuild:

```bash
./exercises/load.sh contact-request basics/extending-core-modules/skeleton
docker/sdk console c:e
docker/sdk cli composer dump-autoload
docker/sdk console propel:install
docker/sdk console transfer:generate
```

Two things the loader does **not** clean up after the assistant, because it only ever adds to those files:

- **The navigation entry**, if the assistant's module used a different key from Exercise 6's. The Back Office menu then keeps a link to a controller that no longer exists. Remove the entry from `config/Zed/navigation.xml` and run `docker/sdk console navigation:build-cache`.
- **Anything it wrote in `src/Pyz` or `config/`.** `git diff` after the load shows what survived; the table it created stays in the database as well.

The assistant's module is safe in the commit from Part 5, so you can read it again whenever you want:

```bash
git show --stat HEAD~0                       # or whichever commit it was
git checkout <commit> -- src/SprykerAcademy  # put it back in the tree
```

## Going Further

- Give the exact same prompt to a second assistant or a second model on the same clean shop, commit that one too, and diff the two commits. The differences between two AI runs are as instructive as the differences from your own code.
- Run it once **without** the workflow block from Part 2 and once with it, and count how many skills each run names. That is the cheapest demonstration there is of why a context file is worth writing.
- Add one sentence to the requirement - "the admin can reply to a message and the customer sees the reply" - and watch whether it extends the existing design or bolts on a parallel one.
- Start the MCP server (`docker/sdk console ai-dev:mcp-server -q`), connect it to your tool, and ask the assistant which transfers exist for the module it just built.
