defmodule AgentJido.ContentGen.Backends.ReqLLMBackend do
  @moduledoc """
  ReqLLM-backed generation using direct provider APIs.
  """

  @behaviour AgentJido.ContentGen.Backends.Backend

  alias ReqLLM.Context
  alias ReqLLM.Generation
  alias ReqLLM.Response

  @default_model "google:gemini-2.5-pro"
  @default_system_prompt "You are an expert technical documentation author. Return only JSON."
  @default_max_tokens 8_000
  @default_receive_timeout_ms 180_000
  @output_schema [
    frontmatter: [type: :map, required: true, doc: "Frontmatter map for the page"],
    body_markdown: [type: :string, required: true, doc: "Markdown body without frontmatter fences"],
    citations: [type: {:list, :string}, required: false, doc: "Module or file references used"],
    audit_notes: [type: {:list, :string}, required: false, doc: "Generation notes for downstream auditing"]
  ]

  @impl true
  def generate(prompt, opts) when is_binary(prompt) do
    model = model(opts)
    messages = messages(prompt, opts)
    generation_opts = generation_opts(opts)

    case generate_object(prompt, opts) do
      {:ok, %{object: object, meta: meta}} ->
        envelope = normalize_object_envelope(object)
        {:ok, %{text: Jason.encode!(envelope), meta: meta}}

      {:error, error} ->
        generate_text_fallback(model, messages, generation_opts, error)
    end
  end

  @spec generate_object(String.t(), keyword()) :: {:ok, %{object: map(), meta: map()}} | {:error, term()}
  def generate_object(prompt, opts) when is_binary(prompt) do
    model = model(opts)
    messages = messages(prompt, opts)
    output_schema = Keyword.get(opts, :output_schema, @output_schema)
    generation_opts = generation_opts(opts)

    case Generation.generate_object(model, messages, output_schema, generation_opts) do
      {:ok, response} ->
        case Response.object(response) do
          object when is_map(object) and map_size(object) > 0 ->
            {:ok,
             %{
               object: object,
               meta: %{
                 backend: :req_llm,
                 mode: :structured_object,
                 model: model,
                 usage: Response.usage(response)
               }
             }}

          _missing_object ->
            {:error, :empty_structured_object_payload}
        end

      {:error, error} ->
        case generate_object_text_fallback(model, messages, generation_opts, error) do
          {:ok, %{object: _object, meta: _meta} = result} -> {:ok, result}
          {:error, fallback_error} -> {:error, fallback_error}
        end
    end
  end

  defp maybe_put_opts(base, extra) when is_list(extra), do: Keyword.merge(base, extra)
  defp maybe_put_opts(base, _extra), do: base

  defp model(opts), do: Keyword.get(opts, :model, @default_model)

  defp messages(prompt, opts) do
    system_prompt = Keyword.get(opts, :system_prompt, @default_system_prompt)

    [
      Context.system(system_prompt),
      Context.user(prompt)
    ]
  end

  defp generation_opts(opts) do
    [
      temperature: 0.2,
      max_tokens: @default_max_tokens,
      receive_timeout: @default_receive_timeout_ms,
      req_http_options: [receive_timeout: @default_receive_timeout_ms]
    ]
    |> maybe_put_opts(Keyword.get(opts, :generation_opts, []))
  end

  defp generate_text_fallback(model, messages, generation_opts, object_error) do
    case Generation.generate_text(model, messages, generation_opts) do
      {:ok, response} ->
        {:ok,
         %{
           text: Response.text(response) || "",
           meta: %{
             backend: :req_llm,
             mode: :text_fallback,
             model: model,
             usage: Response.usage(response),
             object_error: normalize_error(object_error)
           }
         }}

      {:error, text_error} ->
        {:error, "object mode failed: #{normalize_error(object_error)}; text fallback failed: #{normalize_error(text_error)}"}
    end
  end

  defp generate_object_text_fallback(model, messages, generation_opts, object_error) do
    case Generation.generate_text(model, messages, generation_opts) do
      {:ok, response} ->
        text = Response.text(response) || ""

        case decode_json_object(text) do
          {:ok, object} ->
            {:ok,
             %{
               object: object,
               meta: %{
                 backend: :req_llm,
                 mode: :text_json_object_fallback,
                 model: model,
                 usage: Response.usage(response),
                 object_error: normalize_error(object_error)
               }
             }}

          {:error, reason} ->
            {:error, "object mode failed: #{normalize_error(object_error)}; text-json fallback parse failed: #{reason}"}
        end

      {:error, text_error} ->
        {:error, "object mode failed: #{normalize_error(object_error)}; text fallback failed: #{normalize_error(text_error)}"}
    end
  end

  defp decode_json_object(text) when is_binary(text) do
    candidate =
      text
      |> String.trim()
      |> extract_fenced_json_payload()

    case Jason.decode(candidate) do
      {:ok, map} when is_map(map) and map_size(map) > 0 -> {:ok, map}
      {:ok, _other} -> {:error, "decoded payload is not a JSON object"}
      {:error, _decode_error} -> {:error, "response was not valid JSON object content"}
    end
  end

  defp decode_json_object(_text), do: {:error, "response was not text"}

  defp extract_fenced_json_payload(text) do
    case Regex.run(~r/```(?:json)?\s*(\{.*\})\s*```/s, text, capture: :all_but_first) do
      [json_payload] -> String.trim(json_payload)
      _other -> text
    end
  end

  defp normalize_object_envelope(payload) when is_map(payload) do
    %{
      frontmatter: payload[:frontmatter] || payload["frontmatter"] || %{},
      body_markdown: to_string(payload[:body_markdown] || payload["body_markdown"] || ""),
      citations: normalize_list(payload[:citations] || payload["citations"] || []),
      audit_notes: normalize_list(payload[:audit_notes] || payload["audit_notes"] || [])
    }
  end

  defp normalize_list(items) when is_list(items), do: Enum.map(items, &to_string/1)
  defp normalize_list(_other), do: []

  defp normalize_error(%{__exception__: true} = error), do: Exception.message(error)
  defp normalize_error(error) when is_atom(error), do: Atom.to_string(error)
  defp normalize_error(error) when is_binary(error), do: error
  defp normalize_error(error), do: inspect(error)
end
