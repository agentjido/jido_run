defmodule AgentJido.Analytics.Ingestion.TrackedRepository do
  @moduledoc """
  Git repository selected for external analytics collection.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_tracked_repositories" do
    field :provider, :string, default: "github"
    field :owner, :string
    field :name, :string
    field :full_name, :string
    field :url, :string
    field :label, :string
    field :source, :string
    field :active, :boolean, default: true
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          provider: String.t(),
          owner: String.t(),
          name: String.t(),
          full_name: String.t(),
          url: String.t() | nil,
          label: String.t() | nil,
          source: String.t() | nil,
          active: boolean(),
          metadata: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Builds a changeset for creating or updating a tracked repository.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = repository, attrs) when is_map(attrs) do
    repository
    |> cast(attrs, [:provider, :owner, :name, :full_name, :url, :label, :source, :active, :metadata])
    |> normalize_string(:provider)
    |> normalize_string(:owner)
    |> normalize_string(:name)
    |> normalize_string(:full_name)
    |> normalize_string(:url)
    |> normalize_string(:label)
    |> normalize_string(:source)
    |> put_provider_default()
    |> put_full_name()
    |> validate_required([:provider, :owner, :name, :full_name])
    |> validate_length(:provider, min: 2, max: 40)
    |> validate_length(:owner, min: 1, max: 120)
    |> validate_length(:name, min: 1, max: 180)
    |> validate_length(:full_name, min: 3, max: 320)
    |> validate_map(:metadata)
    |> unique_constraint([:provider, :owner, :name])
  end

  defp put_provider_default(changeset) do
    case get_field(changeset, :provider) do
      nil -> put_change(changeset, :provider, "github")
      "" -> put_change(changeset, :provider, "github")
      _provider -> changeset
    end
  end

  defp put_full_name(changeset) do
    owner = get_field(changeset, :owner)
    name = get_field(changeset, :name)

    if present?(owner) and present?(name) do
      put_change(changeset, :full_name, "#{owner}/#{name}")
    else
      changeset
    end
  end

  defp normalize_string(changeset, field) do
    update_change(changeset, field, fn
      value when is_binary(value) -> value |> String.trim() |> blank_to_nil()
      value when is_atom(value) -> value |> Atom.to_string() |> String.trim() |> blank_to_nil()
      value when is_number(value) -> value |> to_string() |> String.trim() |> blank_to_nil()
      _value -> nil
    end)
  end

  defp validate_map(changeset, field) do
    validate_change(changeset, field, fn
      ^field, value when is_map(value) -> []
      ^field, nil -> []
      ^field, _value -> [{field, "must be a map"}]
    end)
  end

  defp present?(value), do: is_binary(value) and value != ""
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
