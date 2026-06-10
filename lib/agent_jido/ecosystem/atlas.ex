defmodule AgentJido.Ecosystem.Atlas do
  @moduledoc """
  Contributor-facing Atlas rendering backed by ecosystem package metadata.
  """

  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.SupportLevel

  @category_specs [
    {:core, "Core"},
    {:ai, "AI"},
    {:runtime, "Runtime"},
    {:tools, "Tools"},
    {:integrations, "Integrations"}
  ]

  @facet_specs %{
    core: [{:primitives, "Primitives"}],
    ai: [
      {:reasoning_models, "Reasoning & Models"},
      {:memory, "Memory"},
      {:evaluation, "Evaluation"},
      {:optimization, "Optimization"}
    ],
    runtime: [
      {:harness, "Harness"},
      {:distributed, "Distributed"},
      {:applications, "Applications"}
    ],
    tools: [
      {:workflow, "Workflow"},
      {:workspace, "Workspace"},
      {:automation, "Automation"},
      {:developer_ux, "Developer UX"}
    ],
    integrations: [
      {:framework_bridges, "Framework Bridges"},
      {:chat, "Chat"},
      {:provider_adapters, "Provider Adapters"},
      {:protocols, "Protocols"},
      {:observability, "Observability"},
      {:storage, "Storage"}
    ]
  }

  @facet_labels @facet_specs |> Enum.flat_map(fn {_category, specs} -> specs end) |> Map.new()

  @category_order @category_specs
                  |> Enum.with_index()
                  |> Map.new(fn {{category, _label}, index} -> {category, index} end)

  @facet_order @facet_labels
               |> Enum.with_index()
               |> Map.new(fn {{facet, _label}, index} -> {facet, index} end)

  @atlas_placeholder "{{contributors_ecosystem_atlas_tables}}"

  @doc """
  Placeholder token used by contributor docs pages.
  """
  @spec placeholder() :: String.t()
  def placeholder, do: @atlas_placeholder

  @doc """
  Renders Atlas markdown from the public ecosystem registry.
  """
  @spec render_markdown() :: String.t()
  def render_markdown do
    Ecosystem.public_packages()
    |> Enum.group_by(& &1.category)
    |> Enum.sort_by(fn {category, _packages} -> Map.get(@category_order, category, 999) end)
    |> Enum.map(fn {category, packages} -> render_category(category, packages) end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp render_category(_category, []), do: ""

  defp render_category(category, packages) do
    heading = category_heading(category)
    grouped = group_by_facet(category, packages)

    body =
      if length(grouped) <= 1 do
        grouped
        |> List.first()
        |> case do
          nil -> ""
          {_facet, grouped_packages} -> render_table(grouped_packages)
        end
      else
        Enum.map_join(grouped, "\n\n", fn {facet, grouped_packages} ->
          """
          ### #{facet_heading(facet)}

          #{render_table(grouped_packages)}
          """
          |> String.trim()
        end)
      end

    """
    ## #{heading}

    #{body}
    """
    |> String.trim()
  end

  defp group_by_facet(category, packages) do
    packages
    |> Enum.group_by(&Map.get(&1, :atlas_facet))
    |> Enum.sort_by(fn {facet, grouped_packages} ->
      {
        Map.get(@facet_order, facet, 999),
        grouped_packages |> List.first() |> sort_name()
      }
    end)
    |> Enum.map(fn {facet, grouped_packages} ->
      {facet, Enum.sort_by(grouped_packages, &sort_key(category, &1))}
    end)
  end

  defp render_table(packages) do
    rows =
      Enum.map_join(packages, "\n", &table_row/1)

    """
    | Package | Support | Owner | Release | Purpose |
    | --- | --- | --- | --- | --- |
    #{rows}
    """
    |> String.trim()
  end

  defp table_row(pkg) do
    package = "[#{pkg.title}](/ecosystem/#{pkg.id})"
    support = SupportLevel.label(pkg.support_level) || "Unknown"
    owner = "`#{pkg.tech_lead || "TBD"}`"
    release = "`#{Map.get(pkg, :hex_status) || pkg.version || "unreleased"}`"
    purpose = atlas_purpose(pkg)

    "| #{package} | #{support} | #{owner} | #{release} | #{purpose} |"
  end

  defp atlas_purpose(pkg) do
    pkg.tagline
    |> normalize_text()
    |> Kernel.||(normalize_text(pkg.description))
    |> Kernel.||("Purpose not yet defined.")
    |> String.replace("|", "\\|")
    |> String.replace("\n", " ")
  end

  defp sort_key(category, pkg) do
    {
      Map.get(@category_order, category, 999),
      Map.get(@facet_order, Map.get(pkg, :atlas_facet), 999),
      sort_name(pkg)
    }
  end

  defp sort_name(pkg) do
    normalize_text(pkg.title) || normalize_text(pkg.name) || pkg.id
  end

  defp category_heading(category) do
    case Enum.find(@category_specs, fn {candidate, _label} -> candidate == category end) do
      {_candidate, label} -> label
      nil -> category |> Atom.to_string() |> String.replace("_", " ") |> Phoenix.Naming.humanize()
    end
  end

  defp facet_heading(nil), do: "General"

  defp facet_heading(facet) do
    Map.get(@facet_labels, facet) ||
      facet
      |> Atom.to_string()
      |> String.replace("_", " ")
      |> Phoenix.Naming.humanize()
  end

  defp normalize_text(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp normalize_text(_value), do: nil
end
