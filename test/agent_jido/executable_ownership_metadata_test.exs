defmodule AgentJido.ExecutableOwnershipMetadataTest do
  @moduledoc """
  Freshness + ownership publication gate (jido-e12-t14).

  Acceptance condition: missing metadata blocks publication.

  An executable page is a runnable Livebook notebook: `is_livebook == true`
  and `livebook.runnable == true` (see the Livebook Authoring Standards page).
  The E12 epic exit criterion is "executable pages have owners, versions, and
  validation dates." This gate locks that invariant as a single publication
  gate: every published runnable notebook must carry all three —
  `last_validated` (ISO date), `tested_with` (package/version map), and
  `owner` (accountable person) — so a notebook cannot ship without the
  freshness + ownership trio.

  The per-field shape is locked by ExecutableLastValidatedMetadataTest
  (jido-e06-t12) and ExecutableVersionMetadataTest (jido-e06-t11). This gate
  consolidates the three under one "blocks publication" check and adds the
  `owner` requirement, which was the last unenforced field (E12-T14 open note:
  "last_validated/tested_with/owner metadata required for executable content
  not yet enforced").

  Positive controls prove the gate trips on each missing field, so a future
  notebook that drops any one of the three fails CI instead of publishing.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Pages

  # An executable page is a runnable Livebook notebook.
  @executable_pages Pages.all_pages()
                    |> Enum.filter(& &1.is_livebook)
                    |> Enum.filter(&(Map.get(&1.livebook || %{}, :runnable) == true))

  # The freshness + ownership trio required on every executable page.
  @required_metadata [:last_validated, :tested_with, :owner]

  describe "every executable page carries the freshness + ownership trio (jido-e12-t14)" do
    test "there is at least one executable page to check" do
      assert length(@executable_pages) > 0,
             "expected at least one runnable Livebook notebook to be published"
    end

    for page <- @executable_pages do
      test "#{page.path} carries last_validated, tested_with, and owner" do
        page = unquote(Macro.escape(page))

        assert missing_for(page) == [],
               "#{page.path} is missing required executable metadata: #{inspect(missing_for(page))}. " <>
                 "An executable page cannot publish without last_validated, tested_with, and owner (jido-e12-t14)."
      end
    end
  end

  describe "the gate blocks publication when metadata is missing (jido-e12-t14)" do
    # Positive controls: prove each missing field trips the gate. A future
    # notebook that drops any one of the three must fail, not publish.
    test "a blank last_validated is flagged" do
      assert missing_for(%{last_validated: "", tested_with: %{jido: "2.3.2"}, owner: "x"}) ==
               [:last_validated]
    end

    test "an empty tested_with is flagged" do
      assert missing_for(%{last_validated: "2026-07-24", tested_with: %{}, owner: "x"}) ==
               [:tested_with]
    end

    test "a blank owner is flagged" do
      assert missing_for(%{last_validated: "2026-07-24", tested_with: %{jido: "2.3.2"}, owner: ""}) ==
               [:owner]
    end

    # Negative control: a complete trio is never flagged.
    test "a complete trio is not flagged" do
      assert missing_for(%{last_validated: "2026-07-24", tested_with: %{jido: "2.3.2"}, owner: "x"}) ==
               []
    end
  end

  # Returns the required fields that are missing (nil, empty string, or empty
  # map) on the given page/map. An empty list means the page is publication-ready.
  defp missing_for(page) do
    for field <- @required_metadata, blank?(Map.get(page, field)), do: field
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(map) when is_map(map), do: map_size(map) == 0
  defp blank?(_), do: false
end
