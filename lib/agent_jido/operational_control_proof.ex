defmodule AgentJido.OperationalControlProof do
  @moduledoc """
  Quarterly audit of the operational-control proof (jido-e12-t49).

  The operational-control proof lives in `specs/proof.md` — the "Control Proof
  Fields" section, whose seven-field schema is enforced by the sibling
  jido-e12-t38 proof gate (every claim names its control point, configuration,
  test, limitation, owner, version, and validation date) and the jido-e12-t44
  release gate (the version basis must be a released, supported package). Each
  claim's **validation date** records when its owner last verified it.

  This module turns that proof into a **quarterly audit queue** — the
  operational-control counterpart of the 90-day critical review queue for
  onboarding/operations pages (`AgentJido.Pages.critical_review_queue/1`,
  jido-e12-t15). When a claim's validation date drifts past a quarter (default
  90 days) — or is missing or malformed — the claim becomes assigned work
  attributed to its owner, who must re-verify the four dimensions named in the
  task acceptance ("Owners verify current behavior, versions, limits, and
  links"):

    * **behavior** — control point and configuration describe current behavior.
    * **versions** — the version basis is carried by a released, supported
      package (the jido-e12-t44 release gate).
    * **limits** — the limitation records the claim's current boundary.
    * **links** — every `test/**/*.exs` reference in the test field resolves to a
      real file (the jido-e12-t38 proof gate).

  `audit_queue/1` returns the stale claims as audit entries; `stale?/2` is the
  freshness predicate; `verification/1` reports the four dimensions for any
  claim. The queue is deterministic under a `:today` opt.
  """

  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.SupportLevel

  @proof_path Path.expand("../../specs/proof.md", __DIR__)
  @repo_root Path.expand("../../", __DIR__)

  # One quarter. Mirrors the 90-day critical review window (jido-e12-t15) and
  # the Example staleness query (jido-e08-t15).
  @default_audit_days 90

  # Display label in proof.md -> internal field key. Order is the contract
  # (mirrors the jido-e12-t38 proof gate).
  @field_labels [
    {"Control point:", :control_point},
    {"Configuration:", :configuration},
    {"Test:", :test},
    {"Limitation:", :limitation},
    {"Owner:", :owner},
    {"Version:", :version},
    {"Validation date:", :validation_date}
  ]

  @type claim :: %{
          claim: String.t(),
          control_point: String.t(),
          configuration: String.t(),
          test: String.t(),
          limitation: String.t(),
          owner: String.t(),
          version: String.t(),
          validation_date: String.t()
        }

  @type version_basis_entry :: %{package: String.t(), released: boolean(), approved: boolean()}
  @type test_link :: {path :: String.t(), resolved: boolean()}
  @type dimension :: :behavior | :versions | :limits | :links

  @type verification :: %{
          behavior: boolean(),
          versions: boolean(),
          limits: boolean(),
          links: boolean(),
          version_basis: [version_basis_entry()],
          test_links: [test_link()]
        }

  @type audit_entry :: %{
          claim: claim(),
          owner: String.t(),
          validation_date: String.t() | nil,
          days_since_validation: non_neg_integer() | nil,
          verification: verification()
        }

  @doc """
  Returns the default quarterly audit window in days (one quarter).
  """
  @spec default_audit_days() :: pos_integer()
  def default_audit_days, do: @default_audit_days

  @doc """
  Reads `specs/proof.md` and returns every operational-control claim with its
  seven proof fields. An empty list means the Control Proof Fields section is
  missing or records no claims.
  """
  @spec claims() :: [claim()]
  def claims, do: claims_from(File.read!(@proof_path))

  @doc """
  Returns the operational-control claims parsed from the given proof text.

  Pure helper exposed so the audit (and its tests) can run against synthetic
  proof input without touching the file.
  """
  @spec claims_from(String.t()) :: [claim()]
  def claims_from(proof) when is_binary(proof) do
    section = control_proof_section(proof) || ""

    section
    |> String.split(~r/^###\s+/m)
    |> Enum.drop(1)
    |> Enum.map(fn chunk ->
      case String.split(chunk, "\n", parts: 2) do
        [head] -> {String.trim(head), ""}
        [head, rest] -> {String.trim(head), rest}
      end
    end)
    |> Enum.reject(fn {claim, _} -> claim == "" end)
    |> Enum.map(fn {claim, body} -> to_claim(claim, body) end)
  end

  @doc """
  Returns `true` when the claim's validation date is missing, malformed, or
  older than the quarterly audit window — i.e. the claim is due for owner
  re-verification this quarter.

  ## Options

    * `:audit_after_days` — audit window in days
      (default `#{inspect(@default_audit_days)}`).
    * `:today` — a `Date.t()` to evaluate against (defaults to `Date.utc_today/0`),
      so the check is deterministic under test.
  """
  @spec stale?(claim(), keyword()) :: boolean()
  def stale?(%{} = claim, opts \\ []) when is_list(opts) do
    audit_after_days = Keyword.get(opts, :audit_after_days, @default_audit_days)
    today = Keyword.get(opts, :today, Date.utc_today())

    case Date.from_iso8601(to_string(claim[:validation_date])) do
      {:ok, validated_on} -> Date.diff(today, validated_on) > audit_after_days
      {:error, _} -> true
    end
  end

  @doc """
  Reports the four owner-verification dimensions for a claim — the
  jido-e12-t49 acceptance: "Owners verify current behavior, versions, limits,
  and links."

    * `:behavior` — control point and configuration are both recorded.
    * `:versions` — the version basis names at least one registered package and
      every named package is released and supported (the jido-e12-t44 gate).
    * `:limits` — the limitation is recorded.
    * `:links` — the test field references at least one `*.exs` file and every
      reference resolves to a real file (the jido-e12-t38 gate).

  `version_basis` and `test_links` carry the actionable detail, so an owner
  re-verifying the claim knows exactly what to check.
  """
  @spec verification(claim()) :: verification()
  def verification(%{} = claim) do
    version_basis = version_basis(claim[:version] || "")
    test_links = test_links(claim[:test] || "")

    %{
      behavior: present?(claim[:control_point]) and present?(claim[:configuration]),
      versions: versions_ok?(version_basis),
      limits: present?(claim[:limitation]),
      links: links_ok?(test_links),
      version_basis: version_basis,
      test_links: test_links
    }
  end

  @doc """
  Returns the quarterly audit queue — every operational-control claim whose
  validation date falls outside the audit window (or is missing/malformed),
  each attributed to its owner as assigned re-verification work.

  Each entry carries the claim, its owner, the recorded validation date, days
  since validation (`nil` when never validated), and the four-dimension
  `verification/1` report so the owner sees what to re-check.

  ## Options

    * `:audit_after_days` — audit window in days
      (default `#{inspect(@default_audit_days)}`).
    * `:today` — a `Date.t()` to evaluate against (defaults to `Date.utc_today/0`),
      so the queue is deterministic under test.
    * `:claims` — an explicit claim list to audit (defaults to `claims/0`),
      so the queue is testable against synthetic proof input.
  """
  @spec audit_queue(keyword()) :: [audit_entry()]
  def audit_queue(opts \\ []) when is_list(opts) do
    audit_after_days = Keyword.get(opts, :audit_after_days, @default_audit_days)
    today = Keyword.get(opts, :today, Date.utc_today())
    claims = Keyword.get(opts, :claims) || claims()

    claims
    |> Enum.filter(&stale?(&1, audit_after_days: audit_after_days, today: today))
    |> Enum.map(fn claim ->
      %{
        claim: claim,
        owner: to_string(claim[:owner] || ""),
        validation_date: normalize_date(claim[:validation_date]),
        days_since_validation: days_since_validation(claim[:validation_date], today),
        verification: verification(claim)
      }
    end)
  end

  # --- parsing helpers ---

  defp control_proof_section(proof) do
    case Regex.run(~r/## Control Proof Fields.*?(?=\n## |\z)/s, proof) do
      [section | _] -> section
      nil -> nil
    end
  end

  defp to_claim(claim, body) do
    base = %{
      claim: claim,
      control_point: "",
      configuration: "",
      test: "",
      limitation: "",
      owner: "",
      version: "",
      validation_date: ""
    }

    Enum.reduce(@field_labels, base, fn {label, key}, acc ->
      Map.put(acc, key, field_value(body, label) || "")
    end)
  end

  defp field_value(block, label) do
    # Each field is written as a sentence ending in a period. Strip the single
    # trailing terminator so values are clean — critically so the validation
    # date parses as an ISO date ("2026-07-24", not "2026-07-24."). Presence,
    # version-basis, and link checks are unaffected.
    case Regex.run(~r/- \*\*#{Regex.escape(label)}\*\*\s*(.+)/, block) do
      [_, value] -> value |> String.trim() |> String.replace_suffix(".", "")
      nil -> nil
    end
  end

  # --- verification helpers ---

  # The registry packages whose id appears as a whole word in a Version field —
  # i.e. the packages the claim's version basis depends on. `\b` treats `_` as a
  # word character, so `jido` does not match inside `jido_ai` or `jido_signal`.
  # Mirrors the jido-e12-t44 release gate.
  defp version_basis(version_field) do
    Ecosystem.all_packages()
    |> Enum.filter(fn pkg ->
      version_field =~ ~r/\b#{Regex.escape(pkg.id)}\b/
    end)
    |> Enum.map(fn pkg ->
      %{
        package: pkg.id,
        released: Ecosystem.released?(pkg),
        approved: SupportLevel.approved?(pkg.support_level)
      }
    end)
  end

  defp versions_ok?([]), do: false

  defp versions_ok?(basis) do
    # Every named package must be released and supported, which (for a non-empty
    # basis) also satisfies the jido-e12-t44 "carried by at least one approved
    # package" requirement.
    Enum.all?(basis, fn entry -> entry.released and entry.approved end)
  end

  defp test_links(test_field) do
    ~r{`([^`]+\.exs)`}
    |> Regex.scan(test_field, capture: :all_but_first)
    |> Enum.map(fn [path | _] ->
      {path, File.regular?(Path.expand(path, @repo_root))}
    end)
  end

  defp links_ok?([]), do: false

  defp links_ok?(links) do
    Enum.all?(links, fn {_, resolved?} -> resolved? end)
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false

  # --- date helpers ---

  defp normalize_date(""), do: nil
  defp normalize_date(value) when is_binary(value), do: value
  defp normalize_date(_), do: nil

  defp days_since_validation(validation_date, today) do
    case Date.from_iso8601(to_string(validation_date)) do
      {:ok, validated_on} -> max(0, Date.diff(today, validated_on))
      {:error, _} -> nil
    end
  end
end
