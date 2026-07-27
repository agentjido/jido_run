defmodule AgentJido.UpstreamSkillRouterTest do
  use ExUnit.Case, async: true

  # jido-e10 E10-T31: the router skill must handle operational-control intent —
  # it selects the minimum relevant package skills and includes the
  # host-application duties no package ships. These tests read the router's own
  # content (SKILL.md) and its machine-readable manifest so the behavior cannot
  # regress, and they assert the manifest agrees with the prose (single source
  # of truth, mirroring the parity discipline used by the example/stack MCP
  # tools and the public ControlMatrix).

  @skill_dir Path.expand(
               "../../priv/skills/arrowcircle-jido-skills/skills/jido-skill-router",
               __DIR__
             )
  @skill_md Path.join(@skill_dir, "SKILL.md")
  @manifest Path.join(@skill_dir, "references/skill-manifest.yaml")

  # The adjacent package skills the router may add for a control dimension, and
  # the anchor that supplies authorization hooks + core observation. Matches the
  # public ControlMatrix (:supplies roles for jido / jido_signal / jido_otel).
  @anchor "jido"
  @adjacent_control_skills ~w(jido-signal jido-otel ash-jido)

  describe "the router recognizes operational-control intent (SKILL.md)" do
    test "carries a dedicated Operational-Control Routing section" do
      body = File.read!(@skill_md)

      assert body =~ "## Operational-Control Routing",
             "the router must teach operational-control routing as a named section"
    end

    test "selects the minimum relevant package skills — anchor plus a controlled adjacent set" do
      body = File.read!(@skill_md)

      # The anchor is core Jido: authorization hooks + observation + supervision.
      # Package skills are referenced in the prose as `$<skill>` (backtick-wrapped).
      assert body =~ "`$jido`",
             "the router must anchor operational control on $jido"

      assert body =~ "minimum",
             "the router must state it loads the minimum package set for control"

      for skill <- @adjacent_control_skills do
        assert body =~ "`$#{skill}`",
               "the router must name the adjacent control skill $#{skill}"
      end
    end

    test "includes host-application duties no package ships" do
      body = File.read!(@skill_md)

      # The acceptance condition: host-application duties are named explicitly.
      assert body =~ "Host-application duties",
             "the router must name the host-application duties section"

      # Approval is application-owned by every column in the public ControlMatrix;
      # the router must not imply a package ships it.
      assert body =~ "approval",
             "the router must call out approval as a host-application duty"

      # Authorization enforcement and spend stay with the host.
      assert body =~ "RBAC/ABAC enforcement" or body =~ "authorization decision",
             "the router must name authorization enforcement as a host duty"

      assert body =~ "spend",
             "the router must name overall spend as a host-application duty"
    end

    test "points at the canonical control surface instead of restating terms" do
      body = File.read!(@skill_md)

      assert body =~ "get_operational_control",
             "the router must point at the get_operational_control tool for canonical terms"

      assert body =~ "security-and-governance",
             "the router must point at the Security and governance page for the canonical control surface"
    end

    test "calls out the jido_ai gap rather than inventing a skill" do
      body = File.read!(@skill_md)

      assert body =~ "jido_ai",
             "the router must name the jido_ai package for AI policy/quotas"

      assert body =~ "no vendored skill",
             "the router must call out that jido_ai has no vendored skill"

      refute body =~ ~r/use \$jido-ai\b/i,
             "the router must not present a $jido-ai skill as routable"
    end
  end

  describe "the manifest agrees with the prose (parity)" do
    setup do
      # YamlElixir is a runtime dependency of the catalog; reuse it to parse the
      # manifest exactly as AgentJido.UpstreamSkillCatalog does at compile time.
      {:ok, manifest: YamlElixir.read_from_file!(@manifest)}
    end

    test "carries an operational_control block", %{manifest: manifest} do
      assert is_map(manifest["operational_control"]),
             "the manifest must carry an operational_control routing block"
    end

    test "the block selects the anchor and the controlled adjacent skills", %{manifest: manifest} do
      block = manifest["operational_control"]

      assert block["anchor"] == @anchor,
             "the manifest anchor must be #{@anchor}, got #{inspect(block["anchor"])}"

      adjacent = Enum.map(block["adjacent"] || [], & &1["skill"])

      for skill <- @adjacent_control_skills do
        assert skill in adjacent,
               "the manifest must list #{skill} as an adjacent control skill"
      end
    end

    test "the block includes host-application duties", %{manifest: manifest} do
      duties = manifest["operational_control"]["host_application_duties"]

      assert is_list(duties) and duties != [],
             "the manifest must carry non-empty host_application_duties"

      joined = Enum.join(duties, " ")

      assert joined =~ "approval",
             "the manifest host duties must name approval"

      assert joined =~ "authorization" or joined =~ "RBAC/ABAC",
             "the manifest host duties must name authorization enforcement"
    end

    test "the block records the jido_ai gap", %{manifest: manifest} do
      gap = manifest["operational_control"]["gap"]

      assert gap["package"] == "jido_ai",
             "the manifest gap must name the jido_ai package"

      assert gap["reason"] =~ "no vendored skill",
             "the manifest gap must state jido_ai has no vendored skill"
    end
  end
end
