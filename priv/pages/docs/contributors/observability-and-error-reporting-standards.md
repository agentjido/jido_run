%{
  title: "Observability and error reporting standards",
  description: "Canonical contributor policy for logging, telemetry, sanitization, and Splode-backed error contracts across the Jido ecosystem.",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :contributors, :observability, :errors],
  order: 11,
  menu_label: "Observability Standards",
  audience: :intermediate,
  doc_type: :reference
}
---

This page defines the shared observability and error reporting baseline for public Jido ecosystem packages. These patterns are derived from the execution, sanitization, and error-model work in `jido_action` and are intended to be applied consistently across runtimes, tools, signals, AI integrations, and companion packages.

Link contributors and automated reviewers here when a package PR needs the canonical Jido answer for logging style, telemetry boundaries, Splode error modeling, sanitization, and public error contracts.

> Agent handoff: you can point an implementation or review agent at this page and instruct it to apply or verify these observability and error reporting standards as the canonical Jido ecosystem baseline.

This page defines contributor policy. It is separate from [Package Quality Standards](/docs/contributors/package-quality-standards), which define the broader repository and release bar, and separate from [Telemetry and Observability](/docs/reference/telemetry-and-observability), which should list runtime-specific events, metrics, and integration details.

Use it as the canonical implementation guide when a package needs to decide what should be logged, what should become telemetry, what should normalize into a package-local error, and what should cross a public boundary as a stable serialized payload.

## Fast Path Checklist

- [ ] Packages use direct `Logger` APIs only; they do not create package-local logger wrapper modules
- [ ] Expensive or interpolated log messages use lazy `fn -> ... end` forms
- [ ] Small shared logging helpers live in `Util`-style modules only when they encode policy, such as conditional gating
- [ ] Telemetry events use stable `[:jido, ...]` namespaces and bounded, low-cardinality metadata
- [ ] Logging and telemetry sanitize values explicitly before emission
- [ ] Public error payloads normalize through a package-local `Error.to_map/1`
- [ ] Packages standardize on Splode for error composition and classification
- [ ] Retryability and outcome classification are derived centrally, not controlled by per-call shape switches
- [ ] The same failure is not logged independently at every layer of the stack
- [ ] Changes to telemetry metadata, event names, or public error shape are treated as semver-relevant and documented clearly

## How to use this page

- Use it when designing new runtime or execution surfaces.
- Use it as the review baseline for pull requests that touch logs, telemetry, retries, sanitization, or error contracts.
- Use it as the canonical policy page when agents need a stable source of truth for Jido observability and error reporting patterns.

Packages SHOULD follow these conventions by default. Any exception should be explicit, documented, and justified by a concrete runtime or compatibility constraint.

---

## Core Principles

### Logging is for humans

Logs are an operator and developer narrative. They should help a person answer what happened, where it happened, and whether it needs action.

That means logs should be:

- Lazy, so expensive interpolation is only evaluated when the message will actually be emitted
- Bounded, so they do not dump entire payloads by default
- Sanitized, so secrets and inspect-hostile terms do not leak
- Owned at execution boundaries, so the same failure is not re-logged by every inner helper

### Telemetry is for machines

Telemetry is the machine-readable event stream for metrics, tracing, alerting, and downstream analysis.

That means telemetry should emphasize:

- Stable event names
- Low-cardinality metadata
- Explicit measurements such as duration, counts, and retry counts
- Outcome classification over raw payload dumping

Telemetry is not a replacement for logs, and logs are not a replacement for telemetry.

### Errors are contracts

Errors are part of the package API. Public consumers should receive a stable, documented error shape rather than whatever arbitrary Elixir term happened to exist internally.

That means:

- Package-local error modules define the error taxonomy
- External or raw failures are normalized once at a boundary
- Public error payloads are serialized through a single package-local adapter such as `MyPackage.Error.to_map/1`
- Retryability is derived centrally from typed errors and structured details

### Sanitization is explicit

