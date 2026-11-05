defmodule AgentJido.ContentGen.Writer do
  @moduledoc """
  File IO, frontmatter merge, and idempotence/churn checks for content generation.
  """

  alias AgentJido.ContentGen
  alias AgentJido.Pages.LivebookParser

  @preserved_frontmatter_keys [:category, :legacy_paths, :order, :menu_label, :in_menu]

  @ordered_frontmatter_keys [
    :title,
    :description,
    :category,
    :legacy_paths,
    :tags,
    :order,
    :menu_label,
    :in_menu,
    :draft,
    :doc_type,
    :audience,
    :track,
    :difficulty,
    :duration_minutes,
    :prerequisites,
    :learning_outcomes
  ]

  @spec read_existing(String.t()) :: {:ok, map()} | :missing | {:error, String.t()}
  def read_existing(path) do
    case File.read(path) do
      {:ok, raw} -> parse_existing(path, raw)
      {:error, :enoent} -> :missing
      {:error, reason} -> {:error, "failed to read existing file #{path}: #{inspect(reason)}"}
    end
  end

  @spec parse_existing(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_existing(path, raw) do
    {frontmatter, body} = LivebookParser.parse(path, raw)
    {:ok, %{frontmatter: frontmatter, body: body, raw: raw}}
  rescue
    e -> {:error, "failed to parse existing frontmatter for #{path}: #{Exception.message(e)}"}
  end

  @spec merge_frontmatter(map() | nil, map(), struct(), String.t()) :: map()
  def merge_frontmatter(existing_frontmatter, generated_frontmatter, entry, route) do
    base = generated_frontmatter || %{}
    existing_frontmatter = existing_frontmatter || %{}

    base
    |> ensure_key(:title, existing_frontmatter[:title] || entry.title)
    |> ensure_key(:description, existing_frontmatter[:description] || entry.purpose)
    |> ensure_key(:category, existing_frontmatter[:category] || category_for_route(route))
    |> ensure_key(:order, existing_frontmatter[:order] || entry.order)
    |> preserve_existing(existing_frontmatter)
    |> preserve_published_draft_state(existing_frontmatter)
  end

  @spec render_file(map(), String.t()) :: String.t()
  def render_file(frontmatter, body_markdown) do
    frontmatter_block = render_frontmatter(frontmatter)

    """
    #{frontmatter_block}
    ---
    #{String.trim_leading(body_markdown)}
    """
    |> String.trim_leading()
  end

  @spec noop?(String.t() | nil, String.t()) :: boolean()
  def noop?(nil, _new_raw), do: false

  def noop?(existing_raw, new_raw) when is_binary(existing_raw) and is_binary(new_raw) do
    normalize_text(existing_raw) == normalize_text(new_raw)
  end

  @spec churn_guard(map() | nil, String.t(), non_neg_integer()) :: :ok | {:error, String.t()}
  def churn_guard(nil, _new_raw, _audit_error_count), do: :ok

  def churn_guard(%{raw: existing_raw}, new_raw, audit_error_count)
      when is_binary(existing_raw) and is_binary(new_raw) do
    old_size = byte_size(existing_raw)
    new_size = byte_size(new_raw)

    change_ratio =
      if old_size == 0 do
        1.0
      else
        abs(new_size - old_size) / old_size
      end

    old_headings = heading_count(existing_raw)
    new_headings = heading_count(new_raw)

    cond do
      old_headings >= 2 and new_headings < max(1, div(old_headings, 2)) ->
        {:error, "churn_guard: heading structure regressed"}

      change_ratio > 0.8 and audit_error_count > 0 ->
        {:error, "churn_guard: large rewrite with audit errors"}

      true ->
        :ok
    end
  end

  @spec write(String.t(), String.t()) :: :ok | {:error, String.t()}
  def write(path, content) do
    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, content) do
      :ok
    else
      {:error, reason} -> {:error, "failed to write #{path}: #{inspect(reason)}"}
    end
  end

  defp ensure_key(map, _key, nil), do: map
  defp ensure_key(map, key, value), do: Map.put_new(map, key, value)

  defp preserve_existing(frontmatter, existing_frontmatter) do
    Enum.reduce(@preserved_frontmatter_keys, frontmatter, fn key, acc ->
      case Map.fetch(existing_frontmatter, key) do
        {:ok, value} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end

  defp preserve_published_draft_state(frontmatter, existing_frontmatter) do
    if existing_frontmatter[:draft] == false do
      Map.put(frontmatter, :draft, false)
    else
      frontmatter
    end
  end

  defp category_for_route(route) do
    case ContentGen.normalize_route(route) |> String.trim_leading("/") |> String.split("/", parts: 2) do
      ["docs" | _] -> :docs
      ["training" | _] -> :training
      ["build" | _] -> :build
      ["community" | _] -> :community
      ["ecosystem" | _] -> :ecosystem
      ["features" | _] -> :features
      ["examples" | _] -> :examples
      _ -> :docs
    end
  end

  defp render_frontmatter(frontmatter) do
    ordered_keys =
      @ordered_frontmatter_keys ++
        (frontmatter |> Map.keys() |> Enum.reject(&(&1 in @ordered_frontmatter_keys)) |> Enum.sort())

    lines =
      ordered_keys
      |> Enum.filter(&Map.has_key?(frontmatter, &1))
      |> Enum.map(fn key ->
        "  #{key}: #{to_elixir_literal(frontmatter[key])},"
      end)

    "%{\n" <> Enum.join(lines, "\n") <> "\n}"
  end

  defp to_elixir_literal(value) when is_binary(value), do: inspect(value)
  defp to_elixir_literal(value) when is_atom(value), do: inspect(value)
  defp to_elixir_literal(value) when is_integer(value), do: Integer.to_string(value)
  defp to_elixir_literal(value) when is_float(value), do: Float.to_string(value)

  defp to_elixir_literal(value) when is_list(value) do
    "[" <> Enum.map_join(value, ", ", &to_elixir_literal/1) <> "]"
  end

  defp to_elixir_literal(value) when is_map(value) do
    pairs =
      value
      |> Enum.map_join(", ", fn {k, v} -> "#{to_elixir_literal(k)} => #{to_elixir_literal(v)}" end)

    "%{" <> pairs <> "}"
  end

  defp to_elixir_literal(value), do: inspect(value)

  defp normalize_text(text) do
    text
    |> String.split("\n")
    |> Enum.map_join("\n", &String.trim_trailing/1)
    |> String.trim()
  end

  defp heading_count(text) do
    Regex.scan(~r/^\#{1,3}\s+/m, text) |> length()
  end
end
