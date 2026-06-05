defmodule AgentJido.Analytics.Ingestion.TrackedHexPackage do
  @moduledoc """
  Hex package selected for analytics ingestion.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @type t :: %__MODULE__{}

  schema "analytics_tracked_hex_packages" do
    field :package_name, :string
    field :display_name, :string
    field :url, :string
    field :source, :string
    field :active, :boolean, default: true
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(package, attrs) do
    package
    |> cast(attrs, [:package_name, :display_name, :url, :source, :active, :metadata])
    |> validate_required([:package_name])
    |> update_change(:package_name, &String.trim/1)
    |> update_change(:display_name, &normalize_optional_text/1)
    |> update_change(:url, &normalize_optional_text/1)
    |> update_change(:source, &normalize_optional_text/1)
    |> unique_constraint(:package_name)
  end

  defp normalize_optional_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_optional_text(value), do: value
end
