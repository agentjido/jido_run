defmodule AgentJido.UpstreamSkillCatalogTest do
  use ExUnit.Case, async: true

  alias AgentJido.UpstreamSkillCatalog

  test "exposes the vendored upstream skill counts and support file metadata" do
    assert UpstreamSkillCatalog.count() == 13
    assert UpstreamSkillCatalog.package_count() == 12
    assert UpstreamSkillCatalog.router_count() == 1
    assert UpstreamSkillCatalog.support_file_count() == 24
    assert UpstreamSkillCatalog.skills_root_source_path() == "priv/skills/arrowcircle-jido-skills/skills"
    assert UpstreamSkillCatalog.source_prompt_source_path() == "priv/skills/arrowcircle-jido-skills/source/prompts.md"
  end

  test "maps vendored skill entries to copied source paths and public ecosystem pages when available" do
    entries = UpstreamSkillCatalog.all_entries()
    names = Enum.map(entries, & &1.name)

    assert "jido-skill-router" in names
    assert "jido-action" in names
    assert "req-llm" in names

    router = Enum.find(entries, &(&1.id == "jido-skill-router"))
    assert router.category == :router
    assert router.skill_source_path == "priv/skills/arrowcircle-jido-skills/skills/jido-skill-router/SKILL.md"
    assert router.reference_files == ["priv/skills/arrowcircle-jido-skills/skills/jido-skill-router/references/skill-manifest.yaml"]
    assert router.agent_files == ["priv/skills/arrowcircle-jido-skills/skills/jido-skill-router/agents/openai.yaml"]

    req_llm = Enum.find(entries, &(&1.id == "req-llm"))
    assert req_llm.category == :package
    assert req_llm.ecosystem_package_id == "req_llm"
    assert req_llm.ecosystem_path == "/ecosystem/req_llm"
    assert req_llm.upstream_url == "https://github.com/arrowcircle/jido-skills/tree/main/skills/req-llm"
  end

  # jido-e10 E10-T24: every card must carry a package, task, maturity note,
  # and source so a contributor can choose a skill without opening its files.
  describe "package/task/maturity/source enrichment (jido-e10-t24)" do
    test "every package skill surfaces package, task, maturity, and source" do
      for entry <- UpstreamSkillCatalog.package_entries() do
        assert is_binary(entry.package_name) and entry.package_name != "",
               "package_name missing on #{entry.id}"

        assert is_binary(entry.task) and entry.task != "",
               "task missing on #{entry.id}"

        assert entry.use_when != [],
               "use_when triggers missing on #{entry.id}"

        assert is_binary(entry.maturity_label) and entry.maturity_label != "",
               "maturity_label missing on #{entry.id}"

        assert is_binary(entry.maturity_note) and entry.maturity_note != "",
               "maturity_note missing on #{entry.id}"

        assert is_binary(entry.skill_source_path) and entry.skill_source_path != "",
               "skill_source_path missing on #{entry.id}"

        assert is_binary(entry.upstream_url) and entry.upstream_url != "",
               "upstream_url missing on #{entry.id}"
      end
    end

    test "req-llm resolves the upstream package, stable maturity, and source links" do
      req_llm = Enum.find(UpstreamSkillCatalog.all_entries(), &(&1.id == "req-llm"))

      assert req_llm.package_name == "req_llm"
      assert req_llm.task == "provider transport and LLM request execution"
      assert req_llm.use_when == ["provider adapters", "request shaping", "streaming", "structured output transport"]
      assert req_llm.maturity_label == "Stable"
      assert String.starts_with?(req_llm.maturity_note, "Stable —")
      assert req_llm.hex_url == "https://hex.pm/packages/req_llm"
      assert req_llm.hexdocs_url == "https://hexdocs.pm/req_llm"
    end

    test "beta packages carry a distinct maturity label and note" do
      messaging = Enum.find(UpstreamSkillCatalog.all_entries(), &(&1.id == "jido-messaging"))

      assert messaging.maturity_label == "Beta"
      assert String.starts_with?(messaging.maturity_note, "Beta —")
      # Beta packages surface the api-stability caveat inside the note.
      assert messaging.maturity_note =~ "breaking changes"
    end

    test "the router skill carries a task and maturity note but no single package" do
      router = Enum.find(UpstreamSkillCatalog.all_entries(), &(&1.id == "jido-skill-router"))

      assert router.category == :router
      assert is_binary(router.task) and router.task != ""
      assert router.use_when != []
      assert is_binary(router.maturity_note) and router.maturity_note != ""
      assert is_nil(router.package_name)
      assert is_nil(router.hex_url)
    end

    test "exposes the manifest source path" do
      assert UpstreamSkillCatalog.manifest_source_path() ==
               "priv/skills/arrowcircle-jido-skills/skills/jido-skill-router/references/skill-manifest.yaml"
    end
  end
end
