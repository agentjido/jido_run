defmodule AgentJido.Demos.CodingAssistant.Fixtures do
  @moduledoc """
  Fixture source for the coding-assistant demo.

  The parser module below carries a deliberate nil-handling defect:
  `normalize/1` calls `String.trim/1` directly, which raises on `nil`. The
  `AnalyzeCode` action detects that call site for real, and `ProposePatch`
  builds a guarded replacement from the finding. Keeping the fixture inline
  makes the demo fully deterministic -- no repository checkout, no LLM.
  """

  @parser_source """
  defmodule MyApp.Parser do
    @moduledoc "Normalizes inbound payload strings."

    def normalize(input) do
      String.trim(input)
    end

    def upcase(input) do
      String.upcase(input)
    end
  end
  """

  @spec parser_source() :: String.t()
  def parser_source, do: String.trim_trailing(@parser_source)
end