Jido packages should distinguish between two different sanitization jobs:

- `:telemetry` shaping for logs and events: redact, truncate, bound depth, and make values inspect-safe
- `:transport` shaping for API, tool, or JSON boundaries: convert arbitrary Elixir terms into stable plain data

Rich Elixir terms may stay internal while code is still executing. Once data crosses an observability or transport boundary, the package must choose the correct sanitization profile explicitly.

---

## What Goes Where

| Need | Canonical mechanism | Why |
| --- | --- | --- |
| Human-readable operator or developer narrative | Log line at the owning boundary | Explains what happened without duplicating every internal detail |
| Metrics, tracing, alerting, or machine analysis | `:telemetry` event | Stable, low-cardinality signal for downstream systems |
| Public caller-facing failure contract | `MyPackage.Error.to_map/1` plus `:transport` sanitization | JSON-safe and stable even when internal terms are rich |
| Deep debugging detail | Explicit opt-in debug path | Keeps default logs and telemetry bounded |

The same runtime event may produce all three surfaces, but they should stay intentionally different. Logs explain. Telemetry classifies. Public errors define the contract.

## Canonical Responsibility Split

| Concern | Canonical owner |
| --- | --- |
| Log emission | Direct `Logger` calls in the module that owns the boundary |
| Shared log gating or level comparison | Small helpers in a `Util` module, for example `cond_log/4` |
| Telemetry event definitions | A package-local telemetry or observe module |
| Error taxonomy and constructors | `MyPackage.Error` using Splode |
| Public error serialization | `MyPackage.Error.to_map/1` |
| Sanitization and redaction | A package-local sanitizer with distinct telemetry and transport profiles |

The important constraint is that helpers may centralize policy, but they should not hide core primitives. Contributors should still be able to see `Logger`, `:telemetry`, Splode, and error normalization at the places where those boundaries matter.

## Minimum Package Surface

Not every package needs every helper module, but a package that owns runtime execution or external integration should usually expose these surfaces:

| Surface | Canonical responsibility |
| --- | --- |
| `MyPackage.Error` | Error classes, normalization, retryability, and `to_map/1` |
| `MyPackage.Sanitizer` | Shared `:telemetry` and `:transport` shaping |
| `MyPackage.Observe` or `MyPackage.Telemetry` | Event names, span helpers, and metadata conventions |
| `MyPackage.Util` | Small policy helpers such as conditional logging when they add real value |

The goal is not to force one exact file tree. The goal is to make the policy surfaces obvious, centralized, and easy to review.

## Logging Standards

### Use `Logger` directly

Jido packages should use `Logger` directly. Do not create a package-local logger facade such as `MyPackage.Log`.

If a module logs, it should `require Logger` and use the standard APIs:

- `Logger.debug(fn -> ... end)`
- `Logger.info(fn -> ... end)`
- `Logger.warning(fn -> ... end)`
- `Logger.error(fn -> ... end)`

Use `Logger.log/3` only when the level is dynamic.

```elixir
defmodule MyPackage.Util do
  @moduledoc false

  require Logger

  @spec cond_log(Logger.level(), Logger.level(), Logger.message(), keyword()) :: :ok
  def cond_log(threshold_level, message_level, message, metadata \\ []) do
    valid_levels = Logger.levels()

    cond do
      threshold_level not in valid_levels or message_level not in valid_levels ->
        :ok

      Logger.compare_levels(threshold_level, message_level) in [:lt, :eq] ->
        Logger.log(message_level, message, metadata)

      true ->
        :ok
    end
  end
end
```

Helpers like `cond_log/4` are appropriate because they encode policy. A helper that simply renames `Logger.debug/2` or `Logger.error/2` is not.

### Prefer lazy messages

When a log message involves interpolation, inspection, sanitization, or any non-trivial work, use the lazy function form:

```elixir
Logger.debug(fn ->
  "Running #{inspect(action)} with params=#{inspect(sanitized_params)}"
end)
```

