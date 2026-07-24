defmodule AgentJidoWeb.JidoHomeLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint AgentJidoWeb.Endpoint

  setup_all do
    Enum.each(
      [:telemetry, :phoenix_pubsub, :phoenix, :phoenix_live_view, :jido_action, :jido_browser],
      &ensure_started/1
    )

    if Process.whereis(AgentJido.PubSub) == nil do
      start_supervised!({Phoenix.PubSub, name: AgentJido.PubSub})
    end

    if Process.whereis(AgentJidoWeb.Endpoint) == nil do
      start_supervised!(AgentJidoWeb.Endpoint)
    end

    :ok
  end

  setup do
    {:ok, conn: build_conn()}
  end

  describe "home hero" do
    test "secondary proof CTA links to the runnable failure-drill example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "RUN A FAILURE DRILL"
      assert html =~ ~s(href="/examples/failure-drill-agent")
    end
  end

  describe "home adoption message (E04-T09)" do
    test "the lowest-risk adoption message appears directly after the hero", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # The adoption heading is present on the home page.
      assert {adoption_idx, _} = :binary.match(html, "Start with one Agent")

      # It sits after the hero headline...
      assert {hero_idx, _} = :binary.match(html, "Build long-running agents")
      assert adoption_idx > hero_idx

      # ...and before the deeper sections (the quick-start "first proof"),
      # so the lowest-risk adoption message appears early.
      assert {quick_start_idx, _} = :binary.match(html, "Quick start")
      assert adoption_idx < quick_start_idx
    end

    test "the adoption message links to one-agent integration guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Lowest-risk way to start"
      assert html =~ ~s(href="/features/start-small")
    end
  end

  describe "home Agent model section (E04-T10)" do
    test "renders the four-part Agent model section after the first proof", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="agent-model")
      assert html =~ "How an agent is built"

      # It follows the quick-start proof, not before it.
      assert {quick_start_idx, _} = :binary.match(html, ~s(id="quick-start"))
      assert {model_idx, _} = :binary.match(html, ~s(id="agent-model"))
      assert model_idx > quick_start_idx
    end

    test "each of the four parts is present", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      for part <- ["State", "Lifecycle", "Typed boundaries", "Visible effects"] do
        assert html =~ part
      end
    end

    test "each card maps to a named Jido concept", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # The acceptance condition: every card maps to one of these concepts.
      for concept <- ["Agent", "AgentServer", "Action / Signal", "Directive"] do
        assert html =~ "maps to #{concept}"
      end
    end

    test "each part maps to exactly its concept", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Parse each model card and pair its part with the concept it maps to.
      cards =
        html
        |> Floki.parse_document!()
        |> Floki.find("#agent-model article[data-agent-model-part]")
        |> Map.new(fn card ->
          {Floki.attribute(card, "data-agent-model-part") |> hd(), Floki.attribute(card, "data-maps-to") |> hd()}
        end)

      assert cards == %{
               "State" => "Agent",
               "Lifecycle" => "AgentServer",
               "Typed boundaries" => "Action / Signal",
               "Visible effects" => "Directive"
             }
    end
  end

  describe "home operational-control section (jido-e04-t34)" do
    # Acceptance condition: the section appears after the Agent model (or the
    # deterministic proof) and answers who initiated work, what was allowed,
    # what happened, and how failure was handled. Each answer is tied to a named
    # Jido control surface rather than a promise.

    test "renders the operational-control section after the Agent model", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="operational-control")
      assert html =~ "Operational control"

      # It follows the Agent model section, not before it.
      assert {model_idx, _} = :binary.match(html, ~s(id="agent-model"))
      assert {control_idx, _} = :binary.match(html, ~s(id="operational-control"))
      assert control_idx > model_idx
    end

    test "answers all four control questions", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      questions = operational_control_questions(html)

      # Acceptance condition: the section answers each of the four questions,
      # and each carries a human-readable label that matches the question.
      assert Map.keys(questions) |> MapSet.new() ==
               MapSet.new(~w(who-initiated what-was-allowed what-happened how-failure-was-handled))

      assert questions == %{
               "who-initiated" => "Who initiated work",
               "what-was-allowed" => "What was allowed",
               "what-happened" => "What happened",
               "how-failure-was-handled" => "How failure was handled"
             }
    end

    test "each answer names a Jido control surface and is non-empty", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      answers =
        html
        |> Floki.parse_document!()
        |> Floki.find("#operational-control article[data-control-question] p")
        |> Enum.map(&Floki.text/1)
        |> Enum.map(&String.trim/1)

      assert length(answers) == 4

      for answer <- answers do
        assert byte_size(answer) > 0, "expected a non-empty answer for every control question"
      end
    end
  end

  describe "home control proof cards (jido-e04-t35)" do
    # Acceptance condition: a "Supervise the lifecycle" card sits in the
    # operational-control section and links to AgentServer supervision and a
    # failure-boundary proof. The four control questions above it stay the
    # conceptual story; this card is the proof-routing layer.

    test "renders a 'Supervise the lifecycle' card inside the operational-control section", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "supervise-lifecycle")

      # The card is present within the operational-control section and is labelled
      # "Supervise the lifecycle".
      assert card != nil, "expected a supervise-lifecycle control card"
      assert card |> Floki.find("h3") |> Floki.text() |> String.trim() == "Supervise the lifecycle"
    end

    test "the card sits after the four control question blocks", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # The proof card comes after the last question block, so the conceptual
      # answers lead and the proof routing follows.
      assert {last_block_idx, _} =
               :binary.match(html, ~s(data-control-question="how-failure-was-handled"))

      assert {card_idx, _} = :binary.match(html, ~s(data-control-card="supervise-lifecycle"))
      assert card_idx > last_block_idx
    end

    test "links to AgentServer supervision", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "supervise-lifecycle")

      supervision =
        card
        |> Floki.find("a[data-control-link='supervision']")
        |> Floki.attribute("href")
        |> List.first()

      # AgentServer supervision lives on the self-heal feature page.
      assert supervision == "/features/agents-that-self-heal"
    end

    test "links to a failure-boundary proof", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "supervise-lifecycle")

      proof =
        card
        |> Floki.find("a[data-control-link='failure-boundary-proof']")
        |> Floki.attribute("href")
        |> List.first()

      # The failure drill is the runnable crash-and-restart proof.
      assert proof == "/examples/failure-drill-agent"
    end
  end

  describe "home control proof cards: constrain capabilities (jido-e04-t36)" do
    # Acceptance condition: a "Constrain capabilities" card sits in the
    # operational-control section and links to typed Actions, tool allowlists,
    # policy hooks, effects, and quotas — the five capability surfaces that
    # bound what an agent may do.

    test "renders a 'Constrain capabilities' card inside the operational-control section", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "constrain-capabilities")

      assert card != nil, "expected a constrain-capabilities control card"

      assert card |> Floki.find("h3") |> Floki.text() |> String.trim() ==
               "Constrain capabilities"
    end

    test "the card sits after the supervise-lifecycle card", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Proof cards land in order, so the conceptual answers lead and each
      # routing card follows the last.
      assert {supervise_idx, _} =
               :binary.match(html, ~s(data-control-card="supervise-lifecycle"))

      assert {constrain_idx, _} =
               :binary.match(html, ~s(data-control-card="constrain-capabilities"))

      assert constrain_idx > supervise_idx
    end

    test "links to typed Actions, tool allowlists, policy hooks, effects, and quotas", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "constrain-capabilities")

      # Each concept named in the acceptance condition is documented on the
      # page below: typed Actions and effects (Directives) have their own
      # concept pages, while tool allowlists, policy hooks, and quotas are the
      # jido_ai control surface bounded on the governance page.
      expected = %{
        "typed-actions" => "/docs/concepts/actions",
        "tool-allowlists" => "/docs/operations/security-and-governance",
        "policy-hooks" => "/docs/operations/security-and-governance",
        "effects" => "/docs/concepts/directives",
        "quotas" => "/docs/operations/security-and-governance"
      }

      links =
        card
        |> Floki.find("a[data-control-link]")
        |> Map.new(fn a ->
          slug = Floki.attribute(a, "data-control-link") |> hd()
          href = Floki.attribute(a, "href") |> hd()
          {slug, href}
        end)

      assert Map.keys(links) |> MapSet.new() == MapSet.new(Map.keys(expected)),
             "expected links for #{inspect(Map.keys(expected))}, " <>
               "got #{inspect(Map.keys(links))}"

      for {slug, href} <- expected do
        assert links[slug] == href,
               "expected #{slug} to link to #{href}, got #{inspect(links[slug])}"
      end
    end
  end

  describe "home control proof cards: trace what happened (jido-e04-t37)" do
    # Acceptance condition: a "Trace what happened" card sits in the
    # operational-control section and links to causal Signals, Journal
    # configuration, and correlated telemetry — the three records that let an
    # operator reconstruct what ran and why.

    test "renders a 'Trace what happened' card inside the operational-control section",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "trace-what-happened")

      assert card != nil, "expected a trace-what-happened control card"
      assert card |> Floki.find("h3") |> Floki.text() |> String.trim() == "Trace what happened"
    end

    test "the card sits after the constrain-capabilities card", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Proof cards land in order, so the conceptual answers lead and each
      # routing card follows the last.
      assert {constrain_idx, _} =
               :binary.match(html, ~s(data-control-card="constrain-capabilities"))

      assert {trace_idx, _} =
               :binary.match(html, ~s(data-control-card="trace-what-happened"))

      assert trace_idx > constrain_idx
    end

    test "links to causal Signals, Journal configuration, and correlated telemetry", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "trace-what-happened")

      # Each record named in the acceptance condition routes to the most
      # authoritative page that documents it: causal Signals (the CloudEvents
      # message that carries causation), the durable Journal you configure via
      # the Storage behaviour, and correlated telemetry (trace/span correlation
      # plus the OpenTelemetry bridge).
      expected = %{
        "causal-signals" => "/docs/concepts/signals",
        "journal-configuration" => "/docs/concepts/persistence",
        "correlated-telemetry" => "/docs/reference/telemetry-and-observability"
      }

      links =
        card
        |> Floki.find("a[data-control-link]")
        |> Map.new(fn a ->
          slug = Floki.attribute(a, "data-control-link") |> hd()
          href = Floki.attribute(a, "href") |> hd()
          {slug, href}
        end)

      assert Map.keys(links) |> MapSet.new() == MapSet.new(Map.keys(expected)),
             "expected links for #{inspect(Map.keys(expected))}, " <>
               "got #{inspect(Map.keys(links))}"

      for {slug, href} <- expected do
        assert links[slug] == href,
               "expected #{slug} to link to #{href}, got #{inspect(links[slug])}"
      end
    end
  end

  describe "home control proof cards: integrate your control system (jido-e04-t38)" do
    # Acceptance condition: an "Integrate your control system" card sits in the
    # operational-control section and explains IAM, Ash actor/tenant, storage,
    # SIEM, and OTel integration boundaries — each routed to the boundary's
    # authoritative destination.

    test "renders an 'Integrate your control system' card inside the operational-control section",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "integrate-your-control-system")

      assert card != nil, "expected an integrate-your-control-system control card"

      assert card |> Floki.find("h3") |> Floki.text() |> String.trim() ==
               "Integrate your control system"
    end

    test "the card sits after the trace-what-happened card", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Proof cards land in order, so the conceptual answers lead and each
      # routing card follows the last.
      assert {trace_idx, _} =
               :binary.match(html, ~s(data-control-card="trace-what-happened"))

      assert {integrate_idx, _} =
               :binary.match(html, ~s(data-control-card="integrate-your-control-system"))

      assert integrate_idx > trace_idx
    end

    test "names the IAM, Ash actor/tenant, storage, SIEM, and OTel boundaries in its copy",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "integrate-your-control-system")
      copy = card |> Floki.find("p") |> Floki.text() |> String.downcase()

      # The acceptance condition requires the card to *explain* these five
      # integration boundaries, so each must appear by name in the card copy.
      for term <- ~w(iam ash storage siem otel) do
        assert String.contains?(copy, term),
               "expected card copy to name the #{term} integration boundary"
      end
    end

    test "links each integration boundary to its authoritative destination", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "integrate-your-control-system")

      # Each boundary named in the acceptance condition routes to the page that
      # owns it: the IAM and SIEM boundaries are the integration posture on the
      # governance page; Ash actor/tenant context is the ash_jido bridge;
      # durable storage is the Journal; OTel export is the telemetry bridge.
      expected = %{
        "iam-boundary" => "/docs/operations/security-and-governance",
        "ash-actor-tenant" => "/ecosystem/ash_jido",
        "durable-storage" => "/docs/concepts/persistence",
        "siem-integration" => "/docs/operations/security-and-governance",
        "otel-export" => "/docs/reference/telemetry-and-observability"
      }

      links =
        card
        |> Floki.find("a[data-control-link]")
        |> Map.new(fn a ->
          slug = Floki.attribute(a, "data-control-link") |> hd()
          href = Floki.attribute(a, "href") |> hd()
          {slug, href}
        end)

      assert Map.keys(links) |> MapSet.new() == MapSet.new(Map.keys(expected)),
             "expected links for #{inspect(Map.keys(expected))}, " <>
               "got #{inspect(Map.keys(links))}"

      for {slug, href} <- expected do
        assert links[slug] == href,
               "expected #{slug} to link to #{href}, got #{inspect(links[slug])}"
      end
    end
  end

  describe "home use-case cards (E04-T21)" do
    test "every card links to a unique scoped destination, not the unfiltered index", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      hrefs =
        html
        |> Floki.parse_document!()
        |> Floki.find("#what-you-can-build a.home-pillar-card")
        |> Floki.attribute("href")

      # Six cards, each with a destination.
      assert length(hrefs) == 6

      # Acceptance condition: no two cards default to the same unfiltered index.
      # Each destination is unique...
      assert length(Enum.uniq(hrefs)) == 6
      # ...and none is the bare unfiltered /examples index.
      refute "/examples" in hrefs

      # Every destination is scoped to its own use case.
      for href <- hrefs do
        assert String.starts_with?(href, "/examples?use_case=")
      end

      scopes = Enum.map(hrefs, &String.replace_prefix(&1, "/examples?use_case=", ""))

      assert Enum.sort(scopes) ==
               Enum.sort(~w(coding research documents support devops data-pipelines))
    end
  end

  describe "home use-case card status labels (E04-T22)" do
    # Acceptance condition: a visitor can distinguish a runnable example from a
    # planned pattern. Every card carries a status that matches whether a public
    # example actually exists, so the label tracks reality as examples land.

    test "each card shows a runnable or planned status", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      status_by_use_case = use_case_statuses(html)

      # All six cards carry a status label.
      assert map_size(status_by_use_case) == 6

      statuses = Map.values(status_by_use_case)

      assert Enum.all?(statuses, &(&1 in ~w(runnable planned)))
      # Both kinds are visible, so the two states are distinguishable on the page.
      assert "runnable" in statuses
      assert "planned" in statuses
    end

    test "the status matches whether a public example exists", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      status_by_use_case = use_case_statuses(html)

      expected =
        AgentJido.Examples.UseCases.all()
        |> Map.new(fn %{slug: slug} ->
          {slug, if(AgentJido.Examples.UseCases.available?(slug), do: "runnable", else: "planned")}
        end)

      # The rendered label is derived from the same source of truth as the scoped
      # examples destination, so a card never says "runnable" over an empty scope.
      assert status_by_use_case == expected
    end

    test "runnable and planned cards render distinct, human-readable labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      label_by_use_case =
        html
        |> Floki.parse_document!()
        |> Floki.find("#what-you-can-build a.home-pillar-card")
        |> Map.new(fn card ->
          use_case = Floki.attribute(card, "data-use-case") |> hd()
          label = card |> Floki.find(".home-use-case-status") |> Floki.text() |> String.trim()
          {use_case, label}
        end)

      # The copy maps 1:1 to the acceptance condition language and tracks the
      # same source of truth as the status, so a runnable card never reads
      # "Planned pattern" and vice versa.
      for %{slug: slug} <- AgentJido.Examples.UseCases.all() do
        expected =
          if AgentJido.Examples.UseCases.available?(slug),
            do: "Runnable example",
            else: "Planned pattern"

        assert label_by_use_case[slug] == expected
      end

      # Both labels are present on the page, so the two states are distinguishable.
      labels = MapSet.new(Map.values(label_by_use_case))

      assert MapSet.subset?(
               MapSet.new(["Runnable example", "Planned pattern"]),
               labels
             )
    end
  end

  describe "home ecosystem starting stacks (E04-T24)" do
    # Acceptance condition: the first view is Core, AI, and Operate — three
    # named, explained starting stacks — not nine unexplained package names.

    test "renders three recommended starting stacks named Core, AI, and Operate in order", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, "/")

      stacks = home_ecosystem_stacks(html)

      assert Enum.map(stacks, &elem(&1, 0)) == ~w(core ai operate)
      assert Enum.map(stacks, fn {_key, stack} -> stack.name end) == ~w(Core AI Operate)
    end

    test "each stack explains what it is for, so the names are not unexplained", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      for {key, %{purpose: purpose}} <- home_ecosystem_stacks(html) do
        assert is_binary(purpose) and byte_size(purpose) > 0,
               "expected the #{key} stack to carry a one-line purpose"
      end
    end

    test "the Core stack is marked as the recommended place to start", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      stacks = Map.new(home_ecosystem_stacks(html))

      assert stacks["core"].start
      refute stacks["ai"].start
      refute stacks["operate"].start
    end

    test "the old vague category headers are gone", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      refute html =~ "Add AI when ready"
      refute html =~ "Integrate and extend"
    end
  end

  describe "home ecosystem package roles (E04-T25)" do
    # Acceptance condition: a new user knows why each package is present. Every
    # package shown in the home stacks carries a one-line role, so a name is
    # never presented without an explanation.

    test "every shown package carries a non-empty one-line role", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      packages =
        home_ecosystem_stacks(html)
        |> Enum.flat_map(fn {_key, %{packages: packages}} -> Map.to_list(packages) end)
        |> Map.new()

      # All nine packages across the three stacks are shown.
      assert Map.keys(packages) |> MapSet.new() ==
               MapSet.new(~w(jido jido_action jido_signal jido_ai req_llm llm_db ash_jido jido_messaging jido_otel))

      for {name, role} <- packages do
        assert is_binary(role) and String.trim(role) != "",
               "expected a one-line role for #{name}, got: #{inspect(role)}"
      end
    end

    test "each role is distinct, so the roles explain the packages and not each other",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      roles =
        home_ecosystem_stacks(html)
        |> Enum.flat_map(fn {_key, %{packages: packages}} -> Map.values(packages) end)

      assert length(roles) == 9
      assert length(Enum.uniq(roles)) == 9
    end

    test "no package name is shown without a role beside it", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Every package row pairs the name element with a role element.
      rows =
        html
        |> Floki.parse_document!()
        |> Floki.find("#home-ecosystem-section .home-ecosystem-package-role")

      assert length(rows) == 9

      for row <- rows do
        name = row |> Floki.find(".home-ecosystem-stack-package") |> Floki.text() |> String.trim()
        role = row |> Floki.find(".home-ecosystem-stack-package-role") |> Floki.text() |> String.trim()

        assert name != ""
        assert role != ""
      end
    end
  end

  describe "home ecosystem package support levels (E04-T26)" do
    # Acceptance condition: a support level — Stable, Beta, or Experimental — is
    # visible for the packages shown in the home section. Each package's level is
    # resolved from the authoritative ecosystem registry at render time, so the
    # badge tracks package maturity instead of a hardcoded copy that drifts.

    test "every shown package carries a Stable, Beta, or Experimental level", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      levels = home_ecosystem_package_support_levels(html)

      # All nine packages across the three stacks carry a level.
      assert Map.keys(levels) |> MapSet.new() ==
               MapSet.new(~w(jido jido_action jido_signal jido_ai req_llm llm_db ash_jido jido_messaging jido_otel))

      for {name, %{level: level}} <- levels do
        assert level in ~w(stable beta experimental),
               "expected a support level for #{name}, got: #{inspect(level)}"
      end
    end

    test "the displayed level matches the authoritative ecosystem registry", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      levels = home_ecosystem_package_support_levels(html)

      for {name, %{level: level}} <- levels do
        package = AgentJido.Ecosystem.get_public_package(name)
        assert package != nil, "expected #{name} to be a public ecosystem package"

        # The home badge is derived from the same registry the ecosystem hub uses,
        # so it never claims a maturity the package does not have.
        assert package.support_level in [:stable, :beta, :experimental]
        assert level == Atom.to_string(package.support_level)
      end
    end

    test "a Stable, Beta, or Experimental label is visible to a visitor", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      labels =
        home_ecosystem_package_support_levels(html)
        |> Map.values()
        |> Enum.map(& &1.label)
        |> MapSet.new()

      # The acceptance condition: at least one support level is visible. The copy
      # uses the canonical capitalized labels from SupportLevel, never a bare atom.
      refute MapSet.disjoint?(labels, MapSet.new(["Stable", "Beta", "Experimental"]))

      for label <- labels do
        assert label in ["Stable", "Beta", "Experimental"],
               "expected a canonical support-level label, got: #{inspect(label)}"
      end
    end

    test "each package renders a human-readable level beside its name", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      rows =
        html
        |> Floki.parse_document!()
        |> Floki.find("#home-ecosystem-section .home-ecosystem-package-role")

      assert length(rows) == 9

      for row <- rows do
        label = row |> Floki.find(".home-ecosystem-support-level") |> Floki.text() |> String.trim()
        assert label != "", "expected a support-level label beside every package name"
      end
    end
  end

  describe "home CTA and card destinations (jido-e04-t31)" do
    # Acceptance condition: all CTA and card routes resolve. The static link
    # audit already confirms zero unmatched links across the source files, but it
    # scans static markup — it cannot see the destinations the LiveView actually
    # renders. This mounts the home LiveView, reads every destination a visitor
    # sees (every CTA and card in #home-page), and follows each one through the
    # router, asserting it resolves to a real route or a legacy redirect — never
    # the 404 catch-all.

    test "every CTA and card destination resolves to a real route, not the 404 fallback", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, "/")

      destinations =
        html
        |> Floki.parse_document!()
        |> Floki.find("#home-page a[href]")
        |> Floki.attribute("href")
        |> Enum.filter(&home_route?/1)
        |> Enum.uniq()

      # Sanity floor: the home page carries many CTAs and cards across its
      # sections. This guards against the extraction silently returning an empty
      # or near-empty list, which would make the loop below pass vacuously.
      assert length(destinations) >= 12,
             "expected at least 12 home destinations, got #{length(destinations)}: " <>
               "#{inspect(destinations)}"

      unresolved =
        for destination <- destinations,
            status = get(conn, destination).status,
            status not in 200..399 do
          {destination, status}
        end

      # A status outside 200..399 means the destination only resolved to the
      # router's catch-all (PageController.not_found returns 404), so it does not
      # actually route to a page a visitor can reach.
      assert unresolved == [],
             "home CTA/card destinations that did not resolve: #{inspect(unresolved)}"
    end
  end

  defp home_ecosystem_stacks(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#home-ecosystem-section article[data-stack]")
    |> Enum.map(fn card ->
      key = Floki.attribute(card, "data-stack") |> hd()
      name = card |> Floki.find(".home-ecosystem-row-title") |> Floki.text() |> String.trim()
      purpose = card |> Floki.find(".home-ecosystem-stack-purpose") |> Floki.text() |> String.trim()
      has_start = card |> Floki.find(".home-ecosystem-start-badge") |> Enum.any?()

      packages =
        card
        |> Floki.find(".home-ecosystem-package-role")
        |> Map.new(fn row ->
          pkg_name = Floki.attribute(row, "data-package") |> hd()

          role =
            row |> Floki.find(".home-ecosystem-stack-package-role") |> Floki.text() |> String.trim()

          {pkg_name, role}
        end)

      {key, %{name: name, purpose: purpose, start: has_start, packages: packages}}
    end)
  end

  defp home_ecosystem_package_support_levels(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#home-ecosystem-section .home-ecosystem-package-role")
    |> Map.new(fn row ->
      name = Floki.attribute(row, "data-package") |> hd()
      level = Floki.attribute(row, "data-support-level") |> hd()

      label = row |> Floki.find(".home-ecosystem-support-level") |> Floki.text() |> String.trim()

      {name, %{level: level, label: label}}
    end)
  end

  defp use_case_statuses(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#what-you-can-build a.home-pillar-card")
    |> Map.new(fn card ->
      use_case = Floki.attribute(card, "data-use-case") |> hd()
      status = Floki.attribute(card, "data-status") |> hd()
      {use_case, status}
    end)
  end

  defp operational_control_questions(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#operational-control article[data-control-question]")
    |> Map.new(fn card ->
      slug = Floki.attribute(card, "data-control-question") |> hd()
      question = card |> Floki.find("h3") |> Floki.text() |> String.trim()
      {slug, question}
    end)
  end

  # A single proof card from the operational-control section, looked up by its
  # data-control-card slug (jido-e04-t35+). Returns the Floki node or nil.
  defp operational_control_card(html, slug) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#operational-control article[data-control-card='#{slug}']")
    |> List.first()
  end

  # An internal navigation destination: an absolute path that is not a static
  # asset. External URLs and fragment-only anchors are excluded by the leading
  # "/" check.
  defp home_route?(path) do
    String.starts_with?(path, "/") and
      not String.starts_with?(path, "/assets/") and
      not String.starts_with?(path, "/images/") and
      not String.starts_with?(path, "/fonts/")
  end

  defp ensure_started(app) do
    case Application.ensure_all_started(app) do
      {:ok, _apps} -> :ok
      {:error, {:already_started, _app}} -> :ok
      {:error, reason} -> raise "failed to start #{inspect(app)}: #{inspect(reason)}"
    end
  end
end
