defmodule AgentJido.Demos.DocumentProcessor.Fixtures do
  @moduledoc """
  Fixture documents for the document-processing demo.

  Each fixture is a short, realistic inbound document. The agent's typed
  `ClassifyDocument`, `ExtractFields`, and `RouteDocument` actions operate on
  this text for real -- keyword and pattern matching, not a canned trace -- so
  the demo is fully deterministic and needs no LLM or network call.

  The `unknown` fixture (a meeting summary) carries none of the invoice,
  contract, or ticket signals, so it exercises the unrecognized-document branch
  honestly instead of always classifying as something.
  """

  @invoice """
  Invoice #: INV-20431
  From: Northwind Billing
  Bill To: Globex Corporation

  Subtotal: $1,200.00
  Tax (8.5%): $102.00
  Total Due: $1,302.00
  Due Date: 2026-08-15
  """

  @contract """
  SERVICE AGREEMENT

  This agreement is entered into by and between Acme LLC ("Provider") and
  Initech ("Client"). The parties hereby agree to the terms and conditions
  below.

  Effective Date: 2026-07-01
  """

  @ticket """
  Support Ticket #: TKT-9087
  Subject: Production login returns 500 after deploy
  Reported By: ops-oncall
  Priority: high

  Steps to reproduce: users cannot sign in following the 2026-07-24 release.
  """

  @unknown """
  Weekly Sync Notes - 2026-07-21

  Attendees reviewed the roadmap and agreed to revisit capacity planning next
  week. No decisions were recorded.
  """

  @doc """
  A named fixture document. Falls back to the invoice fixture for an unknown
  name so the loader always returns a non-empty document.
  """
  @spec fetch(:invoice | :contract | :ticket | :unknown | atom()) :: String.t()
  def fetch(:contract), do: String.trim_trailing(@contract)
  def fetch(:ticket), do: String.trim_trailing(@ticket)
  def fetch(:unknown), do: String.trim_trailing(@unknown)
  def fetch(:invoice), do: String.trim_trailing(@invoice)
  def fetch(_which), do: fetch(:invoice)
end