This is the canonical pattern for Jido packages. It keeps log-heavy runtime paths cheaper and makes sanitization work opt-in only when a message will actually be emitted.

### Log at the boundary that owns the outcome

In general:

- Leaf code should return errors, not narrate them repeatedly
- Execution boundaries may log start, retry, validation failure, and terminal outcome
- One failure should usually produce one terminal error log at the owning boundary

Avoid patterns like:

- logging an error in a low-level helper
- wrapping the error and logging it again in the runtime
- serializing it and logging it again at the transport layer

### Recommended level guidance

Use these as the default ecosystem meanings:

- `:debug` for routine start and success flow
- `:info` for retries or notable state transitions that operators may care about
- `:warning` for suspicious but non-terminal conditions, configuration fallback, or caught unexpected non-error control flow
- `:error` for terminal failures and validation failures that change the outcome of the operation

Treat these as defaults, not dogma. The main goal is consistency across packages.

### Logging payload rules

- Do not interpolate full unsanitized params, context, or results into logs
- Sanitize before inspection
- Prefer metadata for identifiers and correlation values
- Avoid high-cardinality values in log metadata unless they are required for debugging
- Never log secrets, tokens, private keys, or raw credentials

---

## Telemetry Standards

### Use stable `[:jido, ...]` namespaces

Telemetry events should use stable, package-appropriate names under the broader Jido namespace. Favor consistency over cleverness.

Typical examples:

- `[:jido, :action, :start]`
- `[:jido, :action, :stop]`
- `[:jido, :agent_server, :signal, :stop]`
- `[:jido, :ai, :tool, :execute, :error]`

Where a span model makes sense, `:telemetry.span/3` is the preferred pattern because it standardizes start/stop/exception emission and duration measurement. For normal handled failures, prefer `:stop` events with `outcome: :error`; reserve `:exception` for truly uncaught failures escaping the span.

### Prefer span-shaped execution helpers

Use one span around the owning execution boundary and return bounded stop metadata:

```elixir
:telemetry.span(
  [:jido, :my_package, :request],
  %{system_time: System.system_time()},
  fn ->
    case MyPackage.Executor.run(input) do
      {:ok, result} ->
        {{:ok, result}, %{outcome: :ok, retry_count: 0}}

      {:error, raw_error} ->
        error = MyPackage.Error.normalize(raw_error)

        {{:error, error},
         %{
           outcome: :error,
           retry_count: 0,
           error_type: MyPackage.Error.type(error),
           retryable?: MyPackage.Error.retryable?(error)
         }}
    end
  end
)
```

That keeps telemetry machine-readable while leaving richer human narration to logs and richer caller contracts to `Error.to_map/1`.

### Use a config-backed default execution log threshold

Packages with execution logging should expose a config-backed default threshold such as:

```elixir
config :my_package,
  default_log_level: :info
```

The canonical precedence is:

1. per-call `opts[:log_level]`
2. `config :my_package, default_log_level: ...`
3. built-in `:info`

This threshold controls package-level execution logging only. It does not replace or reconfigure the application's global Logger backend level, which still acts as the final output filter.

### Emit bounded measurements and metadata

Telemetry should answer questions like:

- How long did the operation take
- Which runtime surface emitted it
- What was the outcome
- Was the operation retried
- Which stable classification applies to the failure

That means default metadata should usually look like:

- package or instance identifier
- module or action name
- outcome class
- retry count
- error class or error type

Default telemetry metadata should not include full params, context, results, stacktraces, or arbitrary user payloads just because they can be sanitized.

If a package needs richer debug-only payloads, make that a deliberate extension and keep it bounded.

### Prefer low-cardinality classifications

Good telemetry metadata:

- `action: MyPackage.Actions.SendEmail`
- `outcome: :error`
- `error_type: :timeout`
- `retryable?: true`

Poor telemetry metadata:

- full raw request body
- unbounded user input
- exception messages with user-specific or request-specific values
- huge nested maps as default metadata

