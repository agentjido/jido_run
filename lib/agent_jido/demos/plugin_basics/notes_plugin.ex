defmodule AgentJido.Demos.PluginBasics.NotesPlugin do
  @moduledoc """
  Minimal notes plugin with mount state and plugin-scoped signal routes.
  """

  alias AgentJido.Demos.PluginBasics.{AddNoteAction, ClearNotesAction}

  Code.ensure_compiled!(AddNoteAction)
  Code.ensure_compiled!(ClearNotesAction)

  use Jido.Plugin,
    name: "notes_plugin",
    state_key: :notes,
    actions: [AddNoteAction, ClearNotesAction],
    description: "Stores lightweight note entries",
    schema:
      Zoi.object(%{
        entries: Zoi.list(Zoi.any()) |> Zoi.default([]),
        label: Zoi.string() |> Zoi.default("default")
      }),
    signal_patterns: ["notes.*"]

  @impl Jido.Plugin
  def mount(_agent, config) do
    {:ok, %{entries: [], label: Map.get(config, :label, "default")}}
  end

  @impl Jido.Plugin
  def signal_routes(_config) do
    [
      {"notes.add", AddNoteAction},
      {"notes.clear", ClearNotesAction}
    ]
  end
end
