defmodule AgentJido.OGImage.Resolver do
  @moduledoc """
  Resolves site routes into normalized Open Graph descriptors.
  """

  require Logger

  alias AgentJido.Blog
  alias AgentJido.Ecosystem
  alias AgentJido.Examples
  alias AgentJido.OGImage.Descriptor
  alias AgentJido.Pages

  @og_render_version "v8"

  @top_level_routes %{
    "/" => %{
      template: :home,
      title: "A Runtime for Reliable Multi-Agent Systems",
      subtitle: "Jido is a runtime for reliable, multi-agent systems, built on Elixir/OTP for fault isolation, concurrency, and production uptime.",
      eyebrow: "JIDO",
      badges: ["Elixir/OTP", "Multi-Agent", "Production"]
    },
    "/getting-started" => %{
      template: :marketing,
      title: "Getting Started with Jido",
      subtitle: "Install Jido and build your first Elixir/OTP multi-agent workflow in minutes.",
      eyebrow: "GETTING STARTED",
      badges: ["Quickstart", "Install", "First Workflow"]
    },
    "/features" => %{
      template: :marketing,
      title: "Jido Features",
      subtitle: "Explore the architecture and runtime capabilities that make Jido reliable for production multi-agent systems.",
      eyebrow: "FEATURES",
      badges: ["Reliability", "Coordination", "Operations"]
    },
    "/ecosystem" => %{
      template: :marketing,
      title: "Jido Ecosystem",
      subtitle: "Discover composable Jido packages across runtime core, AI orchestration, and production operations.",
      eyebrow: "ECOSYSTEM",
      badges: ["Packages", "Composability", "Layers"]
    },
    "/ecosystem/matrix" => %{
      template: :marketing,
      title: "Jido Ecosystem Compare Packages",
      subtitle: "Compare responsibilities, dependencies, and support levels from the main Jido ecosystem hub.",
      eyebrow: "COMPARE PACKAGES",
      badges: ["Compare", "Dependencies", "Support Levels"]
    },
    "/examples" => %{
      template: :marketing,
      title: "Jido Examples",
      subtitle: "Run practical examples that show how to design, coordinate, and operate agents with Jido.",
      eyebrow: "EXAMPLES",
      badges: ["Core", "AI", "Production"]
    },
    "/docs" => %{
      template: :docs_page,
      title: "Jido Documentation",
      subtitle: "Reference docs and implementation guides for building reliable multi-agent systems with Jido.",
      eyebrow: "DOCS",
      badges: ["Reference", "Guides", "Cookbook"]
    },
    "/build" => %{
      template: :marketing,
      title: "Build with Jido",
      subtitle: "Implementation blueprints and practical build paths for shipping Jido-powered agent systems.",
      eyebrow: "BUILD",
      badges: ["Blueprints", "Implementation", "Delivery"]
    },
    "/community" => %{
      template: :marketing,
      title: "Jido Community",
      subtitle: "Build agents with us. Join Discord, collaborate on GitHub, and contribute across the Jido ecosystem.",
      eyebrow: "COMMUNITY",
      badges: ["Discord", "Contributing", "Ecosystem"]
    },
    "/community/showcase" => %{
      template: :marketing,
      title: "Built with Jido Showcase",
      subtitle: "Community projects built with Jido, from production systems to focused experiments.",
      eyebrow: "COMMUNITY SHOWCASE",
      badges: ["Projects", "Community", "Built with Jido"]
    },
    "/blog" => %{
      template: :marketing,
      title: "Blog",
      subtitle: "Product updates, technical write-ups, and release notes from the Jido project.",
      eyebrow: "BLOG",
      badges: ["Updates", "Technical", "Releases"]
    }
  }

  @spec resolve_path(String.t()) :: {:ok, Descriptor.t()}
  def resolve_path(path) do
    normalized_path = normalize_path(path)

    descriptor =
      top_level_descriptor(normalized_path) ||
        blog_tag_descriptor(normalized_path) ||
        blog_post_descriptor(normalized_path) ||
        example_descriptor(normalized_path) ||
        ecosystem_package_descriptor(normalized_path) ||
        page_descriptor(normalized_path) ||
        not_found_descriptor(normalized_path)

    if descriptor.template == :not_found and normalized_path != "/__not_found__" do
      Logger.warning("OG resolver miss path=#{inspect(normalized_path)}")
    end

    {:ok, descriptor}
  rescue
    error ->
      Logger.warning("OG resolver failure path=#{inspect(path)} reason=#{inspect(error)}")
      {:ok, not_found_descriptor(normalize_path(path))}
  end

  defp top_level_descriptor(path) do
    case Map.get(@top_level_routes, path) do
      nil ->
        nil

      metadata ->
        descriptor_from_metadata(path, metadata)
    end
  end

  defp blog_tag_descriptor(path) do
    case Regex.run(~r{^/blog/tags/([^/]+)$}, path) do
      [_, tag] ->
        metadata = %{
          template: :marketing,
          title: "Blog Tag: #{tag}",
          subtitle: "Posts tagged with #{tag} on the Jido blog.",
          eyebrow: "BLOG TAG",
          badges: [tag]
        }

        descriptor_from_metadata(path, metadata)

      _ ->
        nil
    end
  end

  defp blog_post_descriptor(path) do
    case Regex.run(~r{^/blog/([^/]+)$}, path) do
      [_, slug] ->
        case Blog.get_post_by_id!(slug) do
          post ->
            title = post.title |> to_string() |> String.trim()
            subtitle = post_summary(post)
            freshness_hash = freshness_hash(post)
            badges = Enum.take(post.tags || [], 5)

            build_descriptor(%{
              template: :blog_post,
              resolved_path: path,
              title: title,
              subtitle: subtitle,
              eyebrow: "BLOG POST",
              badges: badges,
              footer_path: path,
              content_hash: freshness_hash || hash_from([path, title, subtitle, inspect(badges)])
            })
        end

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp example_descriptor(path) do
    case Regex.run(~r{^/examples/([^/]+)$}, path) do
      [_, slug] ->
        case Examples.get_example(slug) do
          nil ->
            nil

          example ->
            title = example.title |> to_string() |> String.trim()
            subtitle = example.description |> to_string() |> String.trim()

            badges =
              [Atom.to_string(example.category), Atom.to_string(example.difficulty) | example.tags]
              |> Enum.take(5)

            build_descriptor(%{
              template: :example,
              resolved_path: path,
              title: title,
              subtitle: subtitle,
              eyebrow: "EXAMPLE",
              badges: badges,
              footer_path: path,
              content_hash: hash_from([path, title, subtitle, inspect(badges)])
            })
        end

      _ ->
        nil
    end
  end

  defp ecosystem_package_descriptor(path) do
    case Regex.run(~r{^/ecosystem/([^/]+)$}, path) do
      [_, "matrix"] ->
        nil

      [_, "package-matrix"] ->
        nil

      [_, id] ->
        id
        |> Ecosystem.get_public_package()
        |> build_ecosystem_package_descriptor(path)

      _ ->
        nil
    end
  end

  defp build_ecosystem_package_descriptor(nil, _path), do: nil

  defp build_ecosystem_package_descriptor(package, path) do
    title = package.title |> to_string() |> String.trim()
    subtitle = package_subtitle(package)
    badges = ecosystem_badges(package)

    build_descriptor(%{
      template: :ecosystem_package,
      resolved_path: path,
      title: title,
      subtitle: subtitle,
      eyebrow: "ECOSYSTEM PACKAGE",
      badges: badges,
      footer_path: path,
      content_hash: hash_from([path, title, subtitle, package.version || "", inspect(badges)])
    })
  end

  defp package_subtitle(package) do
    case package.landing_summary |> to_string() |> String.trim() do
      "" -> package.tagline |> to_string() |> String.trim()
      value -> value
    end
  end

  defp ecosystem_badges(package) do
    [Atom.to_string(package.category), package.version, Atom.to_string(package.maturity)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.take(5)
  end

  defp page_descriptor(path) do
    case Pages.resolve_page_for_path(path) do
      {:ok, page, _resolution} when page.category in [:docs, :build, :community, :features] ->
        template = if page.category == :docs, do: :docs_page, else: :marketing
        title = page.title |> to_string() |> String.trim()
        subtitle = page_summary(page)
        badges = page_badges(page)
        fresh_hash = freshness_hash(page)

        build_descriptor(%{
          template: template,
          resolved_path: path,
          title: title,
          subtitle: subtitle,
          eyebrow: String.upcase(Atom.to_string(page.category)),
          badges: badges,
          footer_path: Pages.route_for(page),
          content_hash: fresh_hash || hash_from([path, title, subtitle, inspect(badges)])
        })

      _ ->
        nil
    end
  end

  defp descriptor_from_metadata(path, metadata) do
    build_descriptor(%{
      template: metadata.template,
      resolved_path: path,
      title: metadata.title,
      subtitle: metadata.subtitle,
      eyebrow: metadata.eyebrow,
      badges: metadata.badges || [],
      footer_path: path,
      content_hash: hash_from([path, metadata.title, metadata.subtitle || "", inspect(metadata.badges || [])])
    })
  end

  defp not_found_descriptor(path) do
    build_descriptor(%{
      template: :not_found,
      resolved_path: path,
      title: "Page Not Found",
      subtitle: "The requested page could not be resolved for social sharing.",
      eyebrow: "NOT FOUND",
      badges: [],
      footer_path: "/",
      content_hash: hash_from([path, "not_found"])
    })
  end

  defp build_descriptor(attrs) do
    resolved_path = attrs.resolved_path
    content_hash = hash_from([@og_render_version, attrs.content_hash || ""])

    %Descriptor{
      template: attrs.template,
      title: attrs.title,
      subtitle: attrs.subtitle,
      eyebrow: attrs.eyebrow,
      badges: Enum.map(attrs.badges || [], &to_string/1),
      footer_url: footer_url(attrs.footer_path || resolved_path),
      content_hash: content_hash,
      cache_key: "#{@og_render_version}:path=#{resolved_path}:hash=#{content_hash}",
      resolved_path: resolved_path
    }
  end

  defp normalize_path(path) when is_binary(path) do
    parsed_path =
      case URI.parse(path) do
        %URI{path: nil} -> path
        %URI{path: parsed} -> parsed
      end

    normalized_path =
      case parsed_path do
        "" ->
          "/"

        value ->
          if String.starts_with?(value, "/"), do: value, else: "/" <> value
      end

    if normalized_path == "/", do: "/", else: String.trim_trailing(normalized_path, "/")
  end

  defp normalize_path(_), do: "/"

  defp site_host do
    AgentJido.Site.canonical_host()
  end

  defp footer_url(path) do
    normalized = normalize_path(path)

    case normalized do
      "/" -> site_host()
      value -> site_host() <> value
    end
  end

  defp post_summary(post) do
    (post.description || "")
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "Technical write-up from the Jido blog."
      value -> value
    end
  end

  defp page_summary(page) do
    page.description
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "Implementation guidance for building with Jido."
      value -> value
    end
  end

  defp page_badges(page) do
    category_badge =
      page.category
      |> Atom.to_string()
      |> String.upcase()

    [category_badge | Enum.map(page.tags || [], &to_string/1)]
    |> Enum.take(5)
  end

  defp freshness_hash(entity) do
    freshness = Map.get(entity, :freshness, %{}) || %{}
    value = map_value(freshness, :content_hash)

    case value do
      hash when is_binary(hash) and hash != "" -> hash
      _ -> nil
    end
  end

  defp map_value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp map_value(_map, _key), do: nil

  defp hash_from(parts) do
    parts
    |> Enum.map_join("|", &to_string/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
