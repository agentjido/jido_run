defmodule AgentJido.Demos.AiToolAllowlist.AiToolAllowlist do
  @moduledoc """
  AI tool/effect allowlist (jido-e05-T37).

  The jido_ai-layer follow-up to the core `ToolAllowlistPlugin`
  (jido-e07-T41). Both deny a disallowed tool before it runs; this one gates the
  AI tool-calling layer — the tool name the model requested — by delegating
  allowed calls to `Jido.AI.Actions.ToolCalling.ExecuteTool`. A tool not in the
  configured allowlist is rejected with a structured `disallowed_tool` error
  before execution, fail-closed at the effect boundary.

  This is the tested example behind the "AI tool and effect policy" control
  surface in the operational-controls onboarding lane: a disallowed tool or
  effect is rejected before it runs.
  """

  use Jido.Action,
    name: "ai_tool_allowlist",
    description: "Allowlist gate for AI tool calls — denies disallowed tools before execution",
    category: "ai",
    tags: ["tool-calling", "allowlist", "policy", "control"],
    vsn: "1.0.0",
    schema:
      Zoi.object(%{
        tool_name: Zoi.string(description: "The AI tool the model requested"),
        params:
          Zoi.map(description: "Arguments for the tool")
          |> Zoi.default(%{})
          |> Zoi.optional(),
        allowed_tools:
          Zoi.list(Zoi.string(), description: "Tool names the policy permits")
          |> Zoi.default([])
      })

  alias Jido.AI.Actions.ToolCalling.ExecuteTool

  @impl true
  def run(%{tool_name: tool_name, allowed_tools: allowed} = params, context) do
    if tool_name in allowed do
      # Allowed: run the tool through the AI tool-calling layer so its result,
      # effects, and result formatting stay consistent with the rest of jido_ai.
      Jido.Exec.run(
        ExecuteTool,
        %{tool_name: tool_name, params: Map.get(params, :params, %{})},
        context
      )
    else
      # Disallowed: fail closed before the tool ever runs. Return a structured
      # action error so the rejection carries a stable, assertable reason.
      {:error,
       Jido.Action.Error.execution_error(
         "tool #{inspect(tool_name)} is not in the allowlist",
         %{reason: :disallowed_tool, tool: tool_name, allowed_tools: allowed}
       )}
    end
  end
end
