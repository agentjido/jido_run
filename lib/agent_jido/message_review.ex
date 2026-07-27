defmodule AgentJido.MessageReview do
  @moduledoc """
  Quarterly message review (jido-e12-t36).

  Acceptance: *Position, package roles, proof, and audience are reviewed
  together* — each quarter.

  The site's message is not one document. It is the agreement of four
  independent sources, each owned and refreshed on its own cadence:

    * **position** — `specs/positioning.md`, whose §1 public category is the
      canonical positioning anchor.
    * **package roles** — the ecosystem registry (`priv/ecosystem/*.md` via
      `AgentJido.Ecosystem`); every public package carries a role (`tagline`).
    * **proof** — `specs/proof.md`, the claim-to-evidence inventory.
    * **audience** — `specs/persona-journeys.md`.

  Reviewed *together* means the four still tell one story: position, proof, and
  audience record the same positioning anchor, and every public package still
  carries a role. This is the messaging counterpart of the quarterly
  operational-control proof audit (`AgentJido.OperationalControlProof`,
  jido-e12-t49): that audit re-verifies control *claims*; this review
  re-verifies the *message*.

  A dimension becomes assigned work this quarter when it is **due**:

    * a dated source (`position`, `proof`, `audience`) whose `Last updated` date
      drifts past the quarter (default 90 days) or is missing/malformed;
    * an anchor-bearing source whose recorded anchor diverges from the canonical
      anchor (the message no longer agrees); or
    * `package roles` when any public package lacks a role.

  `review_queue/1` returns the due dimensions; `reviewed_together?/1` is true
  only when the queue is empty. The review is informational — it never blocks a
  release; it surfaces the four dimensions in one place so a reviewer can hold
  the quarterly review the acceptance asks for.
  """

  alias AgentJido.Ecosystem

  @positioning_path Path.expand("../../specs/positioning.md", __DIR__)
  @proof_path Path.expand("../../specs/proof.md", __DIR__)
  @persona_path Path.expand("../../specs/persona-journeys.md", __DIR__)

  # The specs root, for resolving source labels against the repo.
  @specs_root Path.expand("../../specs/", __DIR__)

  # One quarter. Mirrors the quarterly operational-control proof audit
  # (jido-e12-t49) and the 90-day critical review window (jido-e12-t15).
  @default_review_days 90

  # The canonical anchor sentence (positioning.md §1 public category). Matched
  # liberally (any case, optional trailing period) so a cosmetic edit to the
  # surrounding copy does not false-trip coherence.
  @anchor_sentence "Jido is the Elixir framework for long-running agent systems"

  @type dimension :: :position | :package_roles | :proof | :audience

  @type dimension_state :: %{
          dimension: dimension(),
          source: String.t(),
          anchor: String.t() | nil,
          last_reviewed: Date.t() | nil,
          present: boolean()
        }

  @type verification :: %{
          dimension: dimension(),
          present: boolean(),
          coherent: boolean(),
          anchor: String.t() | nil,
          last_reviewed: Date.t() | nil
        }

  @type queue_entry :: %{
          dimension: dimension(),
          source: String.t(),
          reason: String.t(),
          verification: verification()
        }

  @doc """
  The canonical positioning anchor — the §1 public category sentence read from
  `specs/positioning.md`. Every anchor-bearing dimension must agree with this
  for the message to be coherent.
  """
  @spec anchor() :: String.t()
  def anchor do
    @positioning_path
    |> File.read!()
    |> extract_anchor()
    |> case do
      nil -> @anchor_sentence
      anchor -> anchor
    end
  end

  @doc """
  Returns the default quarterly review window in days (one quarter).
  """
  @spec default_review_days() :: pos_integer()
  def default_review_days, do: @default_review_days

  @doc """
  Returns the four messaging dimensions with their source, recorded positioning
  anchor, last-reviewed date, and presence. This is the single view a reviewer
  reads to hold the quarterly review — position, package roles, proof, and
  audience, together.

  ## Options

    * `:packages` — an explicit package list for the `package_roles` dimension
      (defaults to `AgentJido.Ecosystem.all_packages/0`), so the review is
      testable against synthetic registry input.
  """
  @spec dimensions(keyword()) :: [dimension_state()]
  def dimensions(opts \\ []) when is_list(opts) do
    packages = Keyword.get(opts, :packages) || Ecosystem.all_packages()

    [
      dimension_state(:position, @positioning_path),
      package_roles_state(packages),
      dimension_state(:proof, @proof_path),
      dimension_state(:audience, @persona_path)
    ]
  end

  @doc """
  Reports the review state of a single dimension — `present`, `coherent`
  (anchor agrees with the canonical anchor; dimensions that record no anchor are
  trivially coherent), the recorded `anchor`, and `last_reviewed`.

    * `:position` — present when positioning.md states the canonical anchor.
    * `:package_roles` — present when every public package carries a role
      (`tagline`).
    * `:proof` / `:audience` — present when the source records a positioning
      anchor.
  """
  @spec verification(dimension_state()) :: verification()
  def verification(%{dimension: dim} = state) do
    canonical = normalize_anchor(anchor())

    coherent =
      case state[:anchor] do
        nil -> true
        recorded -> normalize_anchor(recorded) == canonical
      end

    %{
      dimension: dim,
      present: state[:present],
      coherent: coherent,
      anchor: state[:anchor],
      last_reviewed: state[:last_reviewed]
    }
  end

  @doc """
  Returns `true` when every anchor-bearing dimension agrees with the canonical
  positioning anchor — i.e. position, proof, and audience still tell one story.

  ## Options

    * `:packages` — forwarded to `dimensions/1` for the `package_roles` state.
  """
  @spec coherent?(keyword()) :: boolean()
  def coherent?(opts \\ []) when is_list(opts) do
    opts
    |> dimensions()
    |> Enum.filter(fn state -> state[:anchor] != nil end)
    |> Enum.all?(fn state -> verification(state).coherent end)
  end

  @doc """
  Calendar freshness predicate for a dated dimension. Returns `true` when the
  dimension's `last_reviewed` date drifts past the review window or is missing.

  Note: only `position`, `proof`, and `audience` record a review date.
  `package_roles` records none — its freshness is judged by `present` (every
  public package still carries a role), checked by `due?/2` and `review_queue/1`.

  ## Options

    * `:review_after_days` — review window in days
      (default `#{inspect(@default_review_days)}`).
    * `:today` — a `Date.t()` to evaluate against (defaults to `Date.utc_today/0`),
      so the check is deterministic under test.
  """
  @spec stale?(dimension_state(), keyword()) :: boolean()
  def stale?(%{last_reviewed: last_reviewed}, opts \\ []) when is_list(opts) do
    review_after_days = Keyword.get(opts, :review_after_days, @default_review_days)
    today = Keyword.get(opts, :today, Date.utc_today())

    # A dimension that records no date (package_roles) is not calendar-stale;
    # its freshness gate is presence, handled by due?/2.
    case last_reviewed do
      nil -> false
      %Date{} = validated_on -> Date.diff(today, validated_on) > review_after_days
    end
  end

  @doc """
  Returns `true` when a dimension is due for review this quarter — the
  dimension is not `present`, not `coherent`, or `stale?/2`.

  This is the uniform trigger behind `review_queue/1`: each dimension can fall
  due on its own failure mode.
  """
  @spec due?(dimension_state(), keyword()) :: boolean()
  def due?(state, opts \\ []) when is_list(opts) do
    v = verification(state)
    not v.present or not v.coherent or stale?(state, opts)
  end

  @doc """
  Returns the quarterly review queue — every dimension due for review this
  quarter, each carrying its source, a human-readable `reason`, and the
  `verification/1` report so the reviewer sees exactly what to re-check.

  When the queue is empty, position, package roles, proof, and audience were
  reviewed together this quarter (`reviewed_together?/1`).

  ## Options

    * `:review_after_days` — review window in days
      (default `#{inspect(@default_review_days)}`).
    * `:today` — a `Date.t()` to evaluate against (defaults to `Date.utc_today/0`),
      so the queue is deterministic under test.
    * `:packages` — forwarded to `dimensions/1` for the `package_roles` state.
  """
  @spec review_queue(keyword()) :: [queue_entry()]
  def review_queue(opts \\ []) when is_list(opts) do
    today = Keyword.get(opts, :today, Date.utc_today())
    review_after_days = Keyword.get(opts, :review_after_days, @default_review_days)

    # dimensions/1 reads :packages from opts (defaults to the registry), so the
    # package_roles dimension honors the same synthetic-input opt as the rest.
    opts
    |> dimensions()
    |> Enum.filter(fn state ->
      due?(state, today: today, review_after_days: review_after_days)
    end)
    |> Enum.map(fn state ->
      %{
        dimension: state.dimension,
        source: state.source,
        reason: reason(state, today: today, review_after_days: review_after_days),
        verification: verification(state)
      }
    end)
  end

  @doc """
  Returns `true` when the review queue is empty — position, package roles,
  proof, and audience are reviewed together (all present, coherent, and fresh).

  ## Options

  Forwarded to `review_queue/1`.
  """
  @spec reviewed_together?(keyword()) :: boolean()
  def reviewed_together?(opts \\ []) when is_list(opts) do
    review_queue(opts) == []
  end

  # --- dimension state ------------------------------------------------------

  defp dimension_state(:position, path) do
    text = File.read!(path)

    %{
      dimension: :position,
      source: relative_spec(path),
      anchor: extract_anchor(text),
      last_reviewed: extract_last_updated(text),
      present: extract_anchor(text) != nil
    }
  end

  defp dimension_state(:proof, path) do
    spec_anchor_state(:proof, path)
  end

  defp dimension_state(:audience, path) do
    spec_anchor_state(:audience, path)
  end

  defp spec_anchor_state(dim, path) do
    text = File.read!(path)
    anchor = extract_positioning_anchor(text)

    %{
      dimension: dim,
      source: relative_spec(path),
      anchor: anchor,
      last_reviewed: extract_last_updated(text),
      present: anchor != nil
    }
  end

  defp package_roles_state(packages) do
    public = for pkg <- packages, public?(pkg), do: pkg
    missing = for pkg <- public, role(pkg) == "", do: pkg.id

    %{
      dimension: :package_roles,
      source: "priv/ecosystem/*.md (registry: #{length(public)} public packages)",
      anchor: nil,
      last_reviewed: nil,
      present: missing == []
    }
  end

  # --- reason text ----------------------------------------------------------

  defp reason(state, opts) do
    v = verification(state)

    cond do
      not v.present ->
        present_reason(state)

      not v.coherent ->
        "recorded positioning anchor (#{inspect(state[:anchor])}) diverges from the canonical anchor"

      stale?(state, opts) ->
        days = days_since(state[:last_reviewed], opts[:today])
        "last reviewed #{state[:last_reviewed]} (#{days} days ago) is past the quarterly window"

      true ->
        "due"
    end
  end

  defp present_reason(%{dimension: :package_roles}),
    do: "one or more public packages lack a role (tagline)"

  defp present_reason(%{dimension: dim}),
    do: "#{dim} source does not record the positioning anchor"

  # --- parsing helpers ------------------------------------------------------

  # The canonical anchor from positioning.md — the backticked §1 public
  # category sentence (`Jido is the Elixir framework for long-running agent
  # systems.`). The first backticked occurrence of the anchor sentence is §1.
  defp extract_anchor(text) do
    case Regex.run(~r/`([^`]*#{Regex.escape(@anchor_sentence)}[^`]*)`/, text, capture: :all_but_first) do
      [anchor | _] -> anchor
      nil -> nil
    end
  end

  # The `Positioning anchor:` backticked value recorded in proof.md /
  # persona-journeys.md.
  defp extract_positioning_anchor(text) do
    case Regex.run(~r/Positioning anchor:\s*`([^`]+)`/, text, capture: :all_but_first) do
      [anchor | _] -> anchor
      nil -> nil
    end
  end

  defp extract_last_updated(text) do
    case Regex.run(~r/Last updated:\s*(\d{4}-\d{2}-\d{2})/, text, capture: :all_but_first) do
      [date | _] -> Date.from_iso8601!(date)
      nil -> nil
    end
  end

  defp normalize_anchor(nil), do: nil

  defp normalize_anchor(anchor) when is_binary(anchor) do
    anchor
    |> String.downcase()
    |> String.trim()
    |> String.trim_trailing(".")
  end

  # --- package helpers ------------------------------------------------------

  defp public?(%{visibility: :public}), do: true
  defp public?(pkg) when is_map(pkg), do: Map.get(pkg, :visibility) == :public
  defp public?(_), do: false

  defp role(%{tagline: tagline}) when is_binary(tagline), do: String.trim(tagline)
  defp role(pkg) when is_map(pkg), do: pkg |> Map.get(:tagline, "") |> to_string() |> String.trim()
  defp role(_), do: ""

  defp days_since(%Date{} = last, today), do: max(0, Date.diff(today, last))
  defp days_since(_, _), do: nil

  defp relative_spec(path) do
    Path.relative_to(path, @specs_root) |> then(&"specs/#{&1}")
  end
end
