defmodule AgentJido.Analytics.AnalyticsEvent do
  @moduledoc """
  Append-only first-party analytics event model.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @event_values [
    "content_assistant_submitted",
    "content_assistant_reference_clicked",
    "content_assistant_answer_link_clicked",
    "content_assistant_restored",
    "docs_section_viewed",
    "code_copied",
    "cta_clicked",
    "livebook_run_clicked",
    "agent_run_succeeded",
    "feedback_submitted"
  ]

  @feedback_values ["helpful", "not_helpful"]
  @feedback_surface_values ["content_assistant", "docs_page"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_events" do
    field :event, :string
    field :source, :string
    field :channel, :string
    field :path, :string
    field :section_id, :string
    field :target_url, :string
    field :rank, :integer
    field :feedback_value, :string
    field :feedback_note, :string
    field :visitor_id, :string
    field :session_id, :string
    field :metadata, :map, default: %{}

    belongs_to :query_log, AgentJido.QueryLogs.QueryLog
    belongs_to :user, AgentJido.Accounts.User

    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          event: String.t(),
          source: String.t(),
          channel: String.t(),
          path: String.t(),
          section_id: String.t() | nil,
          target_url: String.t() | nil,
          rank: non_neg_integer() | nil,
          feedback_value: String.t() | nil,
          feedback_note: String.t() | nil,
          query_log_id: Ecto.UUID.t() | nil,
          visitor_id: String.t(),
          session_id: String.t(),
          user_id: Ecto.UUID.t() | nil,
          metadata: map(),
          inserted_at: DateTime.t() | nil
        }

  @doc """
  Valid event values accepted by first-party analytics ingestion.
  """
  @spec event_values() :: [String.t()]
  def event_values, do: @event_values

  @doc """
  Valid feedback value enum.
  """
  @spec feedback_values() :: [String.t()]
  def feedback_values, do: @feedback_values

  @doc """
  Changeset for analytics event insertion.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = analytics_event, attrs) when is_map(attrs) do
    analytics_event
    |> cast(attrs, [
      :event,
      :source,
      :channel,
      :path,
      :section_id,
      :target_url,
      :rank,
      :feedback_value,
      :feedback_note,
      :query_log_id,
      :visitor_id,
      :session_id,
      :user_id,
      :metadata
    ])
    |> normalize_string(:event)
    |> normalize_string(:source)
    |> normalize_string(:channel)
    |> normalize_string(:path)
    |> normalize_string(:section_id)
    |> normalize_string(:target_url)
    |> normalize_string(:feedback_value)
    |> normalize_string(:feedback_note)
    |> validate_required([:event, :source, :channel, :path, :visitor_id, :session_id])
    |> validate_inclusion(:event, @event_values)
    |> validate_inclusion(:feedback_value, @feedback_values)
    |> validate_length(:source, min: 2, max: 100)
    |> validate_length(:channel, min: 2, max: 120)
    |> validate_length(:path, min: 1, max: 500)
    |> validate_length(:section_id, max: 200)
    |> validate_length(:feedback_note, max: 500)
    |> validate_number(:rank, greater_than_or_equal_to: 1)
    |> validate_map(:metadata)
    |> validate_feedback_surface()
    |> foreign_key_constraint(:query_log_id)
    |> foreign_key_constraint(:user_id)
  end

  defp normalize_string(changeset, field) do
    update_change(changeset, field, fn
      value when is_binary(value) -> String.trim(value)
      value when is_atom(value) -> value |> Atom.to_string() |> String.trim()
      value when is_number(value) -> value |> to_string() |> String.trim()
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

  defp validate_feedback_surface(changeset) do
    if get_field(changeset, :event) == "feedback_submitted" do
      metadata = get_field(changeset, :metadata) || %{}
      surface = Map.get(metadata, "surface") || Map.get(metadata, :surface)

      cond do
        is_nil(surface) ->
          add_error(changeset, :metadata, "surface is required for feedback events")

        to_string(surface) in @feedback_surface_values ->
          changeset

        true ->
          add_error(changeset, :metadata, "surface is invalid")
      end
    else
      changeset
    end
  end
end
