# Exercise 13: Order Management System (OMS)

In this exercise, you will build a complete order management process using Spryker's OMS State Machine. You will define states, transitions, events, commands, and conditions in XML, then implement the command and condition plugins in PHP.

You will learn how to:
- Define states with reserved and display properties
- Create transitions between states with events and conditions
- Add commands (business logic) and conditions (routing logic) to the state machine
- Implement `CommandByOrderInterface` and `ConditionInterface` plugins
- Register OMS plugins in the DependencyProvider
- Visualize and test the state machine in the Back Office
- Mark the "happy path" for visual representation

## Prerequisites

- A running Spryker demo shop with products available for checkout
- Understanding of the Facade and DependencyProvider patterns

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/oms/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console cache:empty-all
```

---

## Background: OMS Architecture

Spryker's Order Management System uses an XML-based state machine to define the lifecycle of an order. Each order item moves through states based on events, commands, and conditions.

```
State Machine XML (config/Zed/oms/Demo01.xml)
    ├── States      — positions in the workflow (new, paid, shipped, closed)
    ├── Transitions — connections between states (source → target)
    ├── Events      — triggers for transitions (manual, onEnter, timeout)
    ├── Commands    — PHP plugins that execute business logic
    └── Conditions  — PHP plugins that decide which transition to take
