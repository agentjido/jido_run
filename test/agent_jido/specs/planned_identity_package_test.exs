defmodule AgentJido.Specs.PlannedIdentityPackageTest do
  @moduledoc """
  E09-T48: a planned `jido_identity` (or similar) package is labeled as future
  work until released and tested, and excluded from the current
  operational-control proof.

  Acceptance: *A planned `jido_identity` or similar package is labeled as future
  work until released and tested.* Main targets: ecosystem records and roadmap
  links. Source: Jido Site Improvement Backlog 2026-07-23.md, row E09-T48.

  The current operational-control proof (the controlled-Agent example and the
  package control surfaces) already treats identity storage, authentication, and
  IAM as an application and platform responsibility. This test locks the label
  that says so explicitly: a separate `jido_identity` package is planned future
  work, not released or tested, and no current operational-control claim rests
  on it. The label is asserted in two places the backlog names — the `jido`
  ecosystem record's identity boundary and the contributor roadmap.
  """

  use ExUnit.Case, async: true

  # Paths are relative to the repo root.
  @jido_record "priv/ecosystem/jido.md"
  @roadmap_page "priv/pages/docs/contributors/roadmap.md"

  describe "the jido ecosystem record labels the planned identity package (jido-e09-t48)" do
    test "names the planned jido_identity package as future work" do
      body = File.read!(repo_path(@jido_record))

      assert body =~ "jido_identity",
             "the jido record must name the planned jido_identity package"

      assert body =~ "future work",
             "the jido record must label jido_identity as future work"
    end

    test "states the planned package is not yet released or tested" do
      body = File.read!(repo_path(@jido_record))

      assert body =~ "not yet released or tested",
             "the jido record must state jido_identity is not yet released or tested"
    end

    test "excludes the planned package from the current operational-control proof" do
      body = File.read!(repo_path(@jido_record))

      assert body =~ "no current operational-control claim",
             "the jido record must exclude jido_identity from current operational-control proof"
    end
  end

  describe "the roadmap labels the planned identity package (jido-e09-t48)" do
    test "names the planned jido_identity package as future work" do
      body = File.read!(repo_path(@roadmap_page))

      assert body =~ "jido_identity",
             "the roadmap must name the planned jido_identity package"

      assert body =~ "future work",
             "the roadmap must label jido_identity as future work"
    end

    test "states the planned package is not yet released or tested" do
      body = File.read!(repo_path(@roadmap_page))

      assert body =~ "not yet released or tested",
             "the roadmap must state jido_identity is not yet released or tested"
    end

    test "links the planned package to the identity boundary" do
      body = File.read!(repo_path(@roadmap_page))

      assert body =~ "/docs/operations/security-and-governance",
             "the roadmap must link the planned identity package to the Security and governance identity boundary"
    end
  end

  defp repo_path(relative) do
    Path.expand("../../../" <> relative, __DIR__)
  end
end
