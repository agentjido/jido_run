%{
  title: "Package Quality Standards",
  description: "Canonical checklist for contributor-facing package quality, CI, release automation, and documentation standards across the Jido ecosystem.",
  category: :docs,
  legacy_paths: ["/docs/contributors/generic-package-qa"],
  tags: [:docs, :contributors, :quality],
  order: 10,
  menu_label: "Package Quality Standards"
}
---

This page defines the shared quality baseline for all public OSS packages in the Jido ecosystem. These patterns are derived from `req_llm`, `llm_db`, `jido_action`, and `jido_signal`.

Link contributors and automated reviewers here when a package PR needs the canonical checklist for repository structure, `mix quality`, docs coverage, and release readiness.

> Agent handoff: you can point an implementation or review agent at this page and instruct it to apply or verify these package quality standards as the canonical Jido ecosystem baseline.

This page defines the package bar. It is separate from [Package Support Levels](/docs/contributors/package-support-levels), which define maintenance commitment, and separate from the [Ecosystem Atlas](/docs/contributors/ecosystem-atlas), which lists the current public package roster and owners.

> **Note:** The ecosystem is still finishing the move from Elixir `~> 1.17` packages to an Elixir `~> 1.18` contributor baseline. Treat `~> 1.18` as the target bar for new packages and when touching CI or release surfaces on older packages. CI should exercise every released Elixir version line from that baseline forward and include the current Elixir release candidate in an experimental compile lane.

## Fast Path Checklist

- [ ] Package metadata, README, and docs clearly explain what the package is and where it fits in Jido
- [ ] `mix quality` or the equivalent CI quality gate passes
- [ ] CI and release automation exist and are wired correctly
- [ ] Public API, validation, error, and telemetry patterns follow ecosystem conventions
- [ ] Contributor-facing files exist: `CONTRIBUTING.md`, `CHANGELOG.md`, `AGENTS.md`, and license
- [ ] Git hook and release tooling is worktree-safe and does not depend on compile-time auto-install or ephemeral local paths
- [ ] Examples live outside shipped library code when they need extra app wiring
- [ ] Hex/release metadata is ready if the package is being published
- [ ] Any exception to this page is explicit and documented

## How to use this page

- Use it as the default contributor checklist for new packages.
- Use it as the review baseline for pull requests that change package structure, CI, or release automation.
- Use it as the canonical policy page when agents need a stable source of truth for ecosystem package standards.

New packages MUST:

- Target **Elixir `~> 1.18`** as the baseline.
- Follow the conventions in this document unless there is a strong, documented reason not to.

Existing packages should move to that baseline as they are actively maintained. Do not add new package work below the `~> 1.18` bar.

---

## Package Structure

### Required Files

```text
my_package/
├── .github/
│   └── workflows/
│       ├── ci.yml              # Shared Jido CI caller
│       ├── release.yml         # Shared Jido release caller
│       └── review.yml          # Shared Jido advisory PR review caller
├── config/
│   ├── config.exs              # Base configuration
│   ├── dev.exs                 # Development overrides
│   └── test.exs                # Test overrides
├── examples/                   # Optional: runnable examples or companion Mix apps
│   ├── README.md
│   └── my_example/             # Optional separate Mix app when extra deps are needed
├── guides/                     # Optional: Additional documentation
│   └── getting-started.md
├── lib/
│   └── my_package.ex
├── test/
│   ├── support/                # Test helpers, fixtures
│   └── my_package_test.exs
├── .formatter.exs              # Formatter configuration
├── .gitignore
├── AGENTS.md                   # AI agent instructions
├── CHANGELOG.md                # Conventional changelog
├── CONTRIBUTING.md             # Contribution guidelines
├── LICENSE                     # Apache-2.0 or MIT
├── mix.exs
├── mix.lock
├── README.md
└── usage-rules.md              # LLM usage rules (for Cursor/etc)
```

---

