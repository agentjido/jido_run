defmodule AgentJidoWeb.SitemapController do
  @moduledoc """
  Serves the XML sitemap used by search engines.
  """
  use AgentJidoWeb, :controller

  alias AgentJido.Blog
  alias AgentJido.Ecosystem
  alias AgentJido.Examples
  alias AgentJido.Pages

  def index(conn, _params) do
    pages =
      Pages.all_pages()
      |> Enum.reject(&(&1.category == :training))

    sitemap_xml =
      Phoenix.Template.render_to_string(AgentJidoWeb.SitemapHTML, "index", "xml",
        blog_posts: Blog.all_posts(),
        pages: pages,
        ecosystem_packages: Ecosystem.public_packages(),
        examples: Examples.all_examples()
      )

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, sitemap_xml)
  end
end
