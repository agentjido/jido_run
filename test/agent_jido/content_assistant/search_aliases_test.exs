defmodule AgentJido.ContentAssistant.SearchAliasesTest do
  use ExUnit.Case, async: true

  alias AgentJido.ContentAssistant.SearchAliases

  describe "aliases_for_route/1" do
    test "returns the alias phrases registered for a canonical route" do
      aliases = SearchAliases.aliases_for_route("/docs/concepts/agent-runtime")

      # "agent server" (two words) and "long-running" do not appear in the
      # agent-runtime page body, so their presence here is what makes the page
      # retrievable for those colloquial terms.
      assert "agent server" in aliases
      assert "AgentServer" in aliases
      assert "long-running" in aliases
    end

    test "returns an empty list for a route with no aliases" do
      assert SearchAliases.aliases_for_route("/ecosystem/jido") == []
    end

    test "is insensitive to a trailing slash" do
      assert SearchAliases.aliases_for_route("/features/tools") ==
               SearchAliases.aliases_for_route("/features/tools/")
    end
  end

  describe "routes_for_query/1" do
    test "matches when every token of an alias phrase is present in the query" do
      # The exact common user terms from jido-e10-t04 each resolve to their
      # canonical page.
      assert SearchAliases.routes_for_query("agent server") ==
               ["/docs/concepts/agent-runtime"]

      assert SearchAliases.routes_for_query("AgentServer") ==
               ["/docs/concepts/agent-runtime"]

      assert SearchAliases.routes_for_query("supervision") ==
               ["/docs/operations/supervision-and-failure-boundaries"]

      assert SearchAliases.routes_for_query("restart") ==
               ["/docs/operations/process-crash-and-restart"]

      assert SearchAliases.routes_for_query("durable") ==
               ["/docs/concepts/persistence"]

      assert SearchAliases.routes_for_query("long-running") ==
               ["/docs/concepts/agent-runtime"]

      assert SearchAliases.routes_for_query("tools") == ["/features/tools"]

      assert SearchAliases.routes_for_query("function calling") ==
               ["/docs/learn/ai-agent-with-tools"]
    end

    test "matches a colloquial term embedded in a longer natural query" do
      assert SearchAliases.routes_for_query("how does the agent server work") ==
               ["/docs/concepts/agent-runtime"]

      assert SearchAliases.routes_for_query("show me the function calling guide") ==
               ["/docs/learn/ai-agent-with-tools"]
    end

    test "does not match when only a proper subset of tokens is present" do
      # "agent" alone must not trigger the "agent server" alias.
      assert SearchAliases.routes_for_query("agent") == []
      # "running" alone must not trigger "long-running".
      assert SearchAliases.routes_for_query("running") == []
      # A generic programming query must not trigger "function calling".
      assert SearchAliases.routes_for_query("define a function") == []
    end

    test "returns an empty list for blank or non-matching queries" do
      assert SearchAliases.routes_for_query("") == []
      assert SearchAliases.routes_for_query("   ") == []
      assert SearchAliases.routes_for_query("what is jido") == []
    end
  end

  describe "retired training terms (jido-e10-t05)" do
    # The public Training section was retired; each old /training slug must lead
    # to the active Docs page it redirects to. The mapping mirrors
    # AgentJidoWeb.LegacyRedirects.
    test "aliases_for_route/1 registers each retired Training term on its replacement" do
      assert SearchAliases.aliases_for_route("/docs/getting-started") == ["training"]

      assert SearchAliases.aliases_for_route("/docs/getting-started/first-agent") ==
               ["agent fundamentals"]

      assert SearchAliases.aliases_for_route("/docs/concepts/actions") == ["actions validation"]

      assert SearchAliases.aliases_for_route("/docs/concepts/signals") == ["signals routing"]

      assert SearchAliases.aliases_for_route("/docs/concepts/directives") ==
               ["directives scheduling"]

      assert SearchAliases.aliases_for_route("/docs/getting-started/elixir-developers") ==
               ["liveview integration"]

      assert SearchAliases.aliases_for_route("/docs/guides/error-handling-and-recovery") ==
               ["production readiness"]
    end

    test "routes_for_query/1 resolves each retired Training term to its active Docs page" do
      assert SearchAliases.routes_for_query("training") == ["/docs/getting-started"]

      assert SearchAliases.routes_for_query("agent fundamentals") ==
               ["/docs/getting-started/first-agent"]

      assert SearchAliases.routes_for_query("actions validation") == ["/docs/concepts/actions"]

      assert SearchAliases.routes_for_query("signals routing") == ["/docs/concepts/signals"]

      assert SearchAliases.routes_for_query("directives scheduling") ==
               ["/docs/concepts/directives"]

      assert SearchAliases.routes_for_query("liveview integration") ==
               ["/docs/getting-started/elixir-developers"]

      assert SearchAliases.routes_for_query("production readiness") ==
               ["/docs/guides/error-handling-and-recovery"]
    end

    test "matches a retired Training term hyphenated as the old route slug" do
      # The retired /training route slugs were hyphenated; tokenization collapses
      # the hyphen, so the spaced alias phrase still matches the old slug form.
      assert SearchAliases.routes_for_query("signals-routing") == ["/docs/concepts/signals"]

      assert SearchAliases.routes_for_query("production-readiness") ==
               ["/docs/guides/error-handling-and-recovery"]
    end

    test "matches a retired Training term embedded in a longer query" do
      assert SearchAliases.routes_for_query("where did the training section go") ==
               ["/docs/getting-started"]

      assert SearchAliases.routes_for_query("old actions validation guide") ==
               ["/docs/concepts/actions"]
    end

    test "does not match when only a proper subset of a multi-word term is present" do
      # "signals" alone must not trigger the "signals routing" alias; the bare
      # concept term is handled by ordinary lexical matching, not alias rerank.
      assert SearchAliases.routes_for_query("signals") == []
      assert SearchAliases.routes_for_query("routing") == []
      assert SearchAliases.routes_for_query("production") == []
    end
  end

  describe "operational-control terms (jido-e10-t27)" do
    # The nine dimensions a production agent touches — identity context,
    # authorization, audit, observability, policy, quota, approval, redaction,
    # and the controlled-Agent pattern — are one operational-control model, so
    # each resolves to the canonical Security and Governance guide rather than
    # whichever page mentions the word most. The controlled-Agent example
    # names that page as "the full operational-control model."
    @guide "/docs/operations/security-and-governance"

    test "aliases_for_route/1 registers every control term on the canonical guide" do
      assert SearchAliases.aliases_for_route(@guide) == [
               "identity context",
               "authorization",
               "audit",
               "observability",
               "policy",
               "quota",
               "approval",
               "redaction",
               "controlled agent"
             ]
    end

    test "routes_for_query/1 resolves each control term to the canonical guide" do
      for term <-
            ~w(authorization audit observability policy quota approval redaction) do
        assert SearchAliases.routes_for_query(term) == [@guide],
               "expected the single-token control term #{inspect(term)} to resolve to the guide"
      end

      # The two multi-word control terms resolve as phrases.
      assert SearchAliases.routes_for_query("identity context") == [@guide]
      assert SearchAliases.routes_for_query("controlled agent") == [@guide]
    end

    test "matches a control term embedded in a longer natural query" do
      # "redaction" and "audit" are both single-token aliases on the same guide,
      # so a query carrying either (or both) resolves to the guide once.
      assert SearchAliases.routes_for_query("how do I add authorization to an action") == [@guide]

      assert SearchAliases.routes_for_query("what does redaction cover in the audit trail") ==
               [@guide]
    end

    test "does not match when only a proper subset of a multi-word term is present" do
      # "identity" or "context" alone must not trigger the "identity context"
      # alias; "agent" alone must not trigger "controlled agent".
      assert SearchAliases.routes_for_query("identity") == []
      assert SearchAliases.routes_for_query("context") == []
      assert SearchAliases.routes_for_query("agent") == []
    end
  end
end
