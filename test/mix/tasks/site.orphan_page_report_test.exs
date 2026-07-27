defmodule Mix.Tasks.Site.OrphanPageReportTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  alias Mix.Tasks.Site.OrphanPageReport

  setup do
    Mix.Task.reenable("site.orphan_page_report")

    report_path =
      Path.join(
        System.tmp_dir!(),
        "site_orphan_page_report_#{System.unique_integer([:positive])}.md"
      )

    on_exit(fn ->
      Mix.Task.reenable("site.orphan_page_report")
      File.rm(report_path)
    end)

    {:ok, report_path: report_path}
  end

  test "writes a report and prints the summary", %{report_path: report_path} do
    output =
      capture_io(fn ->
        OrphanPageReport.run(["--report", report_path])
      end)

    assert output =~ "Public content pages checked:"
    assert output =~ "Pages in navigation menu:"
    assert output =~ "Orphan pages: 0"
    assert output =~ "Report written:"

    assert File.exists?(report_path)
    assert File.read!(report_path) =~ "# Orphan Page Report"
  end

  test "raises for invalid options" do
    assert_raise Mix.Error, ~r/Invalid options/, fn ->
      capture_io(fn ->
        OrphanPageReport.run(["--does-not-exist"])
      end)
    end
  end
end
