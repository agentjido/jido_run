defmodule AgentJidoWeb.JidoGettingStartedLive do
  use AgentJidoWeb, :live_view

  alias AgentJido.ReleaseCatalog
  alias AgentJidoWeb.StructuredData

  import AgentJidoWeb.Jido.MarketingLayouts
  import AgentJidoWeb.Jido.MarketingCode

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Getting Started with Jido",
       meta_description: "Install Jido and build your first Elixir/OTP multi-agent workflow in minutes.",
       structured_data: [StructuredData.breadcrumb_list([{"Jido", "/"}, {"Getting Started", "/getting-started"}])]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.marketing_layout
      current_path="/getting-started"
      current_scope={@current_scope}
      analytics_identity={@analytics_identity}
    >
      <div class="container max-w-[800px] mx-auto px-6">
        <section class="py-16 text-center">
          <h1 class="text-3xl md:text-4xl font-bold mb-4">Getting Started</h1>
          <p class="text-muted-foreground text-sm">
            Build your first AI agent in minutes
          </p>
        </section>

        <section class="pb-16 space-y-12">
          <div>
            <h2 class="text-lg font-bold mb-4 flex items-center gap-3">
              <span class="w-8 h-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-sm">
                1
              </span>
              Add Dependencies
            </h2>
            <.code_block
              title="mix.exs"
              code={deps_snippet()}
            />
          </div>

          <div>
            <h2 class="text-lg font-bold mb-4 flex items-center gap-3">
              <span class="w-8 h-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-sm">
                2
              </span>
              Fetch Dependencies
            </h2>
            <.terminal_command command="mix deps.get" />
          </div>

          <div>
            <h2 class="text-lg font-bold mb-4 flex items-center gap-3">
              <span class="w-8 h-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-sm">
                3
              </span>
              Define Your Weather Agent
            </h2>
            <.code_block
              title="lib/my_app/weather_agent.ex"
              code={agent_snippet()}
            />
          </div>

          <div>
            <h2 class="text-lg font-bold mb-4 flex items-center gap-3">
              <span class="w-8 h-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-sm">
                4
              </span>
              Run It in IEx
            </h2>
            <.code_block
              title="iex -S mix"
              language="elixir"
              code={run_snippet()}
            />
          </div>
        </section>

        <section class="text-center pb-16">
          <.link
            navigate="/docs"
            class="bg-primary text-primary-foreground hover:bg-primary/90 text-xs font-bold px-6 py-3 rounded inline-block transition-colors"
          >
            READ THE DOCS →
          </.link>
        </section>
      </div>
    </.marketing_layout>
    """
  end

  defp deps_snippet do
    ReleaseCatalog.deps_block(["jido", "jido_ai"])
  end

  defp agent_snippet do
    ~S"""
    defmodule MyApp.WeatherAgent do
      use Jido.AI.Agent,
        name: "weather_agent",
        description: "Weather Q&A agent",
        tools: [
          Jido.Tools.Weather,
          Jido.Tools.Weather.ByLocation,
          Jido.Tools.Weather.Forecast,
          Jido.Tools.Weather.CurrentConditions,
          Jido.Tools.Weather.Geocode
        ],
        system_prompt: ~S|You are a weather planning assistant.
        Use weather tools to answer with practical advice.|
    end
    """
  end

  defp run_snippet do
    ~S"""
    iex> {:ok, pid} = Jido.AgentServer.start(agent: MyApp.WeatherAgent)

    iex> {:ok, request} = MyApp.WeatherAgent.ask(pid, "What's the weather in Tokyo?")
    iex> {:ok, answer} = MyApp.WeatherAgent.await(request)

    iex> {:ok, answer} = MyApp.WeatherAgent.ask_sync(pid, "Should I bring an umbrella?")
    """
  end
end
