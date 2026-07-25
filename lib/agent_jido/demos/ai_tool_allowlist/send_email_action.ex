defmodule AgentJido.Demos.AiToolAllowlist.SendEmailAction do
  @moduledoc """
  High-impact AI tool for the allowlist demo (jido-e05-T37).

  It runs when invoked directly, but the `AiToolAllowlist` policy denies it
  unless `"send_email"` is explicitly allowlisted. This proves the point of an
  effect policy: a registered, runnable tool is still rejected before execution
  when it falls outside the allowlist. No real email is delivered.
  """

  use Jido.Action,
    name: "send_email",
    description: "Sends an email — a high-impact effect an allowlist should gate",
    category: "ai",
    tags: ["tool-calling", "effect", "control"],
    vsn: "1.0.0",
    schema: [
      to: [type: :string, default: ""],
      subject: [type: :string, default: ""]
    ]

  @impl true
  def run(_params, _context) do
    {:ok, %{sent: true}}
  end
end
