defmodule AgentJido.SkillsCatalogTest do
  @moduledoc """
  Coverage gate for the public Skills catalog (jido-e10 E10-T23 / jido-e12
  E12-T13). The catalog must render cards; an empty catalog is a delivery fault.
  """
  use ExUnit.Case, async: true

  alias AgentJido.UpstreamSkillCatalog

  test "the public skills catalog renders cards" do
    assert UpstreamSkillCatalog.count() > 0
    assert UpstreamSkillCatalog.package_count() > 0
    assert UpstreamSkillCatalog.router_count() == 1
  end
end
