defmodule AgentJidoWeb.LegacyRedirectsTest do
  use ExUnit.Case, async: true

  alias AgentJidoWeb.LegacyRedirects

  describe "retired training and getting-started redirects (E01-T13/T14/T15)" do
    test "retired training routes redirect to active Docs/Examples routes" do
      assert LegacyRedirects.destination("/training/agent-fundamentals") ==
               "/docs/getting-started/first-agent"

      assert LegacyRedirects.destination("/training/actions-validation") == "/docs/concepts/actions"
      assert LegacyRedirects.destination("/training/signals-routing") == "/docs/concepts/signals"

      assert LegacyRedirects.destination("/training/directives-scheduling") ==
               "/docs/concepts/directives"

      assert LegacyRedirects.destination("/training/liveview-integration") ==
               "/docs/getting-started/elixir-developers"

      assert LegacyRedirects.destination("/training/production-readiness") ==
               "/docs/guides/error-handling-and-recovery"
    end

    test "the legacy getting-started route redirects to the canonical docs route" do
      assert LegacyRedirects.destination("/getting-started") == "/docs/getting-started"
    end

    test ".md variants of redirected routes resolve to a markdown destination" do
      dest = LegacyRedirects.destination("/getting-started.md")
      assert is_binary(dest)
      assert String.ends_with?(dest, ".md")
    end
  end
end
