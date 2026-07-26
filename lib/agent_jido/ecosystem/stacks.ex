defmodule AgentJido.Ecosystem.Stacks do
  @moduledoc """
  The three recommended starting stacks and their explicit package ranges
  (`jido-e09-t36`).

  The home page names three stacks — Core, AI, and Operate — and each ships a
  copyable mix.exs dependency block (`jido-e09-t08`). This module is the single
  source of truth for which packages belong to which stack and for the explicit
  supported range each package carries, so the home dependency blocks and the
  Ecosystem compatibility matrix never drift apart. The package composition
  here is kept in lockstep with `AgentJido.Demos.StackExamples`, whose runnable
  examples exercise the same packages (parity is asserted in the test suite).

  Acceptance condition (E09-T36): *supported package ranges are explicit.*
  Each package's range is derived from the authoritative ecosystem registry:
  a package published to Hex pins to its published MAJOR (`~> X.0`) so the
  resolver picks a compatible within-major set, and a package not yet on Hex
  falls back to its public GitHub repo. Both forms resolve on `mix deps.get`,
  which is the install bar. Major pins are used because the registry records
  each package's version independently, so exact per-package pins can be
  mutually incompatible.
  """

  alias AgentJido.Ecosystem

  @stacks [
    %{
      key: "core",
      name: "Core",
      purpose: "The runtime every Jido system runs on — agents, typed Actions, and Signals.",
      packages: [
        %{name: "jido", role: "Agent state, the supervised AgentServer, and Directives."},
        %{name: "jido_action", role: "Typed, validated commands and tools an agent runs."},
        %{name: "jido_signal", role: "CloudEvents messages agents send, route, and replay."}
      ]
    },
    %{
      key: "ai",
      name: "AI",
      purpose: "Add LLM-backed agents, provider choice, and model metadata when you need AI.",
      packages: [
        %{name: "jido_ai", role: "Reasoning strategies, tool use, and accuracy over LLM calls."},
        %{name: "req_llm", role: "Model requests across Anthropic, OpenAI, Google, and more."},
        %{name: "llm_db", role: "Offline model metadata and capability catalog."}
      ]
    },
    %{
      key: "operate",
      name: "Operate",
      purpose: "Ship to production — observability, messaging, and framework integration.",
      packages: [
        %{name: "ash_jido", role: "Turns Ash resources into typed Jido Actions."},
        %{name: "jido_messaging", role: "Chat channels (Slack, Discord, Telegram) for agents."},
        %{name: "jido_otel", role: "Exports Jido telemetry as OpenTelemetry spans."}
      ]
    }
  ]

  @type source :: :hex | :github | :unknown

  @type stack :: %{
          key: String.t(),
          name: String.t(),
          purpose: String.t(),
          packages: [package_spec()]
        }

  @type package_spec :: %{name: String.t(), role: String.t()}

  @type matrix_stack :: %{
          key: String.t(),
          name: String.t(),
          purpose: String.t(),
          packages: [matrix_row()]
        }

  @type matrix_row :: %{
          name: String.t(),
          role: String.t(),
          range: String.t() | nil,
          source: source(),
          source_label: String.t(),
          support_level: SupportLevel.t(),
          path: String.t()
        }

  @doc "The three recommended starting stacks in display order."
  @spec stacks() :: [stack()]
  def stacks, do: @stacks

  @doc "Returns the stack definition for `key`, or `nil`."
  @spec get_stack(String.t()) :: stack() | nil
  def get_stack(key) when is_binary(key), do: Enum.find(@stacks, &(&1.key == key))

  @doc "Returns the stack definition for `key`, or raises if unknown."
  @spec get_stack!(String.t()) :: stack()
  def get_stack!(key) when is_binary(key) do
    get_stack(key) ||
      raise "unknown stack key=#{inspect(key)} (expected one of #{inspect(Enum.map(@stacks, & &1.key))})"
  end

  @doc """
  Enriched per-stack rows for the Ecosystem compatibility matrix.

  Each row carries the stack identity plus one entry per package with its
  explicit supported range, source, and public support level — all derived from
  the registry so the matrix never drifts from the home dependency blocks.
  """
  @spec matrix() :: [matrix_stack()]
  def matrix do
    Enum.map(@stacks, fn stack ->
      %{
        key: stack.key,
        name: stack.name,
        purpose: stack.purpose,
        packages: Enum.map(stack.packages, &to_matrix_row/1)
      }
    end)
  end

  @doc """
  The copyable mix.exs `deps/0` snippet for a set of stack packages
  (`jido-e09-t08`).

  Accepts either package spec maps (`%{name: name}`) or bare package name
  strings. Returns the full `defp deps do ... end` block, or `nil` when no
  package resolves to an installable line.
  """
  @spec dependency_block([package_spec() | String.t()]) :: String.t() | nil
  def dependency_block(packages) when is_list(packages) do
    lines =
      packages
      |> Enum.map(&package_name/1)
      |> Enum.map(&dependency_line/1)
      |> Enum.reject(&is_nil/1)

    if lines == [] do
      nil
    else
      body = Enum.map_join(lines, ",\n", &"      #{&1}")
      "defp deps do\n  [\n#{body}\n  ]\nend"
    end
  end

  @doc """
  The mix.exs dependency line for a stack package.

  Published packages pin to their Hex major (`~> X.0`); unreleased packages
  fall back to their public GitHub repo. Returns `nil` when the package is
  unknown or carries neither a published version nor a GitHub repo.
  """
  @spec dependency_line(String.t()) :: String.t() | nil
  def dependency_line(name) when is_binary(name) do
    case package_compat(name) do
      %{dependency_line: line} -> line
    end
  end

  @doc """
  The explicit supported range a stack promises for a package.

  Mirrors the dependency line's resolution: a Hex major requirement
  (`~> X.0`) for published packages, or a `github: org/repo` pin for
  unreleased ones. This is the supported package range made explicit
  (`jido-e09-t36`).
  """
  @spec supported_range(String.t()) :: String.t() | nil
  def supported_range(name) when is_binary(name) do
    case package_compat(name) do
      %{range: range} -> range
    end
  end

  @doc """
  Where a package's supported range comes from: `:hex` when published,
  `:github` when pinned to a repo, or `:unknown`.
  """
  @spec source(String.t()) :: source()
  def source(name) when is_binary(name) do
    case package_compat(name) do
      %{source: source} -> source
    end
  end

  @doc "Human-readable label for a package source."
  @spec source_label(source()) :: String.t()
  def source_label(:hex), do: "Hex"
  def source_label(:github), do: "GitHub · unreleased"
  def source_label(:unknown), do: "Unavailable"

  defp to_matrix_row(%{name: name} = spec) do
    compat = package_compat(name)

    Map.merge(spec, %{
      range: compat.range,
      source: compat.source,
      source_label: source_label(compat.source),
      support_level: compat.support_level,
      path: "/ecosystem/#{name}"
    })
  end

  defp package_compat(name) do
    pkg = Ecosystem.get_public_package(name)
    major = pkg && published_hex_major(pkg.hex_status)
    repo = pkg && github_repo_path(pkg)

    {range, dependency_line, source} =
      cond do
        major != nil ->
          {"~> #{major}.0", "{:#{name}, \"~> #{major}.0\"}", :hex}

        repo != nil ->
          {"github: \"#{repo}\"", "{:#{name}, github: \"#{repo}\"}", :github}

        true ->
          {nil, nil, :unknown}
      end

    %{
      range: range,
      dependency_line: dependency_line,
      source: source,
      support_level: support_level(pkg)
    }
  end

  defp support_level(%{support_level: level}) when level in [:stable, :beta, :experimental],
    do: level

  defp support_level(_other), do: :experimental

  defp package_name(%{name: name}), do: name
  defp package_name(name) when is_binary(name), do: name

  # The leading major of a recorded published Hex version, or nil when the
  # package is not published (hex_status is "unreleased" or non-version text).
  defp published_hex_major(hex_status) when is_binary(hex_status) do
    case Regex.run(~r/^(\d+)\./, hex_status) do
      [_, major] -> major
      _other -> nil
    end
  end

  defp published_hex_major(_hex_status), do: nil

  defp github_repo_path(%{github_org: org, github_repo: repo})
       when is_binary(org) and org != "" and is_binary(repo) and repo != "",
       do: "#{org}/#{repo}"

  defp github_repo_path(_package), do: nil
end
