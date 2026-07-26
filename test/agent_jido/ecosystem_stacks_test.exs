defmodule AgentJido.EcosystemStacksTest do
  use ExUnit.Case, async: true

  alias AgentJido.Demos.StackExamples
  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.Stacks

  # Acceptance condition (jido-e09-t36): supported package ranges are explicit.
  # Every stack package must carry a concrete, installable range derived from the
  # authoritative registry — a Hex major requirement for published packages, or
  # a GitHub repo pin for unreleased ones — with no nil ranges and no drift from
  # the home dependency blocks.

  describe "stacks/0 — the three main stacks" do
    test "returns Core, AI, and Operate in display order" do
      assert Enum.map(Stacks.stacks(), & &1.key) == ~w(core ai operate)
      assert Enum.map(Stacks.stacks(), & &1.name) == ~w(Core AI Operate)
    end

    test "each stack carries a one-line purpose and named packages with roles" do
      for stack <- Stacks.stacks() do
        assert is_binary(stack.purpose) and stack.purpose != "",
               "expected the #{stack.key} stack to carry a purpose"

        assert stack.packages != [],
               "expected the #{stack.key} stack to list at least one package"

        for pkg <- stack.packages do
          assert is_binary(pkg.name) and pkg.name != ""

          assert is_binary(pkg.role) and pkg.role != "",
                 "expected #{pkg.name} in the #{stack.key} stack to carry a role"
        end
      end
    end

    test "package composition matches the runnable StackExamples (single source of truth)" do
      # StackExamples is the tested source of truth for which packages each stack
      # exercises (jido-e09-t09). Stacks must agree so the matrix, the home card,
      # and the runnable example never name different packages.
      for %{key: key, module: module} <- StackExamples.stacks() do
        example = module.packages() |> Enum.sort()
        declared = Stacks.get_stack!(key).packages |> Enum.map(& &1.name) |> Enum.sort()

        assert declared == example,
               "the #{key} stack declares #{inspect(declared)} but its runnable example " <>
                 "exercises #{inspect(example)}"
      end
    end
  end

  describe "supported_range/1 — explicit ranges derived from the registry" do
    test "every stack package has an explicit, non-nil range" do
      for pkg <- stack_package_names() do
        range = Stacks.supported_range(pkg)

        assert is_binary(range) and range != "",
               "expected an explicit supported range for #{pkg}, got #{inspect(range)}"
      end
    end

    test "published packages pin to their recorded Hex major" do
      for {name, pkg} <- stack_packages(), published?(pkg) do
        expected = "~> #{hex_major(pkg.hex_status)}.0"

        assert Stacks.supported_range(name) == expected,
               "expected #{name} (hex_status #{inspect(pkg.hex_status)}) to resolve to #{expected}"
      end
    end

    test "unreleased packages fall back to their public GitHub repo" do
      for {name, pkg} <- stack_packages(), not published?(pkg) do
        expected = "github: \"#{pkg.github_org}/#{pkg.github_repo}\""

        assert Stacks.supported_range(name) == expected,
               "expected the unreleased #{name} to pin to #{expected}"
      end
    end

    test "source/1 classifies Hex-published vs GitHub-pinned packages" do
      for {name, pkg} <- stack_packages() do
        source = Stacks.source(name)

        assert source == if(published?(pkg), do: :hex, else: :github),
               "unexpected source #{inspect(source)} for #{name}"
      end
    end
  end

  describe "dependency_line/1 and dependency_block/1 — parity with install" do
    test "each line resolves: a Hex major pin or a public GitHub repo" do
      for name <- stack_package_names() do
        line = Stacks.dependency_line(name)

        assert line =~ ~r/"~> \d+\.0"/ or line =~ ~r/github: "[a-z0-9_\-]+\/[a-z0-9_\-]+"/,
               "expected an installable dep line for #{name}, got: #{inspect(line)}"
      end
    end

    test "a stack's dependency block lists exactly its packages in a pasteable deps/0 function" do
      for stack <- Stacks.stacks() do
        block = Stacks.dependency_block(stack.packages)

        names = Enum.map(stack.packages, & &1.name)

        assert String.starts_with?(block, "defp deps do")
        assert String.ends_with?(block, "end")

        for name <- names do
          assert block =~ "{:#{name},",
                 "expected the #{stack.key} block to include the #{name} dependency"
        end

        # The dep count matches the package count — no extra or missing lines.
        dep_count = Regex.scan(~r/\{:[a-z0-9_]+,/, block) |> length()
        assert dep_count == length(names)
      end
    end
  end

  describe "matrix/0 — enriched rows for the compatibility view" do
    test "returns one enriched row per stack with a derived entry per package" do
      matrix = Stacks.matrix()

      assert Enum.map(matrix, & &1.key) == ~w(core ai operate)

      for stack <- matrix do
        assert is_binary(stack.purpose)

        for pkg <- stack.packages do
          # The range and source are derived, not hardcoded, and every package
          # links to its own detail page.
          assert pkg.range == Stacks.supported_range(pkg.name)
          assert pkg.source == Stacks.source(pkg.name)
          assert pkg.source_label == Stacks.source_label(pkg.source)
          assert pkg.support_level in [:stable, :beta, :experimental]
          assert pkg.path == "/ecosystem/#{pkg.name}"
        end
      end
    end
  end

  # --- helpers --------------------------------------------------------------

  defp stack_package_names, do: stack_packages() |> Enum.map(&elem(&1, 0))

  defp stack_packages do
    for stack <- Stacks.stacks(),
        %{name: name} <- stack.packages,
        do: {name, Ecosystem.get_public_package!(name)}
  end

  defp published?(%{hex_status: hex_status}), do: hex_major(hex_status) != nil

  defp hex_major(hex_status) do
    case Regex.run(~r/^(\d+)\./, hex_status || "") do
      [_, major] -> major
      _other -> nil
    end
  end
end
