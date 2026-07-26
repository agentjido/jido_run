defmodule AgentJido.Demos.ControlledAgent.IngressPlugin do
  @moduledoc """
  Ingress hook (`prepare_signal/2`) — verify and enrich the incoming Signal's
  runtime context (`jido-e07-t38`).

  The architecture spec's controlled-agent linear path is:

      carry principal context on the incoming Signal
      → verify/enrich it in prepare_signal/2
      → make prepare_action/3 fail-closed against a policy
      → garden the Actions and effects behind allowlists and quotas
      → ...

  This plugin is the middle step. It runs `IncomingContext.validate/1` against
  the incoming Signal at the earliest Jido hook, **before** routing, the policy
  hook (`prepare_action/3`), and the Action. When the context does not validate,
  the plugin returns `{:error, ...}`; Jido turns that into an error directive
  that stops the signal — so **invalid or missing required context never reaches
  Agent processing**. This is the task's acceptance: *Invalid or missing required
  context stops before Agent processing.*

  When the context validates, the plugin returns the Signal unchanged plus a
  runtime-context delta that enriches later phases (`prepare_action/3`, the
  routed Action) with the five verified fields under one `:incoming_context`
  key — the "enrich" half of the task. The Signal is not rewritten: this hook
  verifies and carries context; it does not authorize work (the
  `AuthorizationPlugin` does) and does not verify identity (the boundary in
  front of Jido does — see `jido-e07-t36`).

  ## The error contract

  A rejected signal fails with `{:error, {:invalid_context, {field, reason}}}`,
  where `field` is one of `IncomingContext.fields/0` and `reason` is `:missing`
  (a required principal is absent) or `:malformed` (a present value is not a
  non-empty binary). `principal` is the only required field; the other four are
  optional and reject only when present-but-malformed.
  """

  use Jido.Plugin,
    name: "ingress",
    state_key: :ingress,
    description: "Verify/enrich incoming runtime context before Agent processing",
    actions: []

  alias AgentJido.Demos.ControlledAgent.IncomingContext
  alias Jido.Signal

  @doc """
  Verify and enrich the incoming Signal's runtime context.

  Returns `{:ok, signal, context_delta}` when every required context field is
  present and well-formed — the delta carries the verified fields so later
  phases receive them. Returns `{:error, {:invalid_context, {field, reason}}}`
  for the first field that fails `IncomingContext.validate/1`; Jido turns that
  into an error directive that stops the signal before Agent processing.
  """
  @impl Jido.Plugin
  def prepare_signal(%Signal{} = signal, _context) do
    case IncomingContext.validate(signal) do
      :ok ->
        {:ok, signal, context_delta(signal)}

      {:error, {field, reason}} ->
        {:error, {:invalid_context, {field, reason}}}
    end
  end

  @doc """
  The runtime-context enrichment produced for a verified Signal — the five
  carried fields read back off the Signal under a single namespaced key.

      iex> alias AgentJido.Demos.ControlledAgent.{IngressPlugin, IncomingContext}
      iex> signal = Jido.Signal.new!("work.approve", %{},
      ...>   IncomingContext.build(principal: "alice", tenant: "acme")
      ...> )
      iex> IngressPlugin.context_delta(signal)[:incoming_context]
      %{principal: "alice", tenant: "acme", request: nil,
        correlation: nil, causation: nil}
  """
  @spec context_delta(Signal.t()) :: %{incoming_context: map()}
  def context_delta(%Signal{} = signal) do
    fields = Map.new(IncomingContext.fields(), &{&1, IncomingContext.get(signal, &1)})
    %{incoming_context: fields}
  end
end
