defmodule AgentJido.OnboardingVersionMetadataTest do
  @moduledoc """
  E05-T28: every onboarding lane surfaces package-version metadata so a reader
  can see the last validation date and the versions the page was tested with.

  The getting-started lanes — first-agent, first-llm-agent, the Phoenix
  starter, and Add operational controls — each carry `last_validated`
  (ISO date) and `tested_with` (a map of package/version pairs) in their
  frontmatter. The Page schema
  (`lib/agent_jido/pages/page.ex`) exposes both as top-level fields, mirroring
  the Example card contract (`lib/agent_jido/examples/example.ex`) and the
  canonical metadata names used by the freshness/validation backlog
  (E06-T11, E06-T12, E12-T14). The docs shell renders them so a reader sees
  them; that rendering is covered by the flaky LiveView test in
  `PageLiveTest` ("onboarding version metadata").
  """
  use ExUnit.Case, async: true

  alias AgentJido.Pages

  @lanes [
    {"/docs/getting-started/first-agent", "priv/pages/docs/getting-started/first-agent.livemd", [:jido]},
    {"/docs/getting-started/first-llm-agent", "priv/pages/docs/getting-started/first-llm-agent.livemd", [:jido, :jido_ai, :req_llm]},
    {"/docs/getting-started/phoenix-starter", "priv/pages/docs/getting-started/phoenix-starter.md", [:jido, :jido_ai, :req_llm]},
    {"/docs/getting-started/operational-controls", "priv/pages/docs/getting-started/operational-controls.md", [:jido, :jido_ai, :req_llm]}
  ]

  describe "onboarding lanes declare package-version metadata (jido-e05-t28)" do
    for {path, source, expected_packages} <- @lanes do
      test "#{path} frontmatter carries last_validated and tested_with" do
        body = File.read!(unquote(source))

        assert body =~ ~r/last_validated:\s*"/,
               "#{unquote(source)} must declare a last_validated date"

        assert body =~ ~r/tested_with:\s*%\{/,
               "#{unquote(source)} must declare a tested_with map of package/version pairs"

        for pkg <- unquote(expected_packages) do
          assert body =~ ~r/tested_with:.*#{pkg}:/s,
                 "#{unquote(source)} must list #{pkg} inside tested_with"
        end
      end

      test "#{path} Page struct exposes last_validated and tested_with" do
        page = Pages.get_page_by_path(unquote(path))
        expected_packages = unquote(expected_packages)

        assert page != nil, "expected a published page at #{unquote(path)}"

        assert String.match?(page.last_validated, ~r/^\d{4}-\d{2}-\d{2}$/),
               "#{unquote(path)} last_validated must be an ISO date, got: #{inspect(page.last_validated)}"

        assert is_map(page.tested_with) and map_size(page.tested_with) > 0,
               "#{unquote(path)} tested_with must be a non-empty map"

        for pkg <- expected_packages do
          assert Map.has_key?(page.tested_with, pkg),
                 "#{unquote(path)} tested_with must include #{pkg}, got: #{inspect(page.tested_with)}"

          assert is_binary(page.tested_with[pkg]) and page.tested_with[pkg] != "",
                 "#{unquote(path)} tested_with[#{pkg}] must be a non-empty version string"
        end
      end
    end
  end
end
