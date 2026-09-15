defmodule AgentJido.ContentGen.Actions.Helpers do
  @moduledoc false

  alias AgentJido.ContentGen.Backends.CodexCLI
  alias AgentJido.ContentGen.Backends.ReqLLMBackend

  @backend_modules %{
    codex: CodexCLI,
    req_llm: ReqLLMBackend
  }

  @structure_schema [
    frontmatter_plan: [type: :map, required: false, doc: "Frontmatter intentions for writer pass"],
    section_order: [type: {:list, :string}, required: true, doc: "Ordered section headings"],
    section_briefs: [type: :string, required: true, doc: "Section-by-section writing brief"],
    code_plan: [type: :string, required: false, doc: "Expected code block strategy"],
    citation_plan: [type: {:list, :string}, required: false, doc: "Planned module/file citations"],
    consistency_rules: [type: {:list, :string}, required: false, doc: "Rules to preserve voice and consistency"]
  ]

  @spec structure_schema() :: keyword()
  def structure_schema, do: @structure_schema

  @spec default_verification() :: map()
  def default_verification do
    %{
      status: "skipped",
      checks: [],
      check_results: %{},
      livebook_test_file: nil,
      command_output_excerpt: nil
    }
  end

  @spec skipped_verification(String.t()) :: map()
  def skipped_verification(reason) do
    %{
      status: "skipped",
      checks: [],
      check_results: %{},
      livebook_test_file: nil,
      command_output_excerpt: reason
    }
  end

  @spec failed_verification(String.t()) :: map()
  def failed_verification(message) do
    %{
      status: "failed",
      checks: ["audit_only", "route_render", "livebook_test"],
      check_results: %{
        audit_only: "failed",
        route_render: "failed",
        livebook_test: "failed"
      },
      livebook_test_file: nil,
      command_output_excerpt: message
    }
  end

  @spec verification_for_audit_failure(map(), map()) :: map()
  def verification_for_audit_failure(context, audit) do
    if context.verify? do
      %{
        status: "failed",
        checks: ["audit_only"],
        check_results: %{audit_only: "failed"},
        livebook_test_file: nil,
        command_output_excerpt:
          audit.errors
          |> Enum.take(8)
          |> Enum.map_join("\n", fn error -> "- #{error.code}: #{error.message}" end)
      }
    else
      default_verification()
    end
  end

  @spec verification_failed?(map()) :: boolean()
  def verification_failed?(%{status: "failed"}), do: true
  def verification_failed?(_), do: false

  @spec safe_target_path?(String.t()) :: boolean()
  def safe_target_path?(path) when is_binary(path) do
    expanded = Path.expand(path, File.cwd!())
    source_root = Path.expand(Path.join(["priv", "pages"]), File.cwd!())

    expanded == source_root or
      String.starts_with?(expanded, source_root <> "/")
  end

  def safe_target_path?(_), do: false

  @spec generation_prompt_opts(map() | nil, map()) :: map()
  def generation_prompt_opts(existing, opts) do
    update_mode = Map.get(opts, :update_mode, :improve)

    %{
      update_mode: update_mode,
      existing: if(update_mode == :improve, do: existing, else: nil)
    }
  end

  @spec build_backend_opts(String.t() | nil, map()) :: keyword()
  def build_backend_opts(model, opts) do
    base_opts =
      [cwd: File.cwd!()]
      |> maybe_put_model(model)

    case Map.get(opts, :backend_opts, []) do
      backend_opts when is_list(backend_opts) -> Keyword.merge(base_opts, backend_opts)
      _other -> base_opts
    end
  end

  @spec backend_module(atom(), map()) :: module()
  def backend_module(backend_key, opts) do
    modules = Map.merge(@backend_modules, Map.get(opts, :backend_modules, %{}))

    case Map.fetch(modules, backend_key) do
      {:ok, module} -> module
      :error -> raise ArgumentError, "no backend configured for #{inspect(backend_key)}"
    end
  end

  defp maybe_put_model(opts, model) when is_binary(model) and model != "", do: Keyword.put(opts, :model, model)
  defp maybe_put_model(opts, _model), do: opts

  @spec normalize_structure_plan(map()) :: {:ok, map()} | {:error, String.t()}
  def normalize_structure_plan(raw) when is_map(raw) do
    section_order =
      raw
      |> fetch_any([:section_order, "section_order"], [])
      |> normalize_section_order()

    if section_order == [] do
      {:error, "empty section_order in structure response"}
    else
      {:ok,
       %{
         frontmatter_plan: fetch_any(raw, [:frontmatter_plan, "frontmatter_plan"], %{}),
         section_order: section_order,
         section_briefs: fetch_any(raw, [:section_briefs, "section_briefs"], "") |> stringify_value(),
         code_plan: fetch_any(raw, [:code_plan, "code_plan"], "") |> stringify_value(),
         citation_plan: raw |> fetch_any([:citation_plan, "citation_plan"], []) |> normalize_string_list(),
         consistency_rules: raw |> fetch_any([:consistency_rules, "consistency_rules"], []) |> normalize_string_list()
       }}
    end
  end

  def normalize_structure_plan(_), do: {:error, "invalid structure response payload"}

  @doc """
  Converts MapSet structs into sorted lists so Runic identity encoding can
  digest workflow values. SourceIndex lookups rehydrate MapSets on demand.
  """
  @spec identity_safe(term()) :: term()
  def identity_safe(%MapSet{} = set) do
    set
    |> MapSet.to_list()
    |> Enum.map(&identity_safe/1)
    |> Enum.sort()
  end

  def identity_safe(map) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {key, value} -> {identity_safe(key), identity_safe(value)} end)
  end

  def identity_safe(list) when is_list(list), do: Enum.map(list, &identity_safe/1)

  def identity_safe(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.map(&identity_safe/1)
    |> List.to_tuple()
  end

  def identity_safe(other), do: other

  @spec default_context(map(), map()) :: map()
  def default_context(entry, run_opts) do
    identity_safe(%{
      entry: entry,
      run_opts: run_opts,
      opts: run_opts.opts,
      apply?: run_opts.apply?,
      fail_on_audit: run_opts.fail_on_audit,
      verify?: run_opts.verify?,
      docs_format: run_opts.docs_format,
      verifier: run_opts.verifier,
      run_dir: run_opts.run_dir,
      page_index: run_opts.page_index,
      route_patterns: run_opts.route_patterns,
      planned_routes: Map.get(run_opts, :planned_routes, []),
      source_index: run_opts.source_index,
      update_mode: Map.get(run_opts.opts, :update_mode, :improve),
      verification: default_verification(),
      status: :unknown,
      reason: nil,
      halted?: false,
      step_failures: [],
      target: nil,
      existing: nil,
      backend_decision: nil,
      backend_module: nil,
      planner_meta: nil,
      backend_meta: nil,
      structure_plan: nil,
      generated_text: nil,
      parse_mode: nil,
      candidate: nil,
      candidate_path: nil,
      audit: nil,
      diff: nil,
      entry_result: nil,
      output_excerpt: nil,
      cleanup_reason: nil
    })
  end

  @spec halt_with_entry_result(map(), atom(), String.t(), String.t(), map()) :: map()
  def halt_with_entry_result(context, status, reason, step, extra \\ %{}) do
    context
    |> add_step_failure(step, reason)
    |> Map.put(:status, status)
    |> Map.put(:reason, reason)
    |> Map.put(:halted?, true)
    |> Map.put(:entry_result, Map.merge(early_entry_result(context, status, reason), extra))
  end

  @spec add_step_failure(map(), String.t(), String.t()) :: map()
  def add_step_failure(context, step, reason) do
    update_in(context.step_failures, fn failures ->
      List.wrap(failures) ++ [%{step: step, reason: reason}]
    end)
  end

  @spec early_entry_result(map(), atom(), String.t()) :: map()
  def early_entry_result(context, status, reason) do
    entry = context.entry

    base =
      %{
        id: entry.id,
        title: entry.title,
        section: entry.section,
        order: entry.order,
        route: context[:target] && context.target.route,
        target_path: context[:target] && context.target.target_path,
        read_path: context[:target] && context.target.read_path,
        conversion_source_path: context[:target] && context.target.conversion_source_path,
        format: context[:target] && context.target.format,
        existed_before: not is_nil(context[:existing]),
        update_mode: context.update_mode,
        verification: context.verification || default_verification(),
        status: status,
        reason: reason,
        workflow_step_failures: context.step_failures || []
      }
      |> maybe_put_backend(context)

    base
  end

  @spec base_entry_result(map()) :: map()
  def base_entry_result(context) do
    early_entry_result(context, context.status, context.reason)
    |> Map.put(:status, context.status || :unknown)
    |> Map.put(:reason, context.reason)
    |> Map.put(:verification, context.verification || default_verification())
  end

  defp maybe_put_backend(result, context) do
    case context.backend_decision do
      %{backend: backend, reason: backend_reason, planner_model: planner_model, writer_model: writer_model} ->
        result
        |> Map.put(:backend, backend)
        |> Map.put(:backend_reason, backend_reason)
        |> Map.put(:model, writer_model)
        |> Map.put(:planner_model, planner_model)
        |> Map.put(:writer_model, writer_model)

      _ ->
        result
    end
  end

  @spec write_candidate_artifact(String.t(), map(), atom(), String.t()) :: String.t() | nil
  def write_candidate_artifact(run_dir, entry, format, raw) do
    ext = if format == :livemd, do: "livemd", else: "md"
    filename = String.replace(entry.id, "/", "__") <> ".#{ext}"
    path = Path.join([run_dir, "candidates", filename])

    :ok = File.mkdir_p(Path.dirname(path))
    :ok = File.write(path, raw || "")
    path
  rescue
    _ -> nil
  end

  @spec existing_raw(map() | nil) :: String.t() | nil
  def existing_raw(nil), do: nil
  def existing_raw(%{raw: raw}) when is_binary(raw), do: raw
  def existing_raw(_), do: nil

  @spec diff_stats(String.t() | nil, String.t()) :: map()
  def diff_stats(old, new) do
    old = old || ""
    new = new || ""

    %{
      changed: normalize_for_diff(old) != normalize_for_diff(new),
      old_bytes: byte_size(old),
      new_bytes: byte_size(new),
      delta_bytes: byte_size(new) - byte_size(old),
      old_lines: line_count(old),
      new_lines: line_count(new),
      delta_lines: line_count(new) - line_count(old)
    }
  end

  @spec content_hash(String.t() | nil) :: String.t() | nil
  def content_hash(raw) when is_binary(raw) do
    :sha256
    |> :crypto.hash(raw)
    |> Base.encode16(case: :lower)
  end

  def content_hash(_), do: nil

  @spec strict_json_required?(map()) :: boolean()
  def strict_json_required?(context), do: context.apply? or context.verify?

  @spec maybe_verify_opts(map()) :: keyword()
  def maybe_verify_opts(context) do
    case Map.get(context.opts, :verify_opts, []) do
      opts when is_list(opts) -> opts
      _other -> []
    end
  end

  @spec enrich_body_for_audit(String.t(), map()) :: String.t()
  def enrich_body_for_audit(body_markdown, entry) do
    body_markdown
    |> normalize_fragmented_json_body(entry)
    |> ensure_source_module_anchors(entry)
    |> ensure_source_file_anchors(entry)
    |> ensure_cross_link_anchor()
    |> String.trim_trailing()
    |> Kernel.<>("\n")
  end

  @spec maybe_cleanup_converted_source(map(), map()) :: :ok | {:error, String.t()}
  def maybe_cleanup_converted_source(target, verification) do
    conversion_source = Map.get(target, :conversion_source_path)

    cond do
      is_nil(conversion_source) ->
        :ok

      verification.status != "passed" ->
        :ok

      true ->
        case File.rm(conversion_source) do
          :ok -> :ok
          {:error, :enoent} -> :ok
          {:error, reason} -> {:error, "failed to remove converted source #{conversion_source}: #{inspect(reason)}"}
        end
    end
  end

  @spec rollback_failed_conversion(map()) :: :ok | {:error, String.t()}
  def rollback_failed_conversion(target) do
    conversion_source = Map.get(target, :conversion_source_path)

    if is_binary(conversion_source) and conversion_source != target.target_path do
      case File.rm(target.target_path) do
        :ok -> :ok
        {:error, :enoent} -> :ok
        {:error, reason} -> {:error, "failed to rollback #{target.target_path}: #{inspect(reason)}"}
      end
    else
      :ok
    end
  end

  defp normalize_for_diff(text) do
    text
    |> String.split("\n")
    |> Enum.map_join("\n", &String.trim_trailing/1)
    |> String.trim()
  end

  defp line_count(text) when text in ["", nil], do: 0
  defp line_count(text), do: text |> String.split("\n") |> length()

  defp normalize_fragmented_json_body(body, entry) when is_binary(body) do
    trimmed = String.trim(body)

    if String.starts_with?(trimmed, "{") and String.contains?(trimmed, "\"frontmatter\"") do
      """
      # #{entry.title}

      #{entry.purpose}

      ## Scope
      - Destination route: `#{entry.destination_route}`
      - Audience: `#{entry.audience}`
      - Content type: `#{entry.content_type}`
      """
    else
      body
    end
  end

  defp ensure_source_module_anchors(body, entry) do
    modules =
      entry
      |> Map.get(:source_modules, [])
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> Enum.reject(&(&1 == ""))

    missing = Enum.reject(modules, &String.contains?(body, &1))

    if missing == [] do
      body
    else
      body <>
        """

        ## Source Modules
        #{Enum.map_join(missing, "\n", fn mod -> "- `#{mod}`" end)}
        """
    end
  end

  defp ensure_source_file_anchors(body, entry) do
    files =
      entry
      |> Map.get(:source_files, [])
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> Enum.reject(&(&1 == ""))

    cited? = Enum.any?(files, fn file -> String.contains?(body, file) or String.contains?(body, Path.basename(file)) end)

    if files == [] or cited? do
      body
    else
      body <>
        """

        ## Source Files
        #{Enum.map_join(files, "\n", fn file -> "- `#{file}`" end)}
        """
    end
  end

  defp ensure_cross_link_anchor(body) do
    links =
      Regex.scan(~r/\]\((\/[^)\s]+)\)/, body)
      |> Enum.map(fn
        [_, link] -> link
        _ -> ""
      end)

    has_cross_link? =
      Enum.any?(links, fn link ->
        String.starts_with?(link, "/build") or
          String.starts_with?(link, "/training") or
          String.starts_with?(link, "/ecosystem") or
          String.starts_with?(link, "/docs")
      end)

    if has_cross_link? do
      body
    else
      body <>
        """

        ## Next Steps
        - [Build Hub](/build)
        - [Docs Hub](/docs)
        """
    end
  end

  defp fetch_any(map, [key | rest], default) do
    if Map.has_key?(map, key) do
      Map.get(map, key)
    else
      fetch_any(map, rest, default)
    end
  end

  defp fetch_any(_map, [], default), do: default

  defp normalize_section_order(value) do
    value
    |> List.wrap()
    |> Enum.map(&extract_section_heading/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp extract_section_heading(value) when is_binary(value), do: value
  defp extract_section_heading(value) when is_atom(value), do: Atom.to_string(value)
  defp extract_section_heading(value) when is_integer(value) or is_float(value), do: to_string(value)

  defp extract_section_heading(value) when is_map(value) do
    value
    |> fetch_any([:heading, "heading", :title, "title", :name, "name", :section, "section"], nil)
    |> case do
      nil -> nil
      heading -> stringify_value(heading)
    end
  end

  defp extract_section_heading(_), do: nil

  defp normalize_string_list(value) do
    value
    |> List.wrap()
    |> Enum.map(&stringify_value/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp stringify_value(value) when is_binary(value), do: value
  defp stringify_value(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_value(value) when is_integer(value) or is_float(value), do: to_string(value)

  defp stringify_value(value) when is_map(value) do
    value
    |> fetch_any([:text, "text", :rule, "rule", :description, "description", :content, "content"], nil)
    |> case do
      nil -> inspect(value)
      extracted -> stringify_value(extracted)
    end
  end

  defp stringify_value(value), do: inspect(value)
end
