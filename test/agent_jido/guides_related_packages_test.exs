defmodule AgentJido.GuidesRelatedPackagesTest do
  @moduledoc """
  E06-T26: every guide names its related packages so package roles and
  maturity render near the instructions.

  A guide installs a concrete set of ecosystem packages (its `Mix.install`
  cell). The E06 backlog requires each guide to surface those packages with
  the role each plays in the guide and each package's current maturity, placed
  next to the instructions rather than buried in the install cell. The Page
  schema (`lib/agent_jido/pages/page.ex`) exposes `related_packages` — a list
  of `%{id, role}` maps — and the docs shell resolves each `id` to its public
  ecosystem package so the role and the canonical maturity render together
  (E06-T26 acceptance: "Package roles and maturity appear near instructions").

  This test enumerates every published guide — docs pages of
  `doc_type: :guide` in the `/docs/guides/` section — and asserts each one
  ships with a non-empty, well-formed `related_packages` whose ids resolve to
  real public ecosystem packages, so no guide can be added without naming its
  packages and no guide can name a package that has no maturity to render.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Ecosystem
  alias AgentJido.Pages

  # A published guide is a docs page of doc_type :guide whose path lives under
  # /docs/guides/. Cookbooks are a distinct doc_type and are excluded.
  @guides Pages.all_pages()
          |> Enum.filter(fn page ->
            page.category == :docs and page.doc_type == :guide and
              String.starts_with?(page.path, "/docs/guides/")
          end)

  describe "every guide declares related packages (jido-e06-t26)" do
    test "there is at least one guide to check" do
      refute Enum.empty?(@guides),
             "expected at least one published guide (doc_type :guide under /docs/guides/) " <>
               "to be checked"
    end

    for page <- @guides do
      test "#{page.path} frontmatter carries a related_packages list" do
        source = unquote(Macro.escape(page)).source_path
        body = File.read!(source)

        assert body =~ ~r/related_packages:\s*\[/,
               "#{source} must declare a related_packages list of %{id, role} maps"
      end

      test "#{page.path} Page struct exposes a non-empty related_packages" do
        page = unquote(Macro.escape(page))
        packages = page.related_packages

        assert is_list(packages),
               "#{page.path} related_packages must be a list, got: #{inspect(packages)}"

        refute Enum.empty?(packages),
               "#{page.path} related_packages must be a non-empty list, " <>
                 "got: #{inspect(packages)}"

        for entry <- packages do
          assert is_map(entry),
                 "#{page.path} each related_packages entry must be a map, got: #{inspect(entry)}"

          id = entry[:id]
          role = entry[:role]

          assert is_binary(id) and id != "",
                 "#{page.path} each related_packages entry needs a non-empty :id, " <>
                   "got: #{inspect(entry)}"

          assert is_binary(role) and String.trim(role) != "",
                 "#{page.path} related_packages[#{id}] needs a non-empty :role describing " <>
                   "what the package does in this guide, got: #{inspect(role)}"
        end
      end

      test "#{page.path} related_packages ids resolve to public ecosystem packages" do
        page = unquote(Macro.escape(page))

        for entry <- page.related_packages do
          pkg = Ecosystem.get_public_package(entry[:id])

          assert pkg != nil,
                 "#{page.path} related_packages[#{entry[:id]}] must be a public ecosystem " <>
                   "package id (a priv/ecosystem/*.md slug) so its maturity can render"

          # Maturity is what the docs shell surfaces near the instructions; a
          # package with neither support_level nor maturity would render a bare
          # name with no maturity, which fails the acceptance condition.
          maturity = pkg.support_level || pkg.maturity

          assert maturity in [:stable, :beta, :experimental],
                 "#{page.path} related_packages[#{entry[:id]}] must carry a maturity " <>
                   "(stable | beta | experimental) so it renders next to the role, " <>
                   "got: #{inspect(maturity)}"
        end
      end
    end
  end
end
