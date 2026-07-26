defmodule AgentJidoWeb.ContentAssistantSupport do
  @moduledoc false

  alias AgentJido.ContentAssistant.Response

  @default_progressive_swap_min_ms 1_200

  def normalize_query(query) when is_binary(query), do: String.trim(query)
  def normalize_query(_query), do: ""

  def normalize_feedback_value(value) when is_binary(value) do
    case String.trim(value) do
      "helpful" -> "helpful"
      "not_helpful" -> "not_helpful"
      _ -> nil
    end
  end

  def normalize_feedback_value(_value), do: nil

  def normalize_feedback_note(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.slice(0, 500)
    |> case do
      "" -> nil
      note -> note
    end
  end

  def normalize_feedback_note(_value), do: nil

  def source_label(:docs), do: "Docs"
  def source_label(:blog), do: "Blog"
  def source_label(:ecosystem), do: "Ecosystem"
  def source_label(:ecosystem_docs), do: "HexDocs"
  def source_label(:examples), do: "Example"
  def source_label(:skills), do: "Skill"
  def source_label(_), do: "Content"

  def provider_label(:hexdocs), do: "HexDocs"
  def provider_label("hexdocs"), do: "HexDocs"
  def provider_label(_provider), do: nil

  def page_kind_label(:module), do: "Module"
  def page_kind_label(:guide), do: "Guide"
  def page_kind_label(:readme), do: "README"
  def page_kind_label(:task), do: "Task"
  def page_kind_label("module"), do: "Module"
  def page_kind_label("guide"), do: "Guide"
  def page_kind_label("readme"), do: "README"
  def page_kind_label("task"), do: "Task"
  def page_kind_label(_kind), do: nil

  # Content-type labels let a user distinguish a definition, guide, package
  # surface, example, and case study across search results (jido-e10-t28).
  def content_type_label(:definition), do: "Definition"
  def content_type_label(:guide), do: "Guide"
  def content_type_label(:package), do: "Package"
  def content_type_label(:example), do: "Example"
  def content_type_label(:case_study), do: "Case study"
  def content_type_label(:skill), do: "Skill"
  def content_type_label(:article), do: "Article"
  def content_type_label(:reference), do: "Reference"
  def content_type_label(_content_type), do: nil

  # Proof-level labels name the strength of evidence behind a result, matching
  # the four-level ladder in `specs/style-voice.md` (jido-e10-t28).
  def proof_level_label(:design_intent), do: "Design intent"
  def proof_level_label(:tested_behavior), do: "Tested behavior"
  def proof_level_label(:benchmark), do: "Benchmark"
  def proof_level_label(:production_evidence), do: "Production evidence"
  def proof_level_label(_proof_level), do: nil

  def external_result?(%{external?: true}), do: true
  def external_result?(_result), do: false

  def result_target(%{external?: true}), do: "_blank"
  def result_target(_result), do: nil

  def result_rel(%{external?: true}), do: "noopener noreferrer"
  def result_rel(_result), do: nil

  def package_label(%{package_title: title}) when is_binary(title) and title != "", do: title
  def package_label(%{package_name: name}) when is_binary(name) and name != "", do: name
  def package_label(%{package_id: id}) when is_binary(id) and id != "", do: id
  def package_label(_result), do: nil

  def analytics_metadata(%Response{} = response, metadata) when is_map(metadata) do
    Map.merge(metadata, %{
      answer_mode: response.answer_mode,
      retrieval_status: response.retrieval_status,
      llm_attempted: response.llm_attempted?,
      llm_enhanced: response.llm_enhanced?,
      enhancement_blocked_reason: response.enhancement_blocked_reason
    })
  end

  def analytics_metadata(_response, metadata) when is_map(metadata), do: metadata

  def analytics_value(nil), do: nil
  def analytics_value(value) when is_atom(value), do: Atom.to_string(value)
  def analytics_value(value), do: value

  def query_latency_ms(started_at) when is_integer(started_at) do
    System.monotonic_time()
    |> Kernel.-(started_at)
    |> System.convert_time_unit(:native, :millisecond)
  end

  def query_latency_ms(_started_at), do: 0

  def progressive_swap_min_ms do
    case content_assistant_config() |> config_value(:progressive_swap_min_ms, @default_progressive_swap_min_ms) do
      value when is_integer(value) and value >= 0 -> value
      _ -> @default_progressive_swap_min_ms
    end
  end

  def maybe_wait_for_progressive_dwell(started_at_ms) when is_integer(started_at_ms) do
    remaining_ms = progressive_swap_min_ms() - (monotonic_ms() - started_at_ms)

    if remaining_ms > 0 do
      Process.sleep(remaining_ms)
    end
  end

  def maybe_wait_for_progressive_dwell(_started_at_ms), do: :ok

  def monotonic_ms do
    System.monotonic_time()
    |> System.convert_time_unit(:native, :millisecond)
  end

  def reset_turnstile_widget(socket) do
    if socket.assigns[:turnstile_required] do
      Phoenix.LiveView.push_event(socket, "content_assistant_turnstile_reset", %{id: socket.assigns.turnstile_widget_id})
    else
      socket
    end
  end

  def turnstile_widget_id(id), do: "#{id}-turnstile"
  def turnstile_input_id(id), do: "#{id}-turnstile-token"
  def turnstile_submit_id(id), do: "#{id}-submit"
  def turnstile_status_id(id), do: "#{id}-turnstile-status"
  def turnstile_retry_id(id), do: "#{id}-turnstile-retry"

  def require_turnstile? do
    turnstile_required =
      content_assistant_config()
      |> config_value(:require_turnstile, false)
      |> truthy?()

    search_response_mode() == :enhanced and turnstile_required
  end

  def turnstile_site_key do
    content_assistant_config()
    |> config_value(:turnstile_site_key, nil)
  end

  def content_assistant_config do
    Application.get_env(:agent_jido, AgentJido.ContentAssistant, [])
  end

  def config_value(config, key, default) when is_list(config), do: Keyword.get(config, key, default)
  def config_value(config, key, default) when is_map(config), do: Map.get(config, key, default)
  def config_value(_config, _key, default), do: default

  def truthy?(value), do: value in [true, "true", 1, "1", "on"]

  def maybe_apply_search_response_mode(opts, stage) when is_list(opts) do
    case {search_response_mode(), stage} do
      {:enhanced, _stage} ->
        opts

      {:deterministic, _stage} ->
        opts
        |> Keyword.put(:llm, nil)
        |> Keyword.put(:require_turnstile, false)

      {:progressive, :enhancement} ->
        opts
        |> Keyword.put_new(:llm, Application.get_env(:arcana, :llm))
        |> Keyword.put(:require_turnstile, false)

      {:progressive, _stage} ->
        opts
        |> Keyword.put(:llm, nil)
        |> Keyword.put(:require_turnstile, false)
    end
  end

  def maybe_apply_search_response_mode(opts, _stage), do: opts

  def search_response_mode do
    case content_assistant_config() |> config_value(:search_response_mode, :progressive) do
      mode when mode in [:progressive, "progressive"] -> :progressive
      mode when mode in [:enhanced, "enhanced"] -> :enhanced
      _ -> :deterministic
    end
  end

  def search_retrieval_mode do
    case content_assistant_config() |> config_value(:search_retrieval_mode, :hybrid) do
      mode when mode in [:hybrid, "hybrid"] -> :hybrid
      _ -> :fulltext
    end
  end

  def llm_enabled?(opts) when is_list(opts) do
    case Keyword.fetch(opts, :llm) do
      {:ok, llm} -> not is_nil(llm)
      :error -> not is_nil(Application.get_env(:arcana, :llm))
    end
  end

  def llm_enabled?(_opts), do: false
end
