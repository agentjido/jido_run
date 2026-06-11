defmodule AgentJido.Analytics.Composite do
  @moduledoc """
  Composite analytics facade that preserves first-party analytics reads while
  mirroring eligible events to PostHog.
  """

  alias AgentJido.Analytics
  alias AgentJido.Analytics.AnalyticsEvent
  alias AgentJido.Analytics.PostHog

  @spec event_values() :: [String.t()]
  defdelegate event_values(), to: Analytics

  @spec feedback_surfaces() :: [String.t()]
  defdelegate feedback_surfaces(), to: Analytics

  @spec dashboard_snapshot(term(), pos_integer(), keyword()) :: Analytics.dashboard_snapshot()
  defdelegate dashboard_snapshot(current_scope, days \\ 7, opts \\ []), to: Analytics

  @spec content_gap_report(term(), pos_integer(), keyword()) :: [map()]
  defdelegate content_gap_report(current_scope, days \\ 7, opts \\ []), to: Analytics

  @spec content_gap_rows_for_export(term(), pos_integer(), pos_integer()) :: [map()]
  defdelegate content_gap_rows_for_export(current_scope, days \\ 7, limit \\ 250), to: Analytics

  @spec feedback_rows_for_export(term(), pos_integer(), pos_integer()) :: [map()]
  defdelegate feedback_rows_for_export(current_scope, days \\ 7, limit \\ 500), to: Analytics

  @spec search_activity_snapshot(term(), pos_integer(), keyword()) :: map()
  defdelegate search_activity_snapshot(current_scope, days \\ 7, opts \\ []), to: Analytics

  @spec external_collection_snapshot(term(), pos_integer()) :: map()
  defdelegate external_collection_snapshot(current_scope, days \\ 7), to: Analytics

  @spec ecosystem_snapshot(term(), pos_integer(), keyword()) :: map()
  defdelegate ecosystem_snapshot(current_scope, days \\ 30, opts \\ []), to: Analytics

  @spec latest_feedback_for_identity(String.t() | nil, String.t() | nil, String.t() | nil, keyword()) ::
          %{feedback_value: String.t() | nil, feedback_note: String.t() | nil} | nil
  defdelegate latest_feedback_for_identity(visitor_id, session_id, path, opts \\ []), to: Analytics

  @spec track_event(term(), map() | keyword()) ::
          {:ok, AnalyticsEvent.t() | :excluded_admin} | {:error, term()}
  def track_event(current_scope, attrs) do
    normalized_attrs = normalize_attrs(attrs)
    result = Analytics.track_event(current_scope, normalized_attrs)
    maybe_capture_posthog(current_scope, normalized_attrs, result)
    result
  end

  @spec track_event_safe(term(), map() | keyword()) :: :ok
  def track_event_safe(current_scope, attrs) do
    _ = track_event(current_scope, attrs)
    :ok
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  @spec track_feedback_safe(term(), map() | keyword()) :: :ok
  def track_feedback_safe(current_scope, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put_new("event", "feedback_submitted")

    track_event_safe(current_scope, attrs)
  end

  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
  defp normalize_attrs(attrs) when is_list(attrs), do: Enum.into(attrs, %{})
  defp normalize_attrs(_attrs), do: %{}

  defp maybe_capture_posthog(current_scope, attrs, result) do
    event_name = Map.get(attrs, "event") || Map.get(attrs, :event)

    if is_binary(event_name) and match?({:ok, _}, result) and not match?({:ok, :excluded_admin}, result) do
      PostHog.capture_event_safe(current_scope, event_name, attrs)
    else
      :ok
    end
  end
end
