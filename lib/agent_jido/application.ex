defmodule AgentJido.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    dns_cluster_query = Application.get_env(:agent_jido, :dns_cluster_query) || :ignore

    children =
      [
        AgentJido.Repo,
        {Oban, Application.fetch_env!(:agent_jido, Oban)},
        AgentJidoWeb.Telemetry,
        {DNSCluster, query: dns_cluster_query},
        {Phoenix.PubSub, name: AgentJido.PubSub},
        AgentJidoWeb.Presence,
        {Finch, name: AgentJido.Finch},
        {Task.Supervisor, name: AgentJido.ContentAssistant.TaskSupervisor},
        {Task.Supervisor, name: AgentJido.ContentIngest.EcosystemDocs.TaskSupervisor},
        AgentJido.ContentAssistant.PageResponseCache
      ] ++
        github_stars_tracker_children() ++
        [
          Arcana.TaskSupervisor,
          AgentJido.ContentIngest.EcosystemDocs.Crawler
        ] ++
        arcana_embedder_children() ++
        [
          AgentJido.OGImage,
          AgentJidoWeb.Endpoint
        ] ++
        jido_runtime_children()

    opts = [strategy: :one_for_one, name: AgentJido.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AgentJidoWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp arcana_embedder_children do
    case Arcana.embedder() do
      {Arcana.Embedder.Local, _opts} ->
        raise """
        Arcana local embedder is disabled in this project.
        Use a remote embedder (for example :openai) to avoid Nx/EXLA runtime dependencies.
        """

      _other ->
        []
    end
  end

  defp github_stars_tracker_children do
    if enabled?(:agent_jido, AgentJido.GithubStarsTracker) do
      [{AgentJido.GithubStarsTracker, []}]
    else
      []
    end
  end

  # ContentOps supervisor startup is intentionally disabled so server boot
  # does not depend on ContentOps runtime/env configuration.
  defp jido_runtime_children do
    if enabled?(:agent_jido, AgentJido.Jido) do
      [AgentJido.Jido]
    else
      []
    end
  end

  defp enabled?(app, key) do
    app
    |> Application.get_env(key, [])
    |> config_enabled?()
  end

  defp config_enabled?(cfg) when is_list(cfg), do: Keyword.get(cfg, :enabled, false)
  defp config_enabled?(cfg) when is_map(cfg), do: Map.get(cfg, :enabled, false)
  defp config_enabled?(_), do: false
end
