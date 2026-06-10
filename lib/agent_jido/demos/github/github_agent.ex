defmodule AgentJido.Demos.GithubAgent do
  @moduledoc """
  ReAct agent for GitHub repository management.

  Manages issues, pull requests, and comments on GitHub repositories.
  Uses GITHUB_TOKEN from environment for authenticated API access.

  ## Usage

      # Start the agent
      {:ok, pid} = Jido.AgentServer.start_link(
        agent: AgentJido.Demos.GithubAgent,
        jido: AgentJido.Jido
      )

      # Ask it to create an issue
      {:ok, result} = AgentJido.Demos.GithubAgent.ask_sync(pid,
        "Create an issue on agentjido/agentjido_xyz titled 'Test Issue' with body 'Hello from GithubAgent'")

      # List open issues
      {:ok, result} = AgentJido.Demos.GithubAgent.ask_sync(pid,
        "List all open issues on agentjido/agentjido_xyz")

  ## PR Body Prompts

  When creating pull requests, the agent uses structured prompts to generate
  well-formatted PR descriptions. You can customize the prompt by including
  instructions in your query:

      AgentJido.Demos.GithubAgent.create_pr(pid,
        owner: "agentjido",
        repo: "agentjido_xyz",
        title: "feat: add GitHub agent",
        head: "feature-branch",
        base: "main",
        context: "Adds a ReAct agent for GitHub management with tools for issues, PRs, and webhooks."
      )

  ## Notes

  - Requires GITHUB_TOKEN environment variable
  - Uses Tentacat library for GitHub API interactions
  - Token is injected via tool_context, never exposed to LLM
  """

  use Jido.AI.Agent,
    name: "github_agent",
    description: "GitHub repository management assistant",
    tags: ["github", "demo"],
    tools: [
      # Issues
      Jido.Tools.Github.Issues.List,
      Jido.Tools.Github.Issues.Filter,
      Jido.Tools.Github.Issues.Find,
      Jido.Tools.Github.Issues.Create,
      Jido.Tools.Github.Issues.Update,
      # Issue comments
      Jido.Tools.Github.IssueComments.List,
      Jido.Tools.Github.IssueComments.Create,
      # Pull requests
      Jido.Tools.Github.Pulls.List,
      Jido.Tools.Github.Pulls.Find,
      Jido.Tools.Github.Pulls.Create,
      Jido.Tools.Github.Pulls.Update
    ],
    system_prompt: """
    You are a GitHub repository management assistant. You help users manage
    issues, pull requests, and comments on GitHub repositories.

    IMPORTANT: The GitHub client is automatically provided via context - you do NOT
    need to create or pass a client parameter. Just use the owner and repo parameters.

    ## Default Repository
    Unless the user specifies otherwise, operate on owner="agentjido" repo="agentjido_xyz".

    ## Available Tools

    ### Issues
    - github_issues_list: List all issues (params: owner, repo)
    - github_issues_filter: Filter issues (params: owner, repo, state, assignee, labels, sort, direction, since)
    - github_issues_find: Get specific issue (params: owner, repo, number)
    - github_issues_create: Create issue (params: owner, repo, title, body, assignee, milestone, labels)
    - github_issues_update: Update issue (params: owner, repo, number, title, body, state, labels)

    ### Issue Comments
    - github_issue_comments_list: List comments on issue (params: owner, repo, number)
    - github_issue_comments_create: Create comment on issue (params: owner, repo, number, body)

    ### Pull Requests
    - github_pulls_list: List PRs (params: owner, repo)
    - github_pulls_find: Get specific PR (params: owner, repo, number)
    - github_pulls_create: Create PR (params: owner, repo, title, body, head, base)
    - github_pulls_update: Update PR (params: owner, repo, number, title, body, state)

    ## PR Body Format
    When creating pull requests, write well-structured PR descriptions using this template:

    ## Summary
    [Concise description of what this PR does]

    ## Changes
    - [List of specific changes]

    ## Motivation
    [Why these changes are needed]

    ## Testing
    [How to test / what was tested]

    Always be helpful, concise, and explain what actions you're taking.
    """,
    max_iterations: 15

  alias AgentJido.Github.Optional, as: GithubOptional
  alias Jido.AI.Request

  @default_timeout 60_000

  @impl true
  def on_before_cmd(agent, {:react_start, %{query: query} = params} = _action) do
    case System.get_env("GITHUB_TOKEN") do
      nil ->
        agent = %{
          agent
          | state:
              agent.state
              |> Map.put(:last_query, query)
              |> Map.put(:completed, false)
              |> Map.put(:last_answer, "Error: GITHUB_TOKEN environment variable is not set.")
              |> Map.put(:github_token_present, false)
        }

        {:ok, agent, {:react_start, params}}

      token when is_binary(token) and byte_size(token) > 0 ->
        case GithubOptional.build_client(token) do
          {:ok, client} ->
            existing_context = Map.get(params, :tool_context, %{})
            new_context = Map.put(existing_context, :client, client)
            updated_params = Map.put(params, :tool_context, new_context)

            agent = %{
              agent
              | state:
                  agent.state
                  |> Map.put(:last_query, query)
                  |> Map.put(:completed, false)
                  |> Map.put(:last_answer, "")
                  |> Map.put(:github_token_present, true)
            }

            {:ok, agent, {:react_start, updated_params}}

          {:error, reason} ->
            agent = %{
              agent
              | state:
                  agent.state
                  |> Map.put(:last_query, query)
                  |> Map.put(:completed, false)
                  |> Map.put(:last_answer, github_client_error(reason))
                  |> Map.put(:github_token_present, false)
            }

            {:ok, agent, {:react_start, params}}
        end
    end
  end

  @impl true
  def on_before_cmd(agent, action), do: {:ok, agent, action}

  @impl true
  def on_after_cmd(agent, {:react_start, %{request_id: request_id}}, directives) do
    snap = strategy_snapshot(agent)

    agent =
      if snap.done? do
        Request.complete_request(agent, request_id, snap.result, meta: thinking_meta(snap))
      else
        agent
      end

    {:ok, agent, directives}
  end

  @impl true
  def on_after_cmd(agent, _action, directives) do
    snap = strategy_snapshot(agent)

    agent =
      if snap.done? do
        %{
          agent
          | state:
              Map.merge(agent.state, %{
                last_answer: snap.result || "",
                completed: true
              })
        }
      else
        agent
      end

    {:ok, agent, directives}
  end

  defp thinking_meta(snap) do
    details = snap.details || %{}
    meta = %{}

    meta =
      if details[:thinking_trace] && details[:thinking_trace] != [],
        do: Map.put(meta, :thinking_trace, details[:thinking_trace]),
        else: meta

    meta =
      if details[:streaming_thinking] && details[:streaming_thinking] != "",
        do: Map.put(meta, :last_thinking, details[:streaming_thinking]),
        else: meta

    meta
  end

  # --- Convenience Functions ---

  @doc """
  Create a GitHub issue.

  ## Examples

      {:ok, result} = GithubAgent.create_issue(pid,
        owner: "agentjido", repo: "agentjido_xyz",
        title: "Bug report", body: "Something broke")
  """
  @spec create_issue(pid(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def create_issue(pid, opts) do
    owner = Keyword.fetch!(opts, :owner)
    repo = Keyword.fetch!(opts, :repo)
    title = Keyword.fetch!(opts, :title)
    body = Keyword.get(opts, :body, "")
    labels = Keyword.get(opts, :labels, [])

    labels_str = if labels != [], do: " with labels: #{Enum.join(labels, ", ")}", else: ""

    query = """
    Create an issue on #{owner}/#{repo} with title "#{title}" and body:
    #{body}#{labels_str}
    """

    ask_sync(pid, query, timeout: @default_timeout)
  end

  @doc """
  Create a pull request with a well-structured body.

  ## Examples

      {:ok, result} = GithubAgent.create_pr(pid,
        owner: "agentjido", repo: "agentjido_xyz",
        title: "feat: add feature", head: "feature-branch", base: "main",
        context: "Description of changes")
  """
  @spec create_pr(pid(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def create_pr(pid, opts) do
    owner = Keyword.fetch!(opts, :owner)
    repo = Keyword.fetch!(opts, :repo)
    title = Keyword.fetch!(opts, :title)
    head = Keyword.fetch!(opts, :head)
    base = Keyword.get(opts, :base, "main")
    context = Keyword.get(opts, :context, "")

    query = """
    Create a pull request on #{owner}/#{repo}:
    - Title: "#{title}"
    - Head branch: #{head}
    - Base branch: #{base}

    Write a well-structured PR body following this template:

    ## Summary
    [Based on the title and context below]

    ## Changes
    [Infer from the title and context]

    ## Motivation
    [Why these changes matter]

    Context for the PR:
    #{context}
    """

    ask_sync(pid, query, timeout: @default_timeout)
  end

  @doc """
  Configure a webhook on a GitHub repository.

  This is a utility function (not agent-based) for setting up webhooks
  to notify a deployed URL when events happen on the repository.

  ## Examples

      {:ok, result} = GithubAgent.setup_webhook(
        owner: "agentjido", repo: "agentjido_xyz",
        url: "https://jido.run/api/webhooks/github",
        events: ["issues", "pull_request", "issue_comment"]
      )
  """
  @spec setup_webhook(keyword()) :: {:ok, map()} | {:error, term()}
  def setup_webhook(opts) do
    owner = Keyword.fetch!(opts, :owner)
    repo = Keyword.fetch!(opts, :repo)
    url = Keyword.fetch!(opts, :url)
    events = Keyword.get(opts, :events, ["issues", "pull_request", "issue_comment"])
    secret = Keyword.get(opts, :secret)

    case System.get_env("GITHUB_TOKEN") do
      nil ->
        {:error, "GITHUB_TOKEN environment variable is not set"}

      token ->
        with {:ok, client} <- GithubOptional.build_client(token) do
          GithubOptional.webhooks_create(owner, repo, url, events, secret, client)
        end
    end
  end

  @doc """
  List existing webhooks on a repository.
  """
  @spec list_webhooks(keyword()) :: {:ok, map()} | {:error, term()}
  def list_webhooks(opts) do
    owner = Keyword.fetch!(opts, :owner)
    repo = Keyword.fetch!(opts, :repo)

    case System.get_env("GITHUB_TOKEN") do
      nil ->
        {:error, "GITHUB_TOKEN environment variable is not set"}

      token ->
        with {:ok, client} <- GithubOptional.build_client(token) do
          GithubOptional.webhooks_list(owner, repo, client)
        end
    end
  end

  defp github_client_error(:missing_github_token) do
    "Error: GITHUB_TOKEN environment variable is not set."
  end

  defp github_client_error({:module_unavailable, module, function, arity}) do
    "Error: optional GitHub dependency is unavailable (#{inspect(module)}.#{function}/#{arity})."
  end
end