### Bridge from telemetry instead of inventing parallel instrumentation

OpenTelemetry, metrics reporters, and tracing bridges should consume the package's `:telemetry` events. Do not create a parallel instrumentation system that bypasses the telemetry stream unless there is a compelling, documented reason.

---

## Sanitization Standards

### Use explicit profiles

Packages should implement a shared sanitizer with at least two conceptual profiles:

- `:telemetry`
- `:transport`

The exact API shape can vary by package, but the behavior should not.

One straightforward package shape is:

```elixir
defmodule MyPackage.Sanitizer do
  @type profile :: :telemetry | :transport

  @spec sanitize(term(), profile()) :: term()
  def sanitize(value, :telemetry) do
    # redact, truncate, bound depth, and keep values inspect-safe
  end

  def sanitize(value, :transport) do
    # return stable plain data for JSON or tool boundaries
  end
end
```

### Telemetry profile

The telemetry profile should make values safe for logs and events by:

- redacting sensitive keys
- truncating large binaries and large collections
- bounding recursion depth
- converting inspect-hostile values into inspect-safe forms
- summarizing structs when deep expansion would be noisy or unsafe

The telemetry profile is optimized for observability, not fidelity.

### Transport profile

The transport profile should make values safe for JSON or public boundaries by:

- converting structs to plain maps with explicit markers when needed
- converting tuples and other non-JSON terms into stable plain data
- preserving enough structure to remain useful to consumers
- avoiding runtime-specific inspect strings when structured conversion is possible

The transport profile is optimized for stable public shape, not operator readability.

### Keep rich terms internal until the boundary

Inside execution code, native Elixir terms are often the right representation. The package should not eagerly flatten everything at the first sign of an error.

Instead:

1. Keep rich terms while code is still executing internally.
2. Sanitize with the telemetry profile before logging or emitting observability payloads.
3. Sanitize with the transport profile before encoding public errors, tool results, or API responses.

---

## Splode Error Standards

### Every package gets one error module

Each package should expose a single error module, for example `MyPackage.Error`, built on Splode.

That module should own:

- error classes
- package-specific exception structs
- convenience constructors
- retryability helpers when needed
- public serialization via `to_map/1`

### Keep error classes tight and package-relevant

Use a small set of classes such as:

- `:invalid`
- `:execution`
- `:config`
- `:internal`

Concrete exception structs should still be package-specific and end in `Error`.

```elixir
defmodule MyPackage.Error do
  use Splode,
    error_classes: [
      invalid: Invalid,
      execution: Execution,
      config: Config,
      internal: Internal
    ],
    unknown_error: __MODULE__.Internal.UnknownError

  defmodule Invalid do
    use Splode.ErrorClass, class: :invalid
  end

  defmodule Execution do
    use Splode.ErrorClass, class: :execution
  end

  defmodule Config do
    use Splode.ErrorClass, class: :config
  end

  defmodule Internal do
    use Splode.ErrorClass, class: :internal

    defmodule UnknownError do
      defexception [:message, :details]
    end
  end

  defmodule InvalidInputError do
    defexception [:message, :field, :value, :details]
  end

  defmodule ExecutionFailureError do
    defexception [:message, :details]
  end
end
```

The package error module should also own the public adapter:

```elixir
@spec to_map(Exception.t()) :: map()
def to_map(error) do
  %{
    type: type(error),
    message: Exception.message(error),
    details: MyPackage.Sanitizer.sanitize(Map.get(error, :details, %{}), :transport),
    retryable?: retryable?(error)
  }
end
```

The exact helper names can vary, but there should be one obvious place where public error payloads are serialized.

### Normalize raw failures once

If a callback or dependency returns a raw atom, string, map, or foreign exception, normalize it once at the package boundary into a package-local Splode error or exception struct.

Do not make public error shape a caller-controlled option. Canonical behavior should not depend on per-call switches such as alternate normalization modes.

### Public error shape should be stable

Packages should expose a stable public map shape similar to:

