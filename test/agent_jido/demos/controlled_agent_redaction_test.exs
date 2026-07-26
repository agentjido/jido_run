defmodule AgentJido.Demos.ControlledAgentRedactionTest do
  @moduledoc """
  Redaction across the controlled-agent observation path (`jido-e07-t48`).

  Acceptance: *The defined sensitive fixtures do not appear in captured
  operational data.*

  The reference app routes each defined sensitive fixture (a provider key)
  through the controlled-agent observation path. With redaction configured, the
  fixture is absent from every captured operational-data sink — telemetry, logs,
  the recorded Journal entry, and error output. With redaction off the fixture
  passes through into telemetry, logs, and the Journal, proving the absence is
  the configured redaction and not a missing value.

  Jido supplies the redaction surface (`Jido.Observe.redact/2`, gated by
  `:redact_sensitive`); the application owns the duty to apply it at each sink.
  See `AgentJido.Demos.ControlledAgent.Redaction`.
  """

  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias AgentJido.Demos.ControlledAgent.Redaction

  setup do
    # This test toggles the observability redaction + log config and lowers the
    # Logger primary level so the observation log is captured, so it cannot run
    # concurrently with other observability-sensitive tests.
    prior = Application.get_env(:jido, :observability, [])
    %{level: prior_log_level} = :logger.get_primary_config()
    :logger.set_primary_config(:level, :info)
    handler_id = attach_telemetry()

    on_exit(fn ->
      Application.put_env(:jido, :observability, prior)
      :logger.set_primary_config(:level, prior_log_level)
      Jido.Tracing.Context.clear()
      :telemetry.detach(handler_id)
    end)

    :ok
  end

  # Acceptance: "The defined sensitive fixtures do not appear in captured
  # operational data." Each fixture is routed through the path once and asserted
  # absent from all four operational-data sinks.
  test "the defined sensitive fixtures are absent from every captured sink" do
    configure_redaction(true)

    for fixture <- Redaction.fixtures() do
      {{:ok, %{journal: journal, error: error}}, log} =
        with_log(fn -> Redaction.run(fixture) end)

      telemetry = inspect(drain_telemetry())

      # The fixture was redacted to the placeholder before entering telemetry
      # and logs (so the refutes below are not vacuous)...
      assert String.contains?(telemetry, "[REDACTED]"),
             "expected the redaction marker in the captured telemetry"
      assert String.contains?(log, "[REDACTED]"),
             "expected the redaction marker in the captured logs"

      # ...and the raw fixture never appears in any captured operational data.
      refute String.contains?(telemetry, fixture),
             "fixture #{inspect(fixture)} leaked into telemetry"
      refute String.contains?(log, fixture),
             "fixture #{inspect(fixture)} leaked into logs"
      refute String.contains?(inspect(journal), fixture),
             "fixture #{inspect(fixture)} leaked into the recorded Journal entry"
      refute String.contains?(inspect(error), fixture),
             "fixture #{inspect(fixture)} leaked into error output"
    end
  end

  # Proves the absence above is the configured redaction, not a missing value:
  # with redaction off the fixture passes through unchanged into telemetry,
  # logs, and the recorded Journal entry.
  test "with redaction off the fixture passes through into captured data" do
    configure_redaction(false)

    [fixture | _] = Redaction.fixtures()

    {{:ok, %{journal: journal}}, log} = with_log(fn -> Redaction.run(fixture) end)
    telemetry = inspect(drain_telemetry())

    assert String.contains?(telemetry, fixture),
           "fixture should reach telemetry when redaction is off"
    assert String.contains?(log, fixture),
           "fixture should reach logs when redaction is off"
    assert String.contains?(inspect(journal), fixture),
           "fixture should reach the recorded Journal entry when redaction is off"
  end

  # --- helpers ---

  defp configure_redaction(bool) do
    Application.put_env(:jido, :observability, redact_sensitive: bool, log_level: :info)
  end

  defp attach_telemetry do
    handler_id = "controlled-agent-redaction-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      Redaction.telemetry_events(),
      fn event, measurements, metadata, _config ->
        send(self(), {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    handler_id
  end

  defp drain_telemetry(acc \\ []) do
    receive do
      {:telemetry, _, _, _} = e -> drain_telemetry([e | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end
end
