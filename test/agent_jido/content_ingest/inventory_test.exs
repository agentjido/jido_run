defmodule AgentJido.ContentIngest.InventoryTest do
  use ExUnit.Case, async: true

  alias AgentJido.Blog
  alias AgentJido.ContentIngest.Inventory
  alias AgentJido.ContentIngest.Source
  alias AgentJido.Ecosystem
  alias AgentJido.Examples
  alias AgentJido.Pages
  alias AgentJido.UpstreamSkillCatalog

  describe "build/1" do
    test "returns all managed sources with unique ids" do
      sources = Inventory.build()
      docs_pages = ingestible_docs_pages()

      expected_count =
        length(docs_pages) +
          length(Blog.all_posts()) +
          length(Ecosystem.public_packages()) +
          length(Examples.all_examples()) +
          length(UpstreamSkillCatalog.package_entries())

      assert length(sources) == expected_count
      assert Enum.all?(sources, &match?(%Source{}, &1))

      source_ids = Enum.map(sources, & &1.source_id)
      assert length(source_ids) == length(Enum.uniq(source_ids))

      assert Enum.all?(sources, fn source ->
               source.metadata["managed_by"] == Inventory.managed_by()
             end)

      assert Enum.all?(sources, fn source ->
               hash = source.metadata["content_hash"]
               is_binary(hash) and byte_size(hash) == 64
             end)

      assert Enum.all?(sources, fn source ->
               source.text |> String.trim() |> byte_size() > 0
             end)
    end

    test "supports docs-only scope" do
      sources = Inventory.build(only: [:docs])
      docs_pages = ingestible_docs_pages()

      assert length(sources) == length(docs_pages)

      assert Enum.all?(sources, fn source ->
               String.starts_with?(source.source_id, "docs:") and source.collection == "site_docs"
             end)
    end

    test "excludes retired build and training pages from docs inventory" do
      sources = Inventory.build(only: [:docs])

      refute Enum.any?(sources, &String.starts_with?(&1.source_id, "docs:/build"))
      refute Enum.any?(sources, &String.starts_with?(&1.source_id, "docs:/training"))
    end

    test "supports examples-only scope with one source per public example" do
      sources = Inventory.build(only: [:examples])

      assert length(sources) == length(Examples.all_examples())

      assert Enum.all?(sources, fn source ->
               String.starts_with?(source.source_id, "examples:") and
                 source.collection == "site_examples"
             end)

      persistence = Enum.find(sources, &(&1.source_id == "examples:persistence-storage-agent"))
      assert persistence != nil
      assert persistence.metadata["title"] == "Persistence Storage Agent"
      assert persistence.metadata["url"] == "/examples/persistence-storage-agent"
      assert persistence.metadata["source_type"] == "examples"

      assert persistence.text =~ "/examples/persistence-storage-agent"

      # Example tasks/packages/outcomes are indexed fields (jido-e10-t02).
      assert "persistence" in persistence.metadata["tasks"]
      assert persistence.metadata["packages"] == ["jido"]
      assert persistence.metadata["outcome"] =~ "hibernate/thaw"
      assert persistence.text =~ "persistence"

      # failure-drill-agent carries no "recovery" term in its own
      # tags/description/outcome/body; the canonical :recovery task label is
      # the sole source of the term, so its presence proves task indexing.
      failure_drill = Enum.find(sources, &(&1.source_id == "examples:failure-drill-agent"))
      assert failure_drill != nil
      assert "recovery" in failure_drill.metadata["tasks"]
      assert failure_drill.text =~ "recovery"
    end

    test "supports skills-only scope with one source per public package skill" do
      # Public package skills are indexed so a "<package> skill" query returns
      # the matching card (jido-e10-t03).
      sources = Inventory.build(only: [:skills])

      assert length(sources) == length(UpstreamSkillCatalog.package_entries())

      assert Enum.all?(sources, fn source ->
               String.starts_with?(source.source_id, "skills:") and
                 source.collection == "site_skills"
             end)

      signal = Enum.find(sources, &(&1.source_id == "skills:jido-signal"))

      assert signal != nil
      assert signal.metadata["title"] == "Jido Signal"
      assert signal.metadata["source_type"] == "skills"
      assert signal.metadata["category"] == "package"

      # The skill's ecosystem package id is indexed so a package query matches.
      assert signal.metadata["ecosystem_package_id"] == "jido_signal"

      # A hit lands on the matching card's anchor, not the top of the catalog.
      assert signal.metadata["url"] == "/skills#skill-card-jido-signal"
      assert signal.text =~ "/skills#skill-card-jido-signal"
      assert signal.text =~ "jido_signal"
    end
  end

  defp ingestible_docs_pages do
    Pages.all_pages()
    |> Enum.reject(fn page ->
      String.starts_with?(page.path, "/build") or String.starts_with?(page.path, "/training")
    end)
  end
end
