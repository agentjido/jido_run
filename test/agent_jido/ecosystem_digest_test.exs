defmodule AgentJido.EcosystemDigestTest do
  @moduledoc """
  Locks the adopter-focused ecosystem digest (jido-e11, E11-T14).

  Acceptance condition: "It covers stable releases, new examples, migrations,
  and known issues." This test enforces that the published digest names all four
  areas, points at real surfaces (the version pin set, runnable examples, the
  migrations page, and the public fix note), and states the adoption-evidence gap
  honestly rather than implying production evidence that does not exist.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Blog

  @digest_id "ecosystem-digest-2026-07"
  @digest_path "priv/blog/2026/07-27-ecosystem-digest-2026-07.md"
  @migrations_path "/docs/reference/migrations-and-upgrade-paths"
  @fix_note_path "/blog/fix-first-llm-tutorial-provider-mismatch"

  test "the digest is published and parses as a blog post" do
    post = Blog.get_post_by_id!(@digest_id)

    assert post.id == @digest_id
    assert post.author == "Mike Hostetler"
    assert post.source_path =~ @digest_path
    assert "digest" in (post.tags || [])
    assert post.post_type == :announcement
  end

  describe "covers stable releases" do
    setup do
      [source: File.read!(@digest_path)]
    end

    test "names the core install-stack pin set an adopter runs today",
         %{source: source} do
      # The versions this project itself pins in mix.lock — the digest must
      # state them so an adopter knows exactly what to depend on.
      assert source =~ "jido`",
             "the digest must name the jido package"

      assert source =~ "2.3.2",
             "the digest must state the pinned jido version"

      assert source =~ "jido_ai",
             "the digest must name jido_ai"

      assert source =~ "2.2.0",
             "the digest must state the pinned jido_ai version"

      assert source =~ "req_llm",
             "the digest must name req_llm"

      assert source =~ "1.17.1",
             "the digest must state the pinned req_llm version"

      assert source =~ "/ecosystem",
             "the digest must link to the ecosystem package index"
    end
  end

  describe "covers new examples" do
    setup do
      [source: File.read!(@digest_path)]
    end

    test "points at real runnable examples, not just described ones",
         %{source: source} do
      # The examples the digest features must each have a real deterministic
      # implementation under lib/agent_jido/demos/ — assert the example pages
      # exist and the digest links to them.
      for slug <- ~w(counter-agent demand-tracker-agent data-pipeline-agent operations-agent) do
        assert File.exists?("priv/examples/#{slug}.md"),
               "featured example #{slug} must have a published example page"

        assert source =~ "/examples/#{slug}",
               "the digest must link to the #{slug} example"
      end

      # The controlled-Agent pair is the operational surface this site leans on.
      assert source =~ "/examples/controlled-agent"
      assert source =~ "/examples/failure-drill-agent"
    end
  end

  describe "covers migrations" do
    setup do
      [source: File.read!(@digest_path)]
    end

    test "links to the published upgrade paths and names the dependency-order rule",
         %{source: source} do
      assert source =~ @migrations_path,
             "the digest must link to the migrations and upgrade paths page"

      assert source =~ "dependency order",
             "the digest must name the dependency-order upgrade rule"

      # The cross-package constraint that gates the tightest coupling in the stack.
      assert source =~ "jido_ai",
             "the digest must state the jido_ai upgrade constraint"

      assert source =~ "req_llm ~> 1.12",
             "the digest must state the req_llm ~> 1.12 constraint that gates jido_ai 2.2.x"
    end
  end

  describe "covers known issues" do
    setup do
      [source: File.read!(@digest_path)]
    end

    test "names the public first-LLM fix note", %{source: source} do
      assert source =~ @fix_note_path,
             "the digest must link to the public first-LLM fix note"

      assert source =~ "provider mismatch",
             "the digest must name the provider mismatch as a known, fixed issue"
    end

    test "is honest that some jido_ai examples are still simulated",
         %{source: source} do
      assert source =~ "simulated",
             "the digest must state that some jido_ai examples are still simulated"
    end

    test "names per-package limitations an adopter must weigh", %{source: source} do
      assert source =~ "limitations",
             "the digest must point adopters at per-package limitations"
    end

    test "states the adoption-evidence gap instead of implying production evidence",
         %{source: source} do
      # The epic's honesty principle: no public production case studies or
      # measured benchmarks exist yet. The digest must say so, not imply adoption.
      assert source =~ "production case studies",
             "the digest must address production case studies"

      assert source =~ "no public production case studies",
             "the digest must state plainly that no public production case studies exist yet"
    end
  end
end
