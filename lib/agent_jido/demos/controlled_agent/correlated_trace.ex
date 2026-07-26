defmodule AgentJido.Demos.ControlledAgent.CorrelatedTrace do
  @moduledoc """
  One correlated operational trace for the controlled-Agent example
  (`jido-e08-t43`).

  The operational-control proof's observation acceptance (`jido-e08-t43`):
  *Principal context, request, Signal, Action, policy result, and effect share
  documented correlation.* This module runs one unit of controlled-agent work
  through the real `Jido.AgentServer` and returns a single trace that joins the
  six elements an operator follows — each stamped with the one correlation id
  seeded from the incoming Signal:

  | element       | source                                          |
  |---------------|--------------------------------------------------|
  | `principal`   | `Signal.source` — the already-authenticated caller |
  | `request`     | the `request_id` incoming-context field           |
  | `signal`      | the routed `Signal.type`                          |
  | `action`      | the route table's `Jido.Action` module            |
  | `policy_result` | the fail-closed `AuthorizationPlugin` decision  |
  | `effect`      | the state change the Action produced (or none)    |

  The correlation id is the `jido_trace_id` `Jido.Tracing.Context` seeds from
  the incoming Signal (`ensure_from_signal/1`) — exactly as Signal processing
  seeds it. The whole unit of work is emitted as one `Jido.Observe` trace whose
  spans carry that id, so an operator — or a `jido_otel` exporter attached to
  the same `:telemetry` events — follows the work from who initiated it, through
  the request and signal, to the policy decision and the effect it produced.

  The incoming `causation` context value (`IncomingContext`'s `causation` field,
  on `Signal.extensions["causation_id"]`) rides the same spans, so the
  correlation **and** causation values an operator follows both remain connected
  from ingress to effect (`jido-e12-t43`).

  The policy decision and the effect are **real**, not asserted: the controlled
  agent runs under its real `AgentServer` with its real fail-closed
  `AuthorizationPlugin`, so the trace records an actual allow or deny and the
  state change (or the absence of one). The agent is deterministic and
  side-effect free — no API key, network, or runtime is required — so the whole
  path runs in a normal `mix test` process.

  This is the **observation backend** for the controlled-Agent example: the
  trace an operator reads to answer *who initiated this work, was it allowed,
  and what happened* for one correlated unit of work.
  """

  alias AgentJido.Demos.ControlledAgent
  alias AgentJido.Demos.ControlledAgent.IncomingContext
  alias Jido.AgentServer
  alias Jido.Observe
  alias Jido.Signal
  alias Jido.Tracing.Context

  @enforce_keys [
    :correlation_id,
    :principal,
    :request,
    :signal,
    :action,
    :policy_result,
    :effect
  ]

  # `causation_id` is optional (not every caller supplies a causing signal) so it
  # is not enforced; it defaults to `nil`. It is the incoming `causation` context
  # value carried from ingress to effect alongside the correlation id
  # (`jido-e12-t43`).
  defstruct @enforce_keys ++ [causation_id: nil]

  @type policy_result :: :allowed | {:denied, term()}
  @type effect :: %{approved_count: non_neg_integer(), delta: integer()} | :no_effect

  @type t :: %__MODULE__{
          correlation_id: String.t(),
          principal: String.t() | nil,
          request: String.t() | nil,
          signal: String.t(),
          action: module() | nil,
          policy_result: policy_result(),
          effect: effect(),
          causation_id: String.t() | nil
        }

  # The six legs of one correlated operational trace, in the order an operator
  # reads them: who initiated the work, which request it was, the signal that
  # delivered it, the action it ran, the policy decision, and the effect. Each
  # entry pairs a human label with the canonical `:telemetry` event prefix the
  # leg emits — what a `jido_otel` exporter subscribes to.
  @legs [
    {:principal, [:agent_jido, :controlled_agent, :trace, :principal]},
    {:request, [:agent_jido, :controlled_agent, :trace, :request]},
    {:signal, [:agent_jido, :controlled_agent, :trace, :signal]},
    {:action, [:agent_jido, :controlled_agent, :trace, :action]},
    {:policy, [:agent_jido, :controlled_agent, :trace, :policy]},
    {:effect, [:agent_jido, :controlled_agent, :trace, :effect]}
  ]

  @doc """
  The six legs of one correlated operational trace, each paired with the
  canonical `:telemetry` event prefix it emits. A handler (or `jido_otel`
  exporter) attached to these prefixes sees the whole joined trace.
  """
  @spec legs() :: [{atom(), [atom()]}]
  def legs, do: @legs

  @doc """
  The six element names an operator follows for one unit of controlled-agent
  work, in read order.
  """
  @spec elements() :: [atom()]
  def elements, do: Enum.map(@legs, fn {name, _prefix} -> name end)

  @doc """
  Runs one unit of controlled-agent work and returns a single correlated
  operational trace joining its six elements (`jido-e08-t43`).

  Builds an incoming `work.approve` Signal from `opts`, runs it through a real
  supervised `ControlledAgent` `AgentServer`, and records the policy decision
  and effect. The correlation context is seeded from the incoming Signal
  exactly as Signal processing seeds it (`ensure_from_signal/1`), so the
  returned trace's `correlation_id` ties the principal, request, signal,
  action, policy result, and effect together — and every `:telemetry` span the
  run emits carries the same `jido_trace_id`.

  ## Options

    * `:principal` — the verified caller carried on `Signal.source`
      (default `"alice"`, the allowlisted principal).
    * `:request` — the `request_id` incoming-context field (default `"req-1"`).
    * `:tenant`, `:correlation`, `:causation` — the remaining incoming-context
      fields (optional).

  ## Example

      {:ok, trace} =
        AgentJido.Demos.ControlledAgent.CorrelatedTrace.run(principal: "alice")

      trace.policy_result   # => :allowed
      trace.effect          # => %{approved_count: 1, delta: 1}

      trace = AgentJido.Demos.ControlledAgent.CorrelatedTrace.run!(principal: "mallory")
      trace.policy_result   # => {:denied, :unauthorized}
      trace.effect          # => :no_effect

  Returns `{:ok, %__MODULE__{}}` whose `correlation_id` is shared by all six
  legs.
  """
  @spec run(keyword()) :: {:ok, t()}
  def run(opts \\ []) do
    signal = build_signal(opts)

    # Seed the correlation context from the incoming Signal exactly as Signal
    # processing does, so every span below carries the same jido_trace_id.
    {_traced_signal, trace} = Context.ensure_from_signal(signal)
    correlation_id = trace[:trace_id]

    {policy_result, effect, action} = run_agent(signal)

    trace_record = %__MODULE__{
      correlation_id: correlation_id,
      principal: IncomingContext.get(signal, :principal),
      request: IncomingContext.get(signal, :request),
      signal: signal.type,
      action: action,
      policy_result: policy_result,
      effect: effect,
      # The incoming `causation` context value, carried from ingress so the
      # correlation and causation values an operator follows both reach the
      # effect end of the trace (`jido-e12-t43`).
      causation_id: IncomingContext.get(signal, :causation)
    }

    # Emit the six legs as one correlated observation trace (the observation
    # backend) WHILE the context is still seeded, so every span carries the
    # shared jido_trace_id. An operator following telemetry — or a jido_otel
    # exporter attached to these same events — then sees all six elements on one
    # trace.
    emit_trace(trace_record)

    Context.clear()

    {:ok, trace_record}
  end

  @doc """
  Same as `run/1` but returns the trace struct directly.
  """
  @spec run!(keyword()) :: t()
  def run!(opts \\ []) do
    {:ok, trace} = run(opts)
    trace
  end

  @doc """
  Returns the value the trace records for one element leg, or `nil`.

      iex> alias AgentJido.Demos.ControlledAgent.CorrelatedTrace
      iex> {:ok, t} = CorrelatedTrace.run(principal: "alice")
      iex> is_binary(CorrelatedTrace.leg(t, :correlation_id))
      true
      iex> CorrelatedTrace.leg(t, :policy_result)
      :allowed
  """
  @spec leg(t(), atom()) :: term()
  def leg(%__MODULE__{} = trace, element) when is_atom(element) do
    Map.get(trace, element)
  end

  # --- internals ---

  defp build_signal(opts) do
    attrs =
      IncomingContext.build(
        principal: Keyword.get(opts, :principal, "alice"),
        request: Keyword.get(opts, :request, "req-1"),
        tenant: Keyword.get(opts, :tenant),
        correlation: Keyword.get(opts, :correlation),
        causation: Keyword.get(opts, :causation)
      )

    Signal.new!("work.approve", %{note: "trace"}, attrs)
  end

  # Runs the incoming Signal against a real supervised ControlledAgent and
  # classifies the outcome into the (policy_result, effect, action) legs. The
  # policy decision and effect are real — the AuthorizationPlugin either let the
  # Action run (counter advanced) or denied it before it ran (no effect).
  defp run_agent(signal) do
    {:ok, pid} = start_server()
    before_count = agent_state(pid).approved_count
    result = AgentServer.call(pid, signal)
    after_count = agent_state(pid).approved_count
    stop(pid)

    action = route_action(signal.type)

    case result do
      {:ok, _agent} ->
        {:allowed, %{approved_count: after_count, delta: after_count - before_count}, action}

      {:error, reason} ->
        # Denied at the policy hook: the action was routed but never ran, so
        # there is no effect. The trace still names the action the route
        # resolved to, so the operator sees what was denied. The denial reason
        # is normalized off the Jido error so the trace records a clean policy
        # decision (e.g. :unauthorized), not the wrapped error struct.
        {{:denied, denial_reason(reason)}, :no_effect, action}
    end
  end

  # The Action module the route table resolves the signal type to, read from the
  # table rather than hardcoded — the route, not the call site, directs the work.
  defp route_action(signal_type) do
    case Enum.find(ControlledAgent.signal_routes(), fn {type, _action} ->
           type == signal_type
         end) do
      {_type, action} -> action
      nil -> nil
    end
  end

  # Emits the six legs as one nested span tree — outermost (principal) first —
  # so the emitted :start/:stop events form one trace. Each leg's span carries
  # the shared jido_trace_id (via Jido.Observe's correlation enrichment from the
  # seeded context) plus the correlation_id and the leg's value, so an operator
  # reading the observation stream sees all six elements tied to one unit of
  # work.
  defp emit_trace(%__MODULE__{} = trace) do
    @legs
    |> Enum.reverse()
    |> Enum.reduce(fn -> :ok end, fn {name, prefix}, inner ->
      fn -> Observe.with_span(prefix, leg_metadata(name, trace), inner) end
    end)
    |> then(fn outer -> outer.() end)
  end

  defp leg_metadata(:principal, trace),
    do: %{correlation_id: trace.correlation_id, causation_id: trace.causation_id, principal: trace.principal}

  defp leg_metadata(:request, trace),
    do: %{correlation_id: trace.correlation_id, causation_id: trace.causation_id, request: trace.request}

  defp leg_metadata(:signal, trace),
    do: %{correlation_id: trace.correlation_id, causation_id: trace.causation_id, signal_type: trace.signal}

  defp leg_metadata(:action, trace),
    do: %{correlation_id: trace.correlation_id, causation_id: trace.causation_id, action: inspect(trace.action)}

  defp leg_metadata(:policy, trace),
    do: %{correlation_id: trace.correlation_id, causation_id: trace.causation_id, policy_result: policy_label(trace.policy_result)}

  defp leg_metadata(:effect, trace),
    do: %{correlation_id: trace.correlation_id, causation_id: trace.causation_id, effect: effect_label(trace.effect)}

  # Normalizes a denial off the Jido error the AgentServer returns when a
  # plugin fails, so the trace records the policy decision (e.g.
  # :unauthorized) rather than the wrapped error struct.
  defp denial_reason(%{details: %{reason: reason}}) when not is_nil(reason), do: reason
  defp denial_reason(%{reason: reason}) when not is_nil(reason), do: reason
  defp denial_reason(other), do: other

  defp policy_label(:allowed), do: "allowed"
  defp policy_label({:denied, reason}), do: "denied:#{inspect(reason)}"

  defp effect_label(:no_effect), do: "no_effect"
  defp effect_label(%{approved_count: count, delta: delta}), do: "approved_count:#{count}:delta:#{delta}"

  defp start_server do
    AgentServer.start_link(
      jido: AgentJido.Jido,
      agent: ControlledAgent,
      id: "controlled-trace-#{System.unique_integer([:positive])}"
    )
  end

  defp agent_state(pid) do
    {:ok, st} = AgentServer.state(pid)
    st.agent.state
  end

  defp stop(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal)
  end
end
