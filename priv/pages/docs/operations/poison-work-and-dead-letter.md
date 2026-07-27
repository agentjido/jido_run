%{
  description: "A worked example of poison work and dead-letter handling: a persistently failing item exhausts a bounded retry budget, is moved to a dead-letter store where it can be inspected, and is replayed once the underlying cause is fixed.",
  title: "Poison work and dead-letter handling",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 365,
  draft: false
}
---
# Poison Work and Dead-Letter Handling

[Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure) ends every path the same way: a **bounded** number of retries, then a defined fallback. But some work fails *every* time — a bad payload, a row the schema rejects, a job whose downstream dependency is gone. That is **poison work**. Retrying it without limit poisons the queue: it burns budget, blocks later work, and loops without end. The dead-letter pattern is what stops that. After a bounded retry budget is exhausted, the failed work is moved to a **dead-letter store**, where an operator can **inspect** it and later **replay** it once the underlying cause is fixed.

This is the worked example for the rule the retries guide names twice: poison work that fails every time should "move to a dead-letter path for inspection, not be retried forever." It takes one piece of work against a dependency that can be down, and shows both halves playing out — a persistently failing item dead-lettered after a bounded budget, then inspected and replayed to success.

A dead-letter queue is an **application concern**. Jido does not ship one — the Signal Journal is the closest durable-history surface, and the routing, retention, and replay policy is yours to own. This is a different layer from the [tool error](/docs/operations/tool-error-and-retry-decision) (a retryable/terminal decision at the `run/2` boundary) and the [provider timeout](/docs/operations/provider-timeout-and-fallback) (a bounded retry and an explicit fallback at the model layer). Those recover a *call*; dead-letter handling recovers *work* that the calls keep failing on. This example isolates the application's dead-letter rule so you can see inspect-and-replay on its own.

## The rule

Two things must hold for poison work, and the example makes both observable:

1. **Failed work can be inspected.** When the bounded budget is exhausted, the failed work is not dropped and not lost in a log — it is moved to a dead-letter store as an entry carrying the original work, the failure reason, the attempt count, and a stable id. An operator can list the store and read what failed and why.
2. **Failed work can be replayed.** A dead-lettered entry can be re-submitted to the worker. Once the underlying cause is fixed, the replay succeeds and the entry leaves the dead-letter store. If it fails again, the *same* entry is updated — never a duplicate.

| Work outcome | Retried? | What happens |
|---|---|---|
| The worker succeeds | Only if transient | Return the result. Nothing is dead-lettered. |
| Transient failure, clears inside the budget | Yes, with backoff | Retry up to `max_attempts`. Then succeed. |
| Persistent failure (poison) — exhausts the budget | Yes, but bounded | Dead-letter the work: inspectable entry, replayable later. |

## The example worker and store

The runnable example is a single module, `AgentJido.Demos.PoisonWorkDeadLetter`, with two nested processes. A `Worker` models the external dependency a piece of work calls (a payment gateway, a downstream API) — it has a `mode` the operator controls, so `:broken` makes every run fail (poison work) and `:healthy` makes every run succeed. A `DeadLetterStore` holds the failed work. The top-level `process/2` runs one item with a bounded retry budget; `replay/3` re-runs a dead-lettered entry.

The worker is where the failure comes from. `break/1` and `fix/1` model the dependency going down and coming back — the moment a dead-lettered item can be replayed to success:

```elixir
defmodule AgentJido.Demos.PoisonWorkDeadLetter.Worker do
  use GenServer

  def run(worker, work), do: GenServer.call(worker, {:run, work})
  def break(worker), do: GenServer.call(worker, {:set_mode, :broken})
  def fix(worker), do: GenServer.call(worker, {:set_mode, :healthy})

  @impl true
  def handle_call({:run, work}, _from, %{mode: mode} = state) do
    result =
      case mode do
        :healthy -> {:ok, %{processed: work}}
        :broken -> {:error, {:dependency_down, work[:dep] || :downstream}}
      end

    {:reply, result, state}
  end
  # ... mode get/set elided; see the source.
end
```

The bounded-retry loop is where the rule lives. It retries a failure only while `attempt < max_attempts`, and on exhaustion it hands the work to the store rather than looping:

```elixir
defp run_with_budget(worker, work, attempt, max_attempts, backoff_ms, counter) do
  bump(counter)

  case Worker.run(worker, work) do
    {:ok, result} ->
      {:ok, result, attempt}

    {:error, _reason} when attempt < max_attempts ->
      # Bounded retry — but only inside the budget.
      Worker.sleep_for(backoff_ms, attempt)
      run_with_budget(worker, work, attempt + 1, max_attempts, backoff_ms, counter)

    {:error, reason} ->
      # Budget exhausted. Stop retrying; the caller dead-letters the work.
      {:error, reason, attempt}
  end
end
```

To see how many times the worker actually ran, the example carries a `counter` (a simple `Agent` holding an integer) alongside the options, bumped on every attempt — so the bounded count is observable whether the work recovers or exhausts the budget.

## Healthy work is processed, not dead-lettered

When the dependency is healthy, the worker answers on the first attempt. Nothing is retried, nothing is dead-lettered, and the store stays empty:

```elixir
{:ok, worker} = AgentJido.Demos.PoisonWorkDeadLetter.Worker.start_link(mode: :healthy)
{:ok, store} = AgentJido.Demos.PoisonWorkDeadLetter.DeadLetterStore.start_link()

{:ok, %{processed: %{id: "charge-1", amount: 42}}} =
  AgentJido.Demos.PoisonWorkDeadLetter.process(
    %{id: "charge-1", amount: 42, dep: :payment_gateway},
    worker: worker, store: store, max_attempts: 3
  )

AgentJido.Demos.PoisonWorkDeadLetter.DeadLetterStore.entries(store)   # => []
```

