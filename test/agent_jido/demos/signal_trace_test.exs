defmodule AgentJido.Demos.SignalTraceTest do
  @moduledoc """
  Signal-trace-across-two-agents proof (`jido-e08-t19`).

  Acceptance: "The trace shows cause, route, Action, and result."

  `AgentJido.Demos.SignalTrace.run/0` runs a real two-agent flow — Agent A
  (`EmitterAgent`) emits a `work.ready` Signal, Agent B (`FulfillmentAgent`)
  routes it to `FulfillAction` — and returns a trace whose four legs are the
  cause, the route, the Action, and the result. These tests pin each leg and the
  causal link that ties the two agents together.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.SignalTrace
  alias AgentJido.Demos.SignalTrace.{EmitterAgent, FulfillmentAgent}
  alias AgentJido.Demos.SignalTrace.Actions.{EmitReadyAction, FulfillAction}

  alias Jido.Signal

  describe "the trace shows cause, route, Action, and result (jido-e08-t19)" do
    test "run/0 returns a trace carrying all four legs" do
      trace = SignalTrace.run()

      # The trace is a four-legged record: each leg is present.
      assert %Signal{} = trace.cause
      assert {type, action} = trace.route
      assert is_binary(type)
      assert is_atom(action)
      assert is_atom(trace.action)
      assert is_map(trace.result)
    end

    test "the cause is the Signal Agent A emitted" do
      trace = SignalTrace.run()

      # Cause leg: the originating Signal, of the type the second agent routes.
      assert trace.cause.type == "work.ready"
      assert trace.cause.data == %{work_id: "w-001", units: 3}

      # The cause was produced by Agent A's emit Action, not by Agent B.
      assert trace.cause.source == "/signal_trace/emitter"
    end

    test "the route is the entry Agent B's route table used" do
      trace = SignalTrace.run()

      # Route leg: the {signal_type, action} entry from Agent B's route table,
      # the one that directed the cause Signal.
      assert trace.route == {"work.ready", FulfillAction}

      assert {"work.ready", FulfillAction} in FulfillmentAgent.signal_routes(),
             "the route must come from Agent B's route table"
    end

    test "the Action is the module the route resolved to" do
      trace = SignalTrace.run()

      # Action leg: the module the route pointed the cause Signal at.
      assert trace.action == FulfillAction
      assert trace.action == elem(trace.route, 1)
    end

    test "the result is the state change Agent B's Action produced" do
      trace = SignalTrace.run()

      # Result leg: the effect of running the Action — work fulfilled, units counted.
      assert trace.result == %{work_id: "w-001", fulfilled_units: 3, fulfilled_count: 1}
    end
  end

  describe "the two agents are distinct and causally linked" do
    test "Agent A emits and Agent B routes — they are not the same agent" do
      # The trace spans two agents: an emitter and a router/fulfiller.
      refute EmitterAgent == FulfillmentAgent

      assert EmitterAgent.new().name == "signal_trace_emitter"
      assert FulfillmentAgent.new().name == "signal_trace_fulfillment"
    end

    test "Agent B's result acts on the cause Agent A emitted" do
      trace = SignalTrace.run()

      # Causal link across the two agents: the work B fulfilled is the work A
      # emitted. The cause's work id and units flow through to B's result.
      assert trace.result.work_id == trace.cause.data.work_id
      assert trace.result.fulfilled_units == trace.cause.data.units
    end

    test "the route, not a hardcoded call, directs the cause to the Action" do
      # Agent B only knows about the cause through its route table: the cause
      # type resolves to FulfillAction via signal_routes, and any other type
      # would not. This is what makes the route leg real.
      routes = FulfillmentAgent.signal_routes()

      assert Enum.find(routes, fn {type, _} -> type == "work.ready" end) ==
               {"work.ready", FulfillAction}

      refute Enum.any?(routes, fn {type, _} -> type == "intake.request" end),
             "Agent B routes work.ready, not Agent A's intake.request"
    end
  end

  describe "Agent A's emit Action" do
    test "emits the cause Signal through an Emit directive" do
      alias Jido.Agent.Directive

      agent = EmitterAgent.new()
      {_agent, directives} = EmitterAgent.cmd(agent, {EmitReadyAction, %{work_id: "w-009", units: 2}})

      assert %Directive.Emit{signal: %Signal{} = cause} =
               Enum.find(directives, &match?(%Directive.Emit{}, &1))

      assert cause.type == "work.ready"
      assert cause.data == %{work_id: "w-009", units: 2}
    end
  end
end
