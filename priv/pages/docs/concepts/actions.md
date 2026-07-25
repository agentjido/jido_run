%{
  title: "Actions",
  description: "Discrete, composable units of validated computation that drive agent state transitions.",
  category: :docs,
  legacy_paths: ["/docs/actions"],
  order: 70,
  tags: [:docs, :concepts]
}
---
## What actions solve

Agent systems need a consistent way to express "what should happen" without coupling logic to infrastructure. Raw functions lack validation, composability, and introspection. When you chain several operations together, you need guarantees about data shape at every boundary.

Actions solve this by wrapping each unit of work in a compile-time contract. Every Action declares its expected inputs, validates them at runtime, executes a pure function, and optionally validates the output. Because Actions never perform side effects directly, they remain testable in isolation and composable in sequence.

## Anatomy of an action

An Action is an Elixir module that calls `use Jido.Action` with compile-time configuration. The only required callback is `run/2`, which receives validated params and a context map.

```elixir
defmodule MyApp.CalculateShipping do
  use Jido.Action,
    name: "calculate_shipping",
    description: "Calculates shipping cost for an order",
    schema: Zoi.object(%{
      weight_kg: Zoi.float(),
      destination: Zoi.string()
    }),
    output_schema: Zoi.object(%{
      cost: Zoi.float(),
      carrier: Zoi.string()
    })

  @impl true
  def run(params, _context) do
    cost = params.weight_kg * rate_for(params.destination)
    {:ok, %{cost: cost, carrier: "standard"}}
  end

  defp rate_for("US"), do: 2.50
  defp rate_for(_), do: 5.00
end
```

The `use` macro validates your configuration at compile time. If you pass an invalid schema or omit the required `name` field, compilation fails with a clear error. This catches misconfiguration before your code ever runs.

The `run/2` callback returns one of three shapes:

- `{:ok, result}` - a map of output data
- `{:ok, result, directives}` - output data plus side-effect instructions for the runtime
- `{:error, reason}` - a failure

## Validation

Actions use schema-based validation for both inputs and outputs. You declare schemas using Zoi in the `schema` and `output_schema` fields.

```elixir
defmodule MyApp.CreateInvoice do
  use Jido.Action,
    name: "create_invoice",
    schema: Zoi.object(%{
      customer_id: Zoi.string(),
      line_items: Zoi.list(Zoi.map()),
      currency: Zoi.string() |> Zoi.default("USD")
    }),
    output_schema: Zoi.object(%{
      invoice_id: Zoi.string(),
      total: Zoi.float()
    })

  @impl true
  def run(params, _context) do
    total = Enum.reduce(params.line_items, 0.0, &(&1.amount + &2))
    {:ok, %{invoice_id: "inv_#{params.customer_id}", total: total}}
  end
end
```

Jido uses an open validation model. Only fields declared in the schema are validated - undeclared fields pass through untouched. This design is intentional. When actions compose in a chain, earlier actions may produce fields that later actions need. Open validation prevents intermediate actions from rejecting data they do not use.

You can also hook into the validation lifecycle. Override `on_before_validate_params/1` to transform raw input before validation, or `on_after_validate_params/1` to enrich validated params before execution.

## Composition

Actions compose naturally because their inputs and outputs are plain maps. You pass a list of actions to `cmd/2`, and the framework executes them in sequence. Each action's output merges into the params available to the next action.

```elixir
defmodule MyApp.ValidateOrder do
  use Jido.Action,
    name: "validate_order",
    schema: Zoi.object(%{order_id: Zoi.string()})

  @impl true
  def run(params, _context) do
    {:ok, %{order_id: params.order_id, validated: true}}
  end
end

defmodule MyApp.ApplyDiscount do
  use Jido.Action,
    name: "apply_discount",
    schema: Zoi.object(%{validated: Zoi.boolean()})

  @impl true
  def run(params, _context) do
    discount = if params.validated, do: 0.10, else: 0.0
    {:ok, %{discount: discount}}
  end
end
```

Execute the chain through an agent:

```elixir
{agent, directives} = MyAgent.cmd(agent, [
  {MyApp.ValidateOrder, %{order_id: "ord_99"}},
  MyApp.ApplyDiscount
])
```

`ValidateOrder` produces `%{order_id: "ord_99", validated: true}`. That map flows into `ApplyDiscount`, which finds the `validated` field it needs. Open validation makes this seamless - `ApplyDiscount` does not reject the `order_id` field even though its schema does not declare it.

Actions can also return directives as a third element to request side effects from the runtime:

```elixir
def run(params, _context) do
  signal = %Jido.Signal{
    id: "sig_#{params.order_id}",
    type: "order.confirmed",
    source: "my_app.orders",
    data: %{order_id: params.order_id}
  }

  {:ok, %{status: :confirmed}, %Jido.Agent.Directive.Emit{signal: signal}}
end
```

