defmodule AgentJido.ExamplesTest do
  use ExUnit.Case, async: true

  alias AgentJido.Examples

  @hidden_slug "budget-guardrail-agent"
  @live_slug "counter-agent"
  @pilot_live_slug "signal-routing-agent"
  @new_live_examples [
    {"emit-directive-agent", "AgentJidoWeb.Examples.EmitDirectiveAgentLive"},
    {"state-ops-agent", "AgentJidoWeb.Examples.StateOpsAgentLive"},
    {"plugin-basics-agent", "AgentJidoWeb.Examples.PluginBasicsAgentLive"},
    {"persistence-storage-agent", "AgentJidoWeb.Examples.PersistenceStorageAgentLive"},
    {"schedule-directive-agent", "AgentJidoWeb.Examples.ScheduleDirectiveAgentLive"},
    {"runic-ai-research-studio", "AgentJidoWeb.Examples.RunicResearchStudioLive"},
    {"runic-ai-research-studio-step-mode", "AgentJidoWeb.Examples.RunicResearchStudioStepModeLive"},
    {"runic-adaptive-researcher", "AgentJidoWeb.Examples.RunicAdaptiveResearcherLive"},
    {"runic-structured-llm-branching", "AgentJidoWeb.Examples.RunicStructuredBranchingLive"},
    {"runic-delegating-orchestrator", "AgentJidoWeb.Examples.RunicDelegatingOrchestratorLive"},
    {"jido-ai-actions-runtime-demos", "AgentJidoWeb.Examples.ActionsRuntimeDemoLive"},
    {"jido-ai-browser-web-workflow", "AgentJidoWeb.Examples.BrowserDocsScoutAgentLive"},
    {"jido-ai-weather-multi-turn-context", "AgentJidoWeb.Examples.WeatherMultiTurnContextLive"},
    {"jido-ai-task-execution-workflow", "AgentJidoWeb.Examples.TaskExecutionWorkflowLive"},
    {"jido-ai-skills-runtime-foundations", "AgentJidoWeb.Examples.SkillsRuntimeFoundationsLive"},
    {"jido-ai-skills-multi-agent-orchestration", "AgentJidoWeb.Examples.SkillsMultiAgentOrchestrationLive"},
    {"jido-ai-weather-reasoning-strategy-suite", "AgentJidoWeb.Examples.WeatherReasoningStrategySuiteLive"},
    {"jido-ai-operational-agents-pack", "AgentJidoWeb.Examples.OperationalAgentsPackLive"},
    {"failure-drill-agent", "AgentJidoWeb.Examples.FailureDrillAgentLive"},
    {"controlled-agent", "AgentJidoWeb.Examples.ControlledAgentLive"}
  ]

  test "draft examples are hidden from default lookups" do
    assert is_nil(Examples.get_example(@hidden_slug))
    assert_raise AgentJido.Examples.NotFoundError, fn -> Examples.get_example!(@hidden_slug) end

    refute Enum.any?(Examples.all_examples(), &(&1.slug == @hidden_slug))
    assert Enum.any?(Examples.all_examples(include_unpublished: true), &(&1.slug == @hidden_slug))
  end

  test "include_unpublished opt-in exposes draft examples" do
    example = Examples.get_example!(@hidden_slug, include_unpublished: true)

    assert example.slug == @hidden_slug
    assert example.status == :draft
    assert example.published == false
  end

  test "taxonomy filters can narrow visible examples" do
    filtered = Examples.all_examples(category: :core)

    assert Enum.any?(filtered, &(&1.slug == "counter-agent"))
    assert Enum.any?(filtered, &(&1.slug == "demand-tracker-agent"))
    assert Enum.any?(filtered, &(&1.slug == "address-normalization-agent"))
    refute Enum.any?(filtered, &(&1.slug == @hidden_slug))
  end

  test "selected live examples remain visible by default" do
    example = Examples.get_example!(@live_slug)

    assert example.status == :live
    assert example.demo_mode == :real
  end

  test "examples expose related resources metadata from frontmatter" do
    example = Examples.get_example!(@live_slug)

    assert is_list(example.related_resources)

    assert Enum.any?(example.related_resources, fn resource ->
             Map.get(resource, :path) == "/docs/getting-started/first-agent"
           end)
  end

  test "signal routing pilot example exposes live view module and source files" do
    example = Examples.get_example!(@pilot_live_slug)

    assert example.slug == @pilot_live_slug
    assert example.status == :live
    assert example.live_view_module == "AgentJidoWeb.Examples.SignalRoutingAgentLive"

    assert example.source_files == [
             "lib/agent_jido/demos/signal_routing/signal_routing_agent.ex",
             "lib/agent_jido/demos/signal_routing/actions/increment_action.ex",
             "lib/agent_jido/demos/signal_routing/actions/set_name_action.ex",
             "lib/agent_jido/demos/signal_routing/actions/record_event_action.ex",
             "lib/agent_jido_web/examples/signal_routing_agent_live.ex"
           ]

    assert Enum.map(example.sources, & &1.path) == example.source_files
  end

  test "new published examples expose live view modules and existing source files" do
    Enum.each(@new_live_examples, fn {slug, live_view_module} ->
      example = Examples.get_example!(slug)

      assert example.status == :live
      assert example.live_view_module == live_view_module
      assert example.source_files != []
      assert Enum.map(example.sources, & &1.path) == example.source_files
      assert Enum.all?(example.source_files, &File.exists?/1)
    end)
  end

  test "live runnable examples no longer use the shared simulated showcase surface" do
    offenders =
      Examples.all_examples()
      |> Enum.filter(fn example ->
        example.evidence_surface == :runnable_example and
          (example.live_view_module == "AgentJidoWeb.Examples.SimulatedShowcaseLive" or
             "lib/agent_jido_web/examples/simulated_showcase_live.ex" in example.source_files)
      end)
      |> Enum.map(& &1.slug)

    assert offenders == []
  end

  test "shared simulated showcase examples are restricted to draft examples only" do
    simulator_backed_examples =
      Examples.all_examples(include_unpublished: true)
      |> Enum.filter(&(&1.live_view_module == "AgentJidoWeb.Examples.SimulatedShowcaseLive"))

    assert Enum.all?(simulator_backed_examples, &(&1.status == :draft))
  end

  describe "failure-drill-agent: crash-and-restart proof (jido-e08-t17)" do
    # Acceptance: "It proves restart behavior without claiming state recovery."

    test "is a published, real-runtime example" do
      example = Examples.get_example!("failure-drill-agent")

      assert example.status == :live
      assert example.demo_mode == :real
      assert example.evidence_surface == :runnable_example
    end

    test "its card contract proves restart behavior without claiming state recovery" do
      example = Examples.get_example!("failure-drill-agent")

      # Restart is the behavior the example proves.
      assert example.outcome =~ ~r/restart/i,
             "outcome must prove restart behavior"

      # The expected result makes non-recovery explicit: the in-memory counter
      # resets to its initial value after the restart, so state is not carried
      # across the crash.
      assert example.expected_result =~ ~r/resets? to 0/i,
             "expected_result must state the counter resets to 0"

      # The outcome -- the one sentence stating what this example proves -- must
      # not claim agent state is recovered across the crash.
      refute example.outcome =~ ~r/state.{0,24}recover|recover.{0,24}state/i,
             "outcome must not claim state recovery: #{inspect(example.outcome)}"
    end

    test "its runnable proof test encodes restart and the state reset" do
      example = Examples.get_example!("failure-drill-agent")

      assert example.run_command =~ "failure_drill_agent_test.exs",
             "run_command must point at the runnable proof test"

      {:ok, contents} = File.read("test/agent_jido/demos/failure_drill_agent_test.exs")

      # The proof test asserts the supervisor restarts the process and that the
      # restarted process comes back at its initial state (ticks == 0).
      assert contents =~ "restart"
      assert contents =~ "ticks == 0"
    end
  end
end
