defmodule AgentJidoWeb.JidoExamplesLive do
  @moduledoc """
  Examples index page, driven by NimblePublisher content from priv/examples/.
  """

  use AgentJidoWeb, :live_view

  import AgentJidoWeb.Jido.MarketingLayouts

  alias AgentJido.Examples

  @category_order [:core, :ai, :production]

  # Home use-case cards (jido-e04-t21) deep-link to /examples?use_case=<slug>.
  # Each entry scopes the index to examples whose tags signal that user job, so
  # every card reaches a distinct destination instead of all collapsing onto the
  # unfiltered index. Use cases without a published example yet render an honest
  # scoped empty state until the matching public example lands (jido-e08-t24…t29).
  @home_use_cases %{
    "coding" => %{label: "Coding agents", tags: ~w(coding)},
    "research" => %{label: "Research and synthesis", tags: ~w(runic research)},
    "documents" => %{label: "Document processing", tags: ~w(documents document policy)},
    "support" => %{label: "Customer support", tags: ~w(support ticket triage)},
    "devops" => %{
      label: "DevOps and monitoring",
      tags: ~w(ops-governance operations observability telemetry incident supervision reliability restart)
    },
    "data-pipelines" => %{label: "Data pipelines", tags: ~w(data pipeline sql etl)}
  }

  @impl true
  def mount(_params, session, socket) do
    admin_can_toggle_drafts = Map.get(session, "examples_include_drafts", false)

    {:ok,
     socket
     |> assign(:page_title, "Jido Examples")
     |> assign(
       :meta_description,
       "Run practical examples that show how to design, coordinate, and operate agents with Jido."
     )
     |> assign(:admin_can_toggle_drafts, admin_can_toggle_drafts)
     |> assign(:default_include_drafts, admin_can_toggle_drafts)
     |> assign(:include_drafts, admin_can_toggle_drafts)
     |> assign(:use_case, nil)
     |> assign(:current_params, %{})
     |> assign(:examples, [])
     |> assign(:grouped_examples, %{})
     |> assign(:categories_to_render, [])
     |> assign(:match_count, 0)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    include_drafts =
      resolve_include_drafts(
        params,
        socket.assigns.admin_can_toggle_drafts,
        socket.assigns.default_include_drafts
      )

    use_case = resolve_use_case(params)

    {:noreply,
     socket
     |> assign(:current_params, params)
     |> assign(:include_drafts, include_drafts)
     |> assign(:use_case, use_case)
     |> load_examples()}
  end

  @impl true
  def handle_event("toggle_drafts", _params, socket) do
    if socket.assigns.admin_can_toggle_drafts do
      next_include_drafts = not socket.assigns.include_drafts

      next_params =
        socket.assigns.current_params
        |> Map.delete("hide_drafts")
        |> maybe_put_hide_drafts(next_include_drafts)

      {:noreply,
       socket
       |> push_patch(to: examples_index_path(next_params))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.marketing_layout
      current_path="/examples"
      current_scope={@current_scope}
      analytics_identity={@analytics_identity}
    >
      <div class="container max-w-[1000px] mx-auto px-6 py-12">
        <%!-- Hero --%>
        <section class="text-center mb-12">
          <div class="inline-block px-4 py-2 rounded mb-5 bg-primary/10 border border-primary/30">
            <span class="text-primary text-[11px] font-semibold tracking-widest uppercase">
              EXAMPLES & TUTORIALS
            </span>
          </div>
          <h1 class="text-4xl font-bold mb-4">
            <%= if @use_case do %>
              {@use_case.label}
            <% else %>
              Learn by <span class="text-primary">building</span>
            <% end %>
          </h1>
          <p class="copy-measure-wide mx-auto text-lg text-muted-foreground">
            <%= if @use_case do %>
              Runnable examples for {@use_case.label}.
              <.link navigate="/examples" class="text-primary hover:underline font-semibold">Browse all examples →</.link>
            <% else %>
              Interactive examples with source code, explanation, and live demos.
              AI/browser demos can run in deterministic simulated mode so no external model calls are required.
            <% end %>
          </p>
          <div :if={@admin_can_toggle_drafts} class="mt-4 flex items-center justify-center gap-3">
            <span class="text-[10px] px-2 py-0.5 rounded font-semibold uppercase bg-accent-yellow/10 border border-accent-yellow/30 text-accent-yellow">
              {if @include_drafts, do: "admin preview", else: "drafts hidden"}
            </span>
            <button
              id="toggle-drafts-button"
              phx-click="toggle_drafts"
              type="button"
              class="text-[11px] px-3 py-1 rounded border border-border bg-elevated text-muted-foreground hover:text-foreground hover:border-primary/30 transition-colors"
            >
              {if @include_drafts, do: "Hide Draft Examples", else: "Show Draft Examples"}
            </button>
          </div>
        </section>

        <%!-- Empty state --%>
        <section :if={@examples == []} class="mb-16 rounded-lg border border-border bg-card p-10 text-center">
          <h2 class="text-xl font-bold mb-2">
            <%= if @use_case do %>
              No public examples for {@use_case.label} yet
            <% else %>
              No examples available yet
            <% end %>
          </h2>
          <p class="text-sm text-muted-foreground mb-4">
            <%= if @use_case do %>
              A runnable example for this use case is on the way. Browse the full catalog in the meantime.
            <% else %>
              Check back soon for more runnable examples.
            <% end %>
          </p>
          <.link :if={@use_case} navigate="/examples" class="text-primary hover:underline text-[13px] font-semibold">
            Browse all examples →
          </.link>
        </section>

        <%= for category <- @categories_to_render do %>
          <section class="mb-16">
            <div class="flex justify-between items-center mb-6">
              <span class="text-sm font-bold tracking-wider">{category_heading(category)}</span>
              <span class={"text-[10px] px-2 py-1 rounded font-semibold #{category_badge_class(category)}"}>
                {String.upcase(Atom.to_string(category))}
              </span>
            </div>
            <div class="grid md:grid-cols-2 gap-4">
              <%= for example <- Map.get(@grouped_examples, category, []) do %>
                <.example_card example={example} />
              <% end %>
            </div>
          </section>
        <% end %>

        <%!-- CTA --%>
        <section>
          <div class="cta-glow rounded-lg p-12 text-center">
            <h2 class="text-2xl font-bold mb-3">Want to contribute an example?</h2>
            <p class="text-secondary-foreground text-sm mb-6">
              We welcome community contributions. Check out our contributing guide.
            </p>
            <a
              href="https://github.com/agentjido/jido/blob/main/CONTRIBUTING.md"
              target="_blank"
              rel="noopener noreferrer"
              class="bg-primary text-primary-foreground hover:bg-primary/90 text-[13px] font-bold px-7 py-3 rounded transition-colors inline-block"
            >
              CONTRIBUTING GUIDE →
            </a>
          </div>
        </section>
      </div>
    </.marketing_layout>
    """
  end

  attr :example, :map, required: true

  defp example_card(assigns) do
    ~H"""
    <.link navigate={~p"/examples/#{@example.slug}"} class="feature-card group block">
      <div class="flex justify-end items-start mb-3">
        <div class="flex gap-2">
          <span class={"text-[10px] px-2 py-0.5 rounded font-semibold uppercase #{difficulty_badge(@example.difficulty)}"}>
            {@example.difficulty}
          </span>
          <span
            :if={@example.demo_mode == :simulated}
            class="text-[10px] px-2 py-0.5 rounded font-semibold uppercase bg-accent-cyan/10 text-accent-cyan border border-accent-cyan/30"
          >
            simulated
          </span>
        </div>
      </div>
      <h3 class="font-bold text-[15px] mb-2 group-hover:text-primary transition-colors">
        {@example.title}
      </h3>
      <p class="text-muted-foreground text-xs leading-relaxed mb-4">{@example.description}</p>
      <div class="flex gap-2 flex-wrap mb-2">
        <span class="text-[10px] px-2 py-0.5 rounded bg-primary/10 border border-primary/20 text-primary">
          {labelize(@example.scenario_cluster)}
        </span>
        <span class="text-[10px] px-2 py-0.5 rounded bg-elevated text-muted-foreground">
          {labelize(@example.capability_theme)}
        </span>
      </div>
      <div class="flex gap-2 flex-wrap">
        <%= for tag <- Enum.take(List.wrap(@example.tags), 3) do %>
          <span class="text-[10px] px-2 py-0.5 rounded bg-elevated text-muted-foreground">
            {tag}
          </span>
        <% end %>
      </div>
    </.link>
    """
  end

  defp load_examples(socket) do
    opts = if socket.assigns.include_drafts, do: [include_drafts: true], else: []

    examples =
      opts
      |> Examples.all_examples()
      |> filter_by_use_case(socket.assigns.use_case)

    grouped_examples = Enum.group_by(examples, & &1.category)

    categories_to_render =
      @category_order
      |> Enum.filter(&(Map.get(grouped_examples, &1, []) != []))

    socket
    |> assign(:examples, examples)
    |> assign(:grouped_examples, grouped_examples)
    |> assign(:categories_to_render, categories_to_render)
    |> assign(:match_count, length(examples))
  end

  # Scopes the example list to a home use case (jido-e04-t21). Examples are
  # matched when they carry any tag that signals the use case. An unknown or
  # missing use case leaves the list unfiltered.
  defp filter_by_use_case(examples, nil), do: examples

  defp filter_by_use_case(examples, %{tags: tags}) do
    wanted = MapSet.new(tags, &normalize_tag/1)

    Enum.filter(examples, fn example ->
      example_tags =
        example
        |> Map.get(:tags, [])
        |> List.wrap()
        |> Enum.map(&normalize_tag/1)
        |> MapSet.new()

      not MapSet.disjoint?(wanted, example_tags)
    end)
  end

  defp resolve_use_case(params) do
    case Map.get(params, "use_case") do
      nil -> nil
      slug -> Map.get(@home_use_cases, to_string(slug))
    end
  end

  defp normalize_tag(tag) do
    tag |> to_string() |> String.downcase() |> String.replace("_", "-") |> String.trim()
  end

  defp labelize(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp labelize(value), do: to_string(value)

  defp category_heading(:core), do: "Getting Started"
  defp category_heading(:ai), do: "AI-Powered Agents"
  defp category_heading(:production), do: "Production Patterns"
  defp category_heading(_), do: "Examples"

  defp category_badge_class(:core), do: "bg-accent-cyan/10 border border-accent-cyan/30 text-accent-cyan"
  defp category_badge_class(:ai), do: "bg-accent-yellow/10 border border-accent-yellow/30 text-accent-yellow"
  defp category_badge_class(:production), do: "bg-primary/10 border border-primary/30 text-primary"
  defp category_badge_class(_), do: "bg-elevated border border-border text-muted-foreground"

  defp difficulty_badge(:beginner), do: "bg-accent-green/10 text-accent-green"
  defp difficulty_badge(:intermediate), do: "bg-accent-yellow/10 text-accent-yellow"
  defp difficulty_badge(:advanced), do: "bg-accent-red/10 text-accent-red"
  defp difficulty_badge(_), do: "bg-elevated text-muted-foreground"

  defp resolve_include_drafts(_params, false, _default_include_drafts), do: false

  defp resolve_include_drafts(params, true, default_include_drafts) do
    default_include_drafts and not hide_drafts?(params)
  end

  defp hide_drafts?(params) when is_map(params) do
    params
    |> Map.get("hide_drafts")
    |> truthy_param?()
  end

  defp truthy_param?(value) when value in [true, 1], do: true
  defp truthy_param?(value) when value in [false, nil, 0], do: false

  defp truthy_param?(value) when is_binary(value) do
    String.downcase(String.trim(value)) in ["1", "true", "yes", "on"]
  end

  defp truthy_param?(_value), do: false

  defp maybe_put_hide_drafts(params, true), do: params
  defp maybe_put_hide_drafts(params, false), do: Map.put(params, "hide_drafts", "true")

  defp examples_index_path(params) when is_map(params) do
    case Enum.reject(params, fn {_key, value} -> is_nil(value) or value == "" end) |> Map.new() do
      filtered when map_size(filtered) == 0 -> ~p"/examples"
      filtered -> ~p"/examples?#{filtered}"
    end
  end
end
