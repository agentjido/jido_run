defmodule AgentJido.Demos.ToolAllowlist.ToolAllowlistPlugin do
  @moduledoc """
  Tool/effect allowlist (jido-e07-T41 / jido-e08-T40). Denies an Action before
  it runs unless its Signal type is in the configured allowlist — a disallowed
  tool or effect never reaches execution.
  """
  use Jido.Plugin,
    name: "tool_allowlist",
    state_key: :tool_allowlist,
    description: "Tool/effect allowlist hook",
    actions: [],
    schema: Zoi.object(%{allowed_tools: Zoi.list(Zoi.string()) |> Zoi.default([])})

  alias Jido.Signal

  @impl Jido.Plugin
  def mount(_agent, config), do: {:ok, %{allowed_tools: Map.get(config, :allowed_tools, [])}}

  @impl Jido.Plugin
  def prepare_action(%Signal{type: type}, _action_arg, context) do
    allowed = allowed_tools(context)

    if type in allowed do
      {:ok, %{}}
    else
      {:error, {:disallowed_tool, type}}
    end
  end

  defp allowed_tools(%{config: %{allowed_tools: list}}) when is_list(list), do: list
  defp allowed_tools(%{plugin_instance: %{state: %{allowed_tools: list}}}) when is_list(list), do: list
  defp allowed_tools(_), do: []
end
