defmodule AgentJido.ReleaseCatalogTest do
  use ExUnit.Case, async: true

  alias AgentJido.Pages.LivebookParser
  alias AgentJido.ReleaseCatalog

  test "exposes current package versions and requirements from ecosystem metadata" do
    assert ReleaseCatalog.version("jido") == "2.3.2"
    assert ReleaseCatalog.requirement("jido") == "~> 2.3"
    assert ReleaseCatalog.version("jido_ai") == "2.2.0"
    assert ReleaseCatalog.requirement("jido_ai") == "~> 2.2"
    assert ReleaseCatalog.version("req_llm") == "1.17.1"
    assert ReleaseCatalog.requirement("req_llm") == "~> 1.17"
  end

  test "renders mix dependency snippets from release metadata" do
    assert ReleaseCatalog.mix_dep("jido") == ~s({:jido, "~> 2.3"})
    assert ReleaseCatalog.mix_dep("jido_ai") == ~s({:jido_ai, "~> 2.2"})
    assert ReleaseCatalog.mix_dep("req_llm") == ~s({:req_llm, "~> 1.17"})
  end

  test "expands placeholders in static markdown and livebook content" do
    raw = """
    %{
      title: "Placeholder Example"
    }
    ---
    ```elixir
    Mix.install([
      {{mix_dep:jido}},
      {{mix_dep:jido_ai}},
      {{mix_dep:req_llm}}
    ])
    ```
    """

    {attrs, body} = LivebookParser.parse("placeholder-example.md", raw)

    assert attrs.title == "Placeholder Example"
    assert body =~ ~s({:jido, "~> 2.3"})
    assert body =~ ~s({:jido_ai, "~> 2.2"})
    assert body =~ ~s({:req_llm, "~> 1.17"})
    refute body =~ "{{mix_dep:"
  end

  test "expands contributor ecosystem atlas placeholder from ecosystem metadata" do
    raw = """
    %{
      title: "Atlas Placeholder"
    }
    ---
    {{contributors_ecosystem_atlas_tables}}
    """

    {attrs, body} = LivebookParser.parse("atlas-placeholder.md", raw)

    assert attrs.title == "Atlas Placeholder"
    assert body =~ "## Core"
    assert body =~ "## Integrations"
    assert body =~ "### Chat"
    assert body =~ "[Jido Chat](/ecosystem/jido_chat)"
    refute body =~ "{{contributors_ecosystem_atlas_tables}}"
  end

  test "actual docs sources expand released dependencies instead of github main guidance" do
    source =
      File.read!(Path.expand("../../priv/pages/docs/getting-started/first-llm-agent.livemd", __DIR__))

    {_attrs, body} =
      LivebookParser.parse(
        Path.expand("../../priv/pages/docs/getting-started/first-llm-agent.livemd", __DIR__),
        source
      )

    assert body =~ ~s({:jido, "~> 2.3"})
    assert body =~ ~s({:jido_ai, "~> 2.2"})
    assert body =~ ~s({:req_llm, "~> 1.17"})
    refute body =~ ~s(github: "agentjido/jido_ai")
  end
end
