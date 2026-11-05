defmodule AgentJido.TestProcess do
  @moduledoc false

  @doc "Stops a test process, tolerating one that is already shutting down."
  def stop(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal)
    :ok
  catch
    :exit, _reason -> :ok
  end
end
