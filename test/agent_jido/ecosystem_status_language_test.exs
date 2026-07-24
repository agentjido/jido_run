defmodule AgentJido.EcosystemStatusLanguageTest do
  @moduledoc """
  Status-language gate (jido-e12-t09): public Experimental packages must not
  claim Stable/production-ready status in their forward-facing copy.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Ecosystem

  @stable_claims ~w(production-ready production-grade production-stable "API is stable" stable and production-proven)

  test "public Experimental packages do not claim Stable/production-ready status" do
    offenders =
      for pkg <- Ecosystem.public_packages(),
          pkg.support_level == :experimental,
          copy = Enum.join([pkg.tagline, pkg.landing_summary, pkg.description], " "),
          claim <- @stable_claims,
          String.contains?(copy, claim) do
        {pkg.id, claim}
      end

    assert offenders == [],
           "Experimental packages made Stable/production-ready claims: #{inspect(offenders)}"
  end
end
