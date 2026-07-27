defmodule Mix.Tasks.Site.ContentQualityReportTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  alias Mix.Tasks.Site.ContentQualityReport

  setup do
    Mix.Task.reenable("site.content_quality_report")

    report_path =
      Path.join(
        System.tmp_dir!(),
        "site_content_quality_report_#{System.unique_integer([:positive])}.md"
      )

    on_exit(fn ->
      Mix.Task.reenable("site.content_quality_report")
      File.rm(report_path)
    end)

    {:ok, report_path: report_path}
  end

  test "writes a report and prints the summary", %{report_path: report_path} do
    output =
      capture_io(fn ->
        ContentQualityReport.run(["--report", report_path])
      end)

    assert output =~ "Broken internal links:"
    assert output =~ "Stale pages/examples:"
    assert output =~ "Version-drift findings:"
    assert output =~ "Failed Livebooks (no coverage test):"
    assert output =~ "No-result search phrases:"
    assert output =~ "Report written:"

    assert File.exists?(report_path)
    assert File.read!(report_path) =~ "# Monthly Content-Quality Dashboard"
  end

  test "honors the window-days option", %{report_path: report_path} do
    output =
      capture_io(fn ->
        ContentQualityReport.run(["--report", report_path, "--window-days", "90"])
      end)

    assert output =~ "Report written:"
    assert File.read!(report_path) =~ "last 90 days"
  end

  test "raises for invalid options" do
    assert_raise Mix.Error, ~r/Invalid options/, fn ->
      capture_io(fn ->
        ContentQualityReport.run(["--does-not-exist"])
      end)
    end
  end
end
