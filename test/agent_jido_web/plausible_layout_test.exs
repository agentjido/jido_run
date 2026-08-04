defmodule AgentJidoWeb.PlausibleLayoutTest do
  use AgentJidoWeb.ConnCase, async: false

  setup do
    original_value = Application.get_env(:agent_jido, :enable_analytics)
    Application.put_env(:agent_jido, :enable_analytics, true)

    on_exit(fn ->
      Application.put_env(:agent_jido, :enable_analytics, original_value)
    end)

    :ok
  end

  test "loads Plausible through first-party paths", %{conn: conn} do
    html = conn |> get("/") |> html_response(200)

    assert html =~ ~s(src="/_q/s.js")
    assert html =~ ~s|plausible.init({endpoint: "/_q/e"})|
    refute html =~ "https://plausible.io/js/"
    refute html =~ "https://plausible.io/api/event"
  end
end
