defmodule AgentJido.Ecosystem.SupportLevel do
  @moduledoc """
  Canonical public support-level taxonomy for Jido ecosystem packages.

  This taxonomy defines what the project means operationally when a package is
  described as stable, beta, experimental, or unsupported. Ecosystem package metadata can
  attach one of these levels so site pages and docs use the same language.
  """

  @levels [:stable, :beta, :experimental, :unsupported]

  @definitions %{
    stable: %{
      id: :stable,
      label: "Stable",
      summary: "Public package intended for production use. APIs should move carefully and predictably.",
      short_commitment: "Ongoing maintenance, compatibility work, and careful API evolution.",
      commitment:
        "We maintain dependencies, fix bugs and compatibility issues, keep documentation and examples usable, and continue improving the package without unnecessary churn."
    },
    beta: %{
      id: :beta,
      label: "Beta",
      summary: "Architecturally defined and usable, but still gathering feedback before long-term guarantees are locked down.",
      short_commitment: "Public iteration with faster feedback loops before final release shape settles.",
      commitment:
        "We refine the package in public, respond to feedback, improve examples and onboarding, and accept that some APIs may still change as real usage arrives."
    },
    experimental: %{
      id: :experimental,
      label: "Experimental",
      summary: "Early work, active exploration, or research-oriented package design where the shape is not yet settled.",
      short_commitment: "Open exploration with no stability guarantee.",
      commitment: "Anything can change. Experimental work may be rewritten, archived, or removed entirely if it does not prove out."
    },
    unsupported: %{
      id: :unsupported,
      label: "Unsupported",
      summary: "Archived or deprecated work that remains available only for historical reference.",
      short_commitment: "No maintenance, compatibility, security, or release commitment.",
      commitment:
        "We do not maintain this package, fix bugs or security issues, update dependencies, or publish releases. Do not use it for new work."
    }
  }

  @type t :: :stable | :beta | :experimental | :unsupported
  @type definition :: %{
          id: t(),
          label: String.t(),
          summary: String.t(),
          short_commitment: String.t(),
          commitment: String.t()
        }

  @doc """
  Returns the canonical support-level ids in display order.
  """
  @spec levels() :: [t()]
  def levels, do: @levels

  @doc """
  Returns the canonical support-level definitions in display order.
  """
  @spec all() :: [definition()]
  def all do
    Enum.map(@levels, &Map.fetch!(@definitions, &1))
  end

  @doc """
  Returns the structured definition for a support level.
  """
  @spec definition(t() | String.t() | nil) :: definition() | nil
  def definition(level) do
    with normalized when not is_nil(normalized) <- normalize(level) do
      Map.get(@definitions, normalized)
    end
  end

  @doc """
  Returns the human-readable label for a support level.
  """
  @spec label(t() | String.t() | nil) :: String.t() | nil
  def label(level) do
    case definition(level) do
      %{label: label} -> label
      _other -> nil
    end
  end

  @doc """
  Normalizes a support-level token from atoms or strings.
  """
  @spec normalize(t() | String.t() | nil) :: t() | nil
  def normalize(level) when level in @levels, do: level
  def normalize(nil), do: nil

  def normalize(level) when is_binary(level) do
    normalized =
      level
      |> String.trim()
      |> String.downcase()

    Enum.find(@levels, fn candidate ->
      Atom.to_string(candidate) == normalized
    end)
  end

  def normalize(_level), do: nil
end
