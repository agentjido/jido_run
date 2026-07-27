defmodule AgentJido.Ecosystem do
  @moduledoc """
  Static package registry for the Jido ecosystem.

  Powered by NimblePublisher, this module compiles Markdown files from
  `priv/ecosystem/` into structured `Package` structs at build time.
  Provides indexed lookups by id, category, tier, and tag, plus
  a computed dependency graph across ecosystem packages.
  """

  alias AgentJido.Ecosystem.Package
  alias AgentJido.Ecosystem.SupportLevel

  # NimblePublisher 2.0 builds entries in Task.async_stream, which cannot
  # lazily compile modules the builder calls. Package.build/3 calls
  # SupportLevel, so force it to compile before extraction.
  Code.ensure_compiled!(AgentJido.Ecosystem.SupportLevel)

  use NimblePublisher,
    build: Package,
    from: Application.app_dir(:agent_jido, "priv/ecosystem/**/*.md"),
    as: :packages,
    highlighters: [:makeup_elixir]

  # Date the registry corpus (priv/ecosystem/*.md) was last reconciled against
  # upstream Hex releases. Used as the per-package `last_synced` fallback so
  # registry freshness is visible on every package page even before a package
  # carries its own explicit sync date. Bump this when the corpus is re-synced.
  @registry_last_synced "2026-07-26"

  @packages Enum.sort_by(@packages, fn p -> {p.tier, p.category, p.name} end)

  @public_packages Enum.filter(@packages, &(&1.visibility == :public))
  @public_packages_by_id Map.new(@public_packages, &{&1.id, &1})

  @packages_by_id Map.new(@packages, &{&1.id, &1})

  @packages_by_category @packages
                        |> Enum.group_by(& &1.category)
                        |> Map.new()

  @packages_by_tier @packages
                    |> Enum.group_by(& &1.tier)
                    |> Map.new()

  @packages_by_support_level @packages
                             |> Enum.group_by(&SupportLevel.normalize(&1.support_level))
                             |> Map.new()

  @public_packages_by_support_level @public_packages
                                    |> Enum.group_by(&SupportLevel.normalize(&1.support_level))
                                    |> Map.new()

  # Priority packages (jido-e12-t18).
  #
  # The packages whose upstream README defines a role the public site documents
  # and must keep aligned. These are the core (tier 1) and official (tier 2)
  # packages the Jido team owns — the E09 exit criterion ("package roles and
  # boundaries match current READMEs") applies to exactly this set. A material
  # upstream README change on a priority package is promoted from an
  # informational review item (jido-e09-t32) to an assigned review task during
  # ecosystem ingestion; community (tier 3) packages only surface the item.
  @priority_tiers [1, 2]

  for tier <- @priority_tiers do
    unless Enum.any?(@packages, &(&1.tier == tier)) do
      raise ArgumentError,
            "No ecosystem packages at tier #{tier}; the priority-package set " <>
              "would be incomplete (jido-e12-t18)"
    end
  end

  @tags @packages
        |> Enum.flat_map(& &1.tags)
        |> Enum.uniq()
        |> Enum.sort()

  @categories @packages
              |> Enum.map(& &1.category)
              |> Enum.uniq()
              |> Enum.sort()

  @reverse_deps (
                  deps_map =
                    Enum.reduce(@packages, %{}, fn pkg, acc ->
                      Enum.reduce(pkg.ecosystem_deps, acc, fn dep_id, inner_acc ->
                        Map.update(inner_acc, dep_id, [pkg.id], &[pkg.id | &1])
                      end)
                    end)

                  Map.new(deps_map, fn {k, v} -> {k, Enum.sort(Enum.uniq(v))} end)
                )

  defmodule NotFoundError do
    defexception [:message, plug_status: 404]
  end

  @spec all_packages() :: [Package.t()]
  def all_packages, do: @packages

  @spec public_packages() :: [Package.t()]
  def public_packages, do: @public_packages

  @spec get_package(String.t()) :: Package.t() | nil
  def get_package(id), do: Map.get(@packages_by_id, id)

  @spec get_package!(String.t()) :: Package.t()
  def get_package!(id) do
    Map.get(@packages_by_id, id) ||
      raise NotFoundError, "package with id=#{id} not found"
  end

  @spec get_public_package(String.t()) :: Package.t() | nil
  def get_public_package(id), do: Map.get(@public_packages_by_id, id)

  @spec get_public_package!(String.t()) :: Package.t()
  def get_public_package!(id) do
    Map.get(@public_packages_by_id, id) ||
      raise NotFoundError, "public package with id=#{id} not found"
  end

  @spec packages_by_category(atom()) :: [Package.t()]
  def packages_by_category(category), do: Map.get(@packages_by_category, category, [])

  @spec packages_by_tier(integer()) :: [Package.t()]
  def packages_by_tier(tier), do: Map.get(@packages_by_tier, tier, [])

  @doc """
  Returns the priority packages — the core (tier 1) and official (tier 2)
  packages whose upstream README defines a role the public site documents and
  must keep aligned.

  A material upstream README change on a priority package creates an assigned
  review task during ecosystem ingestion (jido-e12-t18); community (tier 3)
  packages only surface the informational readme_drift review item
  (jido-e09-t32).
  """
  @spec priority_packages() :: [Package.t()]
  def priority_packages, do: Enum.filter(@packages, &(&1.tier in @priority_tiers))

  @doc """
  Returns `true` when the given package is a priority package — core (tier 1)
  or official (tier 2). Accepts a `Package.t()` or a package id string.

  See `priority_packages/0` (jido-e12-t18).
  """
  @spec priority_package?(Package.t() | String.t()) :: boolean()
  def priority_package?(%Package{tier: tier}), do: tier in @priority_tiers

  def priority_package?(id) when is_binary(id) do
    case get_package(id) do
      nil -> false
      pkg -> priority_package?(pkg)
    end
  end

  @spec packages_by_support_level(SupportLevel.t() | String.t()) :: [Package.t()]
  def packages_by_support_level(level), do: Map.get(@packages_by_support_level, SupportLevel.normalize(level), [])

  @spec public_packages_by_support_level(SupportLevel.t() | String.t()) :: [Package.t()]
  def public_packages_by_support_level(level),
    do: Map.get(@public_packages_by_support_level, SupportLevel.normalize(level), [])

  @spec all_categories() :: [atom()]
  def all_categories, do: @categories

  @spec all_tags() :: [atom()]
  def all_tags, do: @tags

  @spec support_levels() :: [SupportLevel.definition()]
  def support_levels, do: SupportLevel.all()

  @doc """
  Returns true when a package carries a published Hex version — i.e. an
  approved version exists in the release catalog.

  `hex_status` holds the version published to Hex.pm, or `"unreleased"` when the
  package is not yet published. This is the approved-version half of the
  public-claim release gate (`jido-e12-t44`): only a released package can
  satisfy a public claim.
  """
  @spec released?(Package.t() | String.t()) :: boolean()
  def released?(%Package{hex_status: hex_status}) do
    is_binary(hex_status) and
      String.downcase(String.trim(hex_status)) not in ["", "unreleased"]
  end

  def released?(id) when is_binary(id) do
    case get_package(id) do
      nil -> false
      pkg -> released?(pkg)
    end
  end

  @doc """
  The public release catalog: public packages that carry a published Hex version.

  These are the packages an approved version and support level can be cited from
  to satisfy a public claim (`jido-e12-t44`).
  """
  @spec released_public_packages() :: [Package.t()]
  def released_public_packages, do: Enum.filter(public_packages(), &released?/1)

  @spec ecosystem_deps(String.t()) :: [String.t()]
  def ecosystem_deps(id) do
    case get_package(id) do
      nil -> []
      pkg -> pkg.ecosystem_deps
    end
  end

  @spec reverse_deps(String.t()) :: [String.t()]
  def reverse_deps(id), do: Map.get(@reverse_deps, id, [])

  @spec dependency_graph() :: %{String.t() => [String.t()]}
  def dependency_graph do
    Map.new(@packages, fn pkg -> {pkg.id, pkg.ecosystem_deps} end)
  end

  @spec package_count() :: non_neg_integer()
  def package_count, do: length(@packages)

  @doc """
  ISO date (YYYY-MM-DD) the registry corpus was last reconciled.

  Serves as the per-package `last_synced` fallback on package pages so registry
  freshness is visible even for packages without an explicit sync date.
  """
  @spec registry_last_synced() :: String.t()
  def registry_last_synced, do: @registry_last_synced
end
