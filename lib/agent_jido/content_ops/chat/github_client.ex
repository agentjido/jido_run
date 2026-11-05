defmodule AgentJido.ContentOps.Chat.GithubClient do
  @moduledoc """
  Minimal GitHub API client wrapper used by ContentOps chat services.
  """

  alias AgentJido.ContentOps.Chat.Config
  alias AgentJido.Github.Optional, as: GithubOptional

  @type issue_request :: %{
          required(:title) => String.t(),
          optional(:body) => String.t(),
          optional(:labels) => [String.t()]
        }

  @doc "Create a GitHub issue in the configured repo."
  @spec create_issue(issue_request(), map()) :: {:ok, map()} | {:error, term()}
  def create_issue(request, context \\ %{}) when is_map(request) and is_map(context) do
    with {:ok, client} <- resolve_client(context),
         {:ok, owner, repo} <- resolve_repo(context),
         payload <- issue_payload(request),
         {status, body, _headers} when status in 200..299 <-
           api(context).issues_create(client, owner, repo, payload) do
      {:ok,
       %{
         owner: owner,
         repo: repo,
         number: body["number"],
         title: body["title"],
         url: body["html_url"] || body["url"],
         raw: body
       }}
    else
      {status, body, _headers} ->
        {:error, {:github_error, status, body}}

      {:error, _reason} = error ->
        error

      other ->
        {:error, {:github_error, other}}
    end
  end

  @doc "Create a comment on an existing GitHub issue."
  @spec create_issue_comment(pos_integer(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def create_issue_comment(number, body, context \\ %{})
      when is_integer(number) and number > 0 and is_binary(body) and is_map(context) do
    with {:ok, client} <- resolve_client(context),
         {:ok, owner, repo} <- resolve_repo(context),
         payload <- %{"body" => body},
         {status, result, _headers} when status in 200..299 <-
           api(context).issue_comments_create(client, owner, repo, number, payload) do
      {:ok,
       %{
         owner: owner,
         repo: repo,
         number: number,
         url: result["html_url"] || result["url"],
         raw: result
       }}
    else
      {status, result, _headers} ->
        {:error, {:github_error, status, result}}

      {:error, _reason} = error ->
        error

      other ->
        {:error, {:github_error, other}}
    end
  end

  defp resolve_client(context) do
    case Map.get(context, :github_client, Map.get(context, :client)) do
      nil ->
        token = System.get_env("GITHUB_TOKEN")

        if is_binary(token) and token != "" do
          GithubOptional.build_client(token)
        else
          {:error, :missing_github_token}
        end

      client ->
        {:ok, client}
    end
  end

  defp resolve_repo(context) do
    cfg = Config.load!()

    owner = Map.get(context, :github_owner, cfg.github_owner)
    repo = Map.get(context, :github_repo, cfg.github_repo)

    if owner in [nil, ""] or repo in [nil, ""] do
      {:error, :missing_repo_config}
    else
      {:ok, owner, repo}
    end
  end

  defp issue_payload(request) do
    payload =
      %{
        "title" => to_string(Map.get(request, :title, "")),
        "body" => blank_to_nil(Map.get(request, :body)),
        "labels" => normalize_labels(Map.get(request, :labels, []))
      }
      |> Enum.reject(fn
        {"title", ""} -> true
        {_k, nil} -> true
        {"labels", []} -> true
        _ -> false
      end)
      |> Map.new()

    payload
  end

  defp normalize_labels(labels) when is_list(labels) do
    labels
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_labels(_), do: []

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: to_string(value)

  defp api(context) do
    Map.get(context, :github_api, DefaultAPI)
  end

  defmodule DefaultAPI do
    @moduledoc false

    alias AgentJido.Github.Optional, as: GithubOptional

    def issues_create(client, owner, repo, payload) do
      GithubOptional.issues_create(client, owner, repo, payload)
    end

    def issue_comments_create(client, owner, repo, number, payload) do
      GithubOptional.issue_comments_create(client, owner, repo, number, payload)
    end
  end
end
