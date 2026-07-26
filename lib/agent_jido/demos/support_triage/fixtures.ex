defmodule AgentJido.Demos.SupportTriage.Fixtures do
  @moduledoc """
  Fixture support messages for the support-triage demo.

  Each fixture is a short, realistic inbound customer message. The agent's typed
  `ClassifyIntent`, `AssessUrgency`, and `Respond` actions operate on this text
  for real -- keyword and pattern matching, not a canned trace -- so the demo is
  fully deterministic and needs no LLM or network call.

  The `thanks` fixture (a praise message) carries none of the billing, bug, or
  how-to intent signals, so it exercises the unrecognized-intent branch honestly
  instead of always classifying as something.
  """

  @billing """
  Hi,

  I was charged twice for my July subscription. My card shows $49 twice for
  invoice INV-9921. Please refund the duplicate charge.

  Thanks!
  """

  @bug """
  This is BROKEN. The dashboard crashes every time I click Export, and it is
  blocking my team's deadline TODAY. Fix this immediately!!!
  """

  @howto """
  How do I invite a teammate to my workspace? I've looked in settings and can't
  find it anywhere.
  """

  @thanks """
  Just wanted to say thanks for the great product -- you folks are the best!
  """

  @doc """
  A named fixture support message. Falls back to the billing fixture for an
  unknown name so the loader always returns a non-empty message.
  """
  @spec fetch(:billing | :bug | :howto | :thanks | atom()) :: String.t()
  def fetch(:billing), do: String.trim_trailing(@billing)
  def fetch(:bug), do: String.trim_trailing(@bug)
  def fetch(:howto), do: String.trim_trailing(@howto)
  def fetch(:thanks), do: String.trim_trailing(@thanks)
  def fetch(_which), do: fetch(:billing)
end