### Example Applications and Companion Apps

If an example needs extra dependencies, its own application wiring, or a runnable companion project, do not place that example under `lib/`.

Keep `lib/` reserved for the package's shipped library code. Put runnable examples in a top-level `examples/` directory instead, and use a separate Mix app inside `examples/` when the example needs dependencies or runtime setup that should not leak into the main package.

That means example-only dependencies belong to the example app, not the package's primary runtime dependency graph, unless those dependencies are truly part of the library itself.

#### Examples Checklist

- [ ] Examples that need extra packages do not live under `lib/`.
- [ ] Runnable companion projects live under a top-level `examples/` directory.
- [ ] Separate example Mix apps carry their own dependencies and config when needed.
- [ ] The main package dependency graph stays focused on the library, not demo-only code.

---

## Standard Ecosystem Modules

All ecosystem packages should use shared building blocks consistently.

### Zoi Schemas (Canonical Validation)

Use **Zoi** as the canonical schema + struct validation library.

#### Pattern

```elixir
defmodule MyPackage.Model do
  @moduledoc """
  Brief description of what this model represents.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish(),
              tags: Zoi.array(Zoi.string()) |> Zoi.default([])
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for this struct."
  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc "Builds a new struct from a map, validating with Zoi."
  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs), do: Zoi.parse(@schema, attrs)

  @doc "Like new/1 but raises on validation errors."
  @spec new!(map()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, value} -> value
      {:error, reason} -> raise ArgumentError, "Invalid #{inspect(__MODULE__)}: #{inspect(reason)}"
    end
  end
end
```

#### Zoi Checklist

- [ ] Core structs define a `@schema` using `Zoi.struct(__MODULE__, ...)`.
- [ ] `@type t :: unquote(Zoi.type_spec(@schema))` is present.
- [ ] `@enforce_keys` and `defstruct` are derived via `Zoi.Struct`.
- [ ] `schema/0`, `new/1`, and (optionally) `new!/1` are defined.
- [ ] Validation logic is in the Zoi schema, not scattered across callers.

---

### Module Namespace Convention

Use `Jido.<PackageName>` as the canonical public namespace for Jido ecosystem packages.

In Elixir terms, the package root should be a predictable top-level module such as `Jido.Browser`, `Jido.Signal`, or `Jido.Action`. Extend from that root only when you are describing a real subdomain, for example `Jido.Browser.Session` or `Jido.Browser.Actions.Navigate`.

Avoid inventing an extra branded root like `Jido.BrowserCamelCase` when `Jido.Browser` is the package namespace, and avoid treating a deeper nested module as the package's canonical public entrypoint when the real package root should stay at `Jido.<PackageName>`.

#### Namespace Checklist

- [ ] The primary public package root is `Jido.<PackageName>`.
- [ ] Nested modules extend a real package root, not a one-off naming convention.
- [ ] Contributor docs, examples, and reviews refer to the canonical package root consistently.

---

### Splode Errors (Tight, Project-Relevant Types)

Use **Splode** for error composition and classification. Keep error types **tight and specific to the package**.

#### Pattern

