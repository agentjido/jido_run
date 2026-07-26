defmodule AgentJidoWeb.AnalyticsEventControllerTest do
  use AgentJidoWeb.ConnCase, async: false

  import Ecto.Query
  import AgentJido.AccountsFixtures

  alias AgentJido.Analytics.AnalyticsEvent
  alias AgentJido.Repo

  test "accepts valid analytics event", %{conn: conn} do
    conn =
      post(conn, ~p"/analytics/events", %{
        "event" => "code_copied",
        "properties" => %{
          "source" => "docs",
          "channel" => "copy_button",
          "path" => "/docs/concepts/agents",
          "metadata" => %{"surface" => "docs_page"}
        }
      })

    assert json_response(conn, 202)["ok"]

    event = Repo.one(from(e in AnalyticsEvent, order_by: [desc: e.inserted_at], limit: 1))
    assert event.event == "code_copied"
    assert event.path == "/docs/concepts/agents"
    assert event.user_id == nil
    assert event.metadata["surface"] == "docs_page"
  end

  test "accepts the home-to-onboarding CTA click event (jido-e12-t21)", %{conn: conn} do
    conn =
      post(conn, ~p"/analytics/events", %{
        "event" => "cta_clicked",
        "properties" => %{
          "source" => "home",
          "channel" => "home_hero",
          "path" => "/",
          "section_id" => "hero",
          "target_url" => "/docs/getting-started"
        }
      })

    assert json_response(conn, 202)["ok"]

    event = Repo.one(from(e in AnalyticsEvent, order_by: [desc: e.inserted_at], limit: 1))
    assert event.event == "cta_clicked"
    assert event.source == "home"
    assert event.section_id == "hero"
    assert event.target_url == "/docs/getting-started"
  end

  test "accepts the first core Agent success event (jido-e12-t23)", %{conn: conn} do
    conn =
      post(conn, ~p"/analytics/events", %{
        "event" => "agent_run_succeeded",
        "properties" => %{
          "source" => "example",
          "channel" => "interactive_demo",
          "path" => "/examples/counter-agent",
          "section_id" => "counter-agent",
          "target_url" => "/examples/counter-agent",
          "metadata" => %{"surface" => "example_demo", "example" => "counter-agent", "action" => "IncrementAction"}
        }
      })

    assert json_response(conn, 202)["ok"]

    event = Repo.one(from(e in AnalyticsEvent, order_by: [desc: e.inserted_at], limit: 1))
    assert event.event == "agent_run_succeeded"
    assert event.source == "example"
    assert event.channel == "interactive_demo"
    assert event.section_id == "counter-agent"
    assert event.metadata["example"] == "counter-agent"
  end

  test "rejects invalid event names", %{conn: conn} do
    conn =
      post(conn, ~p"/analytics/events", %{
        "event" => "unknown_event",
        "properties" => %{
          "source" => "docs",
          "channel" => "copy_button",
          "path" => "/docs"
        }
      })

    response = json_response(conn, 422)
    assert response["ok"] == false
  end

  test "ignores client-supplied user_id and uses authenticated scope user", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    conn =
      post(conn, ~p"/analytics/events", %{
        "event" => "livebook_run_clicked",
        "properties" => %{
          "source" => "docs",
          "channel" => "quick_links",
          "path" => "/docs/concepts/agents",
          "target_url" => "https://example.com/livebook",
          "user_id" => Ecto.UUID.generate()
        }
      })

    assert json_response(conn, 202)["ok"]

    event = Repo.one(from(e in AnalyticsEvent, order_by: [desc: e.inserted_at], limit: 1))
    assert event.event == "livebook_run_clicked"
    assert event.user_id == user.id
  end

  test "accepts admin events but does not persist them", %{conn: conn} do
    admin = admin_user_fixture()
    conn = log_in_user(conn, admin)
    before_count = Repo.aggregate(AnalyticsEvent, :count, :id)

    conn =
      post(conn, ~p"/analytics/events", %{
        "event" => "code_copied",
        "properties" => %{
          "source" => "docs",
          "channel" => "copy_button",
          "path" => "/docs/concepts/agents",
          "metadata" => %{"surface" => "docs_page"}
        }
      })

    assert json_response(conn, 202)["ok"]
    assert Repo.aggregate(AnalyticsEvent, :count, :id) == before_count
  end
end
