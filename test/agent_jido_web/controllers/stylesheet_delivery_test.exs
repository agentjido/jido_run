defmodule AgentJidoWeb.StylesheetDeliveryTest do
  use AgentJidoWeb.ConnCase, async: true

  test "homepage inlines critical CSS and loads the full stylesheet without blocking", %{conn: conn} do
    document =
      conn
      |> get("/")
      |> html_response(200)
      |> Floki.parse_document!()

    assert [{"style", _, [critical_css]}] = Floki.find(document, "style[data-home-critical-css]")
    assert critical_css =~ ".font-mono"
    assert critical_css =~ "#home-page .home-eyebrow-label"
    assert byte_size(critical_css) < 30_000

    assert [stylesheet] = Floki.find(document, "link#app-stylesheet")
    assert attribute(stylesheet, "rel") == "stylesheet"
    assert attribute(stylesheet, "href") == "/assets/app.css"
    assert attribute(stylesheet, "media") == "print"

    assert [fallback] = Floki.find(document, ~s(noscript link[rel="stylesheet"]))
    assert attribute(fallback, "href") == "/assets/app.css"
  end

  test "other routes keep the blocking stylesheet", %{conn: conn} do
    document =
      conn
      |> get("/features")
      |> html_response(200)
      |> Floki.parse_document!()

    assert Floki.find(document, "style[data-home-critical-css]") == []
    assert Floki.find(document, "link#app-stylesheet") == []

    assert Enum.any?(Floki.find(document, ~s(link[rel="stylesheet"])), fn link ->
             attribute(link, "href") == "/assets/app.css" and is_nil(attribute(link, "media"))
           end)
  end

  defp attribute({_, attributes, _}, name) do
    case List.keyfind(attributes, name, 0) do
      {^name, value} -> value
      nil -> nil
    end
  end
end
