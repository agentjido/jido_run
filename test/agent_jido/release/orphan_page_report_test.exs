defmodule AgentJido.Release.OrphanPageReportTest do
  use ExUnit.Case, async: true

  alias AgentJido.Release.OrphanPageReport

  describe "classify/3" do
    test "flags pages with no menu entry and no inbound link, ignoring self-links" do
      root = System.tmp_dir!()

      pages = [
        {"/docs/alpha", %{source_path: "#{root}/priv/pages/docs/alpha.md", title: "Alpha", in_menu: true}},
        {"/docs/beta", %{source_path: "#{root}/priv/pages/docs/beta.md", title: "Beta", in_menu: false}},
        {"/docs/gamma", %{source_path: "#{root}/priv/pages/docs/gamma.md", title: "Gamma", in_menu: false}},
        {"/docs/delta", %{source_path: "#{root}/priv/pages/docs/delta.md", title: "Delta", in_menu: false}}
      ]

      inbound = %{
        # Cross-link from alpha to beta -> beta is reachable.
        "/docs/beta" => ["priv/pages/docs/alpha.md:4"],
        # gamma only links to itself -> still an orphan.
        "/docs/gamma" => ["priv/pages/docs/gamma.md:2"]
      }

      classified = OrphanPageReport.classify(pages, inbound, root)

      orphan_routes = Enum.map(classified.orphans, & &1.route) |> Enum.sort()
      assert orphan_routes == ["/docs/delta", "/docs/gamma"]

      # beta kept its cross-link source (self-link of gamma was dropped).
      beta = Enum.find(classified.entries, &(&1.route == "/docs/beta"))
      assert beta.inbound == ["priv/pages/docs/alpha.md:4"]

      # alpha is in the menu with no related-content link -> menu_only, not orphan.
      menu_only_routes = Enum.map(classified.menu_only, & &1.route)
      assert menu_only_routes == ["/docs/alpha"]
    end
  end

  describe "collect_inbound_links/1" do
    test "collects internal links from pages, blog, examples, ecosystem, and templates" do
      root =
        Path.join(System.tmp_dir!(), "orphan_inbound_#{System.unique_integer([:positive])}")

      File.mkdir_p!(Path.join(root, "priv/pages/docs"))
      File.mkdir_p!(Path.join(root, "priv/blog"))
      File.mkdir_p!(Path.join(root, "priv/examples"))
      File.mkdir_p!(Path.join(root, "priv/ecosystem"))
      File.mkdir_p!(Path.join(root, "lib/agent_jido_web/components"))

      File.write!(Path.join(root, "priv/pages/docs/alpha.md"), "See [beta](/docs/beta).\n")

      File.write!(Path.join(root, "priv/blog/post.md"), """
      # Post

      Read [the guide](/docs/gamma).
      """)

      File.write!(Path.join(root, "priv/examples/ex.md"), "Links [delta](/docs/delta).")

      File.write!(Path.join(root, "priv/ecosystem/pkg.md"), "See [epsilon](/docs/epsilon).")

      File.write!(
        Path.join(root, "lib/agent_jido_web/components/nav.heex"),
        ~s(<.link navigate="/docs/zeta">Zeta</.link>\n)
      )

      # A link inside a Livebook code fence must not be collected.
      File.write!(Path.join(root, "priv/pages/docs/noise.livemd"), """
      # Noise

      ```elixir
      # [ignored](/docs/ignored)
      ```
      """)

      on_exit(fn -> File.rm_rf!(root) end)

      inbound = OrphanPageReport.collect_inbound_links(root)

      assert inbound["/docs/beta"]
      assert inbound["/docs/gamma"]
      assert inbound["/docs/delta"]
      assert inbound["/docs/epsilon"]
      assert inbound["/docs/zeta"]
      refute Map.has_key?(inbound, "/docs/ignored")
    end
  end

  describe "run/1 release gate" do
    # E12-T20: every public content page must have an inbound navigation or
    # related-content link. A non-empty orphan list blocks the release. The
    # ceiling is 0 — if a page must be hidden from the menu, add a cross-link
    # to it from another page or template.
    @tag :release_gate
    test "the live site has no orphan public content pages" do
      report_path =
        Path.join(
          System.tmp_dir!(),
          "orphan_page_report_release_#{System.unique_integer([:positive])}.md"
        )

      on_exit(fn -> File.rm(report_path) end)

      assert {:ok, report} = OrphanPageReport.run(report_path: report_path)

      assert report.orphans == [],
             "orphan pages found: #{inspect(Enum.map(report.orphans, & &1.route))}. " <>
               "Each must gain an inbound navigation or related-content link."

      assert report.public_page_count > 0
      assert File.exists?(report_path)
      assert File.read!(report_path) =~ "# Orphan Page Report"
    end
  end
end
