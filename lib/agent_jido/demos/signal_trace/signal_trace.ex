defmodule AgentJido.Demos.SignalTrace do
  @moduledoc """
  A Signal trace across two Agents (`jido-e08-t19`).

  A routed Signal is only legible when you can see all four legs it travels.
  This module runs that flow against the real runtime and returns a trace that
  records exactly those legs:

    * `cause`  — the Signal **Agent A emitted** that Agent B reacts to;
    * `route`  — the `{signal_type, action}` entry **Agent B's route table**
                 used to direct that Signal;
    * `action` — the **Action module** the route resolved to; and
    * `result` — the **state change** that Action produced in Agent B.

  Agent A (`EmitterAgent`) accepts an intake request and emits a `work.ready`
  Signal. Agent B (`FulfillmentAgent`) routes `work.ready` to `FulfillAction`
  and fulfils the work. `run/0` performs both legs and returns the trace; the
  cause A emits is the same Signal B routes, so the trace is causally linked
  across the two agents.
  """

  alias AgentJido.Demos.SignalTrace.{
    EmitterAgent,
    FulfillmentAgent,
    Actions.EmitReadyAction
  }

  alias Jido.Agent.Directive
  alias Jido.AgentServer

  defstruct [:cause, :route, :action, :result]

  @type t :: %__MODULE__{
          cause: Jido.Signal.t(),
          route: {String.t(), module()},
          action: module(),
          result: map()
        }

  @default_request %{work_id: "w-001", units: 3}

  @doc """
  Runs the two-agent flow and returns the trace.

  Agent A emits the `work.ready` cause; Agent B routes and fulfils it. Agent B
  is driven through the `AgentServer` so its route table — not a hardcoded call
  — directs the Signal. The returned struct carries the cause, the route B used,
  the Action B ran, and the result, which are the four legs a Signal trace must
  show.
  """
  @spec run(keyword()) :: t()
  def run(opts \\ []) do
    request = Keyword.get(opts, :request, @default_request)

    # Leg 1 (Agent A): emit the cause Signal.
    agent_a = EmitterAgent.new()
    {_agent_a, directives} = EmitterAgent.cmd(agent_a, {EmitReadyAction, request})
    %Directive.Emit{signal: cause} = emitted_signal(directives)

    # Leg 2 (Agent B): route the cause Signal to its Action through the
    # AgentServer, so the route table directs the Signal.
    {:ok, pid_b} = start_fulfillment_server()
    {:ok, agent_b} = AgentServer.call(pid_b, cause)

    route = route_for(cause.type)
    {_type, action} = route
    result = result_view(agent_b)

    stop(pid_b)

    %__MODULE__{cause: cause, route: route, action: action, result: result}
  end

  # The Emit directive Agent A returned carries the cause Signal.
  defp emitted_signal(directives) do
    Enum.find(directives, &match?(%Directive.Emit{}, &1)) ||
      raise "EmitterAgent did not emit a cause Signal"
  end

  # Resolve the route Agent B's table uses for the cause Signal type. Reading it
  # from the route table — not from the call site — is what makes this the
  # *route* leg of the trace.
  defp route_for(signal_type) do
    Enum.find(FulfillmentAgent.signal_routes(), fn {type, _action} -> type == signal_type end) ||
      raise "FulfillmentAgent has no route for signal type #{inspect(signal_type)}"
  end

  # A focused view of the state change Agent B's Action produced — the *result*
  # leg. It echoes the cause's work id so the causal link is visible here too.
  defp result_view(agent_b) do
    state = agent_b.state

    %{
      work_id: hd(state.fulfilled).work_id,
      fulfilled_units: state.total_units,
      fulfilled_count: length(state.fulfilled)
    }
  end

  defp start_fulfillment_server do
    AgentServer.start_link(
      jido: AgentJido.Jido,
      agent: FulfillmentAgent,
      id: "signal-trace-b-#{System.unique_integer([:positive])}"
    )
  end

  defp stop(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal)
  end
end