```elixir
defmodule MyPackage.Error do
  @moduledoc """
  Centralized error handling for MyPackage using Splode.

  Error classes are for classification; concrete `...Error` structs are for raising/matching.
  """

  use Splode,
    error_classes: [
      invalid: Invalid,
      execution: Execution,
      config: Config,
      internal: Internal
    ],
    unknown_error: __MODULE__.Internal.UnknownError

  # Error classes – classification only
  defmodule Invalid do
    @moduledoc "Invalid input error class for Splode."
    use Splode.ErrorClass, class: :invalid
  end

  defmodule Execution do
    @moduledoc "Execution error class for Splode."
    use Splode.ErrorClass, class: :execution
  end

  defmodule Config do
    @moduledoc "Configuration error class for Splode."
    use Splode.ErrorClass, class: :config
  end

  defmodule Internal do
    @moduledoc "Internal error class for Splode."
    use Splode.ErrorClass, class: :internal

    defmodule UnknownError do
      @moduledoc false
      defexception [:message, :details]
    end
  end

  # Concrete exception structs – raise/rescue these
  defmodule InvalidInputError do
    @moduledoc "Error for invalid input parameters."
    defexception [:message, :field, :value, :details]
  end

  defmodule ExecutionFailureError do
    @moduledoc "Error for runtime execution failures."
    defexception [:message, :details]
  end

  # Helper functions
  @spec validation_error(String.t(), map()) :: InvalidInputError.t()
  def validation_error(message, details \\ %{}) do
    InvalidInputError.exception(Keyword.merge([message: message], Map.to_list(details)))
  end

  @spec execution_error(String.t(), map()) :: ExecutionFailureError.t()
  def execution_error(message, details \\ %{}) do
    ExecutionFailureError.exception(message: message, details: details)
  end
end
```

#### Splode Checklist

- [ ] Single `MyPackage.Error` module exists.
- [ ] Uses **a small set of error classes** (e.g. `:invalid`, `:execution`, `:config`, `:internal`).
- [ ] Concrete exception structs end in `Error` and are **package-specific**.
- [ ] Helpers like `validation_error/2`, `config_error/2` exist for common errors.
- [ ] External errors are normalized to `MyPackage.Error` types.

---

### Igniter Installs

Use **Igniter** to provide a consistent install experience for packages that need configuration, files, or scaffolding.

#### Pattern

- Expose an installer module (e.g. `MyPackage.Igniter`) following patterns from other Jido packages.
- Document in `README.md`:

````markdown
## Installation via Igniter

```bash
mix igniter.install my_package
```
````

#### Igniter Checklist

- [ ] Non-trivial packages provide an Igniter installer module.
- [ ] Install steps (config, files, migrations) are handled via Igniter.
- [ ] `README.md` includes "Installation via Igniter" section if supported.

---

### Documentation Coverage (MixDoctor / `mix doctor`)

Use **MixDoctor** via **`mix doctor`** to enforce documentation coverage consistently.

#### Doctor Checklist

- [ ] MixDoctor is installed via the `doctor` dev dependency.
- [ ] `mix doctor --raise` runs in `mix quality` and CI.
- [ ] Public APIs are documented; `@moduledoc false` is used intentionally for internals.

---

## mix.exs Configuration

### Standard Project Configuration

```elixir
defmodule MyPackage.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/agentjido/my_package"
  @description "Brief description of the package"

  def project do
    [
      app: :my_package,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Documentation
      name: "My Package",
      description: @description,
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs(),

      # Test Coverage
      test_coverage: [
        tool: ExCoveralls,
        summary: [threshold: 80]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.github": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Runtime
      {:jason, "~> 1.4"},
      {:zoi, "~> 0.14"},
      {:splode, "~> 0.2"},

      # Dev/Test
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test]},
      {:doctor, "~> 0.21", only: :dev, runtime: false},
      {:git_hooks, "~> 0.8", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.9", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      install_hooks: ["git_hooks.install"],
      test: "test --exclude flaky",
      q: ["quality"],
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --min-priority higher",
        "dialyzer",
        "doctor --raise"
      ]
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE", "CHANGELOG.md", "usage-rules.md"],
      maintainers: ["Your Name"],
      licenses: ["Apache-2.0"],
      links: %{
        "Changelog" => "https://hexdocs.pm/my_package/changelog.html",
        "Discord" => "https://jido.run/discord",
        "Documentation" => "https://hexdocs.pm/my_package",
        "GitHub" => @source_url,
        "Website" => "https://jido.run"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md"
      ]
    ]
  end
end
```

When a package uses `git_hooks`, keep installation explicit rather than compile-time or dependency-compile side effects. That keeps contributor worktrees, detached review checkouts, and automation environments usable.

