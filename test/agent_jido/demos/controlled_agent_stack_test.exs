defmodule AgentJido.Demos.ControlledAgentStackTest do
  @moduledoc """
  Compatibility CI for the controlled-Agent dependency set (`jido-e09-t50`).

  Acceptance: *the documented versions install and run the integrated example
  together.* The controlled-Agent dependency set is the control matrix's package
  columns — one combination — and this test asserts both halves:

    * every documented version installs — published packages load at their
      stated Hex major, and unreleased packages pin a public GitHub repo;
    * the integrated controlled-agent example runs end to end with that set.

  Together that is the "one supported combination" the task names: the set is
  mutually installable and the example runs against it.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.ControlledAgentStack, as: Stack
  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.ControlMatrix
  alias AgentJido.Ecosystem.Stacks

  describe "packages/0 — the controlled-Agent dependency set as one combination" do
    test "names the six control packages in matrix display order" do
      assert Stack.packages() == [
               "jido",
               "jido_action",
               "jido_signal",
               "jido_ai",
               "ash_jido",
               "jido_otel"
             ]
    end

    test "is exactly the control matrix's package columns (single source of truth)" do
      # The combination is the set the operational-control matrix compares —
      # never a second hand-maintained list that can drift from it.
      matrix_keys = Enum.map(ControlMatrix.package_columns(), & &1.key)

      assert Stack.packages() == matrix_keys
    end
  end

  describe "the documented versions install together (the install bar)" do
    test "each published package loads at its stated Hex major" do
      for name <- Stack.packages(), published?(name) do
        vsn = assert_loaded_version!(name)

        assert loaded_major(vsn) == stated_major(name),
               "#{name} is stated at ~> #{stated_major(name)}.0 but loaded at #{vsn}"
      end
    end

    test "each unreleased package pins a public GitHub repo" do
      for name <- Stack.packages(), not published?(name) do
        package = Ecosystem.get_public_package(name)

        assert {package.github_org, package.github_repo} != {nil, nil},
               "#{name} is unreleased with no GitHub fallback recorded"
      end
    end

    test "the combination resolves to one pasteable, installable deps/0 block" do
      names = Stack.packages()
      block = Stacks.dependency_block(names)

      assert String.starts_with?(block, "defp deps do")
      assert String.ends_with?(block, "end")

      # Every line is a Hex major pin or a GitHub repo — i.e. each documented
      # version resolves on `mix deps.get`, the install bar.
      for name <- names do
        line = Stacks.dependency_line(name)

        assert line =~ ~r/"~> \d+\.0"/ or line =~ ~r/github: "[a-z0-9_\-]+\/[a-z0-9_\-]+"/,
               "expected an installable dep line for #{name}, got: #{inspect(line)}"

        assert block =~ "{:#{name},",
               "expected the controlled-Agent dependency block to include #{name}"
      end

      # No extra or missing lines — the block is exactly the combination.
      dep_count = Regex.scan(~r/\{:[a-z0-9_]+,/, block) |> length()
      assert dep_count == length(names)
    end
  end

  describe "run/0 — the integrated example runs with the set (the run bar)" do
    test "runs the integrated controlled agent end to end" do
      result = Stack.run()

      # Allowed path: the Action ran and advanced state (jido hooks + the
      # jido_action contract). The effect is real, not asserted.
      assert result.allowed.principal == "alice"
      assert result.allowed.policy_result == :allowed
      assert result.allowed.effect == %{approved_count: 1, delta: 1}

      # Denied path: the fail-closed hook rejected the Action before it ran, so
      # there is no effect.
      assert result.denied.principal == "mallory"
      assert result.denied.policy_result == {:denied, :unauthorized}
      assert result.denied.effect == :no_effect
    end
  end

  describe "the combination installs and runs together (jido-e09-t50)" do
    test "the documented versions install and run the integrated example together" do
      # Install bar: every documented version in the combination resolves.
      for name <- Stack.packages() do
        assert_installs(name)
      end

      # Run bar: the integrated example runs end to end with that set.
      result = Stack.run()

      assert result.allowed.policy_result == :allowed
      assert result.denied.policy_result == {:denied, :unauthorized}
    end
  end

  # --- helpers --------------------------------------------------------------

  # The acceptance bar, checked per package: the documented version resolves.
  #   * Published on Hex (hex_status like "2.2.0") — stated as `~> MAJOR.0`. The
  #     running application must be within the stated major.
  #   * Unreleased on Hex — the block pins the GitHub repo, which must be recorded.
  defp assert_installs(name) do
    package = Ecosystem.get_public_package(name)
    assert package != nil, "#{name} is not a public ecosystem package"

    case stated_major(name) do
      nil ->
        assert {package.github_org, package.github_repo} != {nil, nil},
               "#{name} is unreleased with no GitHub fallback recorded"

      major ->
        vsn = assert_loaded_version!(name)

        assert loaded_major(vsn) == major,
               "#{name} is stated at ~> #{major}.0 but loaded at #{vsn}"
    end
  end

  defp published?(name), do: stated_major(name) != nil

  # The leading major of a package's recorded published Hex version, or nil when
  # the package is unreleased.
  defp stated_major(name) do
    package = Ecosystem.get_public_package(name)

    case Regex.run(~r/^(\d+)\./, package.hex_status || "") do
      [_, major] -> major
      _other -> nil
    end
  end

  defp loaded_major(vsn) do
    case Regex.run(~r/^(\d+)\./, vsn) do
      [_, major] -> major
      _other -> nil
    end
  end

  defp assert_loaded_version!(name) do
    app = String.to_atom(name)

    case Application.spec(app, :vsn) do
      nil ->
        flunk("#{name} is stated as a published Hex package but application #{app} is not loaded")

      vsn ->
        to_string(vsn)
    end
  end
end
