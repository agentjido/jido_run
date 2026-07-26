defmodule AgentJido.Demos.DataPipeline.Fixtures do
  @moduledoc """
  Fixture data sources for the data-pipeline demo.

  Each source is a realistic batch of records a scheduled pipeline would
  collect from a separate system -- orders from the commerce service, users
  from the identity service, and events from the product analytics stream. The
  agent's typed `ValidateRecords`, `TransformRecords`, `LoadRecords`, and
  `Summarize` actions operate on these records for real -- schema checks,
  deterministic transforms, and a stable destination checksum -- so the demo is
  fully deterministic and needs no LLM or network call.

  Each source deliberately includes one malformed record so the validate step
  exercises a real rejection path instead of always accepting everything.
  """

  # %{which: => %{source:, records:}}. Each batch is a realistic point-in-time
  # pull from a separate upstream system, with one malformed record per source
  # so validation has a real rejection path.
  @sources %{
    orders: %{
      source: "orders",
      records: [
        %{id: 1001, customer: "Acme", amount_cents: 4999, currency: "usd"},
        %{id: 1002, customer: "Globex", amount_cents: 12_500, currency: "eur"},
        %{id: 1003, customer: "", amount_cents: 3000, currency: "usd"},
        %{id: 1004, customer: "Initech", amount_cents: nil, currency: "usd"}
      ]
    },
    users: %{
      source: "users",
      records: [
        %{id: 501, email: "Ada@Example.com", country: "us", signup_at: "2026-01-04"},
        %{id: 502, email: "grace@example.com", country: "gb", signup_at: "2026-02-11"},
        %{id: 503, email: "not-an-email", country: "ca", signup_at: "2026-03-02"}
      ]
    },
    events: %{
      source: "events",
      records: [
        %{id: 9001, event: "page_view", user_id: 501, occurred_at: "2026-04-01"},
        %{id: 9002, event: "signup", user_id: 502, occurred_at: "2026-04-02"},
        %{id: 9003, event: "purchase", user_id: nil, occurred_at: "2026-04-03"}
      ]
    }
  }

  @doc """
  The list of source names a visitor can collect from, in display order.
  """
  @spec sources() :: [:orders | :users | :events]
  def sources, do: [:orders, :users, :events]

  @doc """
  A named source batch: `%{source:, records:}`. Falls back to the orders batch
  for an unknown name so the loader always returns a coherent source.
  """
  @spec fetch(:orders | :users | :events | atom()) :: %{source: String.t(), records: [map()]}
  def fetch(which) when which in [:orders, :users, :events], do: Map.fetch!(@sources, which)
  def fetch(_which), do: fetch(:orders)
end
