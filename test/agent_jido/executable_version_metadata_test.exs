defmodule AgentJido.ExecutableVersionMetadataTest do
  @moduledoc """
  E06-T11: every executable page carries a tested-version field so version
  context renders for readers.

  An executable page is a runnable Livebook notebook: `is_livebook == true`
  and `livebook.runnable == true` (see the Livebook Authoring Standards page).
  Each such page declares `tested_with` — a map of package/version pairs the
  notebook was validated against — and the docs shell renders it as "Tested
  with" in the page header. The Page schema
  (`lib/agent_jido/pages/page.ex`) exposes `tested_with` as a top-level
  field, mirroring the Example card contract and the canonical metadata names
  used by the freshness/validation backlog (E06-T11, E06-T12, E12-T14).

  This test enumerates every published runnable notebook and asserts it ships
  with a non-empty, well-formed `tested_with`, so no executable page can be
  added without version context.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Pages

  # An executable page is a runnable Livebook notebook.
  @executable_pages Pages.all_pages()
                    |> Enum.filter(& &1.is_livebook)
                    |> Enum.filter(&(Map.get(&1.livebook || %{}, :runnable) == true))

  describe "every executable page declares a tested-version field (jido-e06-t11)" do
    test "there is at least one executable page to check" do
      assert length(@executable_pages) > 0,
             "expected at least one runnable Livebook notebook to be published"
    end

    for page <- @executable_pages do
      test "#{page.path} frontmatter carries a tested_with map" do
        source = unquote(Macro.escape(page)).source_path
        body = File.read!(source)

        assert body =~ ~r/tested_with:\s*%\{/,
               "#{source} must declare a tested_with map of package/version pairs"
      end

      test "#{page.path} Page struct exposes a non-empty tested_with" do
        page = unquote(Macro.escape(page))

        assert is_map(page.tested_with) and map_size(page.tested_with) > 0,
               "#{page.path} tested_with must be a non-empty map, got: #{inspect(page.tested_with)}"

        for {pkg, version} <- page.tested_with do
          assert is_atom(pkg),
                 "#{page.path} tested_with keys must be package-name atoms, got: #{inspect(pkg)}"

          assert is_binary(version) and version != "",
                 "#{page.path} tested_with[#{pkg}] must be a non-empty version string"

          assert String.match?(version, ~r/^\d+\.\d+/),
                 "#{page.path} tested_with[#{pkg}] must look like a version, got: #{inspect(version)}"
        end
      end
    end
  end
end
