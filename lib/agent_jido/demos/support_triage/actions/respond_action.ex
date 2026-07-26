defmodule AgentJido.Demos.SupportTriage.Actions.RespondAction do
  @moduledoc """
  Drafts a routed reply to the classified support message.

  The reply and its destination queue are derived for real from the prior steps:
  a billing message routes to a billing queue (priority when urgent) and
  references the captured invoice, a bug routes to engineering (P1 when urgent),
  a how-to routes to self-serve, and an unrecognized message routes to general.
  No LLM is called.
  """

  use Jido.Action,
    name: "respond",
    description: "Drafts a routed reply to the classified support message"

  alias AgentJido.Demos.SupportTriage.Classifier

  @impl true
  def run(_params, %{state: state}) do
    %{incoming_message: message, intent: intent, urgency: urgency} = state

    # Resolve intent and urgency from the stored values, or derive them from the
    # message when an earlier step has not run yet, so this step is
    # self-sufficient.
    effective_intent = Classifier.resolve(intent, message)
    effective_urgency = Classifier.resolve_urgency(urgency, message)

    {queue, reply} = dispatch(effective_intent, message, effective_urgency)

    response =
      ["- Queue: #{queue}", "- Urgency: #{effective_urgency}", "- Suggested reply: #{reply}"]
      |> Enum.join("\n")

    {:ok, %{intent: effective_intent, urgency: effective_urgency, response: response}}
  end

  defp dispatch("billing", message, urgency) do
    queue = if urgency == "high", do: "billing-priority", else: "billing"
    opening = opening_for(message)
    reply = "Hi -- #{opening}. I've routed this to our #{queue} queue for a refund review; you'll hear back within one business day."
    {queue, reply}
  end

  defp dispatch("bug", _message, urgency) do
    queue = if urgency == "high", do: "engineering-p1", else: "engineering"
    reply = "Hi -- thanks for the crash report. This is now tracked with #{queue}; a fix or workaround will follow shortly."
    {queue, reply}
  end

  defp dispatch("how-to", _message, _urgency) do
    reply = "Hi -- to invite a teammate, open Settings, go to Members, and click Invite. They'll get an email to join your workspace."
    {"self-serve", reply}
  end

  defp dispatch(_intent, _message, _urgency) do
    reply = "Hi -- thanks for reaching out! I've logged your note with our team. Let us know if there's anything we can help with."
    {"general", reply}
  end

  # A billing message often names an invoice; reference it when present so the
  # reply is specific instead of generic.
  defp opening_for(message) do
    case invoice_ref(message) do
      nil -> "I see the duplicate charge on your account"
      ref -> "I see the duplicate charge on invoice #{ref}"
    end
  end

  defp invoice_ref(message) do
    case Regex.run(~r/[Ii]nvoice\s*(?:#|No\.?)?\s*([A-Z]{3}-?\d+)/, message, capture: :all_but_first) do
      [ref | _] -> String.trim(ref)
      _ -> nil
    end
  end
end
