defmodule AgentJido.EcosystemPriorityPackagesTest do
  use ExUnit.Case, async: true

  alias AgentJido.Ecosystem

  describe "priority_packages/0 (jido-e12-t18)" do
    test "returns the core (tier 1) and official (tier 2) packages" do
      packages = Ecosystem.priority_packages()

      assert packages != []
      assert Enum.all?(packages, &(&1.tier in [1, 2]))

      # Every tier-1 and tier-2 package is included.
      assert Enum.all?(Ecosystem.packages_by_tier(1), &(&1 in packages))
      assert Enum.all?(Ecosystem.packages_by_tier(2), &(&1 in packages))
    end

    test "excludes community (tier 3) packages" do
      tier3 = Ecosystem.packages_by_tier(3)
      assert tier3 != []

      packages = Ecosystem.priority_packages()
      assert Enum.all?(tier3, &(&1 not in packages))
    end

    test "includes the foundational core packages" do
      ids = Ecosystem.priority_packages() |> Enum.map(& &1.id) |> MapSet.new()

      ["jido", "jido_action", "jido_signal", "jido_ai", "req_llm"]
      |> Enum.all?(&MapSet.member?(ids, &1))
      |> assert()
    end
  end

  describe "priority_package?/1 (jido-e12-t18)" do
    test "accepts a package struct or a package id" do
      jido = Ecosystem.get_package!("jido")

      assert Ecosystem.priority_package?(jido) == true
      assert Ecosystem.priority_package?("jido") == true
      assert Ecosystem.priority_package?("jido_action") == true
      assert Ecosystem.priority_package?("ash_jido") == true
    end

    test "returns false for community (tier 3) packages" do
      assert Ecosystem.packages_by_tier(3) != []
      assert Ecosystem.priority_package?("jido_phx_starter") == false
    end

    test "returns false for an unknown package id" do
      assert Ecosystem.priority_package?("does_not_exist") == false
    end
  end

  test "priority packages carry an owner so a review task can be assigned" do
    # Public priority packages all carry a tech lead (owner) so a material
    # upstream README change creates assigned, attributable work (jido-e12-t18).
    public_priority =
      Ecosystem.priority_packages()
      |> Enum.filter(&(&1.visibility == :public))

    assert Enum.all?(public_priority, &is_binary(&1.tech_lead))
  end
end
