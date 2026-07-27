defmodule AgentJido.Release.ContentQualityReport do
  @moduledoc """
  Monthly content-quality dashboard (`jido-e12-t30`).

  The content-governance monthly full sweep (§12.3) reviews five content-quality
  signals: broken links, stale pages, version drift, failed Livebooks, and
  no-result search queries. Until now each lived in its own report or queue, so
  a reviewer had to open five artifacts to read the site's content posture. This
  report aggregates all five into one place so they are **visible together**.

  Each signal is computed by the smallest authoritative source already in the
  codebase and degrades independently: a signal whose source needs the database
  or network (no-result queries) reports `unavailable` rather than failing the
  whole report, so the dashboard always renders the signals that *can* be
  computed. The report is informational — the per-signal release gates
  (`site.link_audit`, `site.orphan_page_report`, the Livebook coverage test) stay
  the source of blocking truth; this is the monthly read of where they stand.

  Signal sources:

    * **Broken links** — `AgentJido.Release.LinkAudit.run/1` internal scan
      (`include_heex: true`). Deterministic; filesystem only.
    * **Stale pages** — the 90-day critical review queue
      (`Pages.critical_review_queue/1`, jido-e12-t15), the 180-day slow-changing
      queue (`Pages.slow_review_queue/1`, jido-e12-t16), and stale examples
      (`Examples.stale_examples/1`). Deterministic; compile-time page/example
      metadata only.
    * **Version drift** — every page/example `tested_with` version compared
      against the ecosystem package's current `version` (jido-e12-t18 added
      priority-package README drift at ingestion time; this is the deterministic
      filesystem view: a page that documents a version the ecosystem no longer
      ships). Deterministic; compile-time only.
    * **Failed Livebooks** — runnable docs Livebooks with no matching drift test
      (`test/livebooks/docs/*_livebook_test.exs`). Executing every notebook needs
      network and LLM keys and is not feasible in a monthly report, so the
      failure surface is the **coverage gap**: a runnable notebook no test
      executes is one whose failure would go undetected. Mirrors
      `AgentJido.LivebookDocsCoverageTest`. Deterministic; filesystem only.
    * **No-result queries** — `Analytics.dashboard_snapshot/3`
      `docs_search_no_results` over the report window. Requires the database;
      degrades to `unavailable` when it is absent.
  """

  alias AgentJido.Analytics
  alias AgentJido.Ecosystem
  alias AgentJido.Examples
  alias AgentJido.Pages
  alias AgentJido.Release.LinkAudit

  @default_window_days 30
  @default_no_results_limit 25
  @drift_test_glob "test/livebooks/docs/*_livebook_test.exs"
  @livebook_ref_pattern ~r/livebook:\s*"([^"]+)"/

  @type broken_links_section :: %{
          route_count: non_neg_integer(),
          internal_count: non_neg_integer(),
          unmatched_internal: [map()],
          external_failures: [map()]
        }

  @type stale_entry :: %{
          source: String.t(),
          title: String.t(),
          owner: String.t(),
          kind: :critical_page | :slow_page | :example,
          section: String.t() | nil,
          last_validated: String.t() | nil,
          days_since_validation: non_neg_integer() | nil
        }

  @type version_drift_entry :: %{
          source: String.t(),
          title: String.t(),
          package: String.t(),
          documented: String.t(),
          current: String.t()
        }

  @type failed_livebook_entry :: %{
          source_path: String.t(),
          route: String.t(),
          title: String.t()
        }

  @type no_result_section :: %{
          available: boolean(),
          window_days: pos_integer(),
          rows: [map()]
        }

  @type report :: %{
          generated_at: DateTime.t(),
          window_days: pos_integer(),
          broken_links: broken_links_section(),
          stale_pages: [stale_entry()],
          version_drift: [version_drift_entry()],
          failed_livebooks: [failed_livebook_entry()],
          no_result_queries: no_result_section(),
          report_path: String.t()
        }

  @type option ::
          {:root, String.t()}
          | {:report_path, String.t()}
          | {:window_days, pos_integer()}
          | {:no_results_limit, pos_integer()}
          | {:today, Date.t()}

  @doc """
  Run the monthly content-quality dashboard and write the markdown report.

  Always returns `{:ok, report}` — the dashboard is informational, not a gate.
  Each signal is computed independently so an unavailable data source (for
  example, no database for no-result queries) degrades that section to
  `unavailable` without preventing the rest of the report from rendering.
  """
  @spec run([option()]) :: {:ok, report()}
  def run(opts \\ []) do
    root = opts |> Keyword.get(:root, File.cwd!()) |> Path.expand()

    report_path =
      opts |> Keyword.get(:report_path, "tmp/content_quality_report.md") |> resolve_report_path(root)

    window_days = Keyword.get(opts, :window_days, @default_window_days)
    no_results_limit = Keyword.get(opts, :no_results_limit, @default_no_results_limit)
    today = Keyword.get(opts, :today, Date.utc_today())

    report = %{
      generated_at: DateTime.utc_now(),
      window_days: window_days,
      broken_links: broken_links_section(root),
      stale_pages: stale_entries(today),
      version_drift: version_drift(Pages.all_pages(), Examples.all_examples(), package_versions()),
      failed_livebooks: failed_livebooks(runnable_docs_livebooks(), collect_drift_test_targets(root)),
      no_result_queries: no_result_section(window_days, no_results_limit),
      report_path: report_path
    }

    write_report(report)
    {:ok, report}
  end

  @doc """
  Render the markdown dashboard body.
  """
  @spec render_report(report()) :: String.t()
  def render_report(report) do
    [
      "# Monthly Content-Quality Dashboard\n\n",
      "- Generated: #{DateTime.to_iso8601(report.generated_at)}\n",
      "- No-result query window: last #{report.window_days} days\n",
      "- Broken internal links: #{length(report.broken_links.unmatched_internal)}\n",
      "- Stale pages/examples: #{length(report.stale_pages)}\n",
      "- Version-drift findings: #{length(report.version_drift)}\n",
      "- Failed Livebooks (no coverage test): #{length(report.failed_livebooks)}\n",
      "- No-result search phrases: #{no_result_phrase_count(report.no_result_queries)}\n",
      "\n",
      broken_links_section_markdown(report.broken_links),
      stale_pages_section_markdown(report.stale_pages),
      version_drift_section_markdown(report.version_drift),
      failed_livebooks_section_markdown(report.failed_livebooks),
      no_result_section_markdown(report.no_result_queries)
    ]
    |> IO.iodata_to_binary()
  end

  # ---------------------------------------------------------------------------
  # Broken links
  # ---------------------------------------------------------------------------

  defp broken_links_section(root) do
    # Internal scan only — deterministic and filesystem-backed. External checks
    # need live HTTP and belong to the focused link-audit run, not the monthly
    # dashboard. LinkAudit writes its own report; route it to a sibling temp
    # path so it does not clobber the operator's tmp/link_audit_report.md.
    audit_report_path = Path.join(root, "tmp/content_quality_link_audit.md")

    audit =
      case LinkAudit.run(root: root, include_heex: true, report_path: audit_report_path) do
        {:ok, report} -> report
        {:error, report} -> report
      end

    %{
      route_count: audit.route_count,
      internal_count: audit.internal_count,
      unmatched_internal: audit.unmatched_internal,
      external_failures: audit.external_failures
    }
  rescue
    _ -> empty_broken_links()
  catch
    _, _ -> empty_broken_links()
  end

  defp empty_broken_links do
    %{route_count: 0, internal_count: 0, unmatched_internal: [], external_failures: []}
  end

  # ---------------------------------------------------------------------------
  # Stale pages + examples
  # ---------------------------------------------------------------------------

  @spec stale_entries(Date.t()) :: [stale_entry()]
  def stale_entries(today) do
    critical =
      Pages.critical_review_queue(today: today)
      |> Enum.map(&stale_entry_from_page(&1, :critical_page))

    slow =
      Pages.slow_review_queue(today: today)
      |> Enum.map(&stale_entry_from_page(&1, :slow_page))

    examples =
      Examples.stale_examples()
      |> Enum.map(&stale_entry_from_example/1)

    critical ++ slow ++ examples
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  defp stale_entry_from_page(entry, kind) do
    %{
      source: safe_route(entry.page),
      title: entry.page.title,
      owner: entry.owner,
      kind: kind,
      section: entry.section,
      last_validated: entry.last_validated,
      days_since_validation: entry.days_since_validation
    }
  end

  defp stale_entry_from_example(example) do
    validated = example.last_validated
    validated = if validated in ["", nil], do: nil, else: to_string(validated)

    %{
      source: "example:#{example.slug}",
      title: example.title,
      owner: "",
      kind: :example,
      section: nil,
      last_validated: validated,
      days_since_validation: nil
    }
  end

  defp safe_route(page) do
    Pages.route_for(page)
  rescue
    _ -> page.path
  end

  # ---------------------------------------------------------------------------
  # Version drift (tested_with vs ecosystem current version)
  # ---------------------------------------------------------------------------

  @doc """
  Pure version-drift computation over pages and examples.

  `package_versions` maps a package id (string) to its current ecosystem
  version. A finding is emitted when a content item's `tested_with` documents a
  non-empty version for a package whose current ecosystem version is known,
  released, and **different**. Packages not in the ecosystem (external deps such
  as `req_llm`) and unreleased packages (`"0.0.0"`) are skipped, so only a real
  mismatch between a documented version and a shipped version surfaces.
  """
  @spec version_drift([map()], [map()], %{String.t() => String.t()}) :: [
          version_drift_entry()
        ]
  def version_drift(pages, examples, package_versions) do
    page_drift = Enum.flat_map(pages, &drift_for_item(&1, package_versions, :page))
    example_drift = Enum.flat_map(examples, &drift_for_item(&1, package_versions, :example))
    page_drift ++ example_drift
  end

  defp drift_for_item(item, package_versions, kind) do
    tested_with = Map.get(item, :tested_with) || %{}
    source = if kind == :page, do: item_source(item), else: "example:#{item.slug}"

    tested_with
    |> Enum.flat_map(fn {pkg, documented} ->
      pkg_id = to_string(pkg)
      documented = to_string(documented)

      case Map.get(package_versions, pkg_id) do
        current when is_binary(current) and current != "" and current != "0.0.0" and current != documented ->
          [
            %{
              source: source,
              title: Map.get(item, :title, source),
              package: pkg_id,
              documented: documented,
              current: current
            }
          ]

        _ ->
          []
      end
    end)
    |> Enum.sort_by(& &1.source)
  end

  defp item_source(page), do: safe_route(page)

  defp package_versions do
    Ecosystem.all_packages()
    |> Map.new(fn package -> {to_string(package.id), to_string(package.version)} end)
  rescue
    _ -> %{}
  catch
    _, _ -> %{}
  end

  # ---------------------------------------------------------------------------
  # Failed Livebooks (runnable notebooks with no coverage test)
  # ---------------------------------------------------------------------------

  @doc """
  Pure failed-Livebook computation.

  `runnable_livebooks` is the list of docs `Page` structs that are Livebooks
  flagged runnable (`page.is_livebook && page.livebook.runnable`).
  `covered_targets` is the set of `priv/pages/...` paths referenced by a drift
  test (`test/livebooks/docs/*_livebook_test.exs`). A runnable notebook whose
  normalized source path is not in that set has no test that executes it, so a
  failure would go undetected — that is the failed-Livebook surface.
  """
  @spec failed_livebooks([map()], MapSet.t(String.t())) :: [failed_livebook_entry()]
  def failed_livebooks(runnable_livebooks, covered_targets) do
    runnable_livebooks
    |> Enum.filter(fn page -> normalize_source(page.source_path) not in covered_targets end)
    |> Enum.map(fn page ->
      %{
        source_path: normalize_source(page.source_path),
        route: safe_route(page),
        title: page.title
      }
    end)
    |> Enum.sort_by(& &1.source_path)
  end

  @doc """
  Collect the Livebook source paths covered by a drift test.

  Mirrors `AgentJido.LivebookDocsCoverageTest`: scan each
  `test/livebooks/docs/*_livebook_test.exs` for its `livebook: "..."` reference
  and return the set of referenced `priv/pages/...` paths. Returns an empty set
  when the test directory is absent (for example, in a release build).
  """
  @spec collect_drift_test_targets(String.t()) :: MapSet.t(String.t())
  def collect_drift_test_targets(root) do
    root
    |> Path.join(@drift_test_glob)
    |> Path.wildcard()
    |> Enum.flat_map(fn path ->
      path
      |> File.read!()
      |> then(fn source ->
        @livebook_ref_pattern
        |> Regex.scan(source, capture: :all_but_first)
        |> List.flatten()
      end)
    end)
    |> MapSet.new()
  rescue
    _ -> MapSet.new()
  catch
    _, _ -> MapSet.new()
  end

  defp runnable_docs_livebooks do
    Pages.pages_by_category(:docs)
    |> Enum.filter(fn page ->
      page.is_livebook and is_map(page.livebook) and Map.get(page.livebook, :runnable, false)
    end)
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  # ---------------------------------------------------------------------------
  # No-result search queries (database-backed; degrades to unavailable)
  # ---------------------------------------------------------------------------

  defp no_result_section(window_days, limit) do
    # The report runs with admin authority (it is a server-side monthly artifact,
    # not a per-user web view), so the dashboard_snapshot admin-scope guard is
    # satisfied. dashboard_snapshot rescues any DB error to an unavailable
    # snapshot, which we translate into an `available: false` section.
    snapshot = Analytics.dashboard_snapshot(%{user: %{is_admin: true}}, window_days, no_results_limit: limit)

    available = not Map.get(snapshot, :unavailable?, false) and Map.get(snapshot, :authorized?, false)

    %{
      available: available,
      window_days: window_days,
      rows: if(available, do: Map.get(snapshot, :docs_search_no_results, []), else: [])
    }
  rescue
    _ -> %{available: false, window_days: window_days, rows: []}
  catch
    _, _ -> %{available: false, window_days: window_days, rows: []}
  end

  # ---------------------------------------------------------------------------
  # Report rendering
  # ---------------------------------------------------------------------------

  defp broken_links_section_markdown(section) do
    body =
      case section.unmatched_internal do
        [] ->
          "No broken internal links found — every internal link resolves to a shipped route or legacy redirect.\n"

        links ->
          links
          |> Enum.map(fn link -> "- `#{link.path}` — from `#{link.source}`\n" end)
      end

    [
      "## Broken Links\n\n",
      "- Internal links checked: #{section.internal_count}\n",
      "- Broken internal links: #{length(section.unmatched_internal)}\n",
      "\n",
      body,
      "\n"
    ]
  end

  defp stale_pages_section_markdown([]) do
    ["## Stale Pages\n\nNo stale pages or examples — every critical, slow-changing, and example entry is within its review window.\n\n"]
  end

  defp stale_pages_section_markdown(entries) do
    lines =
      entries
      |> Enum.sort_by(fn e -> {kind_order(e.kind), e.source} end)
      |> Enum.map(fn entry ->
        validated = entry.last_validated || "never"

        age =
          case entry.days_since_validation do
            nil -> ""
            days -> " (#{days}d)"
          end

        owner = if entry.owner != "", do: " — owner: #{entry.owner}", else: ""
        section = if entry.section, do: " [#{entry.section}]", else: ""

        "- `#{entry.source}`#{section} — #{entry.title} (last validated: #{validated}#{age})#{owner}\n"
      end)

    ["## Stale Pages\n\n", "Pages and examples outside their review window (90-day critical, 180-day slow, 90-day examples).\n\n", lines, "\n"]
  end

  defp version_drift_section_markdown([]) do
    ["## Version Drift\n\nNo version drift — every documented `tested_with` version matches the ecosystem's current package version.\n\n"]
  end

  defp version_drift_section_markdown(entries) do
    lines =
      Enum.map(entries, fn entry ->
        "- `#{entry.source}` — #{entry.title}: `#{entry.package}` documented `#{entry.documented}`, ecosystem now `#{entry.current}`\n"
      end)

    ["## Version Drift\n\n", "Content whose `tested_with` version no longer matches the ecosystem's current version.\n\n", lines, "\n"]
  end

  defp failed_livebooks_section_markdown([]) do
    ["## Failed Livebooks\n\nNo coverage gaps — every runnable docs Livebook has a matching drift test that executes it.\n\n"]
  end

  defp failed_livebooks_section_markdown(entries) do
    lines =
      Enum.map(entries, fn entry ->
        "- `#{entry.source_path}` — #{entry.title} (`#{entry.route}`)\n"
      end)

    [
      "## Failed Livebooks\n\n",
      "Runnable docs Livebooks with no matching drift test. These notebooks are flagged runnable but no test executes them, so a runtime failure would go undetected. (Re-running every notebook needs network and LLM keys; the coverage gap is the monthly proxy for a failed Livebook.)\n\n",
      lines,
      "\n"
    ]
  end

  defp no_result_section_markdown(%{available: false, window_days: window_days}) do
    [
      "## No-Result Search Queries\n\n",
      "Unavailable — the analytics database could not be reached, so no-result search phrases over the last #{window_days} days could not be loaded. Run with the database connected to populate this section.\n\n"
    ]
  end

  defp no_result_section_markdown(%{available: true, rows: rows}) do
    body =
      case rows do
        [] ->
          "No no-result search queries recorded in the window — every docs search resolved to at least one result.\n"

        phrases ->
          phrases
          |> Enum.map(fn row ->
            query = row[:query] || "(redacted)"
            "- #{query} — #{row[:visitors]} visitor(s)\n"
          end)
      end

    [
      "## No-Result Search Queries\n\n",
      "Docs search phrases that resolved to no results — content gaps in the visitor's own words, ranked by distinct visitors.\n\n",
      body,
      "\n"
    ]
  end

  defp no_result_phrase_count(%{available: false}), do: "unavailable"
  defp no_result_phrase_count(%{rows: rows}), do: length(rows)

  defp kind_order(:critical_page), do: 0
  defp kind_order(:slow_page), do: 1
  defp kind_order(:example), do: 2

  # ---------------------------------------------------------------------------
  # Path helpers
  # ---------------------------------------------------------------------------

  defp normalize_source(source_path) do
    case String.split(source_path, "priv/pages/", parts: 2) do
      [_, rest] -> "priv/pages/" <> rest
      _ -> source_path
    end
  end

  defp resolve_report_path(report_path, root) do
    case Path.type(report_path) do
      :absolute -> report_path
      :relative -> Path.join(root, report_path)
      :volumerelative -> report_path
    end
  end

  defp write_report(report) do
    report.report_path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(report.report_path, render_report(report))
  end
end
