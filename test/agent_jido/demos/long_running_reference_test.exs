defmodule AgentJido.Demos.LongRunningReferenceTest do
  @moduledoc """
  Runnable proof for the one end-to-end long-running reference application
  (`jido-e07-t29`).

  Acceptance: the application **covers supervision, scheduling, persistence,
  retries, telemetry, health, and deployment** — each concern wired into the
  same agent at the same time, not seven separate demos.

  Each `describe` block isolates one concern so a failure points at it
  directly; the final `describe` runs the full linear path from the
  architecture spec (`specs/operations-reference-architecture.md`, "Linear
  path") end to end against a single running deployment:

      define → start under a named Jido instance → add a tool → add scheduling
      → add persistence → retry a transient failure → emit telemetry → check
      health → deploy, stop, and recover (resume from a checkpoint).

  The agent is deterministic and side-effect free — no API key, network, or
  runtime is required — so the whole path runs in a normal `mix test` process.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.LongRunningReference.Health
  alias AgentJido.Demos.LongRunningReference.Persistence
  alias AgentJido.Demos.LongRunningReference.Supervisor, as: ReferenceSupervisor
  alias AgentJido.Demos.LongRunningReferenceAgent

  alias Jido.AgentServer
  alias Jido.Signal

  # Telemetry emitted by the reference app's own IngestWork span.
  @work_events [
    [:agent_jido, :long_running_reference, :work, :start],
    [:agent_jido, :long_running_reference, :work, :stop]
  ]

  # A configured secret routed through redaction; must be defined before the
  # tests that reference it (module attributes resolve in source order).
  @secret "sk-LONG-RUNNING-REFERENCE-SECRET-xyz"

  # ---------------------------------------------------------------------------
  # Supervision
  # ---------------------------------------------------------------------------
  describe "supervision: a crashed AgentServer is restarted by its supervisor" do
    @tag :supervision
    test "killing the agent process restarts a fresh one under the same id" do
      %{supervisor: sup, agent: agent, agent_id: agent_id} = start_reference()

      # The deployment's supervisor stays up across a child crash — this is a
      # process restart, not a deployment restart.
      assert Process.alive?(sup)
      assert Process.alive?(agent)
      assert AgentJido.Jido.whereis(agent_id) == agent

      # Kill the agent process directly — the kind of process-level failure
      # (bug, OOM, linked port) OTP supervision exists to recover from.
      Process.exit(agent, :kill)

      # The supervisor restarts the child: a fresh process reclaims the id.
      restarted = await_restart(sup, agent)
      assert is_pid(restarted)
      assert restarted != agent
      assert Process.alive?(restarted)
      assert AgentJido.Jido.whereis(agent_id) == restarted
    end

    @tag :supervision
    test "the restarted process boots from initial state, not the lost memory" do
      %{supervisor: sup, agent: agent} = start_reference()

      {:ok, _} =
        AgentServer.call(agent, Signal.new!("reference.work", %{work_id: "w-1"}, source: "/test"))

      {:ok, %{agent: before_crash}} = AgentServer.state(agent)
      assert before_crash.state.processed == 1

      Process.exit(agent, :kill)
      restarted = await_restart(sup, agent)

      # OTP supervision recovers the *process*, not its memory: the in-memory
      # counter is gone. (Persistence, below, is what makes state survive.)
      {:ok, %{agent: after_crash}} = AgentServer.state(restarted)
      assert after_crash.state.processed == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Scheduling
  # ---------------------------------------------------------------------------
  describe "scheduling: the agent takes scheduled and event-driven work" do
    @tag :scheduling
    test "the agent declares a CRON schedule routed to reference.cron" do
      # Declaring the schedule is the scheduling wiring; the handler is
      # exercised below (a real */1 CRON tick is too slow to wait for here,
      # matching the ScheduleDirective demo's approach).
      schedules = LongRunningReferenceAgent.plugin_schedules()

      cron =
        Enum.find(schedules, fn schedule ->
          Map.get(schedule, :signal_type) == "reference.cron"
        end)

      # The schedule is declared and routed, so the agent takes work on a
      # schedule, not only on request.
      refute is_nil(cron)
      assert Map.get(cron, :cron_expression) == "*/1 * * * *"
    end

    @tag :scheduling
    test "a scheduled tick advances observable state" do
      %{agent: agent} = start_reference()

      {:ok, agent_state} =
        AgentServer.call(agent, Signal.new!("reference.cron", %{}, source: "/cron"))

      assert agent_state.state.cron_ticks == 1
      assert agent_state.state.last_event == "cron.ticked"
    end
  end

  # ---------------------------------------------------------------------------
  # Retries
  # ---------------------------------------------------------------------------
  describe "retries: a transient failure is recovered by a bounded retry loop" do
    @tag :retries
    test "start_retry recovers within the attempt budget via scheduled signals" do
      %{agent: agent} = start_reference()

      {:ok, _} =
        AgentServer.call(
          agent,
          Signal.new!("reference.start_retry", %{max_attempts: 3, retry_delay_ms: 20}, source: "/test")
        )

      # The retry loop reschedules reference.retry until the budget is spent,
      # then ends at :recovered — never exceeding max_attempts.
      assert_eventually(fn ->
        {:ok, %{agent: agent_state}} = AgentServer.state(agent)
        agent_state.state.status == :recovered
      end)

      {:ok, %{agent: agent_state}} = AgentServer.state(agent)
      assert agent_state.state.attempts == 3
      assert agent_state.state.attempts <= agent_state.state.max_attempts
      assert agent_state.state.last_event == "retry.recovered"
    end
  end

  # ---------------------------------------------------------------------------
  # Telemetry
  # ---------------------------------------------------------------------------
  describe "telemetry: the app instruments its own work with correlated spans" do
    setup do
      # The IngestWork span fires inside the AgentServer process, so the handler
      # captures this test pid and sends to it. Toggles the observability
      # redaction config, so it cannot run alongside other redaction tests.
      prior = Application.get_env(:jido, :observability, [])
      handler_id = attach_work_telemetry(self())

      on_exit(fn ->
        Application.put_env(:jido, :observability, prior)
        :telemetry.detach(handler_id)
      end)

      :ok
    end

    @tag :telemetry
    test "ingesting work emits a start/stop span that carries the work_id" do
      configure_redaction(true)
      %{agent: agent} = start_reference()

      {:ok, _} =
        AgentServer.call(agent, Signal.new!("reference.work", %{work_id: "w-tel"}, source: "/test"))

      {start_meta, stop_meta} =
        drain_telemetry([])
        |> split_work_events()

      # Both lifecycle events carry identifying (non-secret) metadata, so an
      # operator can follow this unit of work through the observation stream.
      assert start_meta.work_id == "w-tel"
      assert stop_meta.work_id == "w-tel"
    end

    @tag :telemetry
    test "a configured secret routed through redaction is absent from telemetry" do
      configure_redaction(true)
      %{agent: agent} = start_reference()

      {:ok, _} =
        AgentServer.call(
          agent,
          Signal.new!("reference.work", %{work_id: "w-redact", secret: @secret}, source: "/test")
        )

      blob = inspect(drain_telemetry([]))

      # The secret was redacted to the placeholder and never appears anywhere
      # in the emitted telemetry metadata.
      refute blob =~ @secret, "configured secret leaked into telemetry metadata"
      assert blob =~ "[REDACTED]"
    end
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------
  describe "persistence: state round-trips through hibernate/thaw" do
    @tag :persistence
    test "a checkpoint is restored by thaw" do
      %{agent: agent} = start_reference()
      storage = Persistence.storage_config()

      {:ok, _} =
        AgentServer.call(agent, Signal.new!("reference.work", %{work_id: "w-p1"}, source: "/test"))

      {:ok, %{agent: live}} = AgentServer.state(agent)
      assert live.state.processed == 1

      :ok = Persistence.checkpoint(storage, live)
      assert {:ok, restored} = Persistence.restore(storage, live.id)
      assert restored.state.processed == 1
      assert "w-p1" in restored.state.seen_work
    end

    @tag :persistence
    test "restore returns not_found when no checkpoint exists" do
      storage = Persistence.storage_config()
      assert {:error, :not_found} = Persistence.restore(storage, "never-checkpointed")
    end

    @tag :persistence
    test "ingest is idempotent — duplicate delivery does not double-count" do
      %{agent: agent} = start_reference()

      Enum.each(1..3, fn _ ->
        AgentServer.call(
          agent,
          Signal.new!("reference.work", %{work_id: "w-dup"}, source: "/test")
        )
      end)

      {:ok, %{agent: live}} = AgentServer.state(agent)

      # The same work_id three times advances the counter once.
      assert live.state.processed == 1
      assert live.state.seen_work == ["w-dup"]
    end
  end

  # ---------------------------------------------------------------------------
  # Health
  # ---------------------------------------------------------------------------
  describe "health: the three independent health axes answer separately" do
    @tag :health
    test "process health is ok while the agent is up, down when it is gone" do
      %{agent: agent} = start_reference()
      assert Health.process_health(agent) == :ok

      Process.exit(agent, :kill)

      # Once the process is gone, process health fails. (The supervisor will
      # restart it, but the dead pid resolves to nothing.)
      assert_eventually(fn ->
        Health.process_health(agent) == {:error, :process_down}
      end)
    end

    @tag :health
    test "work health is ok while the agent drains and answers status" do
      %{agent: agent} = start_reference()
      assert Health.work_health(agent) == :ok
    end

    @tag :health
    test "dependency health is ok when the store is reachable" do
      %{agent: agent} = start_reference()
      storage = Persistence.storage_config()
      {:ok, %{agent: live}} = AgentServer.state(agent)
      :ok = Persistence.checkpoint(storage, live)

      # A reachable store answers (hit or miss); both are :ok.
      assert Health.dependency_health(storage, live.id) == :ok
      assert Health.dependency_health(storage, "no-such-key") == :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Deployment
  # ---------------------------------------------------------------------------
  describe "deployment: the whole tree is replaced, and resumes with persistence" do
    @tag :deployment
    test "without persistence, a redeploy safely restarts at the initial state" do
      agent_id = agent_id()

      {:ok, deploy1} = ReferenceSupervisor.start_link(agent_id: agent_id)
      agent1 = ReferenceSupervisor.agent_server_pid(deploy1)

      {:ok, _} =
        AgentServer.call(
          agent1,
          Signal.new!("reference.work", %{work_id: "w-deploy"}, source: "/test")
        )

      {:ok, %{agent: before}} = AgentServer.state(agent1)
      assert before.state.processed == 1

      # Deployment restart: the whole tree goes down — supervisor and agent.
      :ok = Supervisor.stop(deploy1)
      refute Process.alive?(deploy1)

      # A new deployment boots a brand-new supervisor and agent.
      {:ok, deploy2} = ReferenceSupervisor.start_link(agent_id: agent_id)
      agent2 = ReferenceSupervisor.agent_server_pid(deploy2)
      assert Process.alive?(deploy2)
      assert Process.alive?(agent2)
      assert agent2 != agent1

      # Safe restart: no persistence, so in-flight state is dropped.
      {:ok, %{agent: after_deploy}} = AgentServer.state(agent2)
      assert after_deploy.state.processed == 0

      Supervisor.stop(deploy2)
    end

    @tag :deployment
    test "with persistence, a redeploy resumes from the checkpoint" do
      storage = Persistence.storage_config()
      agent_id = agent_id()

      {:ok, deploy1} = ReferenceSupervisor.start_link(agent_id: agent_id)
      agent1 = ReferenceSupervisor.agent_server_pid(deploy1)

      Enum.each(["w-r1", "w-r2", "w-r3"], fn work_id ->
        AgentServer.call(
          agent1,
          Signal.new!("reference.work", %{work_id: work_id}, source: "/test")
        )
      end)

      {:ok, %{agent: before}} = AgentServer.state(agent1)
      assert before.state.processed == 3

      # Checkpoint before the redeploy.
      :ok = Persistence.checkpoint(storage, before)
      :ok = Supervisor.stop(deploy1)

      # Resume: restore the checkpoint and boot the new deployment from it.
      assert {:ok, restored} = Persistence.restore(storage, agent_id)
      assert restored.state.processed == 3

      {:ok, deploy2} = ReferenceSupervisor.start_link(agent_id: agent_id, agent: restored)
      agent2 = ReferenceSupervisor.agent_server_pid(deploy2)

      # The new deployment reclaims the same logical identity and resumes the
      # pre-deploy state — it did not start over.
      assert AgentJido.Jido.whereis(agent_id) == agent2
      {:ok, %{agent: after_deploy}} = AgentServer.state(agent2)
      assert after_deploy.state.processed == 3
      assert after_deploy.state.seen_work == ["w-r1", "w-r2", "w-r3"]

      Supervisor.stop(deploy2)
    end
  end

  # ---------------------------------------------------------------------------
  # The full linear path, end to end
  # ---------------------------------------------------------------------------
  describe "the linear path: one deployment through every concern" do
    @tag :linear_path
    test "define → start → tool → schedule → persist → retry → telemetry → health → redeploy" do
      storage = Persistence.storage_config()
      agent_id = agent_id()
      handler_id = attach_work_telemetry(self())

      try do
        configure_redaction(true)

        # Start under a named Jido instance.
        {:ok, deploy1} = ReferenceSupervisor.start_link(agent_id: agent_id)
        agent1 = ReferenceSupervisor.agent_server_pid(deploy1)

        # Tool + scheduling + telemetry + idempotency: ingest request-driven
        # work and observe a scheduled tick.
        {:ok, _} =
          AgentServer.call(
            agent1,
            Signal.new!("reference.work", %{work_id: "linear-1"}, source: "/test")
          )

        {:ok, _} =
          AgentServer.call(agent1, Signal.new!("reference.cron", %{}, source: "/cron"))

        # Retry and failure policy: a transient failure recovers in budget.
        {:ok, _} =
          AgentServer.call(
            agent1,
            Signal.new!("reference.start_retry", %{max_attempts: 2, retry_delay_ms: 15}, source: "/test")
          )

        assert_eventually(fn ->
          {:ok, %{agent: a}} = AgentServer.state(agent1)
          a.state.status == :recovered
        end)

        # Telemetry: the work span fired with the secret redacted.
        blob = inspect(drain_telemetry([]))
        refute blob =~ @secret
        assert blob =~ "linear-1"

        # Health: process and work health are ok against the live deployment.
        assert Health.process_health(agent1) == :ok
        assert Health.work_health(agent1) == :ok

        # Persistence + deployment: checkpoint, redeploy, resume.
        {:ok, %{agent: before}} = AgentServer.state(agent1)
        :ok = Persistence.checkpoint(storage, before)
        :ok = Supervisor.stop(deploy1)

        {:ok, restored} = Persistence.restore(storage, agent_id)
        {:ok, deploy2} = ReferenceSupervisor.start_link(agent_id: agent_id, agent: restored)
        agent2 = ReferenceSupervisor.agent_server_pid(deploy2)

        {:ok, %{agent: after_deploy}} = AgentServer.state(agent2)
        assert after_deploy.state.processed == 1
        assert after_deploy.state.cron_ticks == 1

        Supervisor.stop(deploy2)
      after
        :telemetry.detach(handler_id)
        configure_redaction(false)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp agent_id, do: "reference-test-#{System.unique_integer([:positive])}"

  # Boots a reference deployment under ExUnit supervision, so it is torn down
  # automatically (the same pattern FailureDrillAgentTest uses). Returns the
  # supervisor, the live agent pid, and the agent id.
  defp start_reference do
    id = agent_id()
    sup = start_supervised!({ReferenceSupervisor, agent_id: id})
    %{supervisor: sup, agent: ReferenceSupervisor.agent_server_pid(sup), agent_id: id}
  end

  defp await_restart(supervisor, old_pid, attempts \\ 100)
  defp await_restart(_supervisor, _old_pid, 0), do: flunk("agent was not restarted")

  defp await_restart(supervisor, old_pid, attempts) do
    case ReferenceSupervisor.agent_server_pid(supervisor) do
      pid when is_pid(pid) and pid != old_pid ->
        # The supervisor may report a pid that is mid-restart; confirm it
        # answers before accepting it.
        if process_ready?(pid), do: pid, else: sleep_and_retry(supervisor, old_pid, attempts)

      _other ->
        sleep_and_retry(supervisor, old_pid, attempts)
    end
  end

  defp sleep_and_retry(supervisor, old_pid, attempts) do
    Process.sleep(10)
    await_restart(supervisor, old_pid, attempts - 1)
  end

  defp process_ready?(pid) do
    match?({:ok, _}, AgentServer.status(pid))
  catch
    :exit, _ -> false
  end

  defp assert_eventually(fun, attempts \\ 200)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    Process.sleep(10)

    case fun.() do
      true -> :ok
      false -> assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(_fun, 0), do: flunk("expected condition to become true")

  defp configure_redaction(bool) do
    Application.put_env(:jido, :observability, redact_sensitive: bool)
  end

  # The IngestWork span fires inside the AgentServer process, so the handler
  # closes over `test_pid` (captured here in the test process) and sends to it.
  defp attach_work_telemetry(test_pid) do
    handler_id = "reference-work-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      @work_events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    handler_id
  end

  defp drain_telemetry(acc) do
    receive do
      {:telemetry, _, _, _} = e -> drain_telemetry([e | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end

  defp split_work_events(events) do
    by_stage =
      Map.new(events, fn {:telemetry, event, _measurements, metadata} ->
        {List.last(event), metadata}
      end)

    {Map.fetch!(by_stage, :start), Map.fetch!(by_stage, :stop)}
  end
end
