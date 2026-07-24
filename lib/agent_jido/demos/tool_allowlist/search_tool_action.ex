defmodule AgentJido.Demos.ToolAllowlist.SearchToolAction do
  @moduledoc "Allowed tool (read-only search)."
  use Jido.Action, name: "search", schema: [q: [type: :string, default: ""]]
  @impl true
  def run(_params, %{state: %{search_count: n} = state}), do: {:ok, %{state | search_count: n + 1}}
end
