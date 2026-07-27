defmodule AgentJido.ThreatControlModel do
  @moduledoc """
  Threat-and-control model review after a material architecture change
  (jido-e12-t50).

  Acceptance: *A changed trust boundary creates a documentation and proof
  review.*

  The threat-and-control model lives in `specs/operations-reference-architecture.md`
  — its documented **trust boundaries**: the authentication boundary, the
  recovery boundaries, what stays outside Jido, the threat-and-control model
  table, and the explicit non-goals. Each boundary's prose fixes *who is trusted
  on each side and where the decision is made*, so an edit to that prose is a
  material architecture change to a trust boundary.

  This module is the **event-triggered** counterpart of the quarterly
  operational-control proof audit (`AgentJido.OperationalControlProof`,
  jido-e12-t49) and the quarterly message review (`AgentJido.MessageReview`,
  jido-e12-t36). Those fire on the calendar; this fires when a trust boundary
  actually changes.

  Each boundary carries a recorded **content signature** and **last-reviewed
  date** in `specs/audits/trust-boundary-baseline.md`. The signature is the
  boundary's documented prose, normalized (case- and whitespace-insensitive) so
  only a wording change — not a cosmetic edit — flips it. A boundary is
  **changed** when its current signature no longer matches its recorded
  signature (or it has no recorded baseline). A changed boundary creates two
  reviews:

    * **documentation review** — re-read the documented boundary and confirm the
      threat-and-control model still describes the architecture.
    * **proof review** — re-verify the seven proof fields (control point,
      configuration, test, limitation, owner, version, validation date) for each
      operational-control proof claim that depends on the changed boundary
      (`specs/proof.md`, Control Proof Fields; the field set is enforced
      continuously by the jido-e12-t38 proof gate and the jido-e12-t44 release
      gate).

  `review_queue/1` returns the changed boundaries, each carrying both reviews;
  `review_due?/1` is true when any boundary is changed. The review is
  informational — it never blocks a release; it surfaces the work the
  acceptance asks for. After a review, refresh the baseline with
  `to_baseline_markdown/1`.
  """

  alias AgentJido.OperationalControlProof

  @architecture_path Path.expand("../../specs/operations-reference-architecture.md", __DIR__)
  @baseline_path Path.expand("../../specs/audits/trust-boundary-baseline.md", __DIR__)

  @architecture_source "specs/operations-reference-architecture.md"
  @proof_source "specs/proof.md"
  @baseline_source "specs/audits/trust-boundary-baseline.md"

  # The documented trust boundaries. `level` is the markdown heading level of
  # the boundary's section in the reference architecture; `name` is the heading
  # text (prefix-matched, so the trailing `(...)` is not needed); `proof_claims`
  # names the operational-control proof claims whose control point sits on the
  # boundary, so a change creates a proof review for exactly those claims.
  @boundaries [
    %{
      id: :authentication,
      name: "Authentication boundary",
      level: 3,
      proof_claims: ["Fail-closed authorization"]
    },
    %{
      id: :recovery,
      name: "Recovery boundaries",
      level: 2,
      proof_claims: ["Supervised lifecycle"]
    },
    %{
      id: :outside_jido,
      name: "What stays outside Jido",
      level: 3,
      proof_claims: ["Fail-closed authorization", "Causal history", "Correlated telemetry"]
    },
    %{
      id: :threat_control,
      name: "Threat and control model",
      level: 2,
      proof_claims: [
        "Supervised lifecycle",
        "Fail-closed authorization",
        "Causal history",
        "Correlated telemetry",
        "Cost/quota control"
      ]
    },
    %{
      id: :non_goals,
      name: "Explicit non-goals",
      level: 2,
      proof_claims: ["Causal history", "Fail-closed authorization"]
    }
  ]

  @type boundary :: %{
          id: atom(),
          name: String.t(),
          level: pos_integer(),
          proof_claims: [String.t()]
        }

  @type baseline_entry :: %{signature: String.t(), last_reviewed: Date.t() | nil}

  @type documentation_review :: %{
          target: String.t(),
          instruction: String.t()
        }

  @type proof_review :: %{
          target: String.t(),
          claims: [String.t()],
          missing_claims: [String.t()],
          instruction: String.t()
        }

  @type review_entry :: %{
          boundary: %{
            id: atom(),
            name: String.t(),
            source: String.t(),
            proof_claims: [String.t()]
          },
          reason: String.t(),
          last_reviewed: Date.t() | nil,
          current_signature: String.t(),
          baseline_signature: String.t() | nil,
          documentation_review: documentation_review(),
          proof_review: proof_review()
        }

  @doc """
  Returns the documented trust boundaries reviewed by this module.
  """
  @spec boundaries() :: [boundary()]
  def boundaries, do: @boundaries

  @doc """
  Returns the source path of the reference architecture reviewed by this module.
  """
  @spec architecture_source() :: String.t()
  def architecture_source, do: @architecture_source

  @doc """
  Returns the source path of the trust-boundary baseline.
  """
  @spec baseline_source() :: String.t()
  def baseline_source, do: @baseline_source

  @doc """
  Returns the normalized content signature of a boundary's documented prose in
  `specs/operations-reference-architecture.md`. Two boundaries with the same
  wording share a signature; any wording change produces a different signature,
  which is exactly the material change this module detects.
  """
  @spec signature(boundary()) :: String.t()
  def signature(%{level: _, name: _} = boundary) do
    boundary |> section_text(File.read!(@architecture_path)) |> normalize()
  end

  @doc """
  Returns every boundary's current content signature keyed by id.

  ## Options

    * `:architecture` — synthetic architecture text (defaults to the reference
      architecture file), so signatures are testable without touching the file.
  """
  @spec signatures(keyword()) :: %{atom() => String.t()}
  def signatures(opts \\ []) when is_list(opts) do
    doc = architecture(opts)

    for boundary <- boundaries(), into: %{} do
      {boundary.id, section_text(boundary, doc) |> normalize()}
    end
  end

  @doc """
  Reads `specs/audits/trust-boundary-baseline.md` and returns the recorded
  signature and last-reviewed date for each documented boundary. A boundary with
  no recorded section is absent from the map (and is therefore `changed?/2`).
  """
  @spec baseline(keyword()) :: %{atom() => baseline_entry()}
  def baseline(opts \\ []) when is_list(opts) do
    baseline_from(baseline_text(opts))
  end

  @doc """
  Parses a baseline document into a map of boundary id to recorded signature and
  last-reviewed date. Pure helper exposed so the review (and its tests) can run
  against synthetic baseline input without touching the file.
  """
  @spec baseline_from(String.t()) :: %{atom() => baseline_entry()}
  def baseline_from(text) when is_binary(text) do
    text
    |> String.split(~r/^##\s+/m)
    |> Enum.drop(1)
    |> Enum.map(&parse_baseline_section/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  @doc """
  Returns `true` when the boundary's current signature no longer matches its
  recorded baseline signature, or the boundary has no recorded baseline — i.e.
  the trust boundary has changed and a documentation and proof review is due.

  ## Options

    * `:architecture` — synthetic architecture text.
    * `:baseline` — synthetic baseline text.
  """
  @spec changed?(boundary(), keyword()) :: boolean()
  def changed?(boundary, opts \\ []) when is_list(opts) do
    changed?(boundary, architecture(opts), baseline(opts))
  end

  defp changed?(boundary, doc, base) do
    current = section_text(boundary, doc) |> normalize()

    case Map.get(base, boundary.id) do
      nil -> true
      %{signature: sig} -> sig != current
    end
  end

  @doc """
  Returns the changed-boundary review queue — every documented trust boundary
  whose current signature no longer matches its recorded baseline (or has no
  recorded baseline). Each entry carries **both** reviews the acceptance asks
  for: a documentation review (re-read the documented boundary) and a proof
  review (re-verify the seven proof fields for the claims that depend on the
  changed boundary).

  When the queue is empty, no trust boundary has changed and no review is due
  (`review_due?/1`).

  ## Options

    * `:architecture` — synthetic architecture text.
    * `:baseline` — synthetic baseline text.
    * `:claims` — an explicit operational-control claim list (defaults to
      `AgentJido.OperationalControlProof.claims/0`), so the proof review is
      testable against synthetic proof input.
  """
  @spec review_queue(keyword()) :: [review_entry()]
  def review_queue(opts \\ []) when is_list(opts) do
    doc = architecture(opts)
    base = baseline(opts)
    claims = Keyword.get(opts, :claims) || OperationalControlProof.claims()

    boundaries()
    |> Enum.filter(&changed?(&1, doc, base))
    |> Enum.map(&review_entry(&1, doc, base, claims))
  end

  @doc """
  Returns `true` when any documented trust boundary has changed — i.e. a
  documentation and proof review is due.

  ## Options

  Forwarded to `review_queue/1`.
  """
  @spec review_due?(keyword()) :: boolean()
  def review_due?(opts \\ []) when is_list(opts), do: review_queue(opts) != []

  @doc """
  Renders the baseline markdown for `specs/audits/trust-boundary-baseline.md`
  from the boundary signatures in the reference architecture. After completing a
  review, write this output back to the baseline file so the recorded signatures
  match the reviewed architecture and the change trigger resets.

  ## Options

    * `:architecture` — synthetic architecture text.
    * `:last_reviewed` — a `Date.t()` stamped on every boundary
      (defaults to `Date.utc_today/0`).
  """
  @spec to_baseline_markdown(keyword()) :: String.t()
  def to_baseline_markdown(opts \\ []) when is_list(opts) do
    doc = architecture(opts)
    last_reviewed = Keyword.get(opts, :last_reviewed) || Date.utc_today()
    date_str = Date.to_iso8601(last_reviewed)

    sections =
      boundaries()
      |> Enum.map(fn boundary ->
        sig = section_text(boundary, doc) |> normalize()

        """
        ## #{boundary.name}
        - **Signature:** #{sig}
        - **Last reviewed:** #{date_str}
        """
      end)
      |> Enum.join("\n")

    baseline_header() <> "\n\n" <> sections
  end

  # --- review entry ---------------------------------------------------------

  defp review_entry(boundary, doc, base, claims) do
    current = section_text(boundary, doc) |> normalize()
    recorded = Map.get(base, boundary.id)
    known_claims = MapSet.new(claims, & &1.claim)

    missing_claims =
      Enum.reject(boundary.proof_claims, &MapSet.member?(known_claims, &1))

    reason =
      if recorded == nil,
        do: "no recorded baseline — boundary is new or never reviewed",
        else: "documented boundary changed since last review"

    %{
      boundary: %{
        id: boundary.id,
        name: boundary.name,
        source: "#{@architecture_source} § #{boundary.name}",
        proof_claims: boundary.proof_claims
      },
      reason: reason,
      last_reviewed: recorded && recorded[:last_reviewed],
      current_signature: current,
      baseline_signature: recorded && recorded[:signature],
      documentation_review: %{
        target: @architecture_source,
        instruction: "Re-read the documented boundary and confirm the threat-and-control model still describes the architecture."
      },
      proof_review: %{
        target: "#{@proof_source} (Control Proof Fields)",
        claims: boundary.proof_claims,
        missing_claims: missing_claims,
        instruction:
          "Re-verify the seven proof fields (control point, configuration, test, limitation, owner, version, validation date) for each claim, because the boundary it depends on changed."
      }
    }
  end

  # --- baseline parsing -----------------------------------------------------

  defp parse_baseline_section(chunk) do
    case String.split(chunk, "\n", parts: 2) do
      [name_line, body] ->
        name = String.trim(name_line)

        case Enum.find(boundaries(), fn boundary -> boundary.name == name end) do
          nil ->
            nil

          boundary ->
            {boundary.id,
             %{
               signature: field_value(body, "Signature") || "",
               last_reviewed: parse_date(field_value(body, "Last reviewed"))
             }}
        end

      _ ->
        nil
    end
  end

  defp field_value(body, label) do
    case Regex.run(~r/- \*\*#{Regex.escape(label)}:\*\*\s*(.+)/, body) do
      [_, value] -> String.trim(value)
      nil -> nil
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(value) do
    case Date.from_iso8601(to_string(value)) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  # --- signature extraction -------------------------------------------------

  # The boundary's section: from its heading line to the next heading at the
  # same or higher level (a peer heading). Sub-headings inside the section are
  # included; a peer heading ends it.
  defp section_text(boundary, doc) do
    lines = String.split(doc, "\n")
    hashes = String.duplicate("#", boundary.level)

    case find_heading(lines, hashes, boundary.name) do
      nil ->
        ""

      idx ->
        lines
        |> Enum.drop(idx + 1)
        |> Enum.take_while(&(not peer_heading?(&1, boundary.level)))
        |> Enum.join("\n")
    end
  end

  defp find_heading(lines, hashes, name) do
    prefix = hashes <> " "

    Enum.find_index(lines, fn line ->
      String.starts_with?(line, prefix) and
        line |> String.trim_leading(prefix) |> String.starts_with?(name)
    end)
  end

  # A peer heading starts with between 1 and `level` hash characters followed
  # by a space (ATX heading), so it ends the current section. Computed without a
  # regex so the level is plain interpolation, not a sigil.
  defp peer_heading?(line, level) do
    n = leading_hashes(line)
    n >= 1 and n <= level and space_after_hashes?(line, n)
  end

  defp leading_hashes(line) do
    line |> String.graphemes() |> Enum.take_while(&(&1 == "#")) |> length()
  end

  defp space_after_hashes?(line, n) do
    # The character right after the leading hashes must be a space (or absent)
    # for the hashes to open a heading rather than sit inside a word.
    case String.at(line, n) do
      " " -> true
      nil -> true
      _ -> false
    end
  end

  defp normalize(text) do
    text |> String.downcase() |> String.replace(~r/\s+/, " ") |> String.trim()
  end

  # --- sources --------------------------------------------------------------

  defp architecture(opts), do: Keyword.get(opts, :architecture) || File.read!(@architecture_path)
  defp baseline_text(opts), do: Keyword.get(opts, :baseline) || File.read!(@baseline_path)

  defp baseline_header do
    """
    # Trust Boundary Review Baseline

    Status: Living baseline, refreshed after each threat-and-control model review
    (`jido-e12-t50`). Records, for every documented trust boundary in
    `#{@architecture_source}`, the content signature captured at its last review
    and the last-reviewed date.

    When the reference architecture changes a boundary so its current signature
    no longer matches the signature recorded here, the boundary is **changed**
    and `AgentJido.ThreatControlModel.review_queue/1` creates a documentation
    and proof review — the reviewer re-reads the documented boundary and
    re-verifies the operational-control proof claims that depend on it.

    After a review, regenerate this file with
    `AgentJido.ThreatControlModel.to_baseline_markdown/1`.
    """
  end
end
