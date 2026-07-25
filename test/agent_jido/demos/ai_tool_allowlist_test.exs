defmodule AgentJido.Demos.AiToolAllowlistTest do
  @moduledoc """
  AI tool allowlist / effect policy (jido-e05-T37): the jido_ai-layer follow-up
  to the core ToolAllowlistAgent (jido-e07-T41). An allowlisted AI tool runs;
  a disallowed AI tool is rejected before it executes — even when that tool is
  registered and would otherwise run.

  Backs the "AI tool and effect policy" control surface in the
  operational-controls onboarding lane.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Demos.AiToolAllowlist.{AiToolAllowlist, SendEmailAction}
  alias Jido.Tools.Arithmetic

  # Tools resolved by name the way the AI tool-calling layer resolves them.
  @tools %{"add" => Arithmetic.Add, "send_email" => SendEmailAction}

  test "an allowlisted AI tool runs and returns its result" do
    {:ok, result} =
      Jido.Exec.run(
        AiToolAllowlist,
        %{tool_name: "add", params: %{"value" => 2, "amount" => 3}, allowed_tools: ["add"]},
        %{tools: @tools}
      )

    assert result.status == :success
    assert result.tool_name == "add"
    assert result.result.result == 5.0
  end

  test "a disallowed AI tool is rejected before execution" do
    result =
      Jido.Exec.run(
        AiToolAllowlist,
        %{tool_name: "send_email", params: %{"to" => "ops@example.com"}, allowed_tools: ["add"]},
        %{tools: @tools}
      )

    # The policy rejects the tool with a structured, fail-closed error — the
    # registered tool never executes (proven by the next test, which shows the
    # same tool runs once it is allowlisted).
    assert {:error, %Jido.Action.Error.ExecutionFailureError{details: details}} = result
    assert details.reason == :disallowed_tool
    assert details.tool == "send_email"
  end

  test "the disallowed tool still runs when explicitly allowlisted" do
    # Proves the rejection above is the policy, not a missing tool: the same
    # high-impact tool executes once its name is added to the allowlist.
    {:ok, result} =
      Jido.Exec.run(
        AiToolAllowlist,
        %{tool_name: "send_email", params: %{"to" => "ops@example.com"}, allowed_tools: ["send_email"]},
        %{tools: @tools}
      )

    assert result.status == :success
    assert result.tool_name == "send_email"
    assert result.result == %{sent: true}
  end
end
