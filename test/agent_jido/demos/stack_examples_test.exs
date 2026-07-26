defmodule AgentJido.Demos.StackExamplesTest do
  use ExUnit.Case, async: false

  alias AgentJido.Demos.StackExamples, as: SE
  alias AgentJido.Ecosystem

  # The Core example emits a Signal (jido_signal's extension registry), the AI
  # example resolves a model (req_llm + llm_db), and the Operate example starts
  # a messaging bus (jido_signal SignalBus + PubSub). All three need their
  # applications up.
  setup_all do
    Enum.each([:telemetry, :phoenix_pubsub, :jido_signal, :req_llm], &ensure_started/1)
    :ok
  end

  describe "Core stack minimal example (jido-e09-t09)" do
    # Acceptance condition: the example runs with the stated package versions.
    # The Core stack is jido, jido_action, jido_signal — all released and
    # loaded — so the example exercises every stated package.

    test "runs against jido, jido_action, and jido_signal" do
      result = SE.Core.run()

      # jido + jido_action: the validated action transitioned agent state.
      assert result.count == 3

      # jido_signal: a CloudEvents Signal was emitted and carries the new state.
      assert result.signal_type == "stack_core.ping"
      assert result.signal_data == %{count: 3}
    end

    test "the stated versions are the versions the example runs against" do
      assert_stated_versions_run(SE.Core.packages())
    end
  end

  describe "AI stack minimal example (jido-e09-t09)" do
    # Acceptance condition: the example runs with the stated package versions.
    # The AI stack is jido_ai, req_llm, llm_db — all released and loaded. The
    # example composes them without a provider call, so it runs keyless.

    test "runs against jido_ai, req_llm, and llm_db without a provider call" do
      result = SE.AI.run()

      # req_llm resolved the model id through the llm_db catalog.
      assert result.model_provider == :openai
      assert result.model_id == "gpt-4.1-mini"

      # jido_ai enriched the prompt with the retrieved context section.
      assert result.prompt =~ "known_facts"
      assert result.prompt =~ "ultimate question"

      # jido_ai constructed the AI agent wired with its tool: the ask/2 entry
      # point is generated only by `use Jido.AI.Agent`, and run/0 reached the
      # construction step without raising.
      assert result.agent_constructed
      assert function_exported?(SE.AI.Agent, :ask, 2)
    end

    test "the stated versions are the versions the example runs against" do
      assert_stated_versions_run(SE.AI.packages())
    end
  end

  describe "Operate stack minimal example (jido-e09-t09)" do
    # Acceptance condition: the example runs with the stated package versions.
    # The Operate stack is ash_jido, jido_messaging, jido_otel. jido_messaging
    # is the loaded package and the example runs it end to end; ash_jido and
    # jido_otel are unreleased, so their stated version is the GitHub repo the
    # home dependency block pins.

    test "runs the jido_messaging round-trip end to end" do
      result = SE.Operate.run()

      assert is_binary(result.room_id)
      assert result.message_count == 1
    end

    test "jido_messaging is loaded at the repo source the home block states" do
      package = Ecosystem.get_public_package("jido_messaging")

      # Unreleased on Hex — the home block pins the GitHub repo, and that repo
      # is loaded here, so the running example uses the stated source.
      assert published_major(package.hex_status) == nil
      assert app_loaded?(String.to_atom("jido_messaging"))
      assert {package.github_org, package.github_repo} != {nil, nil}
    end

    test "ash_jido and jido_otel are unreleased, matching the GitHub-fallback dep block" do
      for name <- ["ash_jido", "jido_otel"] do
        package = Ecosystem.get_public_package(name)

        assert published_major(package.hex_status) == nil,
               "#{name} should be unreleased so the home block pins its GitHub repo"

        assert {package.github_org, package.github_repo} != {nil, nil},
               "#{name} should record a public GitHub repo for the fallback"
      end
    end
  end

  describe "every stack has a tested minimal example (jido-e09-t09)" do
    test "each stack module runs and states its packages" do
      for %{key: key, module: module} <- SE.stacks() do
        result = module.run()

        assert is_map(result) and map_size(result) > 0,
               "the #{key} stack example should return a non-empty result"

        packages = module.packages()

        assert is_list(packages) and packages != [],
               "the #{key} stack example should state its packages"
      end
    end
  end

  # ----------------------------------------------------------- helpers ----

  # The acceptance bar, checked per stated package: the version the home
  # dependency block states is the version the running example uses.
  #
  #   * Published on Hex (hex_status like "2.2.0") — stated as `~> MAJOR.0`.
  #     The running example uses the loaded application, which must be within
  #     the stated major.
  #   * Unreleased on Hex — the home block pins the GitHub repo. The running
  #     example names these as integration contracts; the repo must be recorded.
  defp assert_stated_versions_run(package_names) do
    for name <- package_names do
      package = Ecosystem.get_public_package(name)
      assert package != nil, "#{name} is not a public ecosystem package"

      case published_major(package.hex_status) do
        nil ->
          assert {package.github_org, package.github_repo} != {nil, nil},
                 "#{name} is unreleased with no GitHub fallback recorded"

        major ->
          app = String.to_atom(name)
          vsn = assert_loaded_version!(app, name)

          assert loaded_major(vsn) == major,
                 "#{name} is stated at ~> #{major}.0 but loaded at #{vsn}"
      end
    end
  end

  defp published_major(hex_status) do
    case Regex.run(~r/^(\d+)\./, hex_status || "") do
      [_, major] -> major
      _ -> nil
    end
  end

  defp loaded_major(vsn) do
    case Regex.run(~r/^(\d+)\./, vsn) do
      [_, major] -> major
      _ -> nil
    end
  end

  defp assert_loaded_version!(app, name) do
    case Application.spec(app, :vsn) do
      nil ->
        flunk("#{name} is stated as a published Hex package but application #{app} is not loaded")

      vsn ->
        to_string(vsn)
    end
  end

  defp app_loaded?(app) do
    Application.spec(app, :vsn) != nil
  end

  defp ensure_started(app) do
    case Application.ensure_all_started(app) do
      {:ok, _apps} -> :ok
      {:error, {:already_started, _app}} -> :ok
      {:error, reason} -> raise "failed to start #{inspect(app)}: #{inspect(reason)}"
    end
  end
end