The directive does not execute inline. It is collected and returned alongside the updated agent, keeping your action logic pure.

## Instructions

An Instruction pairs an Action module with everything it needs to execute: parameters, context, and runtime options. When you call `cmd/2`, Jido normalizes whatever you pass into `%Jido.Instruction{}` structs before execution.

You can express instructions in several formats, from minimal to fully explicit:

### Action module only

The simplest form. No params, no context.

```elixir
MyAgent.cmd(agent, MyApp.ValidateOrder)
```

### Tuple with params

The most common form. Pairs an action with its input data.

```elixir
MyAgent.cmd(agent, {MyApp.ValidateOrder, %{order_id: "ord_99"}})
```

### List of instructions

Chain multiple actions. Each format can be mixed freely in the list.

```elixir
MyAgent.cmd(agent, [
  {MyApp.ValidateOrder, %{order_id: "ord_99"}},
  MyApp.ApplyDiscount,
  {MyApp.CalculateShipping, %{destination: "US"}}
])
```

### Full struct

For cases where you need to set context or runtime options explicitly.

```elixir
instruction = Jido.Instruction.new!(%{
  action: MyApp.ProcessOrder,
  params: %{order_id: "ord_99"},
  context: %{tenant_id: "tenant_456"},
  opts: [timeout: 10_000]
})

MyAgent.cmd(agent, instruction)
```

All formats normalize to the same `%Jido.Instruction{}` struct internally, so the execution path is identical regardless of which shorthand you use.

## Actions as AI tools

Every Action doubles as an LLM tool definition. The same Zoi schema that validates runtime input also generates the JSON Schema that LLMs use to understand available parameters. You define the contract once, and both human callers and AI agents use the same interface.

### Schema to JSON Schema

`Jido.Action.Schema` converts your Zoi schema into a JSON Schema object. The `description` option on each field becomes the parameter description the LLM sees.

```elixir
defmodule MyApp.LookupCustomer do
  use Jido.Action,
    name: "lookup_customer",
    description: "Finds a customer by email address",
    schema: Zoi.object(%{
      email: Zoi.string(description: "The customer's email address")
    })

  @impl true
  def run(params, _context) do
    {:ok, %{customer_id: "cus_123", name: "Jane Doe"}}
  end
end
```

Call `to_tool/0` on any Action to get a generic tool map with name, description, function, and parameters schema. This works with any tool-calling integration.

### ReqLLM integration

When you use `jido_ai`, `Jido.AI.ToolAdapter` converts Actions into `ReqLLM.Tool` structs that plug directly into LLM API calls.

```elixir
tools = Jido.AI.ToolAdapter.from_actions([
  MyApp.LookupCustomer,
  MyApp.CreateOrder
])
```

The adapter registers each tool with a noop callback. Jido does not execute tools inline during the LLM call. Instead, the agent runtime handles execution through `Jido.AI.Directive.ToolExec`, keeping the LLM request and the actual side effect cleanly separated.

### Parameter normalization

LLMs return arguments as string-keyed JSON. Jido handles the mismatch automatically. When the runtime executes a tool call, `convert_params_using_schema/2` converts string keys to atoms and coerces types based on your schema. A value like `"42"` for an integer field becomes `42`. Unknown keys pass through untouched, preserving the open validation model.

### Strict mode

Some providers (OpenAI structured outputs) require `additionalProperties: false` on every object in the schema. Pass `strict: true` to `from_actions/2` or define a `strict?/0` callback on your Action to opt in per-action. The adapter recursively enforces the constraint across nested objects.

## Control surface

An action's control surface is its validated contract plus the fail-closed hook that gates whether it runs. The table names each control point. Param validation checks data shape — it is **not** an authorization decision. Authorization belongs in `prepare_action/3`, which is fail-closed by design: a protected action never runs just because no hook is configured. See [Security and governance](/docs/operations/security-and-governance) for the full control-point map.

| Hook | Input | Decision | Output | Failure behavior | Evidence |
| --- | --- | --- | --- | --- | --- |
| `Jido.Action` param schema | params map | Validate args against the schema | Validated params | `{:error, validation}` returned before `run/2` | Validation result (a data check, not an authorization decision) |
| `prepare_action/3` (plugin hook) | validated params + context | Permit or deny the action | `:ok` or `{:halt, reason}` | Fail-closed — a protected action does not run without an explicit allow | Deny reason; the action never executes |
| `run/2` | validated params + context | Execute the pure computation | result | Typed error tuple; optional output-schema validation | Result value and any output-validation error |

## Next steps

- [Agents](/docs/concepts/agents) - see how agents execute actions through `cmd/2`
- [Directives](/docs/concepts/directives) - understand the side-effect payloads actions can return
- [Signals](/docs/concepts/signals) - learn about typed event envelopes for agent coordination
- [Your first agent](/docs/getting-started/first-agent) - hands-on tutorial using actions in practice
