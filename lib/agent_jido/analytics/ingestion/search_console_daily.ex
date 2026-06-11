defmodule AgentJido.Analytics.Ingestion.SearchConsoleDaily do
  @moduledoc """
  Daily Google Search Console rows for bounded dimension sets.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "analytics_search_console_daily" do
    field :site_url, :string
    field :day, :date
    field :dimension_set, :string
    field :dimension_key, :string
    field :search_type, :string, default: "web"
    field :query, :string
    field :page, :string
    field :country, :string
    field :device, :string
    field :clicks, :integer, default: 0
    field :impressions, :integer, default: 0
    field :ctr, :float
    field :position, :float
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end
end