```elixir
%{
  type: :execution_error,
  message: "timed out waiting for upstream service",
  details: %{timeout_ms: 1000, upstream: :billing},
  retryable?: true
}
```

The exact field set may grow for package-specific reasons, but these expectations should hold:

- `type` is stable and machine-readable
- `message` is human-readable
- `details` is a JSON-safe map
- `retryable?` is computed centrally and consistently

### Contract changes are not "just refactors"

Changing any of the following should be treated as a contract change, not a cleanup detail:

- documented telemetry event names
- default telemetry metadata fields
- public `Error.to_map/1` fields or meanings
- per-call observability options that downstream code may already rely on

For ecosystem packages, these changes should be called out explicitly in PR descriptions, changelogs, and migration notes when relevant. Even when the main execution API stays the same, observability consumers may still experience a real breaking change.

### Retryability is centralized policy

Retryability should be derived from typed errors and structured details in one place, usually the package error module.

Do not scatter retryability heuristics across:

- action callbacks
- runtime branches
- telemetry emitters
- transport serializers

One package should have one canonical answer for whether a failure is retryable.

---

## Boundary Pattern

This is the canonical Jido boundary flow:

```text
internal code
  -> returns rich success value or rich error term
  -> execution boundary normalizes raw failures into package-local Splode errors
  -> telemetry/logging boundary emits sanitized observability data
  -> transport boundary serializes through Error.to_map/1 and transport sanitization
```

In practice that means:

- internal code can keep native structs and rich details
- logs and telemetry see a redacted, bounded, inspect-safe view
- public consumers see a stable, JSON-safe contract

Those are different needs, and they should stay different.

## Verification Expectations

Canonical policy is not enough unless packages prove they implemented it correctly. At minimum, packages that own these boundaries should test:

- `Error.to_map/1` shape stability, including `type`, `message`, `details`, and `retryable?`
- Sanitizer behavior for both `:telemetry` and `:transport`, including redaction, truncation, and JSON-safe conversion
- Telemetry emission for the package's main execution boundary, including stable event names and bounded metadata
- Raw failure normalization, so foreign errors do not leak directly to logs or public payloads
- Logging policy where it matters most, especially that terminal failures are owned at the correct boundary and do not dump unsanitized payloads

Prefer tests that assert policy and structure over tests that snapshot full log prose or every emitted field. The point is to lock down the contract, not incidental wording.

## Review Checklist

Use this checklist when reviewing observability or error-model pull requests:

- [ ] Does the code use `Logger` directly rather than a package-local wrapper module?
- [ ] Are expensive log messages lazy?
- [ ] Is there a clear owner for terminal failure logging?
- [ ] Are telemetry events stable and low-cardinality?
- [ ] Are logs and telemetry sanitized with the right profile?
- [ ] Does the package expose one canonical Splode-backed error module?
- [ ] Are raw failures normalized once at a boundary?
- [ ] Is public error serialization centralized in `Error.to_map/1` or equivalent?
- [ ] Is retryability derived centrally rather than configured ad hoc?
- [ ] If telemetry metadata or public error shape changed, is that change described as a contract change rather than hidden inside a "cleanup" summary?
- [ ] Are there any duplicated logs, leaked secrets, or unbounded payloads?

## Anti-Patterns

Treat the following as ecosystem anti-patterns:

- package-local logger facades that simply rename `Logger`
- unsanitized `inspect/1` of params, context, or results in logs
- full payloads in default telemetry metadata
- caller-configurable public error shape
- retryability rules scattered across multiple layers
- logging the same failure at every layer of the call stack
- transport payloads that still contain raw structs or non-JSON-safe values

## Next steps

- [Package Quality Standards](/docs/contributors/package-quality-standards) - broader package review and release baseline
- [Telemetry and Observability](/docs/reference/telemetry-and-observability) - runtime-specific event and metric inventory
- [Contributing](/docs/contributors/contributing) - contribution flow and where to start
