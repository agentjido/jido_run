defmodule AgentJido.EcosystemControlMatrixTest do
  use ExUnit.Case, async: true

  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.ControlMatrix

  # Acceptance condition (jido-e09-t49): a reader can compare context,
  # authorization hooks, policy, quotas, history, observation, export, approval,
  # and integration duties. The matrix must expose exactly those nine dimensions
  # as rows and one column per control package plus a host-application column,
  # with a grounded role and a non-empty clause in every cell — so the
  # comparison the backlog names is complete and never silently gaps.

  describe "capabilities/0 — the nine comparison dimensions" do
    test "exposes exactly the nine dimensions the backlog names, in order" do
      assert Enum.map(ControlMatrix.capabilities(), & &1.key) ==
               [
                 :context,
                 :authorization_hooks,
                 :policy,
                 :quotas,
                 :history,
                 :observation,
                 :export,
                 :approval,
                 :integration_duties
               ]
    end

    test "each dimension carries a label and a one-line description" do
      for capability <- ControlMatrix.capabilities() do
        assert is_binary(capability.label) and capability.label != "",
               "expected a label for #{capability.key}"

        assert is_binary(capability.description) and capability.description != "",
               "expected a description for #{capability.key}"
      end
    end
  end

  describe "columns/0 — the control packages plus the host application" do
    test "lists the control packages followed by the host-application column" do
      keys = Enum.map(ControlMatrix.columns(), & &1.key)

      assert keys ==
               ["jido", "jido_action", "jido_signal", "jido_ai", "ash_jido", "jido_otel", "host"]
    end

    test "package columns resolve to a real public package and link to their page" do
      for column <- ControlMatrix.columns(), column.kind == :package do
        assert Ecosystem.get_public_package(column.key) != nil,
               "the #{column.key} column must name a real public package"

        assert column.path == "/ecosystem/#{column.key}"
      end
    end

    test "the host column is synthetic — no package, no link" do
      host = Enum.find(ControlMatrix.columns(), &(&1.key == "host"))

      assert host.kind == :host
      assert is_nil(host.path)
    end
  end

  describe "matrix/0 — one grounded cell per capability and column" do
    test "returns one row per capability in order, with a cell per column" do
      matrix = ControlMatrix.matrix()
      column_keys = ControlMatrix.column_keys()

      assert Enum.map(matrix, & &1.key) == ControlMatrix.capability_keys()

      for row <- matrix do
        assert Map.keys(row.cells) |> MapSet.new() == MapSet.new(column_keys),
               "expected the #{row.key} row to carry one cell per column"

        for col_key <- column_keys do
          cell = Map.fetch!(row.cells, col_key)

          assert cell.role in [:supplies, :preserves, :app],
                 "expected a valid role for #{row.key}/#{col_key}, got #{inspect(cell.role)}"

          assert is_binary(cell.text) and cell.text != "",
                 "expected a non-empty clause for #{row.key}/#{col_key}"
        end
      end
    end

    test "the control each dimension is known for is supplied by the right package" do
      matrix = ControlMatrix.matrix() |> Map.new(&{&1.key, &1.cells})

      # Authorization hooks are the fail-closed prepare_action/3 plugin hooks
      # shipped by core Jido.
      assert matrix[:authorization_hooks]["jido"].role == :supplies

      # AI tool/effect/prompt policy and request/token quotas ship with jido_ai.
      assert matrix[:policy]["jido_ai"].role == :supplies
      assert matrix[:quotas]["jido_ai"].role == :supplies

      # Durable, replayable history is the optional Signal Journal (jido_signal).
      assert matrix[:history]["jido_signal"].role == :supplies

      # Core observation is the in-process telemetry jido emits; OTel export is
      # the separate jido_otel package.
      assert matrix[:observation]["jido"].role == :supplies
      assert matrix[:export]["jido_otel"].role == :supplies

      # ash_jido preserves context and Ash policy but the host enforces — it
      # never owns the decision.
      assert matrix[:context]["ash_jido"].role == :preserves
      assert matrix[:authorization_hooks]["ash_jido"].role == :preserves
      assert matrix[:policy]["ash_jido"].role == :preserves
    end

    test "approval is application-owned by every column — no package ships an approval workflow" do
      matrix = ControlMatrix.matrix() |> Enum.find(&(&1.key == :approval))

      for {_col_key, cell} <- matrix.cells do
        assert cell.role == :app,
               "approval must stay application-owned; no package supplies an approval workflow"
      end
    end

    test "integration duties states what each column leaves to the application or platform" do
      matrix = ControlMatrix.matrix() |> Enum.find(&(&1.key == :integration_duties))

      # This row is the boundary summary: every cell is application-owned,
      # naming the duty each column hands off.
      for {_col_key, cell} <- matrix.cells do
        assert cell.role == :app
        assert cell.text != ""
      end
    end
  end

  describe "role_label/1 — legend labels" do
    test "returns a label for every role the grid uses" do
      for role <- [:supplies, :preserves, :app] do
        label = ControlMatrix.role_label(role)
        assert is_binary(label) and label != ""
      end
    end
  end

  describe "package_columns/0 — registry-backed package columns" do
    test "returns every package column the registry carries" do
      keys = Enum.map(ControlMatrix.package_columns(), & &1.key)

      assert keys == ["jido", "jido_action", "jido_signal", "jido_ai", "ash_jido", "jido_otel"]
    end
  end
end
