defmodule AgentJido.Specs.SecondaryCTAConventionTest do
  use ExUnit.Case, async: true

  @style_guide "specs/style-voice.md"
  @home_cta "lib/agent_jido_web/components/jido/home_sections.ex"
  @features_live "lib/agent_jido_web/live/jido_features_live.ex"

  test "defines the task and destination for each secondary CTA (jido-e03-t23)" do
    guide = File.read!(@style_guide)

    assert guide =~ "### Secondary CTA convention"
    assert guide =~ "| **See examples** |"
    assert guide =~ "| **Read the guide** |"
    assert guide =~ "| **Compare packages** |"
    assert guide =~ "`/examples`"
    assert guide =~ "One specific published `/docs/...` guide"
    assert guide =~ "`/ecosystem#compare`"
    assert guide =~ "Do not use this label for competitor comparisons."
  end

  test "shared marketing CTAs use the standard See examples label" do
    assert File.read!(@home_cta) =~ ~s(default: "See examples")
    assert File.read!(@features_live) =~ "See examples"

    refute File.read!(@home_cta) =~ "SEE EXAMPLES"
    refute File.read!(@features_live) =~ "SEE EXAMPLES"
  end
end
