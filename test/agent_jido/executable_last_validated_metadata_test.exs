defmodule AgentJido.ExecutableLastValidatedMetadataTest do
  @moduledoc """
  E06-T12: every executable page carries a last-validated date so staleness
  can be detected automatically.

  An executable page is a runnable Livebook notebook: `is_livebook == true`
  and `livebook.runnable == true` (see the Livebook Authoring Standards page).
  Each such page declares `last_validated` — the ISO date of the most recent
  run that confirmed the notebook against its `tested_with` versions — and the
  docs shell renders it as "Last validated" in the page header. The Page
  schema (`lib/agent_jido/pages/page.ex`) exposes `last_validated` as a
  top-level field, mirroring the Example card contract and the canonical
  metadata names used by the freshness/validation backlog (E06-T11, E06-T12,
  E12-T14).

  This test enumerates every published runnable notebook and asserts it ships
  with a non-empty, well-formed `last_validated` ISO date, so no executable
  page can be added without a validation date.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Pages

  # An executable page is a runnable Livebook notebook.
  @executable_pages Pages.all_pages()
                    |> Enum.filter(& &1.is_livebook)
                    |> Enum.filter(&(Map.get(&1.livebook || %{}, :runnable) == true))

  describe "every executable page declares a last-validated date (jido-e06-t12)" do
    test "there is at least one executable page to check" do
      assert length(@executable_pages) > 0,
             "expected at least one runnable Livebook notebook to be published"
    end

    for page <- @executable_pages do
      test "#{page.path} frontmatter carries a last_validated date" do
        source = unquote(Macro.escape(page)).source_path
        body = File.read!(source)

        assert body =~ ~r/last_validated:\s*"\d{4}-\d{2}-\d{2}"/,
               "#{source} must declare a last_validated ISO date (YYYY-MM-DD)"
      end

      test "#{page.path} Page struct exposes a non-empty last_validated date" do
        page = unquote(Macro.escape(page))

        assert is_binary(page.last_validated) and page.last_validated != "",
               "#{page.path} last_validated must be a non-empty string, got: #{inspect(page.last_validated)}"

        assert String.match?(page.last_validated, ~r/^\d{4}-\d{2}-\d{2}$/),
               "#{page.path} last_validated must be an ISO date (YYYY-MM-DD), got: #{inspect(page.last_validated)}"

        # Date.parse/1 rejects invalid calendar dates such as 2026-13-40.
        assert {:ok, _date} = Date.from_iso8601(page.last_validated),
               "#{page.path} last_validated must be a real calendar date, got: #{inspect(page.last_validated)}"
      end
    end
  end
end
