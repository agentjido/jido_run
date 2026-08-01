defmodule AgentJidoWeb.MarkdownContent do
  @moduledoc """
  Resolves markdown payloads for public site routes.
  """

  alias AgentJido.Blog
  alias AgentJido.Community.Showcase
  alias AgentJido.Ecosystem
  alias AgentJido.Examples
  alias AgentJido.Pages
  alias AgentJido.ReleaseCatalog

  @doc """
  Returns true when the request path is in the markdown-enabled public route set.
  """
  @spec eligible_public_path?(String.t()) :: boolean()
  def eligible_public_path?(path) when is_binary(path) do
    not excluded_prefix?(path) and allowed_prefix?(path)
  end

  @doc """
  Resolves a markdown payload for a request path.

  Returns `:no_match` when the path should fall through to normal routing.
  """
  @spec resolve(String.t(), String.t()) :: {:ok, String.t()} | :no_match
  def resolve(path, absolute_url) when is_binary(path) and is_binary(absolute_url) do
    case resolve_path(path) do
      {:ok, markdown} ->
        {:ok, markdown}

      {:fallback, title, summary} ->
        {:ok, fallback_markdown(title, absolute_url, summary)}

      :no_match ->
        :no_match
    end
  end

  defp resolve_path(path) do
    resolve_from_pages(path) ||
      resolve_from_blog(path) ||
      resolve_from_ecosystem(path) ||
      resolve_from_examples(path) ||
      resolve_from_showcase(path) ||
      resolve_misc(path) ||
      :no_match
  end

  defp resolve_from_pages(path) do
    case Pages.resolve_page_for_path(path) do
      {:ok, _page, :legacy} ->
        # Preserve existing redirect behavior for legacy routes.
        :no_match

      {:ok, page, _resolution} ->
        case read_source_markdown(map_get(page, :source_path)) do
          {:ok, markdown} ->
            # Expand release placeholders so the public `.md` payload carries real
            # dependency requirements instead of raw `{{mix_dep:*}}` tokens. This
            # keeps the Markdown endpoint in parity with the rendered HTML page
            # (see E01-T08). Pages are the surface that uses these tokens.
            {:ok, ReleaseCatalog.expand_placeholders(markdown)}

          _other ->
            {:fallback, map_get(page, :title) || "Site Page", page_summary(page)}
        end

      :error ->
        nil
    end
  end

  defp resolve_from_blog("/blog") do
    {:fallback, "Engineering Blog", "Product updates, release notes, and practical guides for building reliable AI agents in Elixir and on the BEAM."}
  end

  defp resolve_from_blog("/blog/tags/" <> tag_path) do
    if valid_single_segment?(tag_path) do
      tag = String.trim(tag_path)

      try do
        posts = Blog.get_posts_by_tag!(tag)

        {:fallback, "Blog tag: #{tag}", "Posts tagged with #{tag}. Matching posts: #{length(posts)}."}
      rescue
        Blog.NotFoundError -> :no_match
      end
    else
      :no_match
    end
  end

  defp resolve_from_blog("/blog/" <> slug) do
    if valid_single_segment?(slug) do
      try do
        post = Blog.get_post_by_id!(slug)

        case read_source_markdown(map_get(post, :source_path)) do
          {:ok, markdown} ->
            {:ok, markdown}

          _other ->
            {:fallback, map_get(post, :title) || "Blog Post", post_summary(post)}
        end
      rescue
        Blog.NotFoundError -> :no_match
      end
    else
      :no_match
    end
  end

  defp resolve_from_blog(_path), do: nil

  defp resolve_from_ecosystem("/ecosystem") do
    {:fallback, "Jido Ecosystem", "Discover composable Jido packages across runtime core, AI orchestration, and production operations."}
  end

  defp resolve_from_ecosystem("/ecosystem/matrix") do
    {:fallback, "Jido Ecosystem", "Compare packages from the main Jido ecosystem hub."}
  end

  defp resolve_from_ecosystem("/ecosystem/package-matrix") do
    resolve_from_ecosystem("/ecosystem/matrix")
  end

  defp resolve_from_ecosystem("/ecosystem/" <> id_path) do
    if valid_single_segment?(id_path) do
      id_path
      |> String.trim()
      |> Ecosystem.get_public_package()
      |> resolve_markdown_target("Ecosystem Package", &package_summary/1, &map_get(&1, :path), &map_get(&1, :title))
    else
      :no_match
    end
  end

  defp resolve_from_ecosystem(_path), do: nil

  defp resolve_from_examples("/examples") do
    {:fallback, "Jido Examples", "Interactive and production-oriented examples for agent workflows, orchestration, and reliability patterns."}
  end

  defp resolve_from_examples("/examples/" <> slug_path) do
    if valid_single_segment?(slug_path) do
      slug_path
      |> String.trim()
      |> Examples.get_example()
      |> resolve_markdown_target("Example", &example_summary/1, &map_get(&1, :source_path), &map_get(&1, :title))
    else
      :no_match
    end
  end

  defp resolve_from_examples(_path), do: nil

  defp resolve_from_showcase("/community") do
    {:fallback, "Jido Community", "Build agents with us. Join Discord, collaborate on GitHub, and contribute across the Jido ecosystem."}
  end

  defp resolve_from_showcase("/community/showcase") do
    count = Showcase.project_count()

    summary =
      "Community showcase of real projects built with Jido. " <>
        "#{count} project#{if count == 1, do: "", else: "s"} currently listed."

    {:fallback, "Built with Jido Showcase", summary}
  end

  defp resolve_from_showcase(_path), do: nil

  defp resolve_markdown_target(nil, _default_title, _summary_fun, _path_fun, _title_fun), do: :no_match

  defp resolve_markdown_target(item, default_title, summary_fun, path_fun, title_fun) do
    case read_source_markdown(path_fun.(item)) do
      {:ok, markdown} ->
        {:ok, markdown}

      _other ->
        {:fallback, title_fun.(item) || default_title, summary_fun.(item)}
    end
  end

  defp resolve_misc("/") do
    {:fallback, "Agent Jido",
     "The Elixir framework for long-running agent systems. Build supervised agents, typed tools, and explicit workflows on Elixir/OTP."}
  end

  defp resolve_misc("/getting-started") do
    {:fallback, "Getting Started", "First-step onboarding route for building your first agent workflow with Jido."}
  end

  defp resolve_misc("/features") do
    {:fallback, "Jido Features",
     "Runtime capabilities, orchestration strategies, and ecosystem components for long-running agent systems on Elixir/OTP."}
  end

  defp resolve_misc("/skills") do
    {:fallback, "Jido Skills Catalog",
     "Vendored upstream Jido package skills plus the router skill, surfaced as a public catalog page in the workbench."}
  end

  defp resolve_misc(_path), do: nil

  defp fallback_markdown(title, absolute_url, summary) do
    normalized_summary = normalize_summary(summary)

    """
    # #{title}

    Canonical URL: #{absolute_url}

    #{normalized_summary}

    ---
    This markdown payload is generated from the rendered route when direct source markdown is not available.
    """
  end

  defp page_summary(page) do
    map_get(page, :description) || plain_text(map_get(page, :body))
  end

  defp post_summary(post) do
    map_get(post, :description) || plain_text(map_get(post, :body))
  end

  defp package_summary(package) do
    map_get(package, :tagline) || map_get(package, :description) || plain_text(map_get(package, :body))
  end

  defp example_summary(example) do
    map_get(example, :description) || plain_text(map_get(example, :body))
  end

  defp normalize_summary(summary) when is_binary(summary) do
    summary
    |> String.trim()
    |> case do
      "" -> "No additional summary available."
      value -> value
    end
  end

  defp normalize_summary(_summary), do: "No additional summary available."

  defp plain_text(value) when is_binary(value) do
    value
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 280)
  end

  defp plain_text(_value), do: ""

  defp read_source_markdown(path) when is_binary(path) and path != "" do
    case read_if_regular(path) do
      {:ok, markdown} ->
        {:ok, markdown}

      {:error, :missing} ->
        with reconstructed when is_binary(reconstructed) <- reconstruct_packaged_path(path),
             {:ok, markdown} <- read_if_regular(reconstructed) do
          {:ok, markdown}
        else
          _other -> {:error, :missing}
        end
    end
  end

  defp read_source_markdown(_path), do: {:error, :missing}

  defp read_if_regular(path) do
    if File.regular?(path), do: File.read(path), else: {:error, :missing}
  end

  # Pages are compiled with absolute source paths from the build host.
  # At runtime (e.g. release image), that absolute root changes. Rebuild
  # a runtime-local path from the first `/priv/...` suffix if present.
  defp reconstruct_packaged_path(path) when is_binary(path) do
    case String.split(path, "/priv/", parts: 2) do
      [_prefix, suffix] when suffix != "" ->
        Path.join(Application.app_dir(:agent_jido), Path.join("priv", suffix))

      _other ->
        nil
    end
  end

  defp map_get(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp valid_single_segment?(segment) when is_binary(segment) do
    trimmed = String.trim(segment)
    trimmed != "" and not String.contains?(trimmed, "/")
  end

  defp allowed_prefix?(path) do
    path == "/" or
      path == "/getting-started" or
      String.starts_with?(path, "/docs") or
      String.starts_with?(path, "/blog") or
      String.starts_with?(path, "/ecosystem") or
      String.starts_with?(path, "/features") or
      String.starts_with?(path, "/build") or
      String.starts_with?(path, "/community") or
      String.starts_with?(path, "/examples")
  end

  defp excluded_prefix?(path) do
    String.starts_with?(path, "/users") or
      String.starts_with?(path, "/dashboard") or
      String.starts_with?(path, "/dev") or
      String.starts_with?(path, "/assets") or
      String.starts_with?(path, "/og/") or
      path == "/feed" or
      path == "/sitemap.xml"
  end
end
