defmodule AgentJido.ContentGen.SimpleOrchestrator do
  @moduledoc """
  Very small, linear content generation flow for one content-plan entry.

  Intended for local iteration when you want a straightforward path:

    1. Load entry
    2. Resolve output path
    3. Plan structure
    4. Generate draft
    5. Write page
    6. Optionally run Livebook test
  """

  alias AgentJido.ContentGen.Actions.Helpers
  alias AgentJido.ContentGen.Backends.ReqLLMBackend
  alias AgentJido.ContentGen.Contract
  alias AgentJido.ContentGen.LivebookTestGenerator
  alias AgentJido.ContentGen.ModelRouter
  alias AgentJido.ContentGen.OutputParser
  alias AgentJido.ContentGen.PathResolver
  alias AgentJido.ContentGen.PromptBuilder
  alias AgentJido.ContentGen.Prompts
  alias AgentJido.ContentGen.Writer
  alias AgentJido.ContentPlan

  @type run_opts :: %{
          required(:entry) => String.t(),
          optional(:dry_run) => boolean(),
          optional(:docs_format) => :tag | :livemd,
          optional(:planner_model) => String.t() | nil,
          optional(:writer_model) => String.t() | nil,
          optional(:run_livebook_test) => boolean()
        }

  @type result :: %{
          entry_id: String.t(),
          route: String.t(),
          target_path: String.t(),
          format: :md | :livemd,
          parse_mode: :json | :fallback_markdown,
          dry_run: boolean(),
          written?: boolean(),
          planner_model: String.t() | nil,
          writer_model: String.t() | nil,
          livebook_test_file: String.t() | nil,
          warnings: [String.t()]
        }

  @spec run(run_opts(), keyword()) :: {:ok, result()} | {:error, String.t()}
  def run(opts, runtime_opts \\ []) when is_map(opts) do
    logger = Keyword.get(runtime_opts, :log, fn _message -> :ok end)

    with :ok <- ensure_runtime(),
         {:ok, entry} <- load_entry(opts),
         {:ok, target} <- resolve_target(entry, opts),
         :ok <- ensure_safe_target(target),
         {:ok, existing} <- load_existing(target),
         {:ok, structure_plan, planner_model, warnings} <- plan_structure(entry, target, existing, opts, logger),
         {:ok, envelope, parse_mode, writer_model, warnings} <-
           generate_draft(entry, target, existing, structure_plan, opts, warnings, logger),
         {:ok, rendered} <- render_output(entry, target, existing, envelope),
         {:ok, written?} <- persist(target, rendered, opts, logger),
         {:ok, livebook_test_file, warnings} <- maybe_run_livebook_test(target, opts, logger, warnings) do
      {:ok,
       %{
         entry_id: entry.id,
         route: target.route,
         target_path: target.target_path,
         format: target.format,
         parse_mode: parse_mode,
         dry_run: Map.get(opts, :dry_run, false),
         written?: written?,
         planner_model: planner_model,
         writer_model: writer_model,
         livebook_test_file: livebook_test_file,
         warnings: warnings
       }}
    end
  end

  defp load_entry(%{entry: entry_id}) when is_binary(entry_id) and entry_id != "" do
    case ContentPlan.get_entry(entry_id) do
      nil -> {:error, "entry not found in content plan: #{entry_id}"}
      entry -> {:ok, entry}
    end
  end

  defp load_entry(_opts), do: {:error, "missing required option: entry"}

  defp resolve_target(entry, opts) do
    docs_format = Map.get(opts, :docs_format, :tag)

    case PathResolver.resolve(entry, docs_format: docs_format) do
      {:ok, target} ->
        {:ok, target}

      {:skip, :skipped_non_file_target, details} ->
        {:error, "entry route is non-file-backed and cannot be generated: #{details.route}"}
    end
  end

  defp ensure_safe_target(target) do
    if Helpers.safe_target_path?(target.target_path) do
      :ok
    else
      {:error, "refusing to write outside priv/pages: #{target.target_path}"}
    end
  end

  defp load_existing(target) do
    case Writer.read_existing(target.read_path) do
      :missing -> {:ok, nil}
      {:ok, existing} -> {:ok, existing}
      {:error, reason} -> {:error, reason}
    end
  end

  defp plan_structure(entry, target, existing, opts, logger) do
    decision = ModelRouter.choose(entry, target, %{backend: :req_llm})
    planner_model = Map.get(opts, :planner_model) || decision.planner_model
    prompt_opts = %{update_mode: :improve, existing: existing}
    prompt = PromptBuilder.build_structure_pass(entry, target, prompt_opts)

    logger.("Step 1/3 Plan structure: #{entry.id}")

    backend_opts =
      planner_model
      |> Helpers.build_backend_opts(%{})
      |> Keyword.put(:system_prompt, Prompts.system_prompt(:planner))
      |> Keyword.put(:output_schema, Helpers.structure_schema())
      |> Keyword.put(:generation_opts, temperature: 0.1)

    case ReqLLMBackend.generate_object(prompt, backend_opts) do
      {:ok, %{object: raw_structure}} ->
        case Helpers.normalize_structure_plan(raw_structure) do
          {:ok, structure_plan} ->
            {:ok, structure_plan, planner_model, []}

          {:error, reason} ->
            {:ok, fallback_structure_plan(entry, target), planner_model, ["planner output fallback used: #{reason}"]}
        end

      {:error, reason} ->
        {:ok, fallback_structure_plan(entry, target), planner_model, ["planner call failed, fallback used: #{normalize_error(reason)}"]}
    end
  end

  defp generate_draft(entry, target, existing, structure_plan, opts, warnings, logger) do
    decision = ModelRouter.choose(entry, target, %{backend: :req_llm})
    writer_model = Map.get(opts, :writer_model) || decision.writer_model
    prompt_opts = %{update_mode: :improve, existing: existing}
    prompt = PromptBuilder.build_writing_pass(entry, target, prompt_opts, structure_plan)

    logger.("Step 2/3 Generate draft: #{entry.id}")

    backend_opts =
      writer_model
      |> Helpers.build_backend_opts(%{})
      |> Keyword.put(:system_prompt, Prompts.system_prompt(:writer))
      |> Keyword.put(:generation_opts, temperature: 0.2)

    case ReqLLMBackend.generate(prompt, backend_opts) do
      {:ok, %{text: text}} ->
        parse_generated_draft(text, writer_model, warnings)

      {:error, reason} ->
        {:error, "writer call failed: #{normalize_error(reason)}"}
    end
  end

  defp parse_generated_draft(text, writer_model, warnings) do
    raw_text = to_string(text || "")

    case OutputParser.parse(raw_text) do
      {:ok, envelope} ->
        {:ok, envelope, envelope.parse_mode, writer_model, warnings}

      {:error, parse_reason} ->
        fallback_draft(raw_text, parse_reason, writer_model, warnings)
    end
  end

  defp fallback_draft(raw_text, parse_reason, writer_model, warnings) do
    trimmed = String.trim(raw_text)

    if trimmed == "" do
      {:error, "writer returned empty output and parser failed: #{parse_reason}"}
    else
      envelope = %{
        frontmatter: %{},
        body_markdown: trimmed <> "\n",
        citations: [],
        audit_notes: ["writer_raw_text_fallback"],
        parse_mode: :fallback_markdown
      }

      {:ok, envelope, :fallback_markdown, writer_model, warnings ++ ["writer parse fallback used: #{parse_reason}"]}
    end
  end

  defp render_output(entry, target, existing, envelope) do
    merged_frontmatter =
      Writer.merge_frontmatter(
        existing && existing.frontmatter,
        envelope.frontmatter,
        entry,
        target.route
      )

    rendered = Writer.render_file(merged_frontmatter, envelope.body_markdown)
    {:ok, rendered}
  end

  defp persist(target, rendered, opts, logger) do
    if Map.get(opts, :dry_run, false) do
      logger.("Step 3/3 Persist output: dry-run (no write)")
      {:ok, false}
    else
      logger.("Step 3/3 Persist output: writing #{target.target_path}")

      with :ok <- Writer.write(target.target_path, rendered),
           :ok <- maybe_cleanup_converted_source(target) do
        {:ok, true}
      end
    end
  end

  defp maybe_run_livebook_test(target, opts, logger, warnings) do
    run_livebook_test? = Map.get(opts, :run_livebook_test, false)
    dry_run? = Map.get(opts, :dry_run, false)

    cond do
      not run_livebook_test? ->
        {:ok, nil, warnings}

      dry_run? ->
        {:ok, nil, warnings ++ ["livebook test skipped in dry-run mode"]}

      target.format != :livemd ->
        {:ok, nil, warnings ++ ["livebook test requested but target is not .livemd"]}

      true ->
        logger.("Running Livebook ExUnit test for #{target.route}")

        with {:ok, test_file} <- LivebookTestGenerator.ensure_test_file(target.target_path, target.route),
             {:ok, _output} <- run_livebook_test(test_file) do
          {:ok, test_file, warnings}
        end
    end
  end

  defp run_livebook_test(test_file) do
    {output, status} =
      System.cmd("mix", ["test", test_file, "--include", "livebook"],
        env: [{"INCLUDE_LIVEBOOK_TESTS", "1"}],
        stderr_to_stdout: true
      )

    if status == 0 do
      {:ok, output}
    else
      excerpt = output |> to_string() |> String.slice(0, 2_000)
      {:error, "livebook test failed (#{test_file}):\n#{excerpt}"}
    end
  end

  defp maybe_cleanup_converted_source(target) do
    conversion_source = Map.get(target, :conversion_source_path)

    cond do
      not is_binary(conversion_source) ->
        :ok

      conversion_source == target.target_path ->
        :ok

      not File.exists?(conversion_source) ->
        :ok

      true ->
        case File.rm(conversion_source) do
          :ok -> :ok
          {:error, reason} -> {:error, "failed to remove converted source #{conversion_source}: #{inspect(reason)}"}
        end
    end
  end

  defp fallback_structure_plan(entry, target) do
    contract = Contract.contract(entry, target)

    %{
      frontmatter_plan: %{},
      section_order: contract.required_sections,
      section_briefs: Enum.map_join(contract.required_sections, "\n", &"#{&1}: provide practical, source-grounded guidance."),
      code_plan: "",
      citation_plan: [],
      consistency_rules: []
    }
  end

  defp ensure_runtime do
    case Application.ensure_all_started(:req_llm) do
      {:ok, _started} -> :ok
      {:error, reason} -> {:error, "failed to start req_llm runtime: #{inspect(reason)}"}
    end
  end

  defp normalize_error(error) when is_binary(error), do: error
  defp normalize_error(error) when is_atom(error), do: Atom.to_string(error)
end
