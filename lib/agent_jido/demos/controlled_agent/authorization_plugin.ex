defmodule AgentJido.Demos.ControlledAgent.AuthorizationPlugin do
  @moduledoc """
  Fail-closed authorization hook (jido-e07 / jido-e05-T35).

  Denies an Action before it runs unless the incoming Signal's `source` is in
  the configured allowlist. Demonstrates `prepare_action/3` as a fail-closed
  authorization point: a missing or unknown principal never reaches the effect.

  This is an **authorization** (allow/deny) decision, not authentication. The
  `source` is an already-authenticated principal supplied by the boundary in
  front of Jido; this hook never verifies a credential. Jido carries and honors
  the principal — it does not authenticate a user or service by itself. See the
  spec's "Authentication boundary" section (`jido-e07-t36`).
  """
  use Jido.Plugin,
    name: "authorization",
    state_key: :authorization,
    description: "Fail-closed authorization hook",
    actions: [],
    schema: Zoi.object(%{allowed: Zoi.list(Zoi.string()) |> Zoi.default([])})

  alias Jido.Signal

  @impl Jido.Plugin
  def mount(_agent, config) do
    {:ok, %{allowed: Map.get(config, :allowed, [])}}
  end

  @impl Jido.Plugin
  def prepare_action(%Signal{source: source}, _action_arg, context) do
    allowed = allowed_principals(context)

    if is_binary(source) and source in allowed do
      {:ok, %{}}
    else
      {:error, :unauthorized}
    end
  end

  defp allowed_principals(context) do
    case context do
      %{config: %{allowed: list}} when is_list(list) -> list
      %{plugin_instance: %{state: %{allowed: list}}} when is_list(list) -> list
      _other -> []
    end
  end
end
