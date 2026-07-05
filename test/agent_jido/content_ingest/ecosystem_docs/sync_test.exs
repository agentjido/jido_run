defmodule AgentJido.ContentIngest.EcosystemDocs.SyncTest do
  use AgentJido.DataCase, async: false

  import Ecto.Query

  alias AgentJido.ContentIngest.EcosystemDocs
  alias AgentJido.ContentIngest.EcosystemDocs.Sync
  alias Arcana.Document

  defmodule StubClient do
    def fetch_release("jido", _version, opts) do
      fixture = Keyword.get(opts, :fixture, :v1)

      case fixture do
        :unpublished ->
          {:ok, %{status: 404, body: "", headers: [], url: "https://hex.pm/api/packages/jido/releases/2.2.0"}}

        _other ->
          {:ok,
           %{
             status: 200,
             body:
               Jason.encode!(%{
                 "has_docs" => true,
                 "docs_html_url" => "https://hexdocs.pm/jido/2.2.0/"
               }),
             headers: [],
             url: "https://hex.pm/api/packages/jido/releases/2.2.0"
           }}
      end
    end

    def fetch(url, opts) do
      fixture = Keyword.get(opts, :fixture, :v1)
      fetch_fixture(fixture, url)
    end

    defp fetch_fixture(_fixture, "https://hexdocs.pm/jido/2.2.0/" = url) do
      {:ok, response(url, root_html())}
    end

    defp fetch_fixture(fixture, "https://hexdocs.pm/jido/2.2.0/overview.html" = url)
         when fixture in [:v1, :v2, :page_failure] do
      {:ok,
       response(
         url,
         page_html("Overview", "Jido overview and package introduction.", include_sidebar?: true),
         canonical: "https://hexdocs.pm/jido/overview.html"
       )}
    end

    defp fetch_fixture(fixture, "https://hexdocs.pm/jido/2.2.0/getting-started.html" = url)
         when fixture in [:v1, :page_failure] do
      {:ok,
       response(
         url,
         page_html("Getting Started", "Install Jido and call cmd/2 from your first agent."),
         canonical: "https://hexdocs.pm/jido/getting-started.html"
       )}
    end

    defp fetch_fixture(:v2, "https://hexdocs.pm/jido/2.2.0/Jido.Agent.html" = url) do
      {:ok,
       response(
         url,
         page_html("Jido.Agent", "cmd/2 returns an updated agent, directives, and validated state."),
         canonical: "https://hexdocs.pm/jido/Jido.Agent.html"
       )}
    end

    defp fetch_fixture(:v1, "https://hexdocs.pm/jido/2.2.0/Jido.Agent.html" = url) do
      {:ok,
       response(
         url,
         page_html("Jido.Agent", "cmd/2 returns an updated agent and directives."),
         canonical: "https://hexdocs.pm/jido/Jido.Agent.html"
       )}
    end

    defp fetch_fixture(:page_failure, "https://hexdocs.pm/jido/2.2.0/Jido.Agent.html") do
      {:error, :timeout}
    end

    defp fetch_fixture(:v1, "https://hexdocs.pm/jido/2.2.0/dist/sidebar_items-test.js" = url) do
      {:ok, response(url, manifest_js(include_getting_started?: true))}
    end

    defp fetch_fixture(:v2, "https://hexdocs.pm/jido/2.2.0/dist/sidebar_items-test.js" = url) do
      {:ok, response(url, manifest_js(include_getting_started?: false))}
    end

    defp fetch_fixture(:page_failure, "https://hexdocs.pm/jido/2.2.0/dist/sidebar_items-test.js" = url) do
      {:ok, response(url, manifest_js(include_getting_started?: true))}
    end

    defp fetch_fixture(fixture, url) do
      flunk("unexpected fetch #{inspect({fixture, url})}")
    end

    defp response(url, body, opts \\ []) do
      canonical = Keyword.get(opts, :canonical)

      headers =
        if is_binary(canonical) do
          [{"link", ~s(<#{canonical}>; rel="canonical")}]
        else
          []
        end

      %{status: 200, body: body, headers: headers, url: url}
    end

    defp root_html do
      """
      <html>
        <head>
          <meta http-equiv="refresh" content="0; url=overview.html">
        </head>
        <body></body>
      </html>
      """
    end

    defp manifest_js(opts) do
      include_getting_started? = Keyword.get(opts, :include_getting_started?, true)

      extras =
        [
          %{"id" => "overview", "title" => "Overview"}
        ] ++
          if(include_getting_started?, do: [%{"id" => "getting-started", "title" => "Getting Started"}], else: [])

      "sidebarNodes=" <>
        Jason.encode!(%{
          "modules" => [%{"id" => "Jido.Agent", "title" => "Jido.Agent"}],
          "extras" => extras,
          "tasks" => []
        })
    end

    defp page_html(title, body_text, opts \\ []) do
      sidebar_script =
        if Keyword.get(opts, :include_sidebar?, false) do
          ~s(<script defer src="dist/sidebar_items-test.js"></script>)
        else
          ""
        end

      """
      <html>
        <head>
          #{sidebar_script}
        </head>
        <body>
          <main id="main">
            <div id="content">
              <div class="top-search">Search</div>
              <div id="top-content">
                <h1>#{title}</h1>
              </div>
              <section id="summary">
                <h2>Summary</h2>
                <p>#{body_text}</p>
              </section>
              <div class="bottom-actions">Navigation</div>
            </div>
          </main>
        </body>
      </html>
      """
    end
  end

  setup do
    purge_docs()
    :ok
  end

  test "sync_now ingests published package pages and updates in place" do
    first = EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :v1)
    assert first.total_packages == 1
    assert first.eligible_packages == 1
    assert first.inserted == 3
    assert first.failed_count == 0
    assert managed_doc_count() == 3

    second = EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :v1)
    assert second.skipped == 3
    assert second.updated == 0
    assert managed_doc_count() == 3

    third = EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :v2)
    assert third.updated == 1
    assert third.deleted >= 2
    assert managed_doc_count() == 2
    assert latest_package_version() == "2.2.0"
  end

  test "sync_now removes previously indexed docs when the exact release is unpublished" do
    EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :v1)
    assert managed_doc_count() == 3

    result = EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :unpublished)
    assert result.skipped_unpublished_count == 1
    assert result.deleted == 3
    assert managed_doc_count() == 0
  end

  test "sync_now preserves the previous package corpus on transient crawl failure" do
    EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :v1)
    assert managed_doc_count() == 3

    result = EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :page_failure)
    assert result.failed_count == 1
    assert managed_doc_count() == 3
  end

  defp purge_docs do
    from(d in Document,
      join: c in assoc(d, :collection),
      where: c.name == ^Sync.collection(),
      where: fragment("?->>'managed_by' = ?", d.metadata, ^Sync.managed_by())
    )
    |> Repo.delete_all()

    :ok
  end

  defp managed_doc_count do
    from(d in Document,
      join: c in assoc(d, :collection),
      where: c.name == ^Sync.collection(),
      where: fragment("?->>'managed_by' = ?", d.metadata, ^Sync.managed_by()),
      select: count(d.id)
    )
    |> Repo.one()
  end

  defp latest_package_version do
    from(d in Document,
      join: c in assoc(d, :collection),
      where: c.name == ^Sync.collection(),
      where: fragment("?->>'managed_by' = ?", d.metadata, ^Sync.managed_by()),
      order_by: [desc: d.inserted_at],
      limit: 1,
      select: d.metadata
    )
    |> Repo.one()
    |> Map.fetch!("package_version")
  end
end
