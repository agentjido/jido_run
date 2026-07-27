defmodule AgentJidoWeb.Jido.HomeSections do
  @moduledoc """
  Reusable home-page specific section components.
  """
  use AgentJidoWeb, :html

  attr :id, :string, default: "cta"
  attr :section_class, :string, default: "mb-16 opacity-0"
  attr :phx_hook, :string, default: "ScrollReveal"

  attr :title, :string, default: "Build your first agent"

  # No duration: per specs/benchmark-methodology.md (E11-T19) an onboarding-time
  # claim needs a measured median before it can carry a number, so this states
  # the tested outcome instead (jido-e11-t20).
  attr :description, :string, default: "Go from zero to a running, supervised agent."

  attr :primary_label, :string, default: "GET BUILDING →"
  attr :primary_path, :string, default: "/docs/getting-started"
  attr :secondary_label, :string, default: "SEE EXAMPLES"
  attr :secondary_path, :string, default: "/examples"

  @doc """
  Marketing CTA used on the home page, extracted for reuse on additional pages.
  """
  def build_first_agent_cta(assigns) do
    ~H"""
    <section id={@id} class={["home-build-agent-cta", @section_class]} phx-hook={@phx_hook}>
      <div id="home-build-agent-cta" class="home-build-agent-shell cta-glow rounded-lg">
        <h2 class="home-build-agent-title">{@title}</h2>
        <p class="home-build-agent-copy">{@description}</p>

        <div class="home-build-agent-actions">
          <.link
            navigate={@primary_path}
            class="home-build-agent-primary"
            data-analytics-event="cta_clicked"
            data-analytics-source="home"
            data-analytics-channel="home_build_cta"
            data-analytics-section-id="build-first-agent"
            data-analytics-target-url={@primary_path}
          >
            {@primary_label}
          </.link>
          <.link navigate={@secondary_path} class="home-build-agent-secondary">
            {@secondary_label}
          </.link>
        </div>
      </div>
    </section>
    """
  end
end
