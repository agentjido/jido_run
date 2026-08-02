defmodule AgentJidoWeb.BlogLive do
  @moduledoc """
  LiveView-backed blog index, tag listing, and post show pages.
  """
  use AgentJidoWeb, :live_view

  import AgentJidoWeb.Jido.MarketingLayouts

  alias AgentJido.Blog
  alias AgentJidoWeb.MarkdownLinks
  alias AgentJidoWeb.StructuredData

  @blog_index_description "Product updates, technical write-ups, and release notes from the Jido project."

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, tags: Blog.all_tags())}
  end

  @impl true
  def handle_params(params, uri, socket) do
    parsed_uri = URI.parse(uri)
    request_path = parsed_uri.path || "/blog"
    request_url = MarkdownLinks.absolute_url(request_path, parsed_uri.query)

    socket =
      socket
      |> assign(:request_path, request_path)
      |> assign(:request_url, request_url)

    socket =
      case socket.assigns.live_action do
        :index -> assign_index(socket)
        :show -> assign_show(socket, params, request_url)
        :tag -> assign_tag(socket, params)
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.marketing_layout
      current_path="/blog"
      current_scope={@current_scope}
      analytics_identity={@analytics_identity}
    >
      <%= case @live_action do %>
        <% :index -> %>
          <.blog_index posts={@posts} tags={@tags} />
        <% :tag -> %>
          <.blog_tag posts={@posts} tags={@tags} tag={@tag} />
        <% :show -> %>
          <.blog_show post={@post} markdown_action={@markdown_action} />
      <% end %>
    </.marketing_layout>
    """
  end

  attr :posts, :list, required: true
  attr :tags, :list, required: true

  defp blog_index(assigns) do
    ~H"""
    <div id="blog-index-page" class="container max-w-[1000px] mx-auto px-6 py-12">
      <section class="mb-8 rounded-lg border border-border bg-card px-6 py-7 md:px-8 md:py-8">
        <p class="mb-3 text-xs font-semibold uppercase tracking-[0.12em] text-primary">Agent Jido</p>
        <h1 class="text-3xl font-bold tracking-tight text-foreground md:text-4xl">Engineering Blog</h1>
        <p class="copy-measure-wide mt-3 text-sm text-muted-foreground md:text-base">
          Product updates, release notes, and practical guides for building reliable AI agents in Elixir and on the BEAM.
        </p>
      </section>

      <div class="grid grid-cols-1 lg:grid-cols-4 gap-8">
        <div class="lg:col-span-3">
          <%= for post <- @posts do %>
            <.post_card post={post} />
          <% end %>
        </div>

        <div class="lg:col-span-1">
          <div class="sticky top-24 bg-card rounded-lg p-6 border border-border">
            <h2 class="text-xl font-bold mb-4 text-foreground">Tags</h2>
            <div class="flex flex-wrap gap-2 mb-6">
              <%= for tag <- @tags do %>
                <.link
                  patch={~p"/blog/tags/#{tag}"}
                  class="inline-block bg-elevated rounded-full px-3 py-1 text-sm text-muted-foreground hover:text-foreground transition-colors"
                >
                  {tag}
                </.link>
              <% end %>
            </div>

            <h2 class="text-xl font-bold mb-4 text-foreground">Follow us</h2>
            <div class="flex gap-4">
              <a
                href="https://github.com/agentjido/jido"
                class="text-muted-foreground hover:text-foreground transition-colors"
              >
                <AgentJidoWeb.Jido.Nav.github_icon class="w-6 h-6" />
              </a>
              <a
                href="https://x.com/agentjido"
                class="text-muted-foreground hover:text-foreground transition-colors"
              >
                <AgentJidoWeb.Jido.Nav.x_icon class="w-6 h-6" />
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :posts, :list, required: true
  attr :tags, :list, required: true
  attr :tag, :string, required: true

  defp blog_tag(assigns) do
    ~H"""
    <div id="blog-tag-page" class="container max-w-[1000px] mx-auto px-6 py-12">
      <div class="mb-6">
        <.link patch={~p"/blog"} class="text-primary hover:opacity-80 flex items-center gap-1 transition-opacity text-sm">
          <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to all posts
        </.link>
      </div>

      <h1 class="text-3xl font-bold mb-8 text-foreground">Posts tagged with "{@tag}"</h1>

      <div class="grid grid-cols-1 lg:grid-cols-4 gap-8">
        <div class="lg:col-span-3">
          <%= for post <- @posts do %>
            <.post_card post={post} />
          <% end %>
        </div>

        <div class="lg:col-span-1">
          <div class="sticky top-24 bg-card rounded-lg p-6 border border-border">
            <h2 class="text-xl font-bold mb-4 text-foreground">Tags</h2>
            <div class="flex flex-wrap gap-2 mb-6">
              <%= for tag <- @tags do %>
                <.link
                  patch={~p"/blog/tags/#{tag}"}
                  class={
                    if tag == @tag,
                      do: "inline-block bg-primary text-primary-foreground rounded-full px-3 py-1 text-sm transition-colors",
                      else: "inline-block bg-elevated rounded-full px-3 py-1 text-sm text-muted-foreground hover:text-foreground transition-colors"
                  }
                >
                  {tag}
                </.link>
              <% end %>
            </div>

            <h2 class="text-xl font-bold mb-4 text-foreground">Follow us</h2>
            <div class="flex gap-4 mb-6">
              <a
                href="https://github.com/agentjido/jido"
                class="text-muted-foreground hover:text-foreground transition-colors"
              >
                <AgentJidoWeb.Jido.Nav.github_icon class="w-6 h-6" />
              </a>
              <a
                href="https://x.com/agentjido"
                class="text-muted-foreground hover:text-foreground transition-colors"
              >
                <AgentJidoWeb.Jido.Nav.x_icon class="w-6 h-6" />
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :post, :map, required: true
  attr :markdown_action, :map, required: true

  defp blog_show(assigns) do
    ~H"""
    <div id="blog-show-page" class="container max-w-[1000px] mx-auto px-6 py-12">
      <div class="mb-6">
        <.link patch={~p"/blog"} class="text-primary hover:opacity-80 flex items-center gap-1 transition-opacity text-sm">
          <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to all posts
        </.link>
      </div>

      <article class="overflow-hidden rounded-lg border border-border bg-card">
        <header class="border-b border-border px-6 py-6 md:px-8 md:py-7">
          <h1 class="text-3xl leading-tight tracking-tight md:text-4xl font-bold mb-4 text-foreground">
            {@post.title}
          </h1>

          <div class="flex items-center gap-4 text-muted-foreground text-sm">
            <div>by {@post.author}</div>
            <div>•</div>
            <div>{format_date(@post.date)}</div>
          </div>
          <a
            href={@markdown_action.url}
            target="_blank"
            rel="noopener noreferrer"
            class="mt-4 inline-flex text-xs font-semibold uppercase tracking-wide text-primary hover:opacity-80 transition-opacity"
          >
            {@markdown_action.label} →
          </a>
        </header>

        <div class="px-6 py-7 md:px-8 md:py-8">
          <div class="flex flex-wrap gap-2 mb-7">
            <%= for tag <- @post.tags do %>
              <.link
                patch={~p"/blog/tags/#{tag}"}
                class="inline-flex items-center rounded-full border border-border bg-elevated px-3 py-1 text-xs font-medium uppercase tracking-wide text-muted-foreground hover:border-primary/40 hover:text-foreground transition-colors"
              >
                {tag}
              </.link>
            <% end %>
          </div>

          <div class="blog-prose prose max-w-none">
            {Phoenix.HTML.raw(@post.body)}
          </div>
        </div>
      </article>
    </div>
    """
  end

  attr :post, :map, required: true

  defp post_card(assigns) do
    ~H"""
    <div class="bg-card rounded-lg mb-8 overflow-hidden border border-border">
      <div class="p-6">
        <h2 class="text-2xl font-bold mb-2">
          <.link patch={~p"/blog/#{@post.id}"} class="text-foreground hover:opacity-85 transition-opacity">
            {@post.title}
          </.link>
        </h2>
        <div class="text-muted-foreground mb-3">
          by {@post.author} • {format_date(@post.date)}
        </div>
        <div class="prose prose-sm max-w-none mb-4 text-muted-foreground">
          <p>{summary_text(@post)}</p>
        </div>
        <div class="flex flex-wrap gap-2">
          <%= for tag <- @post.tags do %>
            <.link
              patch={~p"/blog/tags/#{tag}"}
              class="inline-block bg-elevated rounded-full px-3 py-1 text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              {tag}
            </.link>
          <% end %>
        </div>
        <div class="mt-4">
          <.link
            patch={~p"/blog/#{@post.id}"}
            class="inline-flex items-center px-4 py-2 bg-primary text-primary-foreground hover:opacity-90 rounded-md transition-opacity text-sm font-medium"
          >
            Read More
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp assign_index(socket) do
    assign(socket,
      page_title: "Blog",
      meta_description: @blog_index_description,
      structured_data: [StructuredData.breadcrumb_list([{"Jido", "/"}, {"Blog", "/blog"}])],
      markdown_action: nil,
      posts: Blog.all_posts(),
      tags: Blog.all_tags()
    )
  end

  defp assign_show(socket, %{"slug" => slug}, request_url) do
    post = Blog.get_published_post_by_slug!(slug)
    seo = post_seo(post)
    canonical_url = seo_value(seo, :canonical_url)
    og_description = seo_value(seo, :og_description)
    noindex? = seo_value(seo, :noindex) == true
    markdown_action = MarkdownLinks.markdown_action(post, request_url)

    assign(socket,
      page_title: post.title,
      meta_description: post_meta_description(post),
      og_description: og_description,
      canonical_url: canonical_url,
      robots: if(noindex?, do: ["noindex", "nofollow"]),
      og_image: seo_value(seo, :og_image),
      structured_data:
        if(noindex?,
          do: [],
          else: [
            StructuredData.breadcrumb_list([
              {"Jido", "/"},
              {"Blog", "/blog"},
              {post.title, "/blog/#{post.id}"}
            ])
          ]
        ),
      post: post,
      markdown_action: markdown_action,
      seo: seo
    )
  end

  defp assign_tag(socket, %{"tag" => tag}) do
    assign(socket,
      page_title: "Blog: #{tag}",
      meta_description: tag_meta_description(tag),
      structured_data: [
        StructuredData.breadcrumb_list([
          {"Jido", "/"},
          {"Blog", "/blog"},
          {"Tag: #{tag}", "/blog/tags/#{tag}"}
        ])
      ],
      markdown_action: nil,
      posts: Blog.get_posts_by_tag!(tag),
      tag: tag,
      tags: Blog.all_tags()
    )
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp preview(body) do
    body
    |> String.slice(0, 150)
    |> String.split(~r/\s/)
    |> Enum.drop(-1)
    |> Enum.join(" ")
    |> Kernel.<>("...")
  end

  defp summary_text(post) do
    case post.description |> to_string() |> String.trim() do
      "" -> preview(post.body)
      description -> description
    end
  end

  defp tag_meta_description(tag) do
    "Posts tagged with \"#{tag}\" from the Jido blog, including product updates, technical write-ups, and release notes."
  end

  defp post_meta_description(post) do
    post
    |> summary_text()
    |> to_string()
    |> String.trim()
  end

  defp post_seo(post) do
    Map.get(post, :seo, %{}) || %{}
  end

  defp seo_value(seo, key) do
    Map.get(seo, key) || Map.get(seo, Atom.to_string(key))
  end
end
