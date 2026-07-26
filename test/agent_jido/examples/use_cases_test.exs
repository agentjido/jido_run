defmodule AgentJido.Examples.UseCasesTest do
  use ExUnit.Case, async: true

  alias AgentJido.Examples
  alias AgentJido.Examples.UseCases

  describe "entry_point/1 (E08-T25)" do
    # Acceptance condition: "The home research card links to one best entry
    # point." The resolver validates the designation so a home card never links
    # to a missing, unpublished, or out-of-scope example.

    test "resolves the designated best entry point for a use case" do
      assert UseCases.entry_point("research") == %{
               slug: "runic-ai-research-studio",
               title: "Runic AI Research Studio",
               href: "/examples/runic-ai-research-studio"
             }
    end

    test "the entry point is a real published example that matches the use case" do
      %{slug: slug} = UseCases.entry_point("research")
      example = Examples.get_example!(slug)

      # The entry point must be a public (non-draft) example...
      assert example.status == :live
      # ...that actually matches the research use case's tags.
      assert UseCases.scope([example], UseCases.fetch("research")) == [example]
    end

    test "returns nil when no entry point is designated" do
      for slug <- ~w(coding documents support devops data-pipelines) do
        assert UseCases.entry_point(slug) == nil,
               "expected #{slug} to have no designated entry point"
      end
    end

    test "returns nil for an unknown use case" do
      assert UseCases.entry_point("not-a-use-case") == nil
    end
  end
end
