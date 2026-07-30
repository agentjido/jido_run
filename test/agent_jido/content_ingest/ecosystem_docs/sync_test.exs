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
         when fixture in [:v1, :v2, :page_failure, :readme_drift_a, :readme_drift_b] do
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

    defp fetch_fixture(fixture, "https://hexdocs.pm/jido/2.2.0/dist/sidebar_items-test.js" = url)
         when fixture in [:readme_drift_a, :readme_drift_b] do
      {:ok, response(url, readme_drift_manifest())}
    end

    defp fetch_fixture(:readme_drift_a, "https://hexdocs.pm/jido/2.2.0/readme.html" = url) do
      {:ok, response(url, page_html("Jido", "README revision A: original package description."))}
    end

    defp fetch_fixture(:readme_drift_b, "https://hexdocs.pm/jido/2.2.0/readme.html" = url) do
      {:ok, response(url, page_html("Jido", "README revision B: materially updated package description."))}
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

    # A single README extra so its page_kind is :readme and its source_id is
    # stable across runs (jido-e09-t32).
    defp readme_drift_manifest do
      "sidebarNodes=" <>
        Jason.encode!(%{
          "modules" => [],
          "extras" => [%{"id" => "readme", "title" => "Jido"}],
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
    assert latest_package_version() == "2.3.2"
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

  describe "README-drift review (jido-e09-t32)" do
    test "a material upstream README change creates a review item on the sync summary" do
      first =
        EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :readme_drift_a)

      # First run ingests the README with no prior version => no drift review item.
      assert first.readme_drift == []
      assert first.readme_drift_count == 0
      assert first.inserted == 1

      second =
        EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :readme_drift_b)

      # The README changed materially => exactly one review item.
      assert second.readme_drift_count == 1
      assert length(second.readme_drift) == 1

      [item] = second.readme_drift

      assert item.package_id == "jido"
      assert item.package_name == "jido"
      assert item.readme_source_id == "ecosystem_docs:jido:readme:readme"
      assert item.page_title == "Jido"
      assert item.previous_content_hash != item.current_content_hash
      assert is_binary(item.previous_content_hash) and item.previous_content_hash != ""
      assert is_binary(item.current_content_hash) and item.current_content_hash != ""
      assert is_binary(item.readme_url) and item.readme_url != ""
      assert {:ok, _detected, _offset} = DateTime.from_iso8601(item.detected_at)
    end

    test "an unchanged upstream README creates no review item" do
      EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :readme_drift_a)

      repeat =
        EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :readme_drift_a)

      assert repeat.readme_drift == []
      assert repeat.readme_drift_count == 0
      assert repeat.updated == 0
    end

    test "dry-run still surfaces drift review items without mutating the corpus" do
      EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :readme_drift_a)
      assert managed_doc_count() == 1

      dry_run =
        EcosystemDocs.sync_package_now("jido",
          repo: Repo,
          client: StubClient,
          fixture: :readme_drift_b,
          dry_run: true
        )

      # Detection is non-destructive: the review item is produced even though
      # nothing is written, and the corpus is left intact.
      assert dry_run.mode == :dry_run
      assert dry_run.readme_drift_count == 1
      assert managed_doc_count() == 1
    end
  end

  describe "package-role review tasks (jido-e12-t18)" do
    # jido is tier 1 (core) — a priority package whose upstream README defines a
    # role the public site must mirror. The README-drift fixtures therefore also
    # exercise the priority promotion path.
    test "a material README change on a priority package creates an assigned review task" do
      EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :readme_drift_a)

      second =
        EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :readme_drift_b)

      # The drift is still surfaced as an informational review item (jido-e09-t32)
      # and additionally promoted to an assigned review task for the priority package.
      assert second.readme_drift_count == 1
      assert second.package_role_review_count == 1
      assert length(second.package_role_review) == 1

      [task] = second.package_role_review

      assert task.package_id == "jido"
      assert task.package_name == "jido"
      assert task.owner == "@mikehostetler"
      assert task.category == :core
      assert task.readme_source_id == "ecosystem_docs:jido:readme:readme"
      assert task.previous_content_hash != task.current_content_hash
      assert is_binary(task.previous_content_hash) and task.previous_content_hash != ""
      assert is_binary(task.current_content_hash) and task.current_content_hash != ""
      assert is_binary(task.readme_url) and task.readme_url != ""
      assert {:ok, _detected, _offset} = DateTime.from_iso8601(task.detected_at)
    end

    test "a new README (no prior version) creates no review task" do
      first =
        EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :readme_drift_a)

      assert first.package_role_review == []
      assert first.package_role_review_count == 0
    end

    test "an unchanged README creates no review task" do
      EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :readme_drift_a)

      repeat =
        EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :readme_drift_a)

      assert repeat.package_role_review == []
      assert repeat.package_role_review_count == 0
    end

    test "a priority package's review task is attributed to its owner even in dry-run" do
      EcosystemDocs.sync_package_now("jido", repo: Repo, client: StubClient, fixture: :readme_drift_a)

      dry_run =
        EcosystemDocs.sync_package_now("jido",
          repo: Repo,
          client: StubClient,
          fixture: :readme_drift_b,
          dry_run: true
        )

      # Detection is non-destructive: the assigned review task is produced even
      # though nothing is written.
      assert dry_run.mode == :dry_run
      assert dry_run.package_role_review_count == 1

      [task] = dry_run.package_role_review
      assert task.owner == "@mikehostetler"
      assert task.category == :core
    end
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
