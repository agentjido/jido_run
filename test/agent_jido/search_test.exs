defmodule AgentJido.ContentAssistant.RetrievalTest do
  use ExUnit.Case, async: true

  alias AgentJido.ContentAssistant.Result
  alias AgentJido.ContentAssistant.Retrieval

  describe "query/2" do
    test "returns empty results for empty queries without calling backend" do
      search_fun = fn _query, _opts ->
        flunk("expected blank query to short-circuit without backend call")
      end

      assert {:ok, []} = Retrieval.query("   ", search_fun: search_fun)
    end

    test "returns normalized cross-collection results" do
      rows = [
        %{document_id: "doc-1", text: "docs snippet", score: 0.9},
        %{document_id: "doc-2", text: "blog snippet", score: 0.7},
        %{document_id: "doc-3", text: "ecosystem snippet"}
      ]

      search_fun = fn query, opts ->
        send(self(), {:search_call, query, opts})
        {:ok, rows}
      end

      document_lookup_fun = fn fetched_rows, _repo ->
        send(self(), {:lookup_call, fetched_rows})

        %{
          "doc-1" => %{
            collection: "site_docs",
            source_id: "docs:/docs/getting-started",
            metadata: %{"title" => "Getting Started", "path" => "/docs/getting-started"}
          },
          "doc-2" => %{
            collection: "site_blog",
            source_id: "blog:release-notes",
            metadata: %{"title" => "Release Notes", "id" => "release-notes", "url" => "/blog/release-notes"}
          },
          "doc-3" => %{
            collection: "site_ecosystem",
            source_id: "ecosystem:jido-core",
            metadata: %{"title" => "Jido Core", "id" => "jido-core"}
          }
        }
      end

      assert {:ok, results} =
               Retrieval.query("arcana", search_fun: search_fun, document_lookup_fun: document_lookup_fun, repo: :repo)

      assert_received {:search_call, "arcana", search_opts}
      assert search_opts[:mode] == :hybrid
      assert search_opts[:collections] == Retrieval.collections()

      assert_received {:lookup_call, ^rows}

      assert results == [
               %Result{
                 title: "Getting Started",
                 snippet: "docs snippet",
                 url: "/docs/getting-started",
                 source_type: :docs,
                 score: 0.9,
                 external?: false
               },
               %Result{
                 title: "Release Notes",
                 snippet: "blog snippet",
                 url: "/blog/release-notes",
                 source_type: :blog,
                 score: 0.7,
                 external?: false
               },
               %Result{
                 title: "Jido Core",
                 snippet: "ecosystem snippet",
                 url: "/ecosystem/jido-core",
                 source_type: :ecosystem,
                 score: nil,
                 external?: false
               }
             ]
    end

    test "resolves metadata when Arcana rows use binary UUID document ids" do
      doc_uuid = Ecto.UUID.generate()
      doc_uuid_binary = Ecto.UUID.dump!(doc_uuid)

      rows = [
        %{document_id: doc_uuid_binary, text: "docs snippet", score: 0.9}
      ]

      search_fun = fn _query, _opts -> {:ok, rows} end

      document_lookup_fun = fn _fetched_rows, _repo ->
        %{
          doc_uuid => %{
            collection: "site_docs",
            source_id: "docs:/docs/getting-started",
            metadata: %{"title" => "Getting Started", "path" => "/docs/getting-started"}
          }
        }
      end

      assert {:ok, [%Result{} = result]} =
               Retrieval.query("jido",
                 search_fun: search_fun,
                 document_lookup_fun: document_lookup_fun,
                 repo: :repo
               )

      assert result.title == "Getting Started"
      assert result.url == "/docs/getting-started"
      assert result.source_type == :docs
    end

    test "derives an internal route from chunk text when metadata lookup is unavailable" do
      doc_uuid_binary = Ecto.UUID.dump!(Ecto.UUID.generate())

      rows = [
        %{
          document_id: doc_uuid_binary,
          text: "Getting Started\n\n/docs/getting-started\n\nJido basics",
          score: 0.7
        }
      ]

      search_fun = fn _query, _opts -> {:ok, rows} end
      document_lookup_fun = fn _fetched_rows, _repo -> %{} end

      assert {:ok, [%Result{} = result]} =
               Retrieval.query("jido",
                 search_fun: search_fun,
                 document_lookup_fun: document_lookup_fun,
                 repo: :repo
               )

      assert result.url == "/docs/getting-started"
    end

    test "normalizes same-site absolute metadata urls to in-site paths" do
      rows = [
        %{document_id: "doc-1", text: "docs snippet", score: 0.9}
      ]

      search_fun = fn _query, _opts -> {:ok, rows} end

      document_lookup_fun = fn _fetched_rows, _repo ->
        %{
          "doc-1" => %{
            collection: "site_docs",
            source_id: "docs:/docs/getting-started",
            metadata: %{
              "title" => "Getting Started",
              "url" => "http://localhost/docs/getting-started#intro"
            }
          }
        }
      end

      assert {:ok, [%Result{} = result]} =
               Retrieval.query("jido",
                 search_fun: search_fun,
                 document_lookup_fun: document_lookup_fun,
                 repo: :repo
               )

      assert result.url == "/docs/getting-started"
    end

    test "returns empty results when backend returns no rows" do
      search_fun = fn _query, _opts -> {:ok, []} end

      assert {:ok, []} =
               Retrieval.query(
                 "does-not-exist",
                 search_fun: search_fun,
                 document_lookup_fun: fn _rows, _repo -> %{} end
               )
    end

    test "normalizes ecosystem docs results to external HexDocs links" do
      rows = [%{document_id: "doc-1", text: "module docs snippet", score: 0.61}]
      search_fun = fn _query, _opts -> {:ok, rows} end

      document_lookup_fun = fn _rows, _repo ->
        %{
          "doc-1" => %{
            collection: "site_ecosystem_docs",
            source_id: "ecosystem_docs:jido:module:Jido.Agent",
            metadata: %{
              "title" => "Jido.Agent",
              "source_type" => "ecosystem_docs",
              "outbound_url" => "https://hexdocs.pm/jido/Jido.Agent.html",
              "package_url" => "/ecosystem/jido",
              "package_id" => "jido",
              "package_name" => "jido",
              "package_version" => "2.1.0",
              "page_kind" => "module"
            }
          }
        }
      end

      assert {:ok, [%Result{} = result]} =
               Retrieval.query("Jido.Agent",
                 search_fun: search_fun,
                 document_lookup_fun: document_lookup_fun,
                 repo: :repo
               )

      assert result.url == "https://hexdocs.pm/jido/Jido.Agent.html"
      assert result.source_type == :ecosystem_docs
      assert result.external? == true
      assert result.provider == :hexdocs
      assert result.secondary_url == "/ecosystem/jido"
      assert result.page_kind == :module
    end

    test "resolves example rows from the site_examples collection to example routes" do
      rows = [%{document_id: "doc-ex", text: "example snippet", score: 0.8}]
      search_fun = fn _query, _opts -> {:ok, rows} end

      document_lookup_fun = fn _rows, _repo ->
        %{
          "doc-ex" => %{
            collection: "site_examples",
            source_id: "examples:persistence-storage-agent",
            metadata: %{
              "title" => "Persistence Storage Agent",
              "id" => "persistence-storage-agent"
            }
          }
        }
      end

      assert {:ok, [%Result{} = result]} =
               Retrieval.query("persistence example",
                 search_fun: search_fun,
                 document_lookup_fun: document_lookup_fun,
                 repo: :repo
               )

      assert result.url == "/examples/persistence-storage-agent"
      assert result.source_type == :examples
      assert result.external? == false
    end

    test "returns the matching example for a 'persistence example' query via fallback" do
      # Backend unavailable -> the local fallback (which now indexes public
      # examples) must still surface the matching example. This is the
      # jido-e10-t01 acceptance condition.
      search_fun = fn _query, _opts -> {:error, :backend_down} end

      assert {:ok, results} = Retrieval.query("persistence example", search_fun: search_fun)

      persistence = Enum.find(results, &(&1.url == "/examples/persistence-storage-agent"))

      assert persistence != nil
      assert persistence.title == "Persistence Storage Agent"
      assert persistence.source_type == :examples
    end

    test "reranks package overviews above deep docs for broad package-intent queries" do
      rows = [
        %{document_id: "doc-overview", text: "overview snippet", score: 0.55},
        %{document_id: "doc-module", text: "module snippet", score: 0.9}
      ]

      search_fun = fn _query, _opts -> {:ok, rows} end

      document_lookup_fun = fn _rows, _repo ->
        %{
          "doc-overview" => %{
            collection: "site_ecosystem",
            source_id: "ecosystem:jido",
            metadata: %{"title" => "Jido", "id" => "jido"}
          },
          "doc-module" => %{
            collection: "site_ecosystem_docs",
            source_id: "ecosystem_docs:jido:module:Jido.Agent",
            metadata: %{
              "title" => "Jido.Agent",
              "source_type" => "ecosystem_docs",
              "outbound_url" => "https://hexdocs.pm/jido/Jido.Agent.html",
              "package_url" => "/ecosystem/jido",
              "package_id" => "jido",
              "package_version" => "2.1.0",
              "page_kind" => "module"
            }
          }
        }
      end

      assert {:ok, [first | _rest]} =
               Retrieval.query("what is jido",
                 search_fun: search_fun,
                 document_lookup_fun: document_lookup_fun,
                 repo: :repo
               )

      assert first.source_type == :ecosystem
      assert first.url == "/ecosystem/jido"
    end

    test "reranks HexDocs above package overviews for API-style queries" do
      rows = [
        %{document_id: "doc-overview", text: "overview snippet", score: 0.95},
        %{document_id: "doc-module", text: "module snippet", score: 0.55}
      ]

      search_fun = fn _query, _opts -> {:ok, rows} end

      document_lookup_fun = fn _rows, _repo ->
        %{
          "doc-overview" => %{
            collection: "site_ecosystem",
            source_id: "ecosystem:jido",
            metadata: %{"title" => "Jido", "id" => "jido"}
          },
          "doc-module" => %{
            collection: "site_ecosystem_docs",
            source_id: "ecosystem_docs:jido:module:Jido.Agent",
            metadata: %{
              "title" => "Jido.Agent",
              "source_type" => "ecosystem_docs",
              "outbound_url" => "https://hexdocs.pm/jido/Jido.Agent.html",
              "package_url" => "/ecosystem/jido",
              "package_id" => "jido",
              "package_version" => "2.1.0",
              "page_kind" => "module"
            }
          }
        }
      end

      assert {:ok, [first | _rest]} =
               Retrieval.query("Jido.Agent cmd/2",
                 search_fun: search_fun,
                 document_lookup_fun: document_lookup_fun,
                 repo: :repo
               )

      assert first.source_type == :ecosystem_docs
      assert first.url == "https://hexdocs.pm/jido/Jido.Agent.html"
    end

    test "filters retired training routes from backend results" do
      rows = [
        %{document_id: "doc-training", text: "old training snippet", score: 0.9},
        %{document_id: "doc-docs", text: "docs snippet", score: 0.7}
      ]

      search_fun = fn _query, _opts -> {:ok, rows} end

      document_lookup_fun = fn _rows, _repo ->
        %{
          "doc-training" => %{
            collection: "site_docs",
            source_id: "docs:/training/agent-fundamentals",
            metadata: %{"title" => "Training Fundamentals", "path" => "/training/agent-fundamentals"}
          },
          "doc-docs" => %{
            collection: "site_docs",
            source_id: "docs:/docs/getting-started",
            metadata: %{"title" => "Getting Started", "path" => "/docs/getting-started"}
          }
        }
      end

      assert {:ok, results} =
               Retrieval.query("jido",
                 search_fun: search_fun,
                 document_lookup_fun: document_lookup_fun,
                 repo: :repo
               )

      assert Enum.all?(results, fn result -> not String.starts_with?(result.url, "/training") end)
      assert Enum.any?(results, fn result -> result.url == "/docs/getting-started" end)
    end

    test "falls back when backend results are only retired routes" do
      rows = [%{document_id: "doc-training", text: "old training snippet", score: 0.9}]
      search_fun = fn _query, _opts -> {:ok, rows} end

      document_lookup_fun = fn _rows, _repo ->
        %{
          "doc-training" => %{
            collection: "site_docs",
            source_id: "docs:/training/agent-fundamentals",
            metadata: %{"title" => "Training Fundamentals", "path" => "/training/agent-fundamentals"}
          }
        }
      end

      fallback_result = %Result{
        title: "Docs Fallback",
        snippet: "Fallback docs result",
        url: "/docs/fallback",
        source_type: :docs,
        score: 1.0
      }

      fallback_fun = fn _query, _opts -> [fallback_result] end

      assert {:ok, [^fallback_result]} =
               Retrieval.query("jido",
                 search_fun: search_fun,
                 document_lookup_fun: document_lookup_fun,
                 fallback_fun: fallback_fun,
                 repo: :repo
               )
    end

    test "falls back to empty results on backend error tuple" do
      search_fun = fn _query, _opts -> {:error, :backend_down} end
      fallback_fun = fn _query, _opts -> [] end

      assert {:ok, []} = Retrieval.query("arcana", search_fun: search_fun, fallback_fun: fallback_fun)
    end

    test "falls back to empty results when backend raises" do
      search_fun = fn _query, _opts -> raise "backend crashed" end
      fallback_fun = fn _query, _opts -> [] end

      assert {:ok, []} = Retrieval.query("arcana", search_fun: search_fun, fallback_fun: fallback_fun)
    end
  end

  describe "query_with_status/2" do
    test "returns success status for normal backend responses" do
      search_fun = fn _query, _opts -> {:ok, []} end
      assert {:ok, [], :success} = Retrieval.query_with_status("arcana", search_fun: search_fun)
    end

    test "returns fallback status when backend returns an error" do
      search_fun = fn _query, _opts -> {:error, :backend_down} end
      fallback_fun = fn _query, _opts -> [] end

      assert {:ok, [], :fallback} =
               Retrieval.query_with_status("arcana", search_fun: search_fun, fallback_fun: fallback_fun)
    end

    test "returns success status when backend fails but fallback provides results" do
      search_fun = fn _query, _opts -> {:error, :backend_down} end

      fallback_result = %Result{
        title: "Fallback Match",
        snippet: "Local content fallback result",
        url: "/docs/fallback",
        source_type: :docs,
        score: 1.0
      }

      fallback_fun = fn _query, _opts -> [fallback_result] end

      assert {:ok, [^fallback_result], :fallback} =
               Retrieval.query_with_status("arcana", search_fun: search_fun, fallback_fun: fallback_fun)
    end

    test "returns fallback status when backend results are fully filtered and no fallback results exist" do
      rows = [%{document_id: "doc-training", text: "old training snippet", score: 0.9}]
      search_fun = fn _query, _opts -> {:ok, rows} end

      document_lookup_fun = fn _rows, _repo ->
        %{
          "doc-training" => %{
            collection: "site_docs",
            source_id: "docs:/training/agent-fundamentals",
            metadata: %{"title" => "Training Fundamentals", "path" => "/training/agent-fundamentals"}
          }
        }
      end

      fallback_fun = fn _query, _opts -> [] end

      assert {:ok, [], :fallback} =
               Retrieval.query_with_status("jido",
                 search_fun: search_fun,
                 document_lookup_fun: document_lookup_fun,
                 fallback_fun: fallback_fun,
                 repo: :repo
               )
    end
  end
end
