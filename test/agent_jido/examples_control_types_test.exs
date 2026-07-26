defmodule AgentJido.ExamplesControlTypesTest do
  @moduledoc """
  E08-T35: add control types to the public example contract.

  Acceptance: "Each example can list identity context, authorization, policy,
  quota, approval, history, observation, and redaction."

  The Example card contract carries a `control_types` field — a list of the
  operational-control types an example proves it exercises. The canonical set is
  owned by `AgentJido.Examples.Taxonomy.control_types/0`, and the frontmatter
  value is normalized to that set (unknown members dropped, duplicates removed),
  so every published card only ever carries a clean subset of the eight control
  types named in the acceptance. These tests lock that contract.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Examples
  alias AgentJido.Examples.Example
  alias AgentJido.Examples.Taxonomy

  # The eight control types named verbatim by the acceptance condition.
  @acceptance_control_types [
    identity_context: "identity context",
    authorization: "authorization",
    policy: "policy",
    quota: "quota",
    approval: "approval",
    history: "history",
    observation: "observation",
    redaction: "redaction"
  ]

  @controlled_agent_slug "controlled-agent"

  describe "the control-type contract (jido-e08-t35)" do
    test "the Example struct exposes a control_types field that defaults to []" do
      minimal = %Example{slug: "x", title: "x", live_view_module: "x"}

      assert :control_types in Map.keys(minimal)
      assert minimal.control_types == []
    end

    test "Taxonomy.control_types/0 is exactly the eight acceptance control types" do
      expected = Keyword.keys(@acceptance_control_types)

      assert Taxonomy.control_types() == expected,
             "control_types/0 must be exactly the acceptance set"
    end

    test "each acceptance control type can be listed on an example" do
      Enum.each(@acceptance_control_types, fn {type, label} ->
        normalized = Taxonomy.metadata(control_types: [type]) |> Map.get(:control_types)

        assert type in normalized,
               "an example must be able to list #{label} (#{inspect(type)})"
      end)
    end

    test "an example can list all eight control types at once" do
      all = Keyword.keys(@acceptance_control_types)

      assert Taxonomy.metadata(control_types: all) |> Map.get(:control_types) ==
               all
    end
  end

  describe "control-type normalization" do
    test "unknown control types are dropped from the canonical set" do
      normalized = Taxonomy.metadata(control_types: [:authorization, :bogus, :redaction])

      assert normalized.control_types == [:authorization, :redaction]
    end

    test "duplicate control types are removed" do
      normalized = Taxonomy.metadata(control_types: [:policy, :policy, :quota])

      assert normalized.control_types == [:policy, :quota]
    end

    test "string control types are accepted and matched case/whitespace-insensitively" do
      normalized = Taxonomy.metadata(control_types: [" Identity_Context ", "POLICY"])

      assert normalized.control_types == [:identity_context, :policy]
    end

    test "a missing control_types value normalizes to []" do
      assert Taxonomy.metadata(%{}).control_types == []
      assert Taxonomy.metadata(control_types: nil).control_types == []
    end
  end

  describe "every published example's control_types stays within the canonical set" do
    # The build pipeline normalizes frontmatter to the canonical set, so this is
    # a contract gate: a live example can never surface an out-of-set control
    # type to a public card.
    test "no live example lists a control type outside control_types/0" do
      canonical = MapSet.new(Taxonomy.control_types())

      offenders =
        Examples.all_examples()
        |> Enum.filter(fn example ->
          example.control_types
          |> List.wrap()
          |> Enum.any?(&(not MapSet.member?(canonical, &1)))
        end)
        |> Enum.map(& &1.slug)

      assert offenders == [],
             "live examples listed out-of-set control types: #{inspect(offenders)}"
    end

    test "every live example's control_types is a unique list" do
      Enum.each(Examples.all_examples(), fn example ->
        types = List.wrap(example.control_types)

        assert types == Enum.uniq(types),
               "#{example.slug} has duplicate control types: #{inspect(types)}"
      end)
    end
  end

  describe "controlled-agent: the integrated control-path example" do
    # controlled-agent is the one published example that exercises control types
    # directly. It implements identity context (IncomingContext + IngressPlugin),
    # authorization + policy (the fail-closed AuthorizationPlugin allowlist),
    # observation (Jido.Observe spans/logs in Redaction + correlation IDs), and
    # redaction (the Redaction module). Quota, approval, and durable history are
    # isolated in focused demos that are not published examples, so they are not
    # attributed here — consistent with the site's no-over-claim proof stance.
    test "lists exactly the control types it implements" do
      example = Examples.get_example!(@controlled_agent_slug)

      assert example.control_types == [
               :identity_context,
               :authorization,
               :policy,
               :observation,
               :redaction
             ]
    end

    test "every listed control type is in the canonical set" do
      example = Examples.get_example!(@controlled_agent_slug)

      Enum.each(example.control_types, fn type ->
        assert type in Taxonomy.control_types(),
               "controlled-agent listed an out-of-set control type: #{inspect(type)}"
      end)
    end
  end
end
