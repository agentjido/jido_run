defmodule AgentJido.EcosystemVersionFreshnessTest do
  @moduledoc """
  Version-freshness gate (jido-e09-t35 / jido-e12-t17): for ecosystem packages
  that are installed dependencies, the registry version must match the installed
  release. Deterministic (no network); a Hex-network freshness check for the
  non-dependency packages is the broader follow-up.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Ecosystem

  @dep_packages ~w(jido jido_ai req_llm llm_db jido_signal)a

  test "installed dependency packages have registry versions matching the installed release" do
    mismatches =
      for id <- @dep_packages,
          pkg = Ecosystem.get_public_package(to_string(id)),
          not is_nil(pkg),
          installed = to_string(Application.spec(id, :vsn)),
          registry = pkg.version,
          registry != installed do
        {id, registry, installed}
      end

    assert mismatches == [],
           "registry versions drifted from installed deps: #{inspect(mismatches)}"
  end
end
