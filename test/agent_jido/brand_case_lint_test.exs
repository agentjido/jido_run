defmodule AgentJido.BrandCaseLintTest do
  @moduledoc """
  Case-sensitive Jido brand scan for public page prose.

  Lowercase `jido` is valid in package names, code, configuration, telemetry
  names, paths, and URLs. The scanner removes those contexts before it checks
  prose, so the remaining lowercase word is a brand-case error.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Pages

  test "public prose uses Jido with an uppercase J (jido-e03-t24)" do
    offenders =
      for page <- Pages.all_pages(),
          path = source_path(page),
          is_binary(path) and File.regular?(path),
          {line, line_number} <- prose_lines(File.read!(path)),
          Regex.match?(~r/\bjido\b/, line),
          not package_heading?(line),
          do: "#{page.path}:#{line_number}: #{String.trim(line)}"

    assert offenders == [],
           "lowercase jido found in public prose; use Jido for the brand and " <>
             "backticks or a package link for the package:\n" <>
             Enum.map_join(offenders, "\n", &"  - #{&1}")
  end

  defp source_path(page), do: Map.get(page, :source_path) || Map.get(page, "source_path")

  defp prose_lines(source) do
    source
    |> strip_frontmatter()
    |> String.replace(~r/```.*?```/s, "")
    |> String.replace(~r/~~~.*?~~~/s, "")
    |> String.replace(~r/`[^`\n]+`/, "")
    |> strip_package_links()
    |> String.replace(~r/\bjido\.run\b/, "")
    |> String.replace(~r/\bjido-[a-z0-9]+(?:-[a-z0-9]+)*\b/, "")
    |> String.replace(~r/\*\*jido(?:_[a-z0-9_]+)?\*\*/, "")
    |> String.replace(~r{https?://\S+}, "")
    |> String.replace(~r/<[^>]+>/, "")
    |> String.split("\n")
    |> Enum.with_index(1)
  end

  defp strip_frontmatter(source) do
    Regex.replace(~r/\A%\{.*?\n---\s*\n/s, source, "")
  end

  defp strip_package_links(source) do
    Regex.replace(~r/\[((?:[^\[\]]|\[[^\]]*\])*)\]\(([^)]+)\)/, source, fn _match, label, destination ->
      if package_link?(label, destination), do: "", else: label
    end)
  end

  defp package_link?(label, destination) do
    Regex.match?(~r/\bjido(?:_[a-z0-9_]+)?\b/, label) and
      (String.starts_with?(destination, "/ecosystem/") or
         String.contains?(destination, "github.com/agentjido/") or
         String.contains?(destination, "hex.pm/packages/") or
         String.contains?(destination, "hexdocs.pm/"))
  end

  defp package_heading?(line) do
    Regex.match?(~r/^\s*#+\s+jido(?:\s+—|\s*:)/, line) or
      Regex.match?(~r/^\s*#+\s+Core events \(jido\)/, line)
  end
end
