defmodule AgentJido.Analytics.PostHog do
  @moduledoc """
  PostHog capture and browser bootstrap helpers for analytics integration.
  """

  alias AgentJido.Accounts
  alias AgentJido.Analytics.AnalyticsEvent

  @browser_ignore_prefixes [
    "/dashboard",
    "/dev",
    "/users",
    "/arcana",
    "/og",
    "/analytics",
    "/live",
    "/assets"
  ]
  @browser_ignore_exact_paths [
    "/status",
    "/favicon.ico",
    "/robots.txt",
    "/sitemap.xml",
    "/feed",
    "/llms.txt"
  ]
  @sensitive_metadata_keys ~w(query query_text feedback_note note answer_html answer_markdown citations related_queries)
  @sensitive_top_level_keys ~w(query query_text feedback_note note)

  @spec browser_init_config(term(), map() | nil, String.t() | nil) :: map() | nil
  def browser_init_config(current_scope, analytics_identity, request_path) do
    config = config()
    identity = normalize_map(analytics_identity)

    if config.browser_enabled and not admin_scope?(current_scope) do
      visitor_id = read(identity, "visitor_id")
      session_id = read(identity, "session_id")

      if is_binary(visitor_id) and is_binary(session_id) do
        %{
          apiKey: config.api_key,
          apiHost: config.browser_api_host,
          uiHost: config.ui_host,
          distinctId: visitor_id,
          sessionId: session_id,
          currentPath: normalize_path(request_path || read(identity, "path")),
          autocaptureEnabled: config.autocapture_enabled,
          sessionReplayEnabled: config.session_replay_enabled,
          sessionReplaySampleRate: config.session_replay_sample_rate,
          pathIgnorePrefixes: @browser_ignore_prefixes,
          pathIgnoreExactPaths: @browser_ignore_exact_paths,
          blockClass: "ph-no-capture",
          maskTextClass: "ph-mask",
          maskAllInputs: true
        }
      end
    end
  end

  @spec capture_analytics_event_safe(term(), AnalyticsEvent.t()) :: :ok
  def capture_analytics_event_safe(current_scope, %AnalyticsEvent{} = event) do
    if capture_enabled_for_scope?(current_scope) and not browser_captured_event?(event) do
      event
      |> analytics_event_properties()
      |> capture_safe(event.event)
    end

    :ok
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  @spec capture_event_safe(term(), String.t(), map() | keyword()) :: :ok
  def capture_event_safe(current_scope, event_name, attrs \\ %{})

  def capture_event_safe(current_scope, event_name, attrs)
      when is_binary(event_name) and (is_map(attrs) or is_list(attrs)) do
    if capture_enabled_for_scope?(current_scope) do
      attrs
      |> normalize_map()
      |> generic_event_properties()
      |> capture_safe(event_name)
    end

    :ok
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  def capture_event_safe(_current_scope, _event_name, _attrs), do: :ok

  @spec config() :: %{
          enabled: boolean(),
          browser_enabled: boolean(),
          server_enabled: boolean(),
          autocapture_enabled: boolean(),
          session_replay_enabled: boolean(),
          session_replay_sample_rate: float(),
          api_key: String.t() | nil,
          api_host: String.t(),
          browser_api_host: String.t(),
          ui_host: String.t() | nil
        }
  def config do
    raw_config = Application.get_env(:agent_jido, :posthog, %{})
    api_host = fetch_config(raw_config, :api_host, "https://us.i.posthog.com")
    browser_api_host = fetch_config(raw_config, :browser_api_host, api_host)
    ui_host = fetch_config(raw_config, :ui_host, infer_ui_host(api_host, browser_api_host))

    %{
      enabled: fetch_config(raw_config, :enabled, false),
      browser_enabled: fetch_config(raw_config, :browser_enabled, false),
      server_enabled: fetch_config(raw_config, :server_enabled, false),
      autocapture_enabled: fetch_config(raw_config, :autocapture_enabled, false),
      session_replay_enabled: fetch_config(raw_config, :session_replay_enabled, false),
      session_replay_sample_rate: fetch_config(raw_config, :session_replay_sample_rate, 0.25),
      api_key: fetch_config(raw_config, :api_key, nil),
      api_host: api_host,
      browser_api_host: browser_api_host,
      ui_host: ui_host
    }
  end

  defp capture_enabled_for_scope?(current_scope) do
    config().server_enabled and not admin_scope?(current_scope)
  end

  defp admin_scope?(%{user: user}), do: Accounts.admin?(user)
  defp admin_scope?(_scope), do: false

  defp browser_captured_event?(%AnalyticsEvent{event: "docs_section_viewed"}), do: true
  defp browser_captured_event?(%AnalyticsEvent{event: "code_copied"}), do: true
  defp browser_captured_event?(%AnalyticsEvent{event: "livebook_run_clicked"}), do: true

  defp browser_captured_event?(%AnalyticsEvent{event: "agent_run_succeeded"}), do: true

  defp browser_captured_event?(%AnalyticsEvent{
         event: "content_assistant_reference_clicked",
         channel: "content_assistant_page"
       }),
       do: true

  defp browser_captured_event?(%AnalyticsEvent{event: "content_assistant_answer_link_clicked"}),
    do: true

  defp browser_captured_event?(_event), do: false

  defp analytics_event_properties(%AnalyticsEvent{} = event) do
    metadata = sanitize_metadata(event.metadata)

    %{}
    |> Map.put("visitor_id", event.visitor_id)
    |> Map.put("session_id", event.session_id)
    |> put_present("source", event.source)
    |> put_present("channel", event.channel)
    |> put_present("path", normalize_path(event.path))
    |> put_present("section_id", event.section_id)
    |> put_present("target_url", event.target_url)
    |> put_present("query_log_id", event.query_log_id)
    |> put_present("rank", event.rank)
    |> put_present("feedback_value", event.feedback_value)
    |> put_present("feedback_note_length", string_length(event.feedback_note))
    |> Map.merge(metadata)
  end

  defp generic_event_properties(attrs) do
    metadata =
      attrs
      |> read("metadata")
      |> sanitize_metadata()

    %{}
    |> put_present("visitor_id", read(attrs, "visitor_id") || read(attrs, "distinct_id"))
    |> put_present("session_id", read(attrs, "session_id"))
    |> put_present("source", read(attrs, "source"))
    |> put_present("channel", read(attrs, "channel"))
    |> put_present("path", normalize_path(read(attrs, "path")))
    |> put_present("section_id", read(attrs, "section_id"))
    |> put_present("target_url", read(attrs, "target_url"))
    |> put_present("query_log_id", read(attrs, "query_log_id"))
    |> put_present("rank", read(attrs, "rank"))
    |> put_present("feedback_value", read(attrs, "feedback_value"))
    |> put_present("feedback_note_length", string_length(read(attrs, "feedback_note") || read(attrs, "note")))
    |> put_present("query_length", string_length(read(attrs, "query") || read(attrs, "query_text")))
    |> Map.merge(sanitize_top_level(attrs))
    |> Map.merge(metadata)
  end

  defp sanitize_top_level(attrs) do
    attrs
    |> Map.drop(
      @sensitive_top_level_keys ++
        ~w(visitor_id distinct_id session_id metadata source channel path section_id target_url query_log_id rank feedback_value)
    )
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case normalize_value(value) do
        nil -> acc
        normalized -> Map.put(acc, normalize_key(key), normalized)
      end
    end)
  end

  defp sanitize_metadata(metadata) when is_map(metadata) do
    normalized = normalize_map(metadata)

    normalized
    |> Map.drop(@sensitive_metadata_keys)
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case normalize_value(value) do
        nil -> acc
        normalized_value -> Map.put(acc, normalize_key(key), normalized_value)
      end
    end)
    |> put_present("query_length", string_length(read(normalized, "query") || read(normalized, "query_text")))
    |> put_present(
      "feedback_note_length",
      string_length(read(normalized, "feedback_note") || read(normalized, "note"))
    )
  end

  defp sanitize_metadata(_metadata), do: %{}

  defp capture_safe(%{"visitor_id" => distinct_id} = properties, event_name)
       when is_binary(distinct_id) and distinct_id != "" do
    properties =
      properties
      |> Map.delete("visitor_id")
      |> Map.put(:distinct_id, distinct_id)

    _ = PostHog.capture(event_name, properties)
    :ok
  end

  defp capture_safe(_properties, _event_name), do: :ok

  defp fetch_config(config, key, default) when is_list(config) do
    Keyword.get(config, key, default)
  end

  defp fetch_config(config, key, default) when is_map(config) do
    Map.get(config, key, Map.get(config, Atom.to_string(key), default))
  end

  defp fetch_config(_config, _key, default), do: default

  defp infer_ui_host("https://us.i.posthog.com", _browser_api_host), do: "https://us.posthog.com"
  defp infer_ui_host("https://eu.i.posthog.com", _browser_api_host), do: "https://eu.posthog.com"
  defp infer_ui_host("https://app.posthog.com", _browser_api_host), do: "https://us.posthog.com"
  defp infer_ui_host(_api_host, "https://us.i.posthog.com"), do: "https://us.posthog.com"
  defp infer_ui_host(_api_host, "https://eu.i.posthog.com"), do: "https://eu.posthog.com"
  defp infer_ui_host(_api_host, "https://app.posthog.com"), do: "https://us.posthog.com"
  defp infer_ui_host(_api_host, _browser_api_host), do: nil

  defp put_present(map, _key, nil), do: map
  defp put_present(map, _key, ""), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp string_length(value) when is_binary(value), do: String.length(value)
  defp string_length(_value), do: nil

  defp normalize_path(path) when is_binary(path) and path != "" do
    if String.starts_with?(path, "/"), do: path, else: "/"
  end

  defp normalize_path(_path), do: nil

  defp normalize_map(value) when is_map(value) do
    Enum.reduce(value, %{}, fn {key, entry}, acc ->
      Map.put(acc, normalize_key(key), entry)
    end)
  end

  defp normalize_map(value) when is_list(value), do: value |> Enum.into(%{}) |> normalize_map()
  defp normalize_map(_value), do: %{}

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key), do: to_string(key)

  defp normalize_value(value) when is_boolean(value), do: value
  defp normalize_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_value(value) when is_binary(value), do: value
  defp normalize_value(value) when is_integer(value), do: value
  defp normalize_value(value) when is_float(value), do: value

  defp normalize_value(value) when is_list(value) do
    Enum.map(value, &normalize_value/1)
  end

  defp normalize_value(value) when is_map(value) do
    value
    |> normalize_map()
    |> Enum.reduce(%{}, fn {key, entry}, acc ->
      case normalize_value(entry) do
        nil -> acc
        normalized -> Map.put(acc, key, normalized)
      end
    end)
  end

  defp normalize_value(%_struct{} = value), do: value |> Map.from_struct() |> normalize_value()
  defp normalize_value(value) when is_nil(value), do: nil
  defp normalize_value(value), do: to_string(value)

  defp read(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, String.to_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end
end