```

**Key concepts:**

| Concept | XML Element | PHP Interface | Purpose |
|---------|-------------|---------------|---------|
| State | `<state name="new"/>` | — | Order's current position |
| Transition | `<transition>` | — | Connects two states |
| Event | `<event name="pay"/>` | — | Triggers a transition |
| Command | `command="Oms/Pay"` | `CommandByOrderInterface` | Executes logic on event |
| Condition | `condition="Oms/IsAuthorized"` | `ConditionInterface` | Routes to different states |

---

## Working on the Exercise

### Part 1: Enable the State Machine

The OMS process must be registered as an active process and mapped to a payment method.

**Coding time:**

Open `config/Shared/common/config_oms-development.php`:

1. Add the state machine name to the list of active processes. The name must match the XML filename without the `.xml` extension (e.g., `'Demo01'`).
2. Map the state machine to the invoice payment method by replacing the current process name with your new one.

> **Verify:** Visit http://backoffice.eu.spryker.local/oms — the Demo01 process should be listed. Clicking it shows a blank page (the state machine is still empty).

---

### Part 2: Define States

States represent the positions an order item can be in during its lifecycle.

**Coding time:**

Open `config/Zed/oms/Demo01.xml`. Inside the `<states>` element, add the following states:
- `new` (reserved)
- `payment pending` (reserved)
- `invalid`
- `payment authorized` (reserved)
- `paid` (reserved)
- `closed`

> **`reserved="true"`:** Reserved states indicate that the order item is still "active" — the associated stock is reserved. Non-reserved states (like `closed` or `invalid`) release the stock reservation.
>
> **`display` attribute:** Optional — provides a translation key for the Back Office UI (e.g., `display="oms.state.new"`).

After adding states, refresh the OMS visualization in the Back Office — you should see all states displayed.

---

### Part 3: Define Transitions

Transitions connect states. They define how an order item moves from one state to another.

**Coding time:**

In the same file, inside the `<transitions>` element, add transitions:

- `new` → `payment pending`
- `new` → `invalid`
- `payment pending` → `payment authorized`
- `payment authorized` → `paid` (auto-transition, no event)
- `paid` → `closed` (auto-transition, no event)

> **Auto-transitions:** Transitions without an event happen automatically when the order enters the source state. Use them for states that should flow through immediately.

---

### Part 4: Define Events

Events are the triggers that cause transitions to happen. They can be:
- **`onEnter="true"`** — triggered automatically when entering the target state
- **`manual="true"`** — triggered by a user clicking a button in the Back Office
- **`timeout="N days"`** — triggered after a time delay
- **`command="Module/Name"`** — executes a PHP plugin when the event fires

**Coding time:**

In the `<events>` element, add:
- `authorize` — with `onEnter="true"` and `manual="true"`
- `pay` — with `onEnter="true"` and `manual="true"`

---

### Part 5: Assign Events to Transitions

Connect events to transitions so the state machine knows which event triggers which transition.

**Coding time:**

Update the transitions to include `<event>` elements:
- `new` → `payment pending` with the `authorize` event
- `new` → `invalid` with the `authorize` event
- `payment pending` → `payment authorized` with the `pay` event

> **Two transitions with the same event:** When `authorize` fires from the `new` state, the system needs a **condition** to decide which transition to take (→ `payment pending` or → `invalid`). We'll add that next.

---

### Part 6: Add Command and Condition

#### 6.1 Add Command to State Machine XML

A command executes PHP logic when an event triggers. Add the `command` attribute to the `authorize` event:

```
command="Demo/Pay"
```

The string `Demo/Pay` is a key that maps to a PHP plugin registered in the DependencyProvider.

#### 6.2 Add Condition to State Machine XML

A condition decides which transition to take when multiple transitions share the same event from the same source state. Add the `condition` attribute to the transition from `new` → `payment pending`:

```
condition="Demo/IsAuthorized"
```

When the condition returns `true`, the order goes to `payment pending` (happy path). When `false`, it goes to `invalid`.

---

### Part 7: Implement the Command Plugin

**Coding time:**

Open `src/SprykerAcademy/Zed/Oms/Communication/Plugin/Oms/Command/PayCommandPlugin.php`. Implement the `run()` method from `CommandByOrderInterface`.

The method receives the order items, the order entity, and a data object. For this exercise, return an empty array.

> **In production:** The command would call a payment gateway, update order data, send notifications, etc. The empty implementation is just for the exercise.
>
> **Method signature:** Check `vendor/spryker/oms/src/Spryker/Zed/Oms/Dependency/Plugin/Command/CommandByOrderInterface.php` for the exact parameters.

---

### Part 8: Implement the Condition Plugin

**Coding time:**

Open `src/SprykerAcademy/Zed/Oms/Communication/Plugin/Oms/Condition/IsAuthorizedConditionPlugin.php`. Implement the `check()` method from `ConditionInterface`.

Return `true` to always authorize (happy path). In production, this would check payment authorization status.

> **Method signature:** Check `vendor/spryker/oms/src/Spryker/Zed/Oms/Dependency/Plugin/Condition/ConditionInterface.php`.

---

### Part 9: Register Plugins in DependencyProvider

**Coding time:**

Open `src/SprykerAcademy/Zed/Oms/OmsDependencyProvider.php`:

1. Add the `PayCommandPlugin` to the command collection with the key `'Demo/Pay'`
2. Add the `IsAuthorizedConditionPlugin` to the condition collection with the key `'Demo/IsAuthorized'`

> **String matching:** The plugin key strings must match EXACTLY what you defined in the XML (`command="Demo/Pay"` and `condition="Demo/IsAuthorized"`). Including the slash.

After registering, refresh the OMS visualization — the red warnings about missing command/condition implementations should disappear.

---

### Part 10: Mark the Happy Path

The happy path is the expected/successful flow through the state machine. Marking it with `happy="true"` on transitions renders them in green in the Back Office visualization.

**Coding time:**

Add `happy="true"` to the transitions that form the successful flow:
`new` → `payment pending` → `payment authorized` → `paid` → `closed`

---

## Test the State Machine

1. Visit http://backoffice.eu.spryker.local/oms and verify the Demo01 process visualization
2. Go to http://yves.eu.spryker.local/ and place an order using the Invoice payment method
3. Open the order in http://backoffice.eu.spryker.local/sales/
4. The order should flow through the states: `new` → `payment pending` → `payment authorized` → `paid` → `closed`
5. Manual events (like `pay`) show as buttons next to the order item — click them to advance the state

---

## Key Concepts Summary

### Event Types

| Type | Attribute | When it fires |
|------|-----------|--------------|
| Auto | `onEnter="true"` | Immediately when entering the source state |
| Manual | `manual="true"` | When a user clicks the button in Back Office |
| Timeout | `timeout="14 days"` | After the specified time has elapsed |

### Condition Routing

When two transitions share the same event from the same source state:
- The transition **with a condition** is checked first
- If the condition returns `true`, that transition is taken
- If `false`, the transition **without a condition** is taken (fallback)

### Plugin Registration Pattern

```
XML: command="Demo/Pay" → PHP: $commandCollection->add(new PayCommandPlugin(), 'Demo/Pay')
XML: condition="Demo/IsAuthorized" → PHP: $conditionCollection->add(new IsAuthorizedConditionPlugin(), 'Demo/IsAuthorized')
```

---

## Solution

```bash
./exercises/load.sh supplier intermediate/oms/complete
```
