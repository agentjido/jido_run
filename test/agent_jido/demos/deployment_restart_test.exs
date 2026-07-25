defmodule AgentJido.Demos.DeploymentRestartTest do
  @moduledoc """
  Runnable proof for the "Deployment restart" example (`jido-e07-t14`).

  Acceptance: "The workflow resumes or safely restarts with stated semantics."

  A deployment restart is *not* a process restart. The entire supervised tree
  — the supervisor and its agent — is torn down and a fresh tree is booted (a
  deploy, a release upgrade, a node restart). These tests simulate that by
  starting the demo supervisor (the deployment), accumulating observable
  state in its agent, stopping the **whole** tree with `Supervisor.stop/1`,
  and starting a second supervisor (a new deployment). They then assert the
  two things the acceptance requires:

    * the whole deployment is **replaced** — the old supervisor and agent are
      dead, a new supervisor and agent are live; and
    * the workflow **safely restarts** with stated semantics — the new
      deployment's agent comes back at its *initial* state, so in-flight work
      is dropped, not resumed. Resuming (replaying persisted state) is named
      here as the application-owned alternative and exercised on the durable
      history lane, not in this demo.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.DeploymentRestart.Supervisor, as: DeploymentSupervisor
  alias AgentJido.Demos.DeploymentRestartAgent

  alias Jido.AgentServer
  alias Jido.Signal

  describe "DeploymentRestartAgent.new/0" do
    test "creates an agent with a zeroed event counter" do
      agent = DeploymentRestartAgent.new()
      assert agent.state.events == 0
    end
  end

  describe "deployment restart: the whole tree is replaced" do
    @tag :deployment_restart
    test "stopping the deployment tears down the supervisor and the agent" do
      agent_id = unique_id()

      {:ok, deploy1} = DeploymentSupervisor.start_link(agent_id: agent_id)
      agent1 = DeploymentSupervisor.agent_server_pid(deploy1)

      assert is_pid(agent1)
      assert Process.alive?(deploy1)
      assert Process.alive?(agent1)

      # Restart the deployment: the whole tree goes down.
      :ok = Supervisor.stop(deploy1)

      # There is no surviving parent here — the supervisor itself is gone,
      # unlike a process crash where the parent supervisor stays up.
      refute Process.alive?(deploy1)
      refute Process.alive?(agent1)
    end

    @tag :deployment_restart
    test "a new deployment boots a distinct, live supervisor and agent" do
      agent_id = unique_id()

      {:ok, deploy1} = DeploymentSupervisor.start_link(agent_id: agent_id)
      agent1 = DeploymentSupervisor.agent_server_pid(deploy1)

      :ok = Supervisor.stop(deploy1)

      {:ok, deploy2} = DeploymentSupervisor.start_link(agent_id: agent_id)
      agent2 = DeploymentSupervisor.agent_server_pid(deploy2)

      # A brand-new supervisor and a brand-new agent process.
      assert deploy2 != deploy1
      assert agent2 != agent1
      assert Process.alive?(deploy2)
      assert Process.alive?(agent2)

      Supervisor.stop(deploy2)
    end

    @tag :deployment_restart
    test "the same logical identity is reclaimed by the new process" do
      agent_id = unique_id()

      {:ok, deploy1} = DeploymentSupervisor.start_link(agent_id: agent_id)
      agent1 = DeploymentSupervisor.agent_server_pid(deploy1)
      assert AgentJido.Jido.whereis(agent_id) == agent1

      :ok = Supervisor.stop(deploy1)

      # The dead process's registry entry is freed asynchronously (the
      # Registry cleans it up on the DOWN message), so wait for it to clear
      # rather than racing the cleanup. Once cleared, between deployments the
      # identity resolves to nothing.
      assert await_registry_clear(agent_id) == nil

      {:ok, deploy2} = DeploymentSupervisor.start_link(agent_id: agent_id)
      agent2 = DeploymentSupervisor.agent_server_pid(deploy2)

      # After the redeploy the same id resolves to the new process, and the
      # status API reports the carried identity behind that new process.
      assert AgentJido.Jido.whereis(agent_id) == agent2

      assert {:ok, status} = AgentServer.status(agent2)
      assert status.pid == agent2
      assert status.agent_id == agent_id

      Supervisor.stop(deploy2)
    end
  end

  describe "deployment restart: safely restarts, not resumes" do
    @tag :deployment_restart
    test "in-flight state is dropped — the new deployment starts at initial state" do
      agent_id = unique_id()

      {:ok, deploy1} = DeploymentSupervisor.start_link(agent_id: agent_id)
      agent1 = DeploymentSupervisor.agent_server_pid(deploy1)

      # Accumulate observable state in the first deployment.
      Enum.each(1..3, fn _ ->
        {:ok, _agent} =
          AgentServer.call(
            agent1,
            Signal.new!("deployment_restart.record", %{by: 1}, source: "/test")
          )
      end)

      # Before the redeploy, the observed state reflects the accumulated work.
      {:ok, %{agent: agent_before}} = AgentServer.state(agent1)
      assert agent_before.state.events == 3

      # Restart the deployment — the whole tree is replaced.
      :ok = Supervisor.stop(deploy1)
      {:ok, deploy2} = DeploymentSupervisor.start_link(agent_id: agent_id)
      agent2 = DeploymentSupervisor.agent_server_pid(deploy2)

      # The observed result is explicit, not assumed. The new deployment's
      # agent is live, but its state is the initial state: the three events
      # that lived only in the first deployment's memory were dropped. The
      # workflow safely restarted — it did not resume mid-flight.
      assert {:ok, %{agent: agent_after}} = AgentServer.state(agent2)
      assert agent_after.state.events == 0

      Supervisor.stop(deploy2)
    end

    @tag :deployment_restart
    test "the new deployment serves new work after the redeploy" do
      agent_id = unique_id()

      {:ok, deploy1} = DeploymentSupervisor.start_link(agent_id: agent_id)
      _agent1 = DeploymentSupervisor.agent_server_pid(deploy1)
      :ok = Supervisor.stop(deploy1)

      {:ok, deploy2} = DeploymentSupervisor.start_link(agent_id: agent_id)
      agent2 = DeploymentSupervisor.agent_server_pid(deploy2)

      {:ok, agent} =
        AgentServer.call(
          agent2,
          Signal.new!("deployment_restart.record", %{by: 2}, source: "/test")
        )

      # Fresh state, then fresh work counted correctly from the initial state.
      assert agent.state.events == 2

      Supervisor.stop(deploy2)
    end
  end

  defp unique_id, do: "deployment-restart-test-#{System.unique_integer([:positive])}"

  # The Registry frees a dead process's key on its DOWN message, which is
  # asynchronous. Wait for that cleanup so the test does not race it.
  defp await_registry_clear(agent_id, attempts \\ 200)
  defp await_registry_clear(agent_id, 0), do: AgentJido.Jido.whereis(agent_id)

  defp await_registry_clear(agent_id, attempts) do
    case AgentJido.Jido.whereis(agent_id) do
      nil ->
        nil

      _pid ->
        Process.sleep(5)
        await_registry_clear(agent_id, attempts - 1)
    end
  end
end
