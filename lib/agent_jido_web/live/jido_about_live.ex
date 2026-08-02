defmodule AgentJidoWeb.JidoAboutLive do
  @moduledoc """
  Placeholder about page.
  """
  use AgentJidoWeb, :live_view

  import AgentJidoWeb.Jido.MarketingLayouts

  alias AgentJidoWeb.StructuredData

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "About Jido",
       meta_description: "About the Jido project.",
       structured_data: [StructuredData.breadcrumb_list([{"Jido", "/"}, {"About", "/about"}])]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.marketing_layout
      current_path="/about"
      current_scope={@current_scope}
      analytics_identity={@analytics_identity}
    >
      <div class="container max-w-[1000px] mx-auto px-6 py-16">
        <h1 class="text-3xl font-bold tracking-tight">About</h1>
      </div>
    </.marketing_layout>
    """
  end
end
