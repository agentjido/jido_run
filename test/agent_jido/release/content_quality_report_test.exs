defmodule AgentJido.Release.ContentQualityReportTest do
  use ExUnit.Case, async: true

  alias AgentJido.Release.ContentQualityReport

  # Plain maps stand in for Page/Example structs in the pure-function tests.
  # drift_for_item/failed_livebooks read the needed keys directly, and
  # safe_route/1 falls back to :path when Pages.route_for/1 has no clause match.

  describe "version_drift/3" do
    test "emits a finding only when a documented version differs from the ecosystem's" do
      page = %{path: "/docs/learn/x", title: "X", tested_with: %{jido: "2.3.2"}}
      versions = %{"jido" => "2.4.0"}

      [finding] = ContentQualityReport.version_drift([page], [], versions)

      assert finding.package == "jido"
      assert finding.documented == "2.3.2"
      assert finding.current == "2.4.0"
      assert finding.source == "/docs/learn/x"
      assert finding.title == "X"
    end

    test "skips packages not in the ecosystem (external deps) and matching versions" do
      page = %{
        path: "/docs/learn/x",
        title: "X",
        # jido matches, req_llm is an external dep not tracked by the ecosystem.
        tested_with: %{jido: "2.3.2", req_llm: "1.17.1"}
      }

      versions = %{"jido" => "2.3.2"}

      assert ContentQualityReport.version_drift([page], [], versions) == []
    end

    test "skips unreleased packages (version 0.0.0 / blank) to avoid false drift" do
      page = %{path: "/docs/x", title: "X", tested_with: %{jido_beta: "0.1.0"}}

      assert ContentQualityReport.version_drift([page], [], %{"jido_beta" => "0.0.0"}) == []
      assert ContentQualityReport.version_drift([page], [], %{"jido_beta" => ""}) == []
    end

    test "covers examples alongside pages, keyed by slug" do
      example = %{slug: "weather-agent", title: "Weather", tested_with: %{jido: "2.3.2"}}

      [finding] = ContentQualityReport.version_drift([], [example], %{"jido" => "2.5.0"})

      assert finding.source == "example:weather-agent"
      assert finding.package == "jido"
    end

    test "treats atom and string tested_with keys identically" do
      atom_key = %{path: "/docs/a", title: "A", tested_with: %{jido: "2.3.2"}}
      string_key = %{path: "/docs/b", title: "B", tested_with: %{"jido" => "2.3.2"}}

      findings = ContentQualityReport.version_drift([atom_key, string_key], [], %{"jido" => "2.4.0"})

      assert length(findings) == 2
    end
  end

  describe "failed_livebooks/2" do
    test "surfaces runnable notebooks whose source path has no matching drift test" do
      covered = MapSet.new(["priv/pages/docs/covered.livemd"])

      runnable = [
        %{source_path: "/build/app/priv/pages/docs/covered.livemd", title: "Covered", path: "/docs/covered"},
        %{source_path: "/build/app/priv/pages/docs/secret.livemd", title: "Secret", path: "/docs/secret"}
      ]

      [gap] = ContentQualityReport.failed_livebooks(runnable, covered)

      assert gap.source_path == "priv/pages/docs/secret.livemd"
      assert gap.route == "/docs/secret"
      assert gap.title == "Secret"
    end

    test "returns no gaps when every runnable notebook is covered" do
      covered = MapSet.new(["priv/pages/docs/a.livemd"])
      runnable = [%{source_path: "priv/pages/docs/a.livemd", title: "A", path: "/docs/a"}]

      assert ContentQualityReport.failed_livebooks(runnable, covered) == []
    end
  end

  describe "collect_drift_test_targets/1" do
    test "collects the livebook path each drift test references" do
      root = Path.join(System.tmp_dir!(), "cqr_drift_#{System.unique_integer([:positive])}")
      test_dir = Path.join(root, "test/livebooks/docs")
      File.mkdir_p!(test_dir)

      File.write!(Path.join(test_dir, "alpha_livebook_test.exs"), """
      defmodule AlphaLivebookTest do
        use AgentJido.LivebookCase, livebook: "priv/pages/docs/alpha.livemd"
      end
      """)

      File.write!(Path.join(test_dir, "beta_livebook_test.exs"), """
      defmodule BetaLivebookTest do
        use AgentJido.LivebookCase, livebook: "priv/pages/docs/beta.livemd"
      end
      """)

      on_exit(fn -> File.rm_rf!(root) end)

      targets = ContentQualityReport.collect_drift_test_targets(root)

      assert MapSet.member?(targets, "priv/pages/docs/alpha.livemd")
      assert MapSet.member?(targets, "priv/pages/docs/beta.livemd")
    end

    test "returns an empty set when the test directory is absent" do
      root = Path.join(System.tmp_dir!(), "cqr_empty_#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf!(root) end)

      assert ContentQualityReport.collect_drift_test_targets(root) == MapSet.new()
    end
  end

  describe "render_report/1" do
    test "renders all five signals together" do
      report =
        clean_report(%{
          broken_links: %{
            route_count: 5,
            internal_count: 10,
            unmatched_internal: [%{source: "priv/pages/docs/a.md", path: "/no/such/route", kind: :md}],
            external_failures: []
          },
          stale_pages: [
            %{
              source: "/docs/operations/x",
              title: "X",
              owner: "alice",
              kind: :critical_page,
              section: "operations",
              last_validated: nil,
              days_since_validation: nil
            }
          ],
          version_drift: [
            %{source: "/docs/learn/y", title: "Y", package: "jido", documented: "2.3.2", current: "2.4.0"}
          ],
          failed_livebooks: [
            %{source_path: "priv/pages/docs/z.livemd", route: "/docs/z", title: "Z"}
          ],
          no_result_queries: %{available: true, window_days: 30, rows: [%{query: "agent retries", visitors: 3}]}
        })

      body = ContentQualityReport.render_report(report)

      assert body =~ "# Monthly Content-Quality Dashboard"
      assert body =~ "## Broken Links"
      assert body =~ "## Stale Pages"
      assert body =~ "## Version Drift"
      assert body =~ "## Failed Livebooks"
      assert body =~ "## No-Result Search Queries"

      # Each signal's findings render.
      assert body =~ "`/no/such/route`"
      assert body =~ "last validated: never"
      assert body =~ "owner: alice"
      assert body =~ "ecosystem now `2.4.0`"
      assert body =~ "`priv/pages/docs/z.livemd`"
      assert body =~ "agent retries — 3 visitor(s)"
    end

    test "renders the no-result section as unavailable when the database is absent" do
      report =
        clean_report(%{
          no_result_queries: %{available: false, window_days: 30, rows: []}
        })

      body = ContentQualityReport.render_report(report)

      assert body =~ "Unavailable — the analytics database could not be reached"
      assert body =~ "No-result search phrases: unavailable"
    end

    test "renders an empty-state line for each clean signal" do
      report = clean_report(%{})

      body = ContentQualityReport.render_report(report)

      assert body =~ "No broken internal links found"
      assert body =~ "No stale pages or examples"
      assert body =~ "No version drift"
      assert body =~ "No coverage gaps"
    end
  end

  describe "run/1" do
    # E12-T30: the dashboard is informational — it aggregates the five
    # content-quality signals so they are visible together. It is not a release
    # gate, so run/1 always returns {:ok, report} and renders every signal,
    # degrading the database-backed no-result section to `unavailable` rather
    # than failing the whole report.
    @tag :release_gate
    test "returns {:ok, report} with all five signals present" do
      report_path =
        Path.join(
          System.tmp_dir!(),
          "content_quality_report_#{System.unique_integer([:positive])}.md"
        )

      on_exit(fn -> File.rm(report_path) end)

      assert {:ok, report} = ContentQualityReport.run(report_path: report_path)

      assert Map.fetch!(report, :broken_links) |> Map.has_key?(:unmatched_internal)
      assert is_list(report.stale_pages)
      assert is_list(report.version_drift)
      assert is_list(report.failed_livebooks)
      assert is_boolean(report.no_result_queries.available)

      assert File.exists?(report_path)

      body = File.read!(report_path)

      assert body =~ "# Monthly Content-Quality Dashboard"
      assert body =~ "## Broken Links"
      assert body =~ "## Stale Pages"
      assert body =~ "## Version Drift"
      assert body =~ "## Failed Livebooks"
      assert body =~ "## No-Result Search Queries"
    end
  end

  # Merge partial overrides onto a default report so render tests stay focused.
  defp clean_report(overrides) do
    %{
      generated_at: DateTime.utc_now(),
      window_days: 30,
      broken_links: %{route_count: 0, internal_count: 0, unmatched_internal: [], external_failures: []},
      stale_pages: [],
      version_drift: [],
      failed_livebooks: [],
      no_result_queries: %{available: true, window_days: 30, rows: []},
      report_path: "tmp/content_quality_report.md"
    }
    |> Map.merge(overrides)
  end
end
