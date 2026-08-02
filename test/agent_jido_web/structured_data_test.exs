defmodule AgentJidoWeb.StructuredDataTest do
  use ExUnit.Case, async: true

  alias AgentJido.Pages
  alias AgentJidoWeb.StructuredData

  test "builds a valid breadcrumb list with absolute URLs" do
    schema =
      StructuredData.breadcrumb_list([
        {"Jido", "/"},
        {"Examples", "/examples"},
        {"Counter Agent", "/examples/counter-agent"}
      ])

    assert schema["@context"] == "https://schema.org"
    assert schema["@type"] == "BreadcrumbList"

    assert schema["itemListElement"] == [
             %{
               "@type" => "ListItem",
               "position" => 1,
               "name" => "Jido",
               "item" => AgentJidoWeb.Endpoint.url() <> "/"
             },
             %{
               "@type" => "ListItem",
               "position" => 2,
               "name" => "Examples",
               "item" => AgentJidoWeb.Endpoint.url() <> "/examples"
             },
             %{
               "@type" => "ListItem",
               "position" => 3,
               "name" => "Counter Agent",
               "item" => AgentJidoWeb.Endpoint.url() <> "/examples/counter-agent"
             }
           ]
  end

  test "uses published documentation titles for semantic ancestors" do
    page = Pages.get_page_by_path!("/docs/learn/agent-fundamentals")
    schema = StructuredData.page_breadcrumb_list(page)

    assert Enum.map(schema["itemListElement"], & &1["name"]) == [
             "Jido",
             "Documentation",
             "Learn",
             "Agent Fundamentals on the BEAM"
           ]
  end

  test "uses the public category landing page for feature pages" do
    page = Pages.get_page_by_path!("/features/how-agents-work")
    schema = StructuredData.page_breadcrumb_list(page)

    assert Enum.map(schema["itemListElement"], & &1["name"]) == [
             "Jido",
             "How Jido Works",
             page.title
           ]
  end

  test "rejects incomplete breadcrumb lists" do
    assert_raise ArgumentError, ~r/requires at least two items/, fn ->
      StructuredData.breadcrumb_list([{"Jido", "/"}])
    end
  end

  test "rejects invalid names and paths" do
    assert_raise ArgumentError, ~r/names must not be empty/, fn ->
      StructuredData.breadcrumb_list([{"Jido", "/"}, {" ", "/examples"}])
    end

    assert_raise ArgumentError, ~r/paths must start/, fn ->
      StructuredData.breadcrumb_list([{"Jido", "/"}, {"Examples", "examples"}])
    end
  end
end
