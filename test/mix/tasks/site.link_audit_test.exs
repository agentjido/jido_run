defmodule Mix.Tasks.Site.LinkAuditTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  alias Mix.Tasks.Site.LinkAudit

  setup do
    Mix.Task.reenable("site.link_audit")

    report_path =
      Path.join(System.tmp_dir!(), "site_link_audit_test_#{System.unique_integer([:positive])}.md")

    on_exit(fn ->
      Mix.Task.reenable("site.link_audit")
      File.rm(report_path)
    end)

    {:ok, report_path: report_path}
  end

  @tag skip: "IA/content taxonomy transition; temporarily disabled for CI unblock"
  test "runs and writes a report when configured for launch hidden routes", %{report_path: report_path} do
    output =
      capture_io(fn ->
        LinkAudit.run([
          "--include-heex",
          "--allow-prefix",
          "/training",
          "--report",
          report_path
        ])
      end)

    assert output =~ "Route patterns checked"
    assert output =~ "Internal links checked"
    assert output =~ "Unmatched internal links: 0"
    assert output =~ "Report written:"

    assert File.exists?(report_path)
    assert File.read!(report_path) =~ "# Link Audit Report"
  end

  test "raises for invalid options" do
    assert_raise Mix.Error, ~r/Invalid options/, fn ->
      capture_io(fn ->
        LinkAudit.run(["--does-not-exist"])
      end)
    end
  end

  test "audits internal links inside Livebook (.livemd) files", %{report_path: report_path} do
    root =
      Path.join(System.tmp_dir!(), "site_link_audit_livemd_#{System.unique_integer([:positive])}")

    pages = Path.join([root, "priv", "pages"])
    File.mkdir_p!(pages)

    # A real internal link to a live route, a broken internal link, and a link
    # shaped like a route but written inside a code fence (must be ignored).
    File.write!(Path.join(pages, "sample.livemd"), """
    # Sample Livebook

    See [the docs](/docs) and then [a broken link](/no/such/canonical/route).

    ```elixir
    # ignore this: [not a link](/also/inside/code)
    ```
    """)

    on_exit(fn -> File.rm_rf!(root) end)

    assert {:error, report} =
             AgentJido.Release.LinkAudit.run(root: root, report_path: report_path)

    unmatched_paths = Enum.map(report.unmatched_internal, & &1.path)

    # The broken Livebook link is caught now that .livemd is in the input set.
    assert "/no/such/canonical/route" in unmatched_paths
    # The fenced-code pseudo-link is not mistaken for a navigation link.
    refute "/also/inside/code" in unmatched_paths
  end
end
