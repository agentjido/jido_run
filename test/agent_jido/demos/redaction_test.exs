defmodule AgentJido.Demos.RedactionTest do
  @moduledoc """
  Redaction regression (jido-e12-T41 / jido-e08-T44): a secret passed as an
  action param does not appear in captured telemetry metadata. Jido's action
  telemetry emits the action module only — params are intentionally excluded.
  """
  use ExUnit.Case, async: false

  alias AgentJido.Demos.Redaction.RedactedAction
  alias Jido.Exec

  @secret "sk-REDACTION-TEST-SECRET-xyz"

  test "a secret action param does not leak into telemetry metadata" do
    handler_id = "redaction-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      [[:jido, :action, :start], [:jido, :action, :stop]],
      fn event, measurements, metadata, _config ->
        send(self(), {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {:ok, _} = Exec.run(RedactedAction, %{token: @secret}, %{})

    events = drain_telemetry([])
    blob = inspect(events)

    # The action was executed (events were emitted)...
    assert events != []
    # ...but the secret never appears in the telemetry metadata.
    refute blob =~ @secret,
           "secret leaked into telemetry metadata"
  end

  defp drain_telemetry(acc) do
    receive do
      {:telemetry, _, _, _} = e -> drain_telemetry([e | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end
end
