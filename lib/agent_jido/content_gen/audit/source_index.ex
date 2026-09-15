defmodule AgentJido.ContentGen.Audit.SourceIndex do
  @moduledoc """
  Builds a module/function export index from sibling repositories, with deps fallback.
  """

  @default_packages ["jido", "jido_action", "jido_signal", "jido_ai", "jido_browser", "req_llm", "agent_jido"]

  @type t :: %{
          modules: MapSet.t(String.t()),
          exports: MapSet.t({String.t(), String.t(), non_neg_integer()}),
          package_paths: %{String.t() => String.t()},
          scanned_files: non_neg_integer()
        }

  @spec build(keyword()) :: t()
  def build(opts \\ []) do
    source_root = Keyword.get(opts, :source_root, "..")

    package_ids =
      opts
      |> Keyword.get(:packages, @default_packages)
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> Enum.uniq()

    package_paths =
      package_ids
      |> Enum.reduce(%{}, fn package_id, acc ->
        case resolve_package_path(package_id, source_root) do
          {:ok, path} -> Map.put(acc, package_id, path)
          :error -> acc
        end
      end)

    {modules, exports, scanned_files} =
      package_paths
      |> Map.values()
      |> Enum.flat_map(&Path.wildcard(Path.join([&1, "lib", "**", "*.ex"])))
      |> Enum.reduce({MapSet.new(), MapSet.new(), 0}, fn file, {modules_acc, exports_acc, count} ->
        case parse_file(file) do
          {:ok, file_modules, file_exports} ->
            {
              MapSet.union(modules_acc, file_modules),
              MapSet.union(exports_acc, file_exports),
              count + 1
            }

          {:error, _reason} ->
            {modules_acc, exports_acc, count}
        end
      end)

    %{
      modules: modules,
      exports: exports,
      package_paths: package_paths,
      scanned_files: scanned_files
    }
  end

  @spec normalize(t() | map()) :: t()
  def normalize(index) when is_map(index) do
    %{
      modules: to_mapset(fetch_index(index, :modules)),
      exports: to_mapset(fetch_index(index, :exports)),
      package_paths: fetch_index(index, :package_paths) || %{},
      scanned_files: fetch_index(index, :scanned_files) || 0
    }
  end

  @spec module_exists?(t(), String.t()) :: boolean()
  def module_exists?(index, module_name) do
    index
    |> normalize()
    |> Map.fetch!(:modules)
    |> MapSet.member?(normalize_module(module_name))
  end

  @spec export_exists?(t(), String.t(), String.t(), non_neg_integer()) :: boolean()
  def export_exists?(index, module_name, function_name, arity) do
    index
    |> normalize()
    |> Map.fetch!(:exports)
    |> MapSet.member?({normalize_module(module_name), to_string(function_name), arity})
  end

  defp fetch_index(index, key) do
    Map.get(index, key) || Map.get(index, Atom.to_string(key))
  end

  defp to_mapset(%MapSet{} = set), do: set
  defp to_mapset(list) when is_list(list), do: MapSet.new(list)
  defp to_mapset(nil), do: MapSet.new()

  defp resolve_package_path(package_id, source_root) do
    cwd = File.cwd!()
    sibling = Path.expand(Path.join(source_root, package_id), cwd)
    deps = Path.expand(Path.join("deps", package_id), cwd)

    cond do
      File.dir?(sibling) -> {:ok, sibling}
      File.dir?(deps) -> {:ok, deps}
      true -> :error
    end
  end

  defp parse_file(path) do
    with {:ok, contents} <- File.read(path),
         {:ok, ast} <- Code.string_to_quoted(contents, file: path) do
      {modules, exports} = collect(ast, nil, MapSet.new(), MapSet.new())
      {:ok, modules, exports}
    else
      _ -> {:error, :parse_failed}
    end
  end

  defp collect({:defmodule, _meta, [module_ast, [do: body]]}, _current_module, modules, exports) do
    module_name = module_ast_to_string(module_ast)
    modules = MapSet.put(modules, module_name)
    collect(body, module_name, modules, exports)
  end

  defp collect({kind, _meta, [{name, _meta2, args} | _]} = ast, current_module, modules, exports)
       when kind in [:def, :defmacro] and is_atom(name) do
    arity = arity(args)

    exports =
      if is_binary(current_module) do
        MapSet.put(exports, {current_module, Atom.to_string(name), arity})
      else
        exports
      end

    recurse(ast, current_module, modules, exports)
  end

  defp collect({:@, _meta, [{attr, _attr_meta, [spec_ast]}]} = ast, current_module, modules, exports)
       when attr in [:callback, :macrocallback] do
    exports =
      case callback_signature(spec_ast) do
        {name, arity} when is_binary(current_module) ->
          MapSet.put(exports, {current_module, name, arity})

        _ ->
          exports
      end

    recurse(ast, current_module, modules, exports)
  end

  defp collect(ast, current_module, modules, exports), do: recurse(ast, current_module, modules, exports)

  defp recurse(list, current_module, modules, exports) when is_list(list) do
    Enum.reduce(list, {modules, exports}, fn item, {m_acc, e_acc} ->
      collect(item, current_module, m_acc, e_acc)
    end)
  end

  defp recurse(tuple, current_module, modules, exports) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.reduce({modules, exports}, fn item, {m_acc, e_acc} ->
      collect(item, current_module, m_acc, e_acc)
    end)
  end

  defp recurse(_other, _current_module, modules, exports), do: {modules, exports}

  defp arity(nil), do: 0
  defp arity(args) when is_list(args), do: length(args)
  defp arity(_args), do: 0

  defp callback_signature({:"::", _meta, [head | _rest]}), do: callback_signature(head)
  defp callback_signature({:when, _meta, [head | _rest]}), do: callback_signature(head)

  defp callback_signature({name, _meta, args}) when is_atom(name) do
    {Atom.to_string(name), arity(args)}
  end

  defp callback_signature(_other), do: nil

  defp module_ast_to_string({:__aliases__, _meta, parts}) when is_list(parts) do
    parts
    |> Module.concat()
    |> Atom.to_string()
    |> normalize_module()
  end

  defp module_ast_to_string(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> normalize_module()
  end

  defp module_ast_to_string(other), do: normalize_module(to_string(other))

  defp normalize_module(module_name) do
    module_name
    |> to_string()
    |> String.replace_prefix("Elixir.", "")
  end
end
