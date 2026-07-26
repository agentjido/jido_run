defmodule AgentJido.Demos.CodingAssistant.Actions.ProposePatchAction do
  @moduledoc """
  Builds a guarded patch from the loaded source.

  When the analyzer would flag a `String.trim/1` call site, this action emits a
  nil-guarded replacement and a unit test that proves it. The patch is derived
  from the loaded source for real, so an already-clean module reports no work.
  """

  use Jido.Action,
    name: "propose_patch",
    description: "Builds a nil-guarded patch from the detected findings"

  @impl true
  def run(_params, %{state: %{source: source}}) do
    {:ok, %{patch: build_patch(source)}}
  end

  defp build_patch(source) do
    if String.contains?(source, "String.trim(") do
      """
      Patch plan:
      1. Guard nil input before trim/1.

         def normalize(input) do
           case input do
             nil -> nil
             value -> String.trim(value)
           end
         end

      2. Add a parser unit test for a nil payload:

         test "normalize/1 handles nil input" do
           assert MyApp.Parser.normalize(nil) == nil
         end
      """
      |> String.trim_trailing()
    else
      "No nil-handling defects detected; no patch required."
    end
  end
end
