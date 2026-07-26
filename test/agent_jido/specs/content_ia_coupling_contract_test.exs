defmodule AgentJido.Specs.ContentIaCouplingContractTest do
  use ExUnit.Case, async: true

  # E12-T34: a route or navigation change must update the content outline, the
  # content system, and the taxonomy together. These tests lock that rule into
  # the Contributor PR checklist and the specs index so it cannot regress.

  @contributor_docs_path Path.expand("../../../specs/contributor-docs.md", __DIR__)
  @specs_readme_path Path.expand("../../../specs/README.md", __DIR__)

  # The three IA spec documents a route/nav change must update in the same PR.
  @ia_spec_docs ["content-outline.md", "content-system.md", "taxonomy.md"]

  describe "the three IA spec documents exist as canonical sources" do
    test "content-outline.md, content-system.md, and taxonomy.md are present" do
      Enum.each(@ia_spec_docs, fn doc ->
        path = Path.expand("../../../specs/#{doc}", __DIR__)

        assert File.exists?(path),
               "expected canonical IA spec specs/#{doc} to exist"
      end)
    end
  end

  describe "the Contributor PR checklist gates route/nav changes on all three IA specs" do
    test "the checklist section is present" do
      assert String.contains?(
               File.read!(@contributor_docs_path),
               "## Contributor PR checklist"
             ),
             "contributor-docs.md must keep the '## Contributor PR checklist' section"
    end

    test "every IA spec doc is named in the checklist gate" do
      checklist = checklist_section()

      Enum.each(@ia_spec_docs, fn doc ->
        assert checklist =~ "`specs/#{doc}`",
               "the Contributor PR checklist must require updating specs/#{doc} for route/nav changes"
      end)
    end
  end

  describe "the specs index couples route/nav changes to the three IA specs" do
    test "the Source rule names all three IA spec docs" do
      readme = File.read!(@specs_readme_path)

      assert readme =~ "If you change IA, routes, or nav",
             "specs/README.md Source rule must state the route/nav coupling requirement"

      Enum.each(@ia_spec_docs, fn doc ->
        assert readme =~ doc,
               "specs/README.md Source rule must name #{doc} for route/nav changes"
      end)
    end
  end

  # Returns only the tail after the "## Contributor PR checklist" heading so the
  # IA-spec assertions are specific to the checklist itself, not the whole file.
  defp checklist_section do
    case String.split(File.read!(@contributor_docs_path), "## Contributor PR checklist", parts: 2) do
      [_, checklist] -> checklist
      [_] -> flunk("contributor-docs.md is missing the '## Contributor PR checklist' section")
    end
  end
end
