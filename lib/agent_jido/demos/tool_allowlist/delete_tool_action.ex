defmodule AgentJido.Demos.ToolAllowlist.DeleteToolAction do
  @moduledoc "Disallowed-by-default high-impact tool (delete)."
  use Jido.Action, name: "delete", schema: [id: [type: :string, default: ""]]
  @impl true
  def run(_params, %{state: %{delete_count: n} = state}), do: {:ok, %{state | delete_count: n + 1}}
end
