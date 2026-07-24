defmodule AgentJido.Demos.ToolAllowlistAgent do
  @moduledoc """
  Tool-allowlist reference demo (jido-e07-T41). Only allowlisted tools run;
  a disallowed tool is denied before execution.
  """
  alias AgentJido.Demos.ToolAllowlist.{DeleteToolAction, SearchToolAction, ToolAllowlistPlugin}

  use Jido.Agent,
    name: "tool_allowlist_agent",
    description: "Demonstrates a tool/effect allowlist",
    schema: [search_count: [type: :integer, default: 0], delete_count: [type: :integer, default: 0]],
    plugins: [{ToolAllowlistPlugin, %{allowed_tools: ["tool.search"]}}],
    signal_routes: [{"tool.search", SearchToolAction}, {"tool.delete", DeleteToolAction}]
end