---

## Elixir Version Baseline

The package baseline is the lowest Elixir version line declared in `mix.exs`.

CI MUST test every supported released Elixir version line from that baseline through the latest stable line used by the ecosystem.

CI SHOULD also compile against the current Elixir release candidate in an experimental lane. Experimental lanes are allowed to warn or fail without failing the required CI gate, but their output should be reviewed before releases and dependency upgrades. Use the latest exact Elixir release-candidate tag supported by the toolchain and pair it with a compatible OTP version.

Update the matrix in the same PR that updates the package's shared workflow installation when a new Elixir version line or release candidate becomes available.

---

## GitHub Actions v4 Integration

Standard Jido packages should use the shared v4 workflow platform from [`agentjido/github-actions`](https://github.com/agentjido/github-actions). Add exactly these caller workflows to the package repository:

- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`
- `.github/workflows/review.yml`

Consumer repositories should call only the public `jido-*` workflows. Do not add package-local copies of the reusable workflows or old internal workflow files such as `elixir-ci.yml`, `elixir-release.yml`, `elixir-quality.yml`, `elixir-test.yml`, `jido-policy.yml`, or `jido-sync.yml`.

### CI Caller

```yaml
name: CI

on:
  pull_request:
  merge_group:
  push:
    branches:
      - main

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  actions: read
  contents: read

jobs:
  ci:
    name: CI
    uses: agentjido/github-actions/.github/workflows/jido-ci.yml@v4
    secrets: inherit
    with:
      otp_versions: '["27", "28"]'
      elixir_versions: '["1.18", "1.19"]'
      # Optional: keep this lane on the latest exact Elixir release-candidate tag.
      experimental_compile_elixir_versions: '["<latest-elixir-rc-tag>"]'
      experimental_compile_otp_versions: '["<matching-otp-version>"]'
      experimental_compile_otp_name: "<otp-major>"
      docs_command: mix docs -f html
      test_command: mix test
```

Packages that are not yet strict-Credo clean may temporarily pass exactly one `credo_command` override under `with:`. Keep the override package-specific and remove it when the package reaches the strict baseline.

```yaml
      credo_command: mix credo --min-priority higher
```

### Release Caller

```yaml
name: Release

on:
  push:
    tags:
      - "v*"
  workflow_dispatch:
    inputs:
      operation:
        description: "Release operation: auto, prepare, or publish"
        required: false
        type: choice
        default: auto
        options:
          - auto
          - prepare
          - publish
      tag_name:
        description: "Optional v-prefixed tag for publish simulation"
        required: false
        type: string
        default: ""
      dry_run:
        description: "Dry run (no git push, no tag, no GitHub release, no Hex publish)"
        required: false
        type: boolean
        default: false
      hex_dry_run:
        description: "Hex dry run only (run all git/release steps, but skip actual Hex publish)"
        required: false
        type: boolean
        default: false
      skip_tests:
        description: "Skip tests before release"
        required: false
        type: boolean
        default: false
      version_override:
        description: "Optional bare SemVer override (for example 1.2.3, not v1.2.3)"
        required: false
        type: string
        default: ""

permissions:
  actions: read
  contents: write

jobs:
  release:
    name: Release
    uses: agentjido/github-actions/.github/workflows/jido-release.yml@v4
    with:
      operation: ${{ inputs.operation || 'auto' }}
      tag_name: ${{ inputs.tag_name || '' }}
      dry_run: ${{ inputs.dry_run || false }}
      hex_dry_run: ${{ inputs.hex_dry_run || false }}
      skip_tests: ${{ inputs.skip_tests || false }}
      version_override: ${{ inputs.version_override || '' }}
    secrets: inherit
```

Use `operation: auto` for normal operation: branch dispatch resolves to release preparation, and pushed `v*` tags resolve to Hex publishing. Real releases require a `HEX_API_KEY` secret for Hex publishing. Non-dry-run release preparation also requires a `RELEASE_TOKEN` secret so release commits and tags can trigger the publish workflow reliably.

### Review Caller

```yaml
name: Jido Review

on:
  pull_request:
    branches:
      - main

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

permissions:
  actions: read
  contents: read
  issues: write
  pull-requests: write

jobs:
  review:
    name: Jido Review
    uses: agentjido/github-actions/.github/workflows/jido-review.yml@v4
```

The review lane is advisory. Keep it separate from CI and do not add write-back, dependency submission, Sobelow, REUSE, or repo-local review configuration unless a future shared workflow release explicitly requires it.

Pin shared workflows to `@v4` for compatible automatic updates, to an exact tag such as `@v4.0.0` for fixed reproducibility, or to a commit SHA for maximum reproducibility. Do not use `@main` for stable package workflows.

---

## Quality Checks

### The `mix quality` Alias

All packages MUST define a `quality` alias that runs:

```elixir
quality: [
  "format --check-formatted",      # Code formatting
  "compile --warnings-as-errors",  # No compiler warnings
  "credo --min-priority higher",   # Linting
  "dialyzer",                      # Type checking
  "doctor --raise"                 # Documentation coverage
]
```

### Running Quality Checks

```bash
mix quality   # or mix q

# Individual checks
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --min-priority higher
mix dialyzer
mix doctor --raise
```

---

## Testing Standards

### Coverage Requirements

- **Minimum threshold**: 80% line coverage
- **Tool**: ExCoveralls
- **CI enforcement**: Coverage check in GitHub Actions

### Test Configuration

```elixir
test_coverage: [
  tool: ExCoveralls,
  summary: [threshold: 80],
  export: "cov",
  ignore_modules: [~r/^MyPackageTest\./]
]
```

### Running Tests

```bash
mix test                    # Run tests (excludes flaky)
mix coveralls               # Run with coverage
mix coveralls.html          # Generate HTML report
mix test --include flaky    # Include all tests
```

### Test Organization

```text
test/
├── support/
│   ├── fixtures.ex         # Test fixtures
│   ├── helpers.ex          # Test helper functions
│   └── case.ex             # Custom ExUnit case modules
├── my_package_test.exs     # High-level API tests
└── my_package/
    ├── module_a_test.exs   # Unit tests for ModuleA
    └── module_b_test.exs   # Unit tests for ModuleB
```

---

## Conventional Commits

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `style` | Formatting, no code change |
| `refactor` | Code change, no fix or feature |
| `perf` | Performance improvement |
| `test` | Adding/fixing tests |
| `chore` | Maintenance, deps, tooling |
| `ci` | CI/CD changes |

**Examples:**

```bash
git commit -m "feat(schema): add validation for email fields"
git commit -m "fix: resolve timeout in async operations"
git commit -m "feat!: breaking change to API"
```

Do not modify `CHANGELOG.md` in normal PRs. Release notes are generated from Git history during release, so keep changes focused on proper Conventional Commits.

---

## Git Hooks and Worktree Safety

Git hooks are useful, but they must not make a repository hostile to secondary worktrees, detached PR review checkouts, or automation environments.

The canonical Jido policy is:

- disable `git_hooks` auto-install in normal environments
- install hooks explicitly from the primary repository checkout
- ensure custom hook scripts resolve the repository root dynamically
- never bake a temporary worktree path into committed or generated hook scripts
- prefer graceful degradation over breaking compile or commit flow when `.git` is unavailable

### Canonical Pattern

```elixir
# config/dev.exs and config/test.exs
import Config

config :git_hooks, auto_install: false
```

```elixir
defp aliases do
  [
    setup: ["deps.get"],
    install_hooks: ["git_hooks.install"]
  ]
end
```

If a package needs custom hook scripts, they should derive the repository root at runtime, for example with `git rev-parse --show-toplevel`, instead of hard-coding an absolute local path.

### Worktree Checklist

- [ ] `git_hooks` auto-install is disabled by default.
- [ ] Hook installation is an explicit maintainer step such as `mix install_hooks`.
- [ ] Hook scripts do not embed temporary or machine-specific absolute paths.
- [ ] Compile and commit flows still work from a secondary worktree or fail with a clear, bounded message.

---

## Release Workflow

Releases in the Jido ecosystem should be GitOps-driven and reproducible from the repository, not dependent on undocumented local release steps.

- Keep release automation in version-controlled GitHub Actions workflows.
- Use `git_ops` to manage versioning, release notes, and release preparation from Git history.
- Treat release workflow configuration as required package infrastructure, not optional polish.

### Release Checklist

- [ ] `.github/workflows/release.yml` exists and is reviewed.
- [ ] Release notes and version metadata are derived from repository state.
- [ ] Package publishing happens from CI, not from ad hoc local commands.
- [ ] The release path is documented for maintainers in `README.md`, `CONTRIBUTING.md`, or both.

---

## Documentation Standards

### Module Documentation

```elixir
defmodule MyPackage.Core do
  @moduledoc """
  Core functionality for MyPackage.

  ## Overview

  Brief description of what this module does.

  ## Examples

      iex> MyPackage.Core.do_thing(:input)
      {:ok, :result}
  """

  @doc """
  Does a specific thing.

  ## Parameters

    * `input` - Description of input
    * `opts` - Keyword list of options
      * `:timeout` - Timeout in milliseconds (default: 5000)

  ## Returns

    * `{:ok, result}` - On success
    * `{:error, reason}` - On failure
  """
  @spec do_thing(atom(), keyword()) :: {:ok, term()} | {:error, term()}
  def do_thing(input, opts \\ [])
end
```

### Required Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | Overview, installation (incl. Igniter if relevant), quick start |
| `CHANGELOG.md` | Generated version history maintained by release automation |
| `CONTRIBUTING.md` | How to contribute |
| `AGENTS.md` | AI agent instructions |
| `usage-rules.md` | LLM usage rules |
| `LICENSE` | License text |

---

## Gitignore Configuration

### Standard `.gitignore`

```text
# Build artifacts
/_build/
/deps/

# Coverage
/cover/

# Dialyzer PLT files - do NOT commit these
*.plt
*.plt.hash

# Editor/IDE
.elixir_ls/
.vscode/
*.swp
*.swo

# Generated files
/doc/
erl_crash.dump

# OS
.DS_Store
Thumbs.db
```

---

## Formatter Configuration

### Standard `.formatter.exs`

```elixir
[
  inputs: [
    "{mix,.formatter,.credo}.exs",
    "{config,lib,test}/**/*.{ex,exs}"
  ],
  line_length: 120
]
```

---

## Dependencies

### Standard Dev/Test Dependencies

```elixir
# Linting & Static Analysis
{:credo, "~> 1.7", only: [:dev, :test], runtime: false},
{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},

# Documentation
{:ex_doc, "~> 0.31", only: :dev, runtime: false},
{:doctor, "~> 0.21", only: :dev, runtime: false},

# Test Coverage
{:excoveralls, "~> 0.18", only: [:dev, :test]},

# Git Tooling
{:git_hooks, "~> 0.8", only: [:dev, :test], runtime: false},
{:git_ops, "~> 2.9", only: :dev, runtime: false},

# Optional
{:stream_data, "~> 1.0", only: [:dev, :test]},              # Property testing
{:mimic, "~> 2.0", only: :test}                             # Mocking
```

### Common Runtime Dependencies

```elixir
{:zoi, "~> 0.14"}              # Canonical schema validation
{:splode, "~> 0.2"}            # Canonical error composition
{:jason, "~> 1.4"}             # JSON
{:uniq, "~> 0.6"}              # UUID generation
```

### Deprecated Dependencies (Replace with Zoi)

The following should be migrated to Zoi when encountered in existing code:

- `nimble_options` → Use Zoi schemas for option validation
- `typedstruct` / `typed_struct` → Use `Zoi.struct/3` pattern (see above)

### IMPORTANT: No jido_dep Helper Functions

**DO NOT use `jido_dep/4` or similar helper functions in mix.exs files.** This pattern causes dependency resolution conflicts and should be removed when encountered.

Instead, use plain direct dependencies:

```elixir
defp deps do
  [
    # Jido ecosystem - use Hex versions directly
    {{mix_dep:jido}},
    {{mix_dep:jido_action}},
    {{mix_dep:jido_signal}},
    {{mix_dep:req_llm}},

    # Runtime deps
    {:jason, "~> 1.4"},
    {:zoi, "~> 0.16"},
    {:splode, "~> 0.3.0"},

    # Dev/Test
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    # ...
  ]
end
```

This approach:
- Works reliably for both workspace and external developers
- Avoids dependency conflict errors from `override: true` clashes
- Simplifies mix.exs files
- Works correctly with `mix hex.publish`

---

## Checklist for New Packages

### Before First Commit

- [ ] `mix.exs` follows standard configuration (Elixir `~> 1.18`).
- [ ] `quality` alias defined (includes `doctor --raise`).
- [ ] Git hook setup is explicit and worktree-safe.
- [ ] `.formatter.exs` configured.
- [ ] `.gitignore` includes `_build/`, `deps/`, `cover/`, `*.plt`, `.elixir_ls/`.
- [ ] `README.md` with installation (Hex + Igniter if applicable) and quick start.
- [ ] `LICENSE` file present.
- [ ] `AGENTS.md` for AI agent instructions.
- [ ] Examples with extra dependencies live in top-level `examples/`, not `lib/`.
- [ ] Public modules are rooted under `Jido.<PackageName>`.
- [ ] `MyPackage.Error` module using Splode is defined (for non-trivial libs).
- [ ] Core structs use Zoi schema pattern.

### Before First Release

- [ ] `mix quality` passes.
- [ ] `mix test` passes with at least 80% coverage.
- [ ] `mix docs` builds without errors.
- [ ] `mix doctor --raise` passes.
- [ ] Release notes are covered by Conventional Commits; `CHANGELOG.md` is generated during release.
- [ ] `CONTRIBUTING.md` describes workflow.
- [ ] GitHub Actions v4 CI configured with required released Elixir version lines and the current RC experimental lane.
- [ ] Release workflow configured with `jido-release.yml@v4`.
- [ ] Advisory review workflow configured with `jido-review.yml@v4`.
- [ ] Hex.pm package metadata complete.
- [ ] Igniter installer documented (if provided).

### Ongoing Maintenance

- [ ] All PRs pass CI.
- [ ] Coverage maintained above threshold.
- [ ] Documentation coverage maintained (doctor).
- [ ] Conventional commits enforced.
- [ ] Hook scripts and git tooling still work from contributor worktrees.
- [ ] `CHANGELOG.md` remains release-automation output, not a normal PR edit target.
- [ ] Dependencies kept up to date.
- [ ] Security advisories addressed promptly.

---

## Quick Reference

```bash
mix setup              # Setup dev environment
mix install_hooks      # Explicitly install git hooks from the primary checkout
mix quality            # Run all quality checks
mix coveralls.html     # Run tests with coverage report
mix docs               # Generate documentation
mix doctor --raise     # Check documentation coverage
mix git_ops.check_message  # Check commit message format
mix git_ops.release    # Create a release
git push && git push --tags
```

## Next Steps

- [Contributors](/docs/contributors) - return to the contributor handbook
- [Package Support Levels](/docs/contributors/package-support-levels) - pair quality gates with the right support commitment
- [Ecosystem Atlas](/docs/contributors/ecosystem-atlas) - see package ownership and current release state
