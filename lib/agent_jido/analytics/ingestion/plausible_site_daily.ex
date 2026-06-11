defmodule AgentJido.Analytics.Ingestion.PlausibleSiteDaily do
  @moduledoc """
  Daily Plausible site aggregate metrics.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "analytics_plausible_site_daily" do
    field :site_id, :string
    field :day, :date
    field :visitors, :integer, default: 0
    field :visits, :integer, default: 0
    field :pageviews, :integer, default: 0
    field :bounce_rate, :float
    field :visit_duration, :integer
    field :events, :integer, default: 0
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end
end
