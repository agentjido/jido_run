defmodule AgentJidoWeb.JidoEcosystemPackageLiveTest do
  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "private packages are not accessible from public ecosystem routes", %{conn: conn} do
    assert_raise AgentJido.Ecosystem.NotFoundError, fn ->
      live(conn, "/ecosystem/jido_memory_os")
    end
  end

  test "renders jido as a curated landing page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    assert html =~ "Jido"
    assert html =~ "long-running, multi-agent systems on OTP and the BEAM"
    assert html =~ "WHEN TO USE Jido"
    assert html =~ "Use This When"
    assert html =~ "Not The Right Fit When"
    assert html =~ "START HERE"
    assert html =~ "Start Here"
    assert html =~ "Guides"
    assert html =~ "Examples"
    assert html =~ "Reference"
    assert html =~ ~s(href="/docs/getting-started/first-agent")
    assert html =~ ~s(href="/examples/counter-agent")
    assert html =~ "KEY MODULES"
    assert html =~ "Jido.Discovery"
    assert html =~ ~s(href="https://hexdocs.pm/jido/Jido.Discovery.html")
    assert html =~ "RELATED PACKAGES"
    assert html =~ "Builds on"
    assert html =~ "Works with"
    assert html =~ "Add next"
    assert html =~ ~s(href="/ecosystem/jido_action")
    assert html =~ "AT A GLANCE"
    assert html =~ "FAQ"
    assert html =~ "Do I need jido_ai to use Jido?"
    assert html =~ "DEEP DIVE"
    assert html =~ "Add to mix.exs"
    assert html =~ "defp deps do"
    assert html =~ "~&gt; 2.3"
    assert html =~ "View package metadata source"
    refute html =~ "Ecosystem Fit"
    refute html =~ "IMPORTANT PACKAGES"
  end

  test "falls back cleanly for a package without curated landing metadata", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat")

    assert html =~ "Jido Chat"
    assert html =~ "SDK-first chat core for typed message flows and adapter contracts"
    assert html =~ "AT A GLANCE"
    assert html =~ "DEEP DIVE"
    assert html =~ ~s(href="https://github.com/agentjido/jido_chat")
    assert html =~ "WHEN TO USE Jido Chat"
    refute html =~ "START HERE"
    refute html =~ "KEY MODULES"
    refute html =~ "RELATED PACKAGES"
    refute html =~ ">FAQ</"
    refute html =~ "Add to mix.exs"
    refute html =~ "Ecosystem Fit"
  end

  test "renders mattermost adapter details with websocket-first positioning", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat_mattermost")

    assert html =~ "Jido Chat Mattermost"
    assert html =~ "Mattermost adapter package implementing the Jido Chat adapter contract"
    assert html =~ "AT A GLANCE"
    assert html =~ "DEEP DIVE"
    assert html =~ "Uses a websocket-only ingress model and does not include webhook ingestion support."
    assert html =~ "Provides standalone transport implementation without external adapter dependencies"
    assert html =~ ~s(href="https://github.com/www-zaq-ai/jido_chat_mattermost")
    assert html =~ "WHEN TO USE Jido Chat Mattermost"
    refute html =~ "START HERE"
    refute html =~ "KEY MODULES"
    refute html =~ "FAQ"
    refute html =~ "Add to mix.exs"
  end

  test "renders registry freshness — tested version and last-sync date (jido-e09-t18)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # Tested version is visible and falls back to the package version when not
    # set in frontmatter (jido's registry version is enforced to the installed
    # release by the version-freshness gate).
    assert html =~ "tested 2.3.2"

    # Last-sync date is visible and well-formed, falling back to the
    # registry-wide reconciliation date.
    assert html =~ ~r/synced \d{4}-\d{2}-\d{2}/
    assert html =~ "synced #{AgentJido.Ecosystem.registry_last_synced()}"
  end

  test "renders registry freshness for packages without curated metadata", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat")

    # Freshness is visible on every package page, not just curated ones.
    assert html =~ ~r/tested \S/
    assert html =~ ~r/synced \d{4}-\d{2}-\d{2}/
  end

  test "renders one best example — curated proof for jido (jido-e09-t19)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # Every package page surfaces a single best example section.
    assert html =~ "ONE BEST EXAMPLE"

    # jido has curated its best example to the canonical counter-agent.
    assert html =~ "proof curated"
    assert html =~ "Counter Agent example"
    assert html =~ ~s(href="/examples/counter-agent")
  end

  test "auto-resolves one best example from the examples registry", %{conn: conn} do
    # jido_signal has no curated best example, so the page auto-resolves the
    # single published example that declares it (signal-routing-agent).
    {:ok, _view, html} = live(conn, "/ecosystem/jido_signal")

    assert html =~ "ONE BEST EXAMPLE"
    assert html =~ "proof auto-resolved"
    assert html =~ ~s(href="/examples/signal-routing-agent")
  end

  test "states proof is missing when no example exercises the package", %{conn: conn} do
    # jido_chat is not exercised by any example, so the page must be explicit
    # that proof is missing rather than silent.
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat")

    assert html =~ "ONE BEST EXAMPLE"
    assert html =~ "proof missing"
    refute html =~ "proof curated"
    refute html =~ "proof auto-resolved"
  end

  # Direct expression of the E09-T19 contract: every public package page either
  # points to proof (a /examples/... link) or explicitly states proof is missing.
  # Uses a disconnected GET render (still runs mount + render) so all public
  # packages can be checked without the connected-LiveView overhead.
  @tag timeout: 120_000
  test "every public package points to proof or states proof is missing (jido-e09-t19)", %{conn: conn} do
    for package <- AgentJido.Ecosystem.public_packages() do
      html = conn |> get("/ecosystem/#{package.id}") |> html_response(200)

      assert html =~ "ONE BEST EXAMPLE",
             "package #{package.id} is missing the ONE BEST EXAMPLE section"

      has_proof_link = html =~ ~s(href="/examples/)
      states_missing = html =~ "proof missing"

      assert has_proof_link != states_missing,
             "package #{package.id} must either link proof or state proof is missing " <>
               "(proof_link=#{has_proof_link}, missing=#{states_missing})"
    end
  end

  test "renders one best guide — curated learning path for jido (jido-e09-t20)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # Every package page surfaces a single best guide section.
    assert html =~ "ONE BEST GUIDE"

    # jido has curated its best guide to the canonical first learning path.
    assert html =~ "guide curated"
    assert html =~ "Your first agent"
    assert html =~ ~s(href="/docs/getting-started/first-agent")
  end

  test "auto-resolves one best guide from the docs guides registry", %{conn: conn} do
    # jido_ai has no curated best guide, so the page auto-resolves the
    # lowest-order published guide whose tested_with declares it
    # (testing-agents-and-actions, order 170).
    {:ok, _view, html} = live(conn, "/ecosystem/jido_ai")

    assert html =~ "ONE BEST GUIDE"
    assert html =~ "guide auto-resolved"
    assert html =~ ~s(href="/docs/guides/testing-agents-and-actions")
  end

  test "states a guide is missing when no guide covers the package", %{conn: conn} do
    # jido_chat is not covered by any guide, so the page must be explicit that
    # no learning path exists rather than silent.
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat")

    assert html =~ "ONE BEST GUIDE"
    assert html =~ "guide missing"
    refute html =~ "guide curated"
    refute html =~ "guide auto-resolved"
  end

  # jido-e10 E10-T25: each Ecosystem package page links to its matching builder
  # skill so package evaluation can continue into builder assistance. The link
  # deep-links to the skill card on the public Skills catalog.
  test "links the matching builder skill when one exists (jido-e10-t25)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido_action")

    assert html =~ "BUILDER SKILL"
    assert html =~ "skill jido-action"
    assert html =~ ~s(href="/skills#skill-card-jido-action")
    assert html =~ "open skill"
  end

  test "omits the builder skill section when no skill matches", %{conn: conn} do
    # jido_chat has no vendored builder skill, so the page must not surface the
    # section rather than link to nothing.
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat")

    refute html =~ "BUILDER SKILL"
    refute html =~ "href=\"/skills#skill-card-"
  end

  # Direct expression of the E10-T25 contract: every public package that has a
  # vendored builder skill links to it from its package page, so package
  # evaluation can continue into builder assistance. Uses a disconnected GET
  # render (still runs mount + render) so all matching packages are checked.
  @tag timeout: 120_000
  test "every public package with a skill links it (jido-e10-t25)", %{conn: conn} do
    alias AgentJido.UpstreamSkillCatalog

    packages_with_skill =
      AgentJido.Ecosystem.public_packages()
      |> Enum.filter(&(UpstreamSkillCatalog.entry_for_ecosystem_package(&1.id) != nil))

    assert packages_with_skill != [],
           "expected at least one public package with a matching builder skill"

    for package <- packages_with_skill do
      entry = UpstreamSkillCatalog.entry_for_ecosystem_package(package.id)
      html = conn |> get("/ecosystem/#{package.id}") |> html_response(200)

      assert html =~ "BUILDER SKILL",
             "package #{package.id} has a matching skill but is missing the BUILDER SKILL section"

      assert html =~ "href=\"/skills#skill-card-#{entry.id}\"",
             "package #{package.id} must deep-link to its matching skill card on /skills"
    end
  end

  # Direct expression of the E09-T20 contract: every public package page either
  # links a maintained learning path (a /docs/... guide link) or explicitly
  # states that a guide is missing. Uses a disconnected GET render (still runs
  # mount + render) so all public packages can be checked.
  @tag timeout: 120_000
  test "every public package links a guide or states a guide is missing (jido-e09-t20)", %{conn: conn} do
    for package <- AgentJido.Ecosystem.public_packages() do
      html = conn |> get("/ecosystem/#{package.id}") |> html_response(200)

      assert html =~ "ONE BEST GUIDE",
             "package #{package.id} is missing the ONE BEST GUIDE section"

      has_guide = html =~ "guide curated" or html =~ "guide auto-resolved"
      states_missing = html =~ "guide missing"

      assert has_guide != states_missing,
             "package #{package.id} must either link a guide or state a guide is missing " <>
               "(guide=#{has_guide}, missing=#{states_missing})"
    end
  end

  test "renders the control surface jido supplies and the result it does not supply (jido-e09-t41)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # Every package page surfaces the operational-control section.
    assert html =~ "OPERATIONAL CONTROL"

    # The control surface jido supplies is stated explicitly.
    assert html =~ "Control surface it supplies"
    assert html =~ "prepare_action/3 is the fail-closed authorization point"

    # The control result jido does not supply is stated explicitly.
    assert html =~ "Control result it does not supply"
    assert html =~ "Does not authenticate principals"
  end

  # Direct expression of the E09-T42 contract: the jido package page states the
  # current meaning of core Agent identity. An Agent's ID is Agent lifecycle or
  # profile state (correlation metadata), and the page must say so in those
  # terms rather than implying it is an authenticated principal identity. The
  # authoritative phrasing lives on the Security and governance identity guide;
  # this asserts the package page carries the same meaning.
  test "states core Agent identity as lifecycle or profile state, not authenticated principal identity (jido-e09-t42)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # Positive meaning: the page names the Agent ID as lifecycle or profile state.
    assert html =~ "Agent lifecycle or profile state",
           "the jido package page must state that an Agent's core identity is " <>
             "Agent lifecycle or profile state, not authenticated principal identity"

    # Boundary: the page must distinguish that meaning from authenticated
    # principal identity so an Agent ID cannot be mistaken for a verified caller.
    assert html =~ "not authenticated principal identity",
           "the jido package page must state core Agent identity is not " <>
             "authenticated principal identity"
  end

  # Direct expression of the E09-T48 contract: the jido package page excludes a
  # planned future identity package from the current operational-control proof
  # and labels it as future work until released and tested. A separate
  # `jido_identity` package that would factor identity storage and IAM out of
  # core Jido is planned but not released or tested, so no current
  # operational-control claim may rest on it. The label lives on the identity
  # control-limitation line, alongside the "Does not authenticate principals"
  # boundary the E09-T42 test pins.
  test "labels the planned jido_identity package as future work excluded from current proof (jido-e09-t48)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # The page names the planned future identity package.
    assert html =~ "jido_identity",
           "the jido package page must name the planned jido_identity package"

    assert html =~ "future work",
           "the jido package page must label jido_identity as future work"

    # The label states the package is not released or tested.
    assert html =~ "not yet released or tested",
           "the jido package page must state jido_identity is not yet released or tested"

    # The label excludes the future package from the current operational-control
    # proof so no claim rests on it.
    assert html =~ "no current operational-control claim",
           "the jido package page must exclude jido_identity from current operational-control proof"
  end

  # Direct expression of the E09-T43 contract: the jido package page documents
  # Jido Plugin hooks as the integration points for authorization, and states
  # explicitly that Jido does not supply a full authorization system. The two
  # released hooks — prepare_signal/2 before a signal routes, prepare_action/3
  # before an action runs (fail-closed) — are the extension points; the
  # authorization *decision* stays with the host application. Mirrors the
  # canonical framing on the Security and governance guide and the
  # controlled-Agent example.
  test "documents plugin hooks as authorization integration points, not a full authorization system (jido-e09-t43)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # Positive: the page names the plugin hooks as the authorization integration
    # points, naming both released hooks.
    assert html =~ "Authorization integration points",
           "the jido package page must document plugin hooks as the integration points for authorization"

    assert html =~ "prepare_signal/2",
           "the jido package page must name prepare_signal/2 as an authorization integration point"

    assert html =~ "prepare_action/3",
           "the jido package page must name prepare_action/3 as an authorization integration point"

    # Boundary: the page must not claim Jido supplies a full authorization
    # system; it states the boundary explicitly.
    assert html =~ "Does not supply a full authorization system",
           "the jido package page must state it does not supply a full authorization system"

    assert html =~ "not a built-in IAM or RBAC product",
           "the jido package page must state it is not a built-in IAM or RBAC product"
  end

  # Direct expression of the E09-T46 contract: the ash_jido package page states
  # the boundary between what AshJido preserves and what the host Ash
  # application enforces. AshJido carries Ash's actor, tenant, and
  # authorization context through to generated Jido actions so Ash policies
  # and validations run unchanged; the host Ash application owns the
  # authorization decisions and policies. Mirrors the canonical framing on the
  # Security and governance operations page ("the host Ash application still
  # enforces authorization") and the 2026-07-23 control-surface inventory.
  test "states what ash_jido preserves and what the host Ash application enforces (jido-e09-t46)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/ash_jido")

    # Preserve side: AshJido carries the Ash actor, tenant, and authorization
    # context through to generated actions.
    assert html =~ "actor, tenant, and authorization context",
           "the ash_jido package page must state it preserves the Ash actor, tenant, and authorization context"

    assert html =~ "policies and validations run unchanged",
           "the ash_jido package page must state Ash policies and validations run unchanged"

    # Enforce side: the host Ash application owns the authorization decisions
    # and policies; AshJido does not define or enforce them.
    assert html =~ "host Ash application",
           "the ash_jido package page must name the host Ash application as the enforcer"

    assert html =~ "authorization decisions",
           "the ash_jido package page must state authorization decisions are owned by the host Ash application"

    # Boundary: the page states the preserve/enforce split in those terms.
    assert html =~ "AshJido preserves what the host Ash application enforces",
           "the ash_jido package page must state the preserve/enforce boundary"
  end

  # Direct expression of the E09-T44 contract: the jido_signal page documents
  # Signal Journal storage choices and durability. It must identify, tied to
  # released behavior, the default adapter, the durable adapters, what happens
  # to recorded history across a restart, the retention story, and the limits on
  # replay. Mirrors the canonical framing on the Journal Retention, Access, and
  # Deletion operations page so the package page and the operations page agree.
  test "documents Signal Journal storage choices and durability (jido-e09-t44)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido_signal")

    # The dedicated storage and durability block is present on the page.
    assert html =~ "Signal Journal storage and durability",
           "the jido_signal page must surface a Signal Journal storage and durability block"

    # Default adapter: names InMemory and states it is not durable.
    assert html =~ "InMemory",
           "the jido_signal page must name the default Journal adapter (InMemory)"

    assert html =~ "not durable",
           "the jido_signal page must state the default Journal adapter is not durable"

    # Durable adapters: names both shipped durable backends and their scope.
    assert html =~ "ETS",
           "the jido_signal page must name the ETS durable Journal adapter"

    assert html =~ "Mnesia",
           "the jido_signal page must name the Mnesia durable Journal adapter"

    assert html =~ "node restart",
           "the jido_signal page must state Mnesia keeps history across a node restart"

    # Restart behavior: states recorded history is lost over the default adapter.
    assert html =~ "gone after a restart",
           "the jido_signal page must state recorded history is lost over the default adapter on restart"

    # Retention: states no retention policy ships and retention is application-owned.
    assert html =~ "No retention policy",
           "the jido_signal page must state no retention policy ships with the Journal"

    assert html =~ "retention is application-owned",
           "the jido_signal page must state retention is application-owned"

    # Replay limits: bounds replay to the in-memory Bus log with a batch cap.
    assert html =~ "batch_size",
           "the jido_signal page must name the replay batch-size limit"

    assert html =~ "100,000",
           "the jido_signal page must state the Bus log size bound"

    assert html =~ "not durable across a Bus restart",
           "the jido_signal page must state replay is not durable across a Bus restart"
  end

  # Direct expression of the E09-T45 contract: the three operational-control
  # roles — core observation (jido core), OpenTelemetry export (jido_otel), and
  # audit history (jido_signal) — must not use interchangeable language on their
  # package pages. Each page names its own role with distinct vocabulary and
  # states the boundary to the other two, mirroring the canonical framing on the
  # Telemetry and Traces operations page ("jido_otel is an exporter, not the
  # source of observation"; "an audit trail is a separate, application-owned
  # duty"). The old interchangeable phrases — jido_otel calling its output "for
  # observation" and both jido_otel and jido_signal opening a limitation with the
  # identical "Does not make telemetry tamper-evident" — must be gone.
  test "separates core observation, jido_otel export, and audit history with distinct language (jido-e09-t45)", %{conn: conn} do
    # Core observation (jido core): names itself the source of observation and
    # states export and audit as separate packages.
    {:ok, _view, jido_html} = live(conn, "/ecosystem/jido")

    assert jido_html =~ "source of core observation",
           "the jido page must name core observation as the source role"

    assert jido_html =~ "the separate jido_otel package",
           "the jido page must separate core observation from the jido_otel export role"

    assert jido_html =~ "Does not retain audit history",
           "the jido page must state the audit-history boundary"

    assert jido_html =~ "the separate jido_signal Signal Journal",
           "the jido page must separate core observation from the jido_signal audit role"

    # OpenTelemetry export (jido_otel): names itself the exporter, explicitly
    # not the source of observation (that is jido core), and not an audit record
    # (that is jido_signal). The old "for observation, not an audit record" and
    # "Does not make telemetry tamper-evident" interchangeable phrases are gone.
    {:ok, _view, otel_html} = live(conn, "/ecosystem/jido_otel")

    assert otel_html =~ "OpenTelemetry export",
           "the jido_otel page must name its role as export"

    assert otel_html =~ "exporter, not the source of observation",
           "the jido_otel page must separate the export role from the core-observation role"

    assert otel_html =~ "emitted by jido core",
           "the jido_otel page must attribute the events it exports to jido core"

    assert otel_html =~ "Does not serve as an audit record",
           "the jido_otel page must state the audit boundary"

    assert otel_html =~ "the separate jido_signal Signal Journal",
           "the jido_otel page must separate the export role from the jido_signal audit role"

    refute otel_html =~ "exported spans are for observation",
           "the jido_otel page must not describe its export output as observation (that is the jido core role)"

    refute otel_html =~ "Does not make telemetry tamper-evident",
           "the jido_otel page must not reuse the jido_signal limitation opener"

    # Audit history (jido_signal): names the Journal as a durable, replayable
    # record and attributes trace context to core observation, not the record.
    # The old "Does not make telemetry tamper-evident" opener — interchangeable
    # with jido_otel — is gone, replaced by the precise audit boundary.
    {:ok, _view, signal_html} = live(conn, "/ecosystem/jido_signal")

    assert signal_html =~ "durable, replayable record",
           "the jido_signal page must name the Journal's audit-history role"

    assert signal_html =~ "correlation metadata from core observation",
           "the jido_signal page must attribute trace context to core observation, not the audit record"

    assert signal_html =~ "not a tamper-evident ledger",
           "the jido_signal page must state the tamper-evidence boundary"

    assert signal_html =~ "correlation metadata, not a verified caller",
           "the jido_signal page must state the audit-identity boundary"

    refute signal_html =~ "Does not make telemetry tamper-evident",
           "the jido_signal page must not reuse the jido_otel limitation opener"

    # The two export/audit pages no longer share an interchangeable limitation
    # opener — their openers are now distinct.
    refute otel_html =~ "Does not prove tamper-evidence or authenticated audit identity",
           "the jido_otel page must not reuse the jido_signal audit-identity opener"

    refute signal_html =~ "Does not serve as an audit record",
           "the jido_signal page must not reuse the jido_otel audit-record opener"
  end

  test "states the control surface is not documented when neither field is set (jido-e09-t41)", %{conn: conn} do
    # jido_chat has no documented control surface, so the page must be explicit
    # about the gap rather than silent.
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat")

    assert html =~ "OPERATIONAL CONTROL"
    assert html =~ "control surface not documented"
    refute html =~ "Control surface it supplies"
    refute html =~ "Control result it does not supply"
  end

  # Direct expression of the E09-T41 contract: every public package page renders
  # the OPERATIONAL CONTROL section and either states the control surface it
  # supplies / the result it does not supply, or is explicit that the control
  # surface is not documented yet. Uses a disconnected GET render (still runs
  # mount + render) so all public packages can be checked.
  @tag timeout: 120_000
  test "every public package states its control surface or flags it undocumented (jido-e09-t41)", %{conn: conn} do
    for package <- AgentJido.Ecosystem.public_packages() do
      html = conn |> get("/ecosystem/#{package.id}") |> html_response(200)

      assert html =~ "OPERATIONAL CONTROL",
             "package #{package.id} is missing the OPERATIONAL CONTROL section"

      states_documented = html =~ "Control surface it supplies" or html =~ "Control result it does not supply"
      states_undocumented = html =~ "control surface not documented"

      assert states_documented != states_undocumented,
             "package #{package.id} must either state its control surface/result or flag it undocumented " <>
               "(documented=#{states_documented}, undocumented=#{states_undocumented})"
    end
  end

  # Direct expression of the E09-T47 contract: each control package is marked
  # with its released version, support level, and proof, and the production claim
  # is gated so experimental or unreleased work cannot support a general
  # production claim. ash_jido is unreleased (GitHub-only), so its
  # operational-control claims must state they do not support a general
  # production claim; jido is released and stable, so its claims are backed by
  # the released and tested package.
  test "marks the released version, support level, and evidence for each control package (jido-e09-t47)", %{conn: conn} do
    # ash_jido is unreleased — its control claims cannot support a general
    # production claim.
    {:ok, _view, ash_html} = live(conn, "/ecosystem/ash_jido")

    assert ash_html =~ "Release basis",
           "the ash_jido page must mark the release basis for its control claims"

    assert ash_html =~ "Unreleased (GitHub-only)",
           "the ash_jido page must mark its released version (unreleased)"

    assert ash_html =~ "support",
           "the ash_jido page must mark its support level"

    assert ash_html =~ "proof",
           "the ash_jido page must mark the evidence for its control claims"

    assert ash_html =~ "do not support a general production claim",
           "the ash_jido page must gate its control claims — it is unreleased"

    # jido is released and stable — its control claims are backed by the released
    # and tested package, and must not carry the gating phrase.
    {:ok, _view, jido_html} = live(conn, "/ecosystem/jido")

    assert jido_html =~ "Release basis",
           "the jido page must mark the release basis for its control claims"

    assert jido_html =~ ~r/Released \d+\.\d+/,
           "the jido page must mark its released version"

    assert jido_html =~ "backed by the released and tested package",
           "the jido page must back its control claims — it is released and stable"

    refute jido_html =~ "do not support a general production claim",
           "the jido page must not gate its control claims — it is released and stable"
  end

  # Direct expression of the E09-T47 contract: every public package that
  # documents an operational-control surface is marked with its released version,
  # support level, and proof, and the production claim is gated so experimental
  # or unreleased work cannot support a general production claim. A package
  # published to Hex at stable or beta support backs the claim; anything
  # experimental or unreleased states it does not support a general production
  # claim yet. Uses a disconnected GET render (still runs mount + render) so all
  # control packages can be checked.
  @tag timeout: 120_000
  test "every control package marks release basis and gates production claims (jido-e09-t47)", %{conn: conn} do
    control_packages =
      AgentJido.Ecosystem.public_packages()
      |> Enum.filter(fn p -> p.control_capabilities != [] or p.control_limitations != [] end)

    assert control_packages != [],
           "expected at least one package with a documented control surface"

    for package <- control_packages do
      html = conn |> get("/ecosystem/#{package.id}") |> html_response(200)

      # Every control package marks the release basis with a released version,
      # a support level, and the evidence (proof).
      assert html =~ "Release basis",
             "control package #{package.id} must mark the release basis"

      assert html =~ "support",
             "control package #{package.id} must mark its support level"

      assert html =~ "proof",
             "control package #{package.id} must mark the evidence for its control claims"

      # Experimental or unreleased control packages cannot support a general
      # production claim; released, stable-or-beta packages back the claim.
      published? = Regex.match?(~r/^\d+\./, package.hex_status || "")
      backs_production = published? and package.support_level in [:stable, :beta]

      if backs_production do
        assert html =~ "backed by the released and tested package",
               "released control package #{package.id} must back its control claims"

        refute html =~ "do not support a general production claim",
               "released control package #{package.id} must not gate its control claims"
      else
        assert html =~ "do not support a general production claim",
               "experimental or unreleased control package #{package.id} must gate its control claims"
      end
    end
  end

  test "renders curated seo metadata and structured data for package pages", %{conn: conn} do
    html =
      conn
      |> get("/ecosystem/jido")
      |> html_response(200)

    assert html =~ "Jido Elixir agent framework for long-running multi-agent systems"
    assert html =~ "Jido: Elixir agent framework on OTP"
    assert html =~ "Build long-running, multi-agent Elixir systems with a deterministic runtime, explicit directives, and BEAM-native supervision."

    assert html =~
             ~s(<meta name="keywords" content="jido, elixir agent framework, otp agents, multi-agent systems, beam agent runtime, Jido.Agent, Jido.AgentServer")

    assert html =~ ~s(<link rel="canonical" href="http://localhost:4002/ecosystem/jido")
    assert html =~ ~s("SoftwareSourceCode")
    assert html =~ ~s("BreadcrumbList")
    assert html =~ ~s("FAQPage")
  end
end
