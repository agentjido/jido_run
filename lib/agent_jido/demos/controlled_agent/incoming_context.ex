defmodule AgentJido.Demos.ControlledAgent.IncomingContext do
  @moduledoc """
  The five context fields an incoming controlled-agent Signal carries
  (`jido-e07-t37`).

  The architecture spec's first control element is **Ingress** — "validate and
  attach principal/tenant/request/causation context at the boundary in front of
  Jido." This module is the carrying contract for that element: it names the
  five fields, where each one rides on the Signal (its **source**), the
  **validation rule** each must satisfy, and how to build and read them.

  ## Field map

  | field | source (Signal location) | validation rule |
  |---|---|---|
  | `principal` | `signal.source` | required, non-empty binary |
  | `tenant` | `signal.extensions["tenant"]` | optional; when present, non-empty binary |
  | `request` | `signal.extensions["request_id"]` | optional; when present, non-empty binary |
  | `correlation` | `signal.extensions["correlation_id"]` | optional; when present, non-empty binary |
  | `causation` | `signal.extensions["causation_id"]` | optional; when present, non-empty binary |

  ## Where each field comes from

  `principal` is the already-authenticated caller, verified at the boundary in
  front of Jido (see the spec's "Authentication boundary" section, `jido-e07-t36`).
  Jido carries it on `Signal.source` and never authenticates it.

  `tenant`, `request`, `correlation`, and `causation` are application-supplied
  context that same boundary attaches as Signal extensions. `correlation` ties
  one unit of work across components; `causation` names the signal or request
  that caused this one. They align with Jido's native trace extension
  (`Jido.Signal.Trace`: `trace_id` / `causation_id`); this module carries them as
  plain, named, uniformly validated fields so the ingress contract is explicit.
  Enriching them onto the live path via `prepare_signal/2` is the
  `IngressPlugin` (`jido-e07-t38`), which runs `validate/1` as the earliest
  Jido hook and stops invalid or missing required context before Agent
  processing.

  This module carries and validates context only — it does not verify identity
  (the boundary in front of Jido does) and does not authorize work (the
  `AuthorizationPlugin` does).
  """

  alias Jido.Signal

  @type field :: :principal | :tenant | :request | :correlation | :causation

  # The single source of truth: each field and the Signal location that carries
  # it. `{:source, nil}` means the field rides on `signal.source`; `{:extension,
  # key}` means it rides on `signal.extensions[key]`.
  @context [
    principal: {:source, nil},
    tenant: {:extension, "tenant"},
    request: {:extension, "request_id"},
    correlation: {:extension, "correlation_id"},
    causation: {:extension, "causation_id"}
  ]

  @fields Keyword.keys(@context)
  @sources Map.new(@context)

  @doc """
  The five context fields, in ingress order.
  """
  @spec fields() :: [field()]
  def fields, do: @fields

  @doc """
  Where a field is carried on the Signal — its **source**.

      iex> AgentJido.Demos.ControlledAgent.IncomingContext.source_of(:principal)
      {:source, nil}
      iex> AgentJido.Demos.ControlledAgent.IncomingContext.source_of(:tenant)
      {:extension, "tenant"}
  """
  @spec source_of(field()) :: {:source, nil} | {:extension, String.t()}
  def source_of(field) when field in @fields, do: Map.fetch!(@sources, field)

  @doc """
  Builds the `Signal.new!/3` attrs (`source:` + `extensions:`) that carry the
  given context.

  `principal` is required; the remaining fields are optional and omitted when
  `nil`. Returns a map ready to pass as the third argument to `Signal.new!/3`.

      iex> attrs = AgentJido.Demos.ControlledAgent.IncomingContext.build(
      ...>   principal: "alice", tenant: "acme", request: "req-1"
      ...> )
      iex> attrs.source
      "alice"
      iex> attrs.extensions["tenant"]
      "acme"
  """
  @spec build(keyword() | map()) :: map()
  def build(context) when is_list(context), do: context |> Map.new() |> build()

  def build(context) when is_map(context) do
    # Only the extension entries (principal rides on `source`, handled below).
    extensions =
      for {field, {:extension, key}} <- @context,
          value = Map.get(context, field),
          not is_nil(value) do
        {key, value}
      end
      |> Map.new()

    %{source: Map.get(context, :principal), extensions: extensions}
  end

  @doc """
  Reads a field off a Signal at its declared source.

      iex> alias AgentJido.Demos.ControlledAgent.IncomingContext
      iex> signal = Jido.Signal.new!("work.approve", %{},
      ...>   IncomingContext.build(principal: "alice", tenant: "acme")
      ...> )
      iex> IncomingContext.get(signal, :principal)
      "alice"
      iex> IncomingContext.get(signal, :tenant)
      "acme"
      iex> IncomingContext.get(signal, :correlation)
      nil
  """
  @spec get(Signal.t(), field()) :: String.t() | nil
  def get(%Signal{} = signal, field) when field in @fields do
    case source_of(field) do
      {:source, nil} -> signal.source
      {:extension, key} -> signal.extensions[key]
    end
  end

  @doc """
  The **validation rule** for one field value.

  `principal` is required and must be a non-empty binary. The other four fields
  are optional: `nil` satisfies the rule, and any present value must be a
  non-empty binary.

      iex> alias AgentJido.Demos.ControlledAgent.IncomingContext
      iex> IncomingContext.valid?(:principal, "alice")
      true
      iex> IncomingContext.valid?(:principal, nil)
      false
      iex> IncomingContext.valid?(:tenant, "")
      false
      iex> IncomingContext.valid?(:tenant, nil)
      true
  """
  @spec valid?(field(), term()) :: boolean()
  def valid?(:principal, value), do: non_empty_binary?(value)
  def valid?(_optional, nil), do: true
  def valid?(_optional, value), do: non_empty_binary?(value)

  @doc """
  Runs every field's validation rule against a Signal.

  Returns `:ok` when all present fields are well-formed (and a principal is
  present), or `{:error, {field, reason}}` for the first field that is not.
  `reason` is `:missing` (a required principal is absent) or `:malformed` (a
  present value is not a non-empty binary).

  Note: `Signal.new!/3` already rejects an empty or missing `source`, so a
  constructed Signal always carries a valid `principal` — this rule is enforced
  defensively here so the contract holds for any `%Signal{}`.
  """
  @spec validate(Signal.t()) :: :ok | {:error, {field(), :missing | :malformed}}
  def validate(%Signal{} = signal) do
    Enum.find_value(@fields, :ok, fn field ->
      value = get(signal, field)

      cond do
        field == :principal and is_nil(value) -> {:error, {:principal, :missing}}
        valid?(field, value) -> nil
        field == :principal -> {:error, {:principal, :malformed}}
        true -> {:error, {field, :malformed}}
      end
    end)
  end

  defp non_empty_binary?(value) do
    is_binary(value) and byte_size(value) > 0
  end
end
