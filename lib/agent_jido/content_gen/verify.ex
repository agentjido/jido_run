defmodule AgentJido.ContentGen.Verify do
  @moduledoc """
  Targeted verification checks for single-entry docs generation runs.
  """

  alias AgentJido.ContentGen.LivebookTestGenerator
  alias AgentJido.Pages

  @type verification :: %{
          status: String.t(),
          checks: [String.t()],
          check_results: map(),
          livebook_test_file: String.t() | nil,
          command_output_excerpt: String.t() | nil
        }

  @spec verify(map(), map(), map(), map(), keyword()) :: verification()
  def verify(entry, target, _candidate, audit, opts \\ []) do
    docs_format = Keyword.get(opts, :docs_format, :tag)
    mix_runner = Keyword.get(opts, :mix_runner, &System.cmd/3)
    test_generator = Keyword.get(opts, :livebook_test_generator, LivebookTestGenerator)

    {audit_status, audit_excerpt} = audit_check(audit)
    {route_status, route_excerpt} = route_render_check(entry, target, docs_format, mix_runner)

    {livebook_status, livebook_file, livebook_excerpt} =
      livebook_test_check(target, test_generator, mix_runner)

    failure_excerpt =
      Enum.find([audit_excerpt, route_excerpt, livebook_excerpt], fn excerpt ->
        is_binary(excerpt) and String.trim(excerpt) != ""
      end)

    overall_status =
      if Enum.all?([audit_status, route_status, livebook_status], &(&1 == "passed")) do
        "passed"
      else
        "failed"
      end

    %{
      status: overall_status,
      checks: ["audit_only", "route_render", "livebook_test"],
      check_results: %{
        audit_only: audit_status,
        route_render: route_status,
        livebook_test: livebook_status
      },
      livebook_test_file: livebook_file,
      command_output_excerpt: failure_excerpt
    }
  end

  defp audit_check(%{errors: []}), do: {"passed", nil}

  defp audit_check(%{errors: errors}) do
    excerpt =
      errors
      |> Enum.take(8)
      |> Enum.map_join("\n", fn error -> "- #{error.code}: #{error.message}" end)

    {"failed", excerpt}
  end

  defp route_render_check(entry, target, docs_format, mix_runner) do
    cond do
      is_nil(Pages.get_page_by_path(target.route)) ->
        {"failed", "route lookup failed: Pages.get_page_by_path(#{target.route}) returned nil"}

      docs_format == :livemd and entry.section == "docs" and not String.ends_with?(target.target_path, ".livemd") ->
        {"failed", "docs-format livemd requires a .livemd target, got #{target.target_path}"}

      true ->
        run_route_render_command(target.route, mix_runner)
    end
  end

  defp run_route_render_command(route, mix_runner) do
    script = route_render_script(route)

    {output, exit_code} =
      mix_runner.(
        "mix",
        ["run", "--no-start", "-e", script],
        env: [{"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    if exit_code == 0 do
      {"passed", nil}
    else
      {"failed", excerpt_output(output)}
    end
  end

  defp route_render_script(route) do
    """
    route = #{Jason.encode!(route)}
    Application.ensure_all_started(:agent_jido)
    conn = Plug.Test.conn("GET", route)
    conn = AgentJidoWeb.Endpoint.call(conn, AgentJidoWeb.Endpoint.init([]))
    if conn.status == 200 do
      IO.puts("route_render_ok:" <> route)
    else
      IO.puts("route_render_failed:" <> route <> ":" <> Integer.to_string(conn.status || 0))
      System.halt(2)
    end
    """
    |> String.trim()
  end

  defp livebook_test_check(target, test_generator, mix_runner) do
    cond do
      target.format != :livemd ->
        {"failed", nil, "livebook verification requires a .livemd target"}

      not File.exists?(target.target_path) ->
        {"failed", nil, "livebook target file missing: #{target.target_path}"}

      code_cell_count(target.target_path) == 0 ->
        {"failed", nil, "livebook verification requires at least one ```elixir code cell"}

      true ->
        livebook_test_result = fn
          _output, 0, livebook_test_file -> {"passed", livebook_test_file, nil}
          output, _exit_code, livebook_test_file -> {"failed", livebook_test_file, excerpt_output(output)}
        end

        case test_generator.ensure_test_file(target.target_path, target.route) do
          {:error, reason} ->
            {"failed", nil, reason}

          {:ok, livebook_test_file} ->
            {output, exit_code} =
              mix_runner.(
                "mix",
                ["test", livebook_test_file, "--include", "livebook"],
                env: [{"MIX_ENV", "test"}, {"INCLUDE_LIVEBOOK_TESTS", "1"}],
                stderr_to_stdout: true
              )

            livebook_test_result.(output, exit_code, livebook_test_file)
        end
    end
  end

  defp code_cell_count(path) do
    ~r/```elixir[^\n]*\n(.*?)```/s
    |> Regex.scan(File.read!(path), capture: :all_but_first)
    |> length()
  rescue
    _ -> 0
  end

  defp excerpt_output(output) do
    output
    |> to_string()
    |> String.trim()
    |> String.slice(-2_400, 2_400)
  end
end
