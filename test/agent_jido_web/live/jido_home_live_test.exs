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

  defp ensure_started(app) do
    case Application.ensure_all_started(app) do
      {:ok, _apps} -> :ok
      {:error, {:already_started, _app}} -> :ok
      {:error, reason} -> raise "failed to start #{inspect(app)}: #{inspect(reason)}"
    end
  end
end
