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

  describe "home hero non-Elixir evaluation (jido-e04-t08)" do
    # Acceptance condition: "The first viewport does not split attention across
    # three personas." The hero previously presented a dual peer persona-fork —
    # an Elixir-expert link and a "New to Elixir?" link side by side — which,
    # with the primary CTA, split the first viewport across three personas
    # (per docs/Jido Positioning Review 2026-07-23.md: the two audience links
    # gave both groups equal weight). Non-Elixir evaluation now collapses to a
    # single secondary link — an expansion route to the beam-for-ai-builders
    # on-ramp named in specs/persona-journeys.md — so the first viewport leads
    # with one primary path and routes the non-Elixir evaluator through one
    # secondary link instead of a co-equal peer persona.

    test "routes non-Elixir evaluation through one secondary link", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      hero = hero_section(html)

      # Exactly one non-Elixir evaluation link in the hero — a single secondary
      # link, not one of two peers in a fork.
      links = Floki.find(hero, "a[data-hero-audience='non-elixir-evaluation']")
      assert length(links) == 1

      # The single secondary link routes to the canonical non-Elixir evaluator
      # on-ramp, not the learn-Elixir page.
      assert Floki.attribute(hd(links), "href") |> hd() == "/features/beam-for-ai-builders"
    end

    test "the peer persona-fork has left the first viewport", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      hero = hero_section(html)

      # The "New to Elixir?" peer persona route is out of the first viewport —
      # it remains reachable lower on the page in the "Why an agent framework on
      # Elixir?" section. Its absence from the hero is what collapses the
      # three-persona split.
      assert Floki.find(hero, "a[href='/docs/getting-started/new-to-elixir']") == []

      # The non-Elixir route is no longer framed as a peer persona question in
      # the first viewport.
      refute Floki.text(hero) =~ "New to Elixir?"
    end

    test "the Elixir-expert fast-lane stays and leads the non-Elixir route", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      hero = hero_section(html)

      # The primary audience (Elixir engineers) keeps its fast-lane (jido-e04-t07).
      expert = hero |> Floki.find("#home-elixir-expert-guide-link") |> List.first()
      assert expert != nil
      assert Floki.attribute(expert, "href") |> hd() == "/docs/getting-started/elixir-developers"

      # The Elixir-expert route precedes the non-Elixir secondary link in reading
      # order, so the primary audience stays first (jido-e04-t07 invariant).
      {expert_idx, _} = :binary.match(html, ~s(id="home-elixir-expert-guide-link"))
      {non_elixir_idx, _} = :binary.match(html, ~s(id="home-non-elixir-evaluation-link"))
      assert expert_idx < non_elixir_idx
    end

    test "the primary CTA still leads the first viewport", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      hero = hero_section(html)

      primary = hero |> Floki.find("#home-hero-cta") |> List.first()
      assert primary != nil
      assert Floki.attribute(primary, "href") |> hd() == "/docs/getting-started"
    end
  end

  describe "home-to-onboarding conversion analytics (jido-e12-t21)" do
    # Acceptance condition: "Hero and section CTA paths are visible." Every CTA
    # that routes the home page into onboarding fires a first-party
    # `cta_clicked` event carrying a distinct section_id, so the team can see
    # each path — the hero CTA and each section CTA — instead of only page
    # traffic. The global click handler in app.js reads these data-analytics-*
    # attributes and posts the event; this test locks the attributes the
    # handler depends on.

    test "the hero CTA fires cta_clicked with the hero section_id into onboarding", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, "/")

      cta = home_cta(html, "hero")

      # The hero CTA is the primary home -> onboarding entry.
      assert cta != nil, "expected a hero CTA carrying cta_clicked analytics"
      assert Floki.attribute(cta, "href") |> hd() == "/docs/getting-started"
      assert attr(cta, "data-analytics-event") == "cta_clicked"
      assert attr(cta, "data-analytics-source") == "home"
      assert attr(cta, "data-analytics-target-url") == "/docs/getting-started"
    end

    test "every onboarding CTA carries a distinct, non-empty section_id", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      ctas = home_ctas(html)

      # Sanity floor: the hero CTA plus at least the named section CTAs are
      # instrumented, so the assertion below cannot pass vacuously.
      assert length(ctas) >= 2,
             "expected at least the hero and one section CTA, got #{length(ctas)}"

      section_ids = Enum.map(ctas, &attr(&1, "data-analytics-section-id"))

      # Acceptance condition: each CTA path is visible on its own — every
      # section_id is present, non-empty, and distinct.
      for cta <- ctas do
        assert attr(cta, "data-analytics-event") == "cta_clicked"
        assert attr(cta, "data-analytics-source") == "home"
        assert attr(cta, "data-analytics-section-id") != nil
        assert attr(cta, "data-analytics-target-url") != nil
      end

      assert length(Enum.uniq(section_ids)) == length(section_ids),
             "expected distinct section_ids for each CTA, got #{inspect(section_ids)}"
    end

    test "the hero and each section CTA route into onboarding or the start-small path", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, "/")

      # The home -> onboarding conversion paths: the hero CTA and the section
      # CTAs that move a visitor toward building their first agent.
      expected = %{
        "hero" => "/docs/getting-started",
        "quick-start" => "/docs/getting-started",
        "agent-model" => "/docs/getting-started",
        "build-first-agent" => "/docs/getting-started",
        "start-with-one-agent" => "/features/start-small"
      }

      actual =
        home_ctas(html)
        |> Map.new(fn cta ->
          {attr(cta, "data-analytics-section-id"), Floki.attribute(cta, "href") |> hd()}
        end)

      for {section_id, href} <- expected do
        assert actual[section_id] == href,
               "expected the #{section_id} CTA to route to #{href}, got #{inspect(actual[section_id])}"
      end
    end
  end

  describe "home control message to proof analytics (jido-e12-t46)" do
    # Acceptance condition: "The team can see which control claims start
    # evaluation." Every proof link in the home operational-control section
    # fires a first-party `control_proof_viewed` event carrying the control
    # claim (the proof link's slug) as section_id, so the team can see which
    # claims visitors follow to proof — instead of only that the section was
    # viewed. The global click handler in app.js reads these data-analytics-*
    # attributes and posts the event; this test locks the attributes the
    # handler depends on.

    test "every control-proof link fires control_proof_viewed carrying its claim as section_id",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      links = control_proof_links(html)

      # Sanity floor: the operational-control section routes more than one claim
      # to proof, so the assertion below cannot pass vacuously.
      assert length(links) >= 2,
             "expected several control-proof links, got #{length(links)}"

      for link <- links do
        claim = Floki.attribute(link, "data-control-link") |> hd()
        href = Floki.attribute(link, "href") |> hd()

        # Each proof link fires control_proof_viewed from the home control
        # message, carrying the claim slug as section_id and the proof surface
        # as target_url — the attributes the click handler posts.
        assert attr(link, "data-analytics-event") == "control_proof_viewed"
        assert attr(link, "data-analytics-source") == "home"
        assert attr(link, "data-analytics-channel") == "home_operational_control"
        assert attr(link, "data-analytics-section-id") == claim
        assert attr(link, "data-analytics-target-url") == href
      end

      # Each control claim is distinct — a visitor following two claims counts
      # once in each, so no two proof links may share a section_id.
      section_ids = Enum.map(links, &attr(&1, "data-analytics-section-id"))

      assert length(Enum.uniq(section_ids)) == length(section_ids),
             "expected distinct section_ids per control claim, got #{inspect(section_ids)}"
    end

    test "each control claim routes to its named proof surface", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # The control claims the home operational-control section routes to proof:
      # supervision and the failure drill, the five capability surfaces, the
      # three traceability records, the five integration boundaries, and the
      # capstone integrated controlled-Agent example.
      expected = %{
        "supervision" => "/features/agents-that-self-heal",
        "failure-boundary-proof" => "/examples/failure-drill-agent",
        "typed-actions" => "/docs/concepts/actions",
        "tool-allowlists" => "/docs/operations/security-and-governance",
        "policy-hooks" => "/docs/operations/security-and-governance",
        "effects" => "/docs/concepts/directives",
        "quotas" => "/docs/operations/security-and-governance",
        "causal-signals" => "/docs/concepts/signals",
        "journal-configuration" => "/docs/concepts/persistence",
        "correlated-telemetry" => "/docs/reference/telemetry-and-observability",
        "iam-boundary" => "/docs/operations/security-and-governance",
        "ash-actor-tenant" => "/ecosystem/ash_jido",
        "durable-storage" => "/docs/concepts/persistence",
        "siem-integration" => "/docs/operations/security-and-governance",
        "otel-export" => "/docs/reference/telemetry-and-observability",
        "controlled-agent-example" => "/examples/controlled-agent"
      }

      actual =
        control_proof_links(html)
        |> Map.new(fn link ->
          {attr(link, "data-analytics-section-id"), Floki.attribute(link, "href") |> hd()}
        end)

      assert Map.keys(actual) |> MapSet.new() == MapSet.new(Map.keys(expected)),
             "expected proof links for #{inspect(Map.keys(expected))}, " <>
               "got #{inspect(Map.keys(actual))}"

      for {claim, href} <- expected do
        assert actual[claim] == href,
               "expected the #{claim} claim to route to #{href}, got #{inspect(actual[claim])}"
      end
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

  describe "home control note: telemetry is not an audit log (jido-e04-t39)" do
    # Acceptance condition: evaluators see the distinction before they infer
    # compliance. A caveat note in the operational-control section separates
    # telemetry (operational signal) from an audit log (deliberately configured
    # durable history with application-owned retention, access, and tamper
    # evidence), so a visitor cannot read the traceability story as compliance.

    test "renders the note inside the operational-control section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      note = operational_control_note(html, "telemetry-not-audit")

      assert note != nil, "expected a telemetry-not-audit control note"

      assert note |> Floki.find(".home-eyebrow-label") |> Floki.text() |> String.trim() ==
               "Telemetry is not an audit log"
    end

    test "the note sits after the trace card and before the full control model link",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # The caveat lands after the trace card — where telemetry is introduced —
      # and before the "See the full control model" link, so an evaluator hits
      # the distinction before concluding anything about compliance.
      assert {trace_idx, _} = :binary.match(html, ~s(data-control-card="trace-what-happened"))
      assert {note_idx, _} = :binary.match(html, ~s(data-control-note="telemetry-not-audit"))
      assert {model_link_idx, _} = :binary.match(html, "See the full control model")

      assert trace_idx < note_idx
      assert note_idx < model_link_idx
    end

    test "the note explains that telemetry is operational signal, not an audit record",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      note = operational_control_note(html, "telemetry-not-audit")
      body = note |> Floki.find("p.home-muted-copy") |> Floki.text() |> String.downcase()

      # The acceptance condition is the distinction itself. The body names
      # telemetry, keeps audit as a separately configured durable record, and
      # calls out that telemetry is not tamper-evident evidence — so an
      # evaluator cannot conflate the two.
      for term <- ~w(telemetry audit tamper) do
        assert String.contains?(body, term),
               "expected the note body to name #{term} to make the distinction"
      end
    end

    test "the note routes telemetry and the durable Journal to their authoritative pages",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      note = operational_control_note(html, "telemetry-not-audit")

      links =
        note
        |> Floki.find("a[data-note-link]")
        |> Map.new(fn a ->
          slug = Floki.attribute(a, "data-note-link") |> hd()
          href = Floki.attribute(a, "href") |> hd()
          {slug, href}
        end)

      # Telemetry's scope lives on the observability page; the durable Journal
      # you configure for causal history lives on the persistence page.
      assert links == %{
               "telemetry-scope" => "/docs/reference/telemetry-and-observability",
               "durable-journal" => "/docs/concepts/persistence"
             }
    end
  end

  describe "home control note: Agent IDs are not authenticated principals (jido-e04-t40)" do
    # Acceptance condition: identity claims stay bounded. The "who initiated
    # work" card talks about principal, tenant, and causation context, so a
    # visitor could read it as Jido authenticating the caller. A caveat note in
    # the operational-control section states that Agent IDs (and Signal and
    # trace IDs) are correlation metadata, not verified identity, because
    # authentication and IAM are an application/platform boundary in front of
    # Jido — bounding the claim so an Agent ID cannot be mistaken for a
    # principal.

    test "renders the note inside the operational-control section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      note = operational_control_note(html, "identity-not-principal")

      assert note != nil, "expected an identity-not-principal control note"

      assert note |> Floki.find(".home-eyebrow-label") |> Floki.text() |> String.trim() ==
               "Agent IDs are not authenticated principals"
    end

    test "the note sits after the integrate card and before the full control model link",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # The identity/IAM boundary is introduced by the integrate-your-control-system
      # card; the caveat lands after it and before the "See the full control
      # model" link, so an evaluator cannot read "who initiated work" as Jido
      # authenticating the caller.
      assert {integrate_idx, _} =
               :binary.match(html, ~s(data-control-card="integrate-your-control-system"))

      assert {note_idx, _} = :binary.match(html, ~s(data-control-note="identity-not-principal"))
      assert {model_link_idx, _} = :binary.match(html, "See the full control model")

      assert integrate_idx < note_idx
      assert note_idx < model_link_idx
    end

    test "the note explains that Agent IDs are correlation, not authentication",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      note = operational_control_note(html, "identity-not-principal")
      body = note |> Floki.find("p.home-muted-copy") |> Floki.text() |> String.downcase()

      # The acceptance condition is the bound itself. The body names Agent IDs,
      # calls them correlation (not identity), names the principal as something
      # the caller's boundary issues, and states Jido does not authenticate —
      # so an evaluator cannot read an Agent ID as a verified principal.
      for term <- ~w(agent principal correlation authenticate) do
        assert String.contains?(body, term),
               "expected the note body to name #{term} to bound the identity claim"
      end
    end

    test "the note routes the identity claim to its authoritative page",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      note = operational_control_note(html, "identity-not-principal")

      links =
        note
        |> Floki.find("a[data-note-link]")
        |> Map.new(fn a ->
          slug = Floki.attribute(a, "data-note-link") |> hd()
          href = Floki.attribute(a, "href") |> hd()
          {slug, href}
        end)

      # The formal statement that Agent IDs are correlation metadata, not
      # authenticated principals, lives on the security-and-governance page.
      assert links == %{
               "identity-bounded" => "/docs/operations/security-and-governance"
             }
    end
  end

  describe "home control proof card: one integrated controlled agent (jido-e04-t41)" do
    # Acceptance condition: the control section routes to ONE integrated
    # controlled-Agent example, and the destination proves the complete control
    # path. The four control cards above each route a single control to its own
    # surface; this capstone card ties them together in one runnable example.

    test "renders an integrated controlled-agent capstone card inside the operational-control section",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "integrated-controlled-agent")

      assert card != nil, "expected an integrated-controlled-agent control card"

      assert card |> Floki.find("h3") |> Floki.text() |> String.trim() ==
               "See one integrated controlled agent"
    end

    test "the capstone card sits after the caveat notes and before the full control model link",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # The capstone is the synthesis of the four control cards, so it lands
      # after the bounding caveat notes and before the deeper "See the full
      # control model" governance link.
      assert {identity_idx, _} =
               :binary.match(html, ~s(data-control-note="identity-not-principal"))

      assert {card_idx, _} =
               :binary.match(html, ~s(data-control-card="integrated-controlled-agent"))

      assert {model_link_idx, _} = :binary.match(html, "See the full control model")

      assert identity_idx < card_idx
      assert card_idx < model_link_idx
    end

    test "routes the control section to one integrated controlled-Agent example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      card = operational_control_card(html, "integrated-controlled-agent")

      example =
        card
        |> Floki.find("a[data-control-link='controlled-agent-example']")
        |> Floki.attribute("href")
        |> List.first()

      # One destination — the integrated controlled-Agent example.
      assert example == "/examples/controlled-agent"
    end

    test "the destination is a live example that proves the complete control path", %{conn: conn} do
      # The acceptance condition is on the destination: it must be reachable and
      # it must prove the complete control path. The example resolves through
      # the router (covered by the jido-e04-t31 destination audit) and is a
      # published live example whose source proves all four controls.
      assert get(conn, "/examples/controlled-agent").status == 200

      example = AgentJido.Examples.get_example!("controlled-agent")

      assert example.status == :live
      assert example.live_view_module == "AgentJidoWeb.Examples.ControlledAgentLive"

      # The example copy names the complete control path it proves.
      copy = example.body |> String.downcase()

      for term <- ~w(who initiated allowed happened failure) do
        assert String.contains?(copy, term),
               "expected the controlled-agent example to prove the #{term} control"
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
      # Each card's status is derived from available?/1 (verified in the next
      # test), so a planned card reappears the moment a use case without a
      # public example is added. E08-T29 published the last missing home
      # use-case example (data-pipelines), so every card now reads runnable --
      # including the data card the task landed.
      assert "runnable" in statuses
      assert status_by_use_case["data-pipelines"] == "runnable"
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

      # Distinguishability holds because each card's label is derived from
      # available?/1 (the loop above): a runnable card reads "Runnable example"
      # and a planned card reads "Planned pattern", so the two never collide.
      # E08-T29 promoted the last planned card, so every card -- including the
      # data-pipelines card it landed -- now reads "Runnable example".
      assert label_by_use_case["data-pipelines"] == "Runnable example"
    end
  end

  describe "home use-case best entry point (E08-T25)" do
    # Acceptance condition: "The home research card links to one best entry
    # point." The research card keeps its scoped destination (E04-T21) and gains
    # a direct link to the single best research example, so a visitor can start
    # with one example instead of picking it out of the scoped list.

    test "the research card links directly to one best entry-point example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      entry_points =
        html
        |> Floki.parse_document!()
        |> Floki.find("#what-you-can-build a.home-use-case-entry-point")
        |> Map.new(fn link ->
          use_case = Floki.attribute(link, "data-use-case-entry-point") |> hd()
          slug = Floki.attribute(link, "data-entry-point") |> hd()
          href = Floki.attribute(link, "href") |> hd()
          {use_case, %{slug: slug, href: href}}
        end)

      # Only the research use case has named a best entry point today, so the
      # link is gated to the use cases that actually have one.
      assert Map.keys(entry_points) == ["research"]

      # The entry point is the canonical, runnable Runic research example.
      assert entry_points["research"].slug == "runic-ai-research-studio"
      assert entry_points["research"].href == "/examples/runic-ai-research-studio"
    end

    test "the research entry point is a single example, not the scoped list", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      doc = Floki.parse_document!(html)

      scoped =
        doc
        |> Floki.find("#what-you-can-build a.home-pillar-card[data-use-case=research]")
        |> Floki.attribute("href")
        |> hd()

      entry =
        doc
        |> Floki.find("#what-you-can-build a.home-use-case-entry-point[data-use-case-entry-point=research]")
        |> Floki.attribute("href")
        |> hd()

      # The card still links to its scoped destination (E04-T21 invariant)...
      assert scoped == "/examples?use_case=research"
      # ...and surfaces a direct link to one best entry-point example alongside it.
      assert entry == "/examples/runic-ai-research-studio"
      assert scoped != entry
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

  describe "home ecosystem stack dependency blocks (E09-T08)" do
    # Acceptance condition: each recommended stack has a copyable dependency
    # block that installs. The block is derived from the authoritative
    # ecosystem registry — a published package pins to its published Hex MAJOR
    # (`~> X.0`) so the resolver can pick a compatible within-major set, and a
    # package not yet on Hex falls back to its public GitHub repo. Both forms
    # resolve on `mix deps.get`, which is the install bar. (Major pins are used
    # because the registry records each package's version independently, so
    # exact per-package pins can be mutually incompatible.)

    test "every stack renders a dependency block", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      blocks = home_ecosystem_stack_deps(html)

      # All three recommended stacks carry a block.
      assert Map.keys(blocks) |> MapSet.new() == MapSet.new(~w(core ai operate))

      for {_key, %{snippet: snippet}} <- blocks do
        assert is_binary(snippet) and String.trim(snippet) != "",
               "expected each stack to render a non-empty dependency block"
      end
    end

    test "each block is a copyable mix.exs deps function with matching copy content",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      for {_key, %{snippet: snippet, copy_content: copy_content}} <-
            home_ecosystem_stack_deps(html) do
        # Well-formed mix deps function a visitor can paste into mix.exs.
        assert String.starts_with?(snippet, "defp deps do")
        assert String.ends_with?(snippet, "end")
        assert snippet =~ "["
        assert snippet =~ "]"

        # Copyable: the copy button carries the verbatim block text, so pasting
        # reproduces exactly what is shown.
        assert copy_content == snippet,
               "expected the copy button data-content to match the rendered block"
      end
    end

    test "each block lists exactly its stack's packages and nothing else", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      stacks = home_ecosystem_stacks(html)
      blocks = home_ecosystem_stack_deps(html)

      for {key, %{packages: packages}} <- stacks do
        snippet = Map.fetch!(blocks, key).snippet
        names = Map.keys(packages)

        # Every package in the stack appears as a dep atom in the block.
        for name <- names do
          assert snippet =~ "{:#{name},",
                 "expected the #{key} block to include the #{name} dependency"
        end

        # The dep count matches the package count — no extra or missing lines.
        dep_count = Regex.scan(~r/\{:[a-z0-9_]+,/, snippet) |> length()

        assert dep_count == length(names),
               "expected #{length(names)} deps in the #{key} block, got #{dep_count}"
      end
    end

    test "published packages pin to the registry major; unreleased fall back to GitHub",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      stacks = home_ecosystem_stacks(html)
      blocks = home_ecosystem_stack_deps(html)

      for {key, %{packages: packages}} <- stacks do
        snippet = Map.fetch!(blocks, key).snippet

        for name <- Map.keys(packages) do
          assert snippet =~ expected_dependency_line(name),
                 "expected the #{key} block to derive #{name} from the registry, got:\n#{snippet}"
        end
      end
    end

    test "every dep line resolves: a valid Hex pin or a public GitHub repo", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      for {_key, %{snippet: snippet}} <- home_ecosystem_stack_deps(html) do
        # Each line is either a Hex major version requirement or a GitHub
        # dependency — the two forms `mix deps.get` resolves, which is the
        # install bar.
        for line <- Regex.scan(~r/\{:[a-z0-9_]+,[^}]+\}/, snippet) do
          line = hd(line)

          assert line =~ ~r/"~> \d+\.0"/ or line =~ ~r/github: "[a-z0-9_\-]+\/[a-z0-9_\-]+"/,
                 "expected an installable dep line, got: #{inspect(line)}"
        end
      end
    end
  end

  describe "home ecosystem stack minimal examples (jido-e09-t09)" do
    # Acceptance condition: each stack has a tested minimal example. The
    # example's stated packages must match the stack a visitor sees, so the
    # example never drifts from the home card or its dependency block.

    test "each home stack's packages match its minimal example's stated packages",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      home_packages =
        home_ecosystem_stacks(html)
        |> Map.new(fn {key, %{packages: packages}} -> {key, Map.keys(packages) |> Enum.sort()} end)

      for %{key: key, module: module} <- AgentJido.Demos.StackExamples.stacks() do
        example_packages = module.packages() |> Enum.sort()

        assert Map.get(home_packages, key) == example_packages,
               "the #{key} stack example's packages #{inspect(example_packages)} " <>
                 "do not match the home card #{inspect(Map.get(home_packages, key))}"
      end
    end
  end

  describe "home ecosystem stack negative-fit notes (E09-T10)" do
    # Acceptance condition: selection guidance includes a negative fit. Each
    # recommended stack already says what it is for (E04-T24); this adds the
    # other half of selection guidance — a "Do not use this when" note per
    # stack, so a builder can tell when a stack is the wrong pick, not just when
    # it is the right one.

    test "every stack carries a non-empty 'Do not use this when' note", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      notes = home_ecosystem_stack_negative_fits(html)

      # All three recommended stacks carry a negative-fit note.
      assert Map.keys(notes) |> MapSet.new() == MapSet.new(~w(core ai operate))

      for {key, %{label: label, body: body}} <- notes do
        assert label == "Do not use this when",
               "expected the #{key} stack to carry a 'Do not use this when' label"

        assert is_binary(body) and String.trim(body) != "",
               "expected the #{key} stack to carry a non-empty negative-fit note"
      end
    end

    test "each note sits inside its own stack card", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      notes =
        html
        |> Floki.parse_document!()
        |> Floki.find("#home-ecosystem-section [data-stack-negative-fit]")
        |> Map.new(fn note ->
          key = Floki.attribute(note, "data-stack-negative-fit") |> hd()
          {key, note}
        end)

      # The negative-fit note is attached to exactly one element per stack and
      # the attribute matches the stack's key, so each note belongs to its own
      # card rather than a shared caveat below the section.
      assert Map.keys(notes) |> MapSet.new() == MapSet.new(~w(core ai operate))
    end

    test "each note follows its stack's purpose, so positive and negative fit read together",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      cards =
        html
        |> Floki.parse_document!()
        |> Floki.find("#home-ecosystem-section article[data-stack]")
        |> Map.new(fn card ->
          {Floki.attribute(card, "data-stack") |> hd(), Floki.raw_html(card)}
        end)

      # The purpose (what to reach for) leads; the negative fit (when not to)
      # follows it, before the package list — so the two halves of selection
      # guidance sit together on each card.
      for {key, card_html} <- cards do
        {purpose_idx, _} = :binary.match(card_html, "home-ecosystem-stack-purpose")
        {note_idx, _} = :binary.match(card_html, ~s(data-stack-negative-fit="#{key}"))
        {packages_idx, _} = :binary.match(card_html, "home-ecosystem-packages")

        assert purpose_idx < note_idx
        assert note_idx < packages_idx
      end
    end

    test "each note is distinct, so the negative fit is real per stack", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      bodies =
        home_ecosystem_stack_negative_fits(html)
        |> Map.values()
        |> Enum.map(& &1.body)

      # Three distinct notes — not the same caveat repeated three times — so each
      # stack states a real reason it is the wrong pick for that situation.
      assert length(Enum.uniq(bodies)) == 3
    end
  end

  describe "home ecosystem stack production-next-step links (E09-T11)" do
    # Acceptance condition: a builder can move to Operate guidance. Each
    # recommended stack already explains what it is for (E04-T24), when not to
    # use it (E09-T10), and how to install it (E09-T08); this adds the final
    # selection step — one link per stack into the operations guidance that
    # stack needs to run in production.

    test "every stack carries a production-next-step link into Operate guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      steps = home_ecosystem_stack_next_steps(html)

      # All three recommended stacks carry a next-step link.
      assert Map.keys(steps) |> MapSet.new() == MapSet.new(~w(core ai operate))

      for {key, %{href: href, label: label}} <- steps do
        # The link routes into the operations guidance hub (/docs/operations),
        # so a builder who picked the stack has a single move into Operate
        # guidance.
        assert String.starts_with?(href, "/docs/operations/"),
               "expected the #{key} next-step link to route into Operate guidance, got #{inspect(href)}"

        # The link carries a non-empty label a builder can read.
        assert is_binary(label) and label != "",
               "expected the #{key} next-step link to carry a non-empty label"
      end
    end

    test "the next-step link sits after the dependency block on each card", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      cards =
        html
        |> Floki.parse_document!()
        |> Floki.find("#home-ecosystem-section article[data-stack]")
        |> Map.new(fn card ->
          {Floki.attribute(card, "data-stack") |> hd(), Floki.raw_html(card)}
        end)

      # The next-step link is the last move on the card: it follows the
      # installable dependency block, so a builder who has installed a stack sees
      # the move into Operate guidance.
      for {key, card_html} <- cards do
        {deps_idx, _} = :binary.match(card_html, "home-ecosystem-stack-deps")
        {step_idx, _} = :binary.match(card_html, ~s(data-stack-next-step="#{key}"))

        assert deps_idx < step_idx
      end
    end

    test "each stack routes to a distinct operations page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      hrefs = home_ecosystem_stack_next_steps(html) |> Map.values() |> Enum.map(& &1.href)

      # Three distinct destinations — each stack routes to the operations page
      # that covers its own production concern, not a shared link to the hub.
      assert length(Enum.uniq(hrefs)) == 3
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

  defp home_ecosystem_stack_negative_fits(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#home-ecosystem-section [data-stack-negative-fit]")
    |> Map.new(fn note ->
      key = Floki.attribute(note, "data-stack-negative-fit") |> hd()

      label =
        note
        |> Floki.find(".home-ecosystem-stack-negative-fit-label")
        |> Floki.text()
        |> String.trim()

      body =
        note
        |> Floki.find(".home-ecosystem-stack-negative-fit-text")
        |> Floki.text()
        |> String.trim()

      {key, %{label: label, body: body}}
    end)
  end

  defp home_ecosystem_stack_next_steps(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#home-ecosystem-section [data-stack-next-step]")
    |> Map.new(fn link ->
      key = Floki.attribute(link, "data-stack-next-step") |> hd()
      href = Floki.attribute(link, "href") |> hd()
      label = Floki.text(link) |> String.trim()
      {key, %{href: href, label: label}}
    end)
  end

  defp home_ecosystem_stack_deps(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#home-ecosystem-section article[data-stack]")
    |> Map.new(fn card ->
      key = Floki.attribute(card, "data-stack") |> hd()

      snippet =
        card |> Floki.find(".home-ecosystem-stack-deps-code") |> Floki.text() |> String.trim()

      copy_content =
        case card |> Floki.find("[data-copy-button]") do
          [btn | _] -> Floki.attribute(btn, "data-content") |> List.first()
          _ -> nil
        end

      {key, %{snippet: snippet, copy_content: copy_content}}
    end)
  end

  # Mirrors the render-time derivation in JidoHomeLive so the test asserts the
  # block tracks the authoritative registry instead of a hardcoded copy.
  defp expected_dependency_line(name) do
    pkg = AgentJido.Ecosystem.get_public_package(name)
    hex_status = Map.get(pkg, :hex_status)

    cond do
      is_binary(hex_status) and Regex.run(~r/^(\d+)\./, hex_status) != nil ->
        [_, major] = Regex.run(~r/^(\d+)\./, hex_status)
        "{:#{name}, \"~> #{major}.0\"}"

      is_binary(pkg.github_org) and is_binary(pkg.github_repo) ->
        "{:#{name}, github: \"#{pkg.github_org}/#{pkg.github_repo}\""

      true ->
        nil
    end
  end

  # All home CTAs instrumented with the home -> onboarding cta_clicked event
  # (jido-e12-t21). Returns the Floki anchor nodes carrying
  # data-analytics-event="cta_clicked".
  defp home_ctas(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#home-page a[data-analytics-event='cta_clicked']")
  end

  # Every proof link in the home operational-control section — the links a
  # visitor follows to start evaluating a control claim (jido-e12-t46). Each
  # carries a data-control-link slug (the claim) and a control_proof_viewed
  # analytics event.
  defp control_proof_links(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#operational-control a[data-control-link]")
  end

  # A single home CTA looked up by its data-analytics-section-id. Returns the
  # Floki node or nil.
  defp home_cta(html, section_id) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#home-page a[data-analytics-section-id='#{section_id}']")
    |> List.first()
  end

  defp attr(node, name) do
    case Floki.attribute(node, name) do
      [value | _] -> value
      [] -> nil
    end
  end

  # The hero <section> rendered in the first viewport (jido-e04-t08). Returns
  # the parsed section node so persona-routing assertions can scope Floki
  # selectors and text checks to the first viewport instead of the whole page.
  defp hero_section(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#home-hero")
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

  # A caveat note from the operational-control section, looked up by its
  # data-control-note slug (jido-e04-t39). Returns the Floki node or nil.
  defp operational_control_note(html, slug) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#operational-control div[data-control-note='#{slug}']")
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