## Poison work is bounded, then dead-lettered

Break the dependency so every run fails, then process the same item with `max_attempts: 3`. The bounded budget is exhausted at exactly three calls — the loop does not run forever — and the work is moved to the dead-letter store:

```elixir
AgentJido.Demos.PoisonWorkDeadLetter.Worker.break(worker)

{:dead_lettered, entry_id} =
  AgentJido.Demos.PoisonWorkDeadLetter.process(
    %{id: "charge-1", amount: 42, dep: :payment_gateway},
    worker: worker, store: store, max_attempts: 3, counter: counter
  )

Agent.get(counter, & &1)   # => 3 — exactly max_attempts, never unbounded
length(AgentJido.Demos.PoisonWorkDeadLetter.DeadLetterStore.entries(store))   # => 1
```

The budget — not the worker, not the store — is what stops a poison item from looping.

## Failed work can be inspected

The acceptance condition is not "the work is dropped on failure." The dead-lettered entry is inspectable: it carries the original work, the failure reason, the attempt count, and the id, so an operator can read what failed and why:

```elixir
entry = AgentJido.Demos.PoisonWorkDeadLetter.DeadLetterStore.get(store, entry_id)

entry.id       # => "dlq-1"
entry.work     # => %{id: "charge-1", amount: 42, dep: :payment_gateway}
entry.reason   # => {:dependency_down, :payment_gateway}
entry.attempts # => 3
```

The store also lists every dead-lettered item (`entries/1`), so an operator can review the full backlog of failed work in one place — not grep a log.

## Failed work can be replayed

A dead-lettered entry is not a terminal state. Once the underlying cause is fixed (`Worker.fix/1` — the dependency is back), the entry can be replayed. The replay re-runs the work through the same bounded budget; on success the entry is removed from the store — the work has left the failed state:

```elixir
AgentJido.Demos.PoisonWorkDeadLetter.Worker.fix(worker)

{:ok, %{processed: %{id: "charge-1", amount: 42}}} =
  AgentJido.Demos.PoisonWorkDeadLetter.replay(
    store, entry_id,
    worker: worker, max_attempts: 3
  )

AgentJido.Demos.PoisonWorkDeadLetter.DeadLetterStore.get(store, entry_id)   # => nil
```

If the replay fails again — the dependency is still down — the *same* entry is updated in place (its reason and attempts refreshed, a replay counter advanced), and the same id is returned. It never spawns a duplicate. That is what makes the dead-letter store a queue you can drain, not a pile of copies.

## What this example shows and what it does not

This example proves two things directly: failed work is inspectable (the entry carries the work, reason, attempts, and id), and failed work is replayable (a fixed cause lets a replay succeed and the entry leaves the store, while a renewed failure updates the same entry).

It does not, by itself:

- **Persist the store.** This store is in-memory; a process or node restart empties it. Durable backing is an application-owned choice — the Signal Journal with a durable adapter is the closest Jido-native surface, and persistence is covered separately on [Scheduling and event input](/docs/operations/scheduling-and-event-input).
- **Recover process state.** Dead-lettering recovers work that keeps failing; it does not reconstruct state lost to a crash. Process recovery is supervision's job — see [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
- **Make replay safe for you.** Re-running side-effecting work requires idempotency keys or Signal IDs, so a replay does not double-charge a card. Wire those before replaying.
- **Serve as an audit trail.** A dead-letter store is an operational backlog for inspection and replay, not a tamper-evident audit log — retention, access, and deletion duties stay with the application. See [Security and governance](/docs/operations/security-and-governance).
- **Replace the call-layer decisions.** A tool error is retried at the `run/2` boundary; a provider failure falls back at the model layer. This page is what happens *after* those budgets run out on work that still fails — see the [Tool Error and Retry Decision](/docs/operations/tool-error-and-retry-decision) and [Provider Timeout and Fallback](/docs/operations/provider-timeout-and-fallback) worked examples.

## Run it yourself

The example ships with a test that encodes the acceptance condition — healthy work is not dead-lettered; poison work is bounded at exactly `max_attempts` and dead-lettered once; the entry is inspectable (work, reason, attempts, id); and the entry is replayable to success after the cause is fixed (or updated in place if it still fails):

```
mix test test/agent_jido/demos/poison_work_dead_letter_test.exs
```

The source is at `lib/agent_jido/demos/poison_work_dead_letter/poison_work_dead_letter.ex`.

> The end-to-end long-running reference application (`jido-e07-t29`) is the tracked follow-up that will fold this poison-work-and-dead-letter path into one runnable app. Until it lands, the example ships as a self-contained, tested demo — the same pattern the [tool error](/docs/operations/tool-error-and-retry-decision), [provider timeout](/docs/operations/provider-timeout-and-fallback), and [process crash](/docs/operations/process-crash-and-restart) worked examples use.

## Next steps

- Read the full framework — tool, HTTP, and model failures, plus the bounded-retry rule that feeds this path — on [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure).
- See the call-layer decisions that run *before* work is dead-lettered: the [Tool Error and Retry Decision](/docs/operations/tool-error-and-retry-decision) and [Provider Timeout and Fallback](/docs/operations/provider-timeout-and-fallback) worked examples.
- Confirm your retry budgets and dead-letter policy against the [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
- Practice a poison-work drill with the [Incident playbooks](/docs/operations/incident-playbooks).
- Pair the dead-letter store with process-level recovery in [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
