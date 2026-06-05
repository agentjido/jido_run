defmodule AgentJido.Analytics.Ingestion.PlausibleDimensionDaily do
  @moduledoc """
  Daily Plausible metrics grouped by a single useful dimension.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "analytics_plausible_dimension_daily" do
    field :site_id, :string
    field :day, :date
    field :dimension, :string
    field :value, :string
    field :value_key, :string
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
