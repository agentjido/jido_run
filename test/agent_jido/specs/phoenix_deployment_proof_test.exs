defmodule AgentJido.Specs.PhoenixDeploymentProofTest do
  @moduledoc """
  Complete-Phoenix-example proof-inventory gate (jido-e08-t23).

  Acceptance: "It moves from local Agent use to a deployed application path."

  The complete Phoenix example is the workbench itself (`agent_jido`): a
  Phoenix 1.8 application that serves the same interactive agent examples
  under `mix phx.server` (local Agent use) and as a production release (the
  deployed application path). What this task closes is **publication as
  proof**: the deployed-application path must be recorded in `specs/proof.md`
  so the "deploy" step of the long-running linear path
  (`specs/operations-reference-architecture.md`) has direct, file-backed proof.

  This gate keeps that publication honest, the same way
  `provider_fallback_proof_test.exs` and `long_running_reference_proof_test.exs`
  keep their rows honest — a proof row that names an acceptance the asset does
  not meet, or that points at a file that does not exist, fails the gate:

    * `specs/proof.md` records the complete-Phoenix-example as existing proof
      that states both halves of the acceptance (local Agent use + a deployed
      application path);
    * the inventory row points at real deployment assets (a renamed or deleted
      release/Dockerfile/Fly env file fails the gate);
    * the deployment assets encode the local-to-deployed move — the same app
      runs under `PHX_SERVER` locally and in the release, the Dockerfile
      packages that release, and the Fly.io release env wires `RELEASE_NODE`.
  """
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../", __DIR__)
  @proof_path Path.expand("../../../specs/proof.md", __DIR__)

  # The canonical deployment assets that make this proof — each is named
  # explicitly (not just any file) so a row that swaps one for a missing file
  # fails the gate.
  @release_start_path "rel/overlays/bin/server"
  @dockerfile_path "Dockerfile"
  @fly_env_path "rel/env.sh.eex"
  @runtime_config_path "config/runtime.exs"
  @local_example_path "priv/examples/failure-drill-agent.md"

  describe "publication in the proof inventory" do
    test "specs/proof.md records the complete-Phoenix-example as existing proof" do
      row = phoenix_row()

      assert row != nil,
             "specs/proof.md must record the complete-Phoenix-example as proof"

      assert String.contains?(row, "✅ exists"),
             "the complete-Phoenix-example proof row must be marked ✅ exists"

      # Both halves of the acceptance must be named in the inventory itself, so
      # the deployed-application-path claim is not backed by a row that names
      # only one.
      assert row =~ ~r/local/i,
             "the complete-Phoenix-example proof row must state local Agent use"

      assert row =~ ~r/deploy/i,
             "the complete-Phoenix-example proof row must state a deployed application path"
    end

    test "the inventory row points at real deployment assets" do
      row = phoenix_row()

      assert row != nil,
             "specs/proof.md must record the complete-Phoenix-example as proof"

      # Every repo-relative path named in the row must resolve — a row that
      # points at a missing file is treated as unproven (proof.md's own rule).
      for path <- paths_in(row) do
        resolved = Path.expand(path, @repo_root)

        assert File.exists?(resolved),
               "complete-Phoenix-example proof row names a non-existent path: #{path}"
      end

      # The release start script, the Docker image, and the Fly.io release env
      # are the three assets that make the deployed-application path, so they
      # are named explicitly (not just any files).
      assert String.contains?(row, @release_start_path),
             "the complete-Phoenix-example proof row must name the release start script"

      assert String.contains?(row, @dockerfile_path),
             "the complete-Phoenix-example proof row must name the Dockerfile"

      assert String.contains?(row, @fly_env_path),
             "the complete-Phoenix-example proof row must name the Fly.io release env"

      # Local Agent use is a real, published interactive surface too.
      assert String.contains?(row, @local_example_path),
             "the complete-Phoenix-example proof row must name a local interactive example"
    end
  end

  describe "the proof encodes the local-to-deployed move" do
    test "local Agent use: the same app runs under PHX_SERVER" do
      runtime = read(@runtime_config_path)

      # config/runtime.exs honors PHX_SERVER to start the endpoint, so the app
      # that serves the interactive examples under `mix phx.server` is the same
      # app the release starts — local Agent use, not a separate codebase.
      assert runtime =~ "PHX_SERVER",
             "config/runtime.exs must honor PHX_SERVER so the release serves the same app"

      # A published interactive example proves local Agent use is a real surface.
      assert File.regular?(Path.expand(@local_example_path, @repo_root)),
             "the local interactive example must exist"
    end

    test "deployed application path: the release starts, the image packages it, and Fly.io deploys it" do
      release_start = read(@release_start_path)
      dockerfile = read(@dockerfile_path)
      fly_env = read(@fly_env_path)

      # The release start script flips PHX_SERVER on and boots the release — the
      # deployed entry point (Procfile: `web: /app/bin/server`).
      assert release_start =~ "PHX_SERVER",
             "rel/overlays/bin/server must set PHX_SERVER to start the endpoint"

      assert release_start =~ ~r/agent_jido start/,
             "rel/overlays/bin/server must start the agent_jido release"

      # The Dockerfile builds the release and packages it as a runnable image.
      assert dockerfile =~ ~r/mix release/,
             "Dockerfile must build the production release (mix release)"

      assert dockerfile =~ ~r{rel/agent_jido},
             "Dockerfile must package the built release into the image"

      # The Fly.io release env wires RELEASE_NODE from the FLY_* env, so the
      # packaged release is deployable — not just buildable.
      assert fly_env =~ "RELEASE_NODE",
             "rel/env.sh.eex must wire RELEASE_NODE for deployment"

      assert fly_env =~ "FLY_",
             "rel/env.sh.eex must derive release config from the FLY_* deploy env"
    end
  end

  # --- helpers ---

  defp phoenix_row do
    proof = File.read!(@proof_path)

    # The complete-Phoenix-example row is the one table row that names it. Pull
    # the single line from the first `|` to the trailing `|`.
    case Regex.run(~r/\|.*Complete Phoenix application.*\|/, proof) do
      [row | _] -> row
      nil -> nil
    end
  end

  defp paths_in(row) do
    # Paths in a proof.md table cell are backtick-wrapped and ` + `-separated, so
    # stop at whitespace, backtick, or pipe. The deployment assets live under
    # rel/ and config/ and include extension-less scripts (bin/server), so this
    # is more permissive than the file-extension scan the provider-fallback gate
    # uses; the bare `Dockerfile` and `Procfile` are checked explicitly above.
    ~r{(?:lib|test|priv|specs|rel|config)/[^\s`|]+}
    |> Regex.scan(row, capture: :first)
    |> List.flatten()
  end

  defp read(path) do
    File.read!(Path.expand(path, @repo_root))
  end
end
