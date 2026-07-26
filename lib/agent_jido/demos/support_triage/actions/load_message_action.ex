defmodule AgentJido.Demos.SupportTriage.Actions.LoadMessageAction do
  @moduledoc """
  Loads a named fixture support message into agent state.

  Selects one of the billing, bug, how-to, or thanks fixtures by the `which`
  parameter. A fresh load clears any prior intent, urgency, and response so the
  triage starts cleanly from a new message.
  """

  use Jido.Action,
    name: "load_message",
    description: "Loads a fixture support message into agent state for triage"

  alias AgentJido.Demos.SupportTriage.Fixtures

  @impl true
  def run(%{which: which}, _context) when which in [:billing, :bug, :howto, :thanks] do
    {:ok,
     %{
       incoming_message: Fixtures.fetch(which),
       intent: "",
       urgency: "",
       response: ""
     }}
  end

  def run(_params, _context) do
    {:ok,
     %{
       incoming_message: Fixtures.fetch(:billing),
       intent: "",
       urgency: "",
       response: ""
     }}
  end
end
