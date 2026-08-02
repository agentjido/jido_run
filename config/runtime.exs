import Config
import Dotenvy

dotenv_sources =
  if config_env() == :test do
    [System.get_env()]
  else
    [".env", System.get_env()]
  end

source!(dotenv_sources)

config :agent_jido, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/agent_jido start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :agent_jido, AgentJidoWeb.Endpoint, server: true
end

canonical_host =
  case env!("CANONICAL_HOST", :string, nil) do
    host when is_binary(host) ->
      host
      |> String.trim()
      |> case do
        "" -> nil
        normalized -> normalized
      end

    _ ->
      nil
  end

default_mailer_from_email =
  case canonical_host do
    host when is_binary(host) and host != "" -> "noreply@#{host}"
    _ -> "noreply@localhost"
  end

config :agent_jido,
  canonical_host: canonical_host,
  site_indexable: env!("SITE_INDEXABLE", :boolean, true),
  # Set to true/false to control Plausible analytics loading, only in production
  enable_analytics: env!("ENABLE_ANALYTICS", :boolean, false),
  discord_invite_link: env!("DISCORD_INVITE_LINK", :string, "https://discord.gg/dMh8CqEH8Q"),
  mailer_from_name: env!("MAILER_FROM_NAME", :string, "AgentJido"),
  mailer_from_email: env!("MAILER_FROM_EMAIL", :string, default_mailer_from_email)

if config_env() != :test do
  posthog_runtime_config = AgentJido.Analytics.PostHog.RuntimeConfig.resolve(&System.get_env/1)

  config :agent_jido, :posthog, posthog_runtime_config
  config :posthog, AgentJido.Analytics.PostHog.RuntimeConfig.posthog_options(posthog_runtime_config)
end

# Agent runtime
jido_config =
  case Application.get_env(:agent_jido, AgentJido.Jido, []) do
    cfg when is_map(cfg) -> Map.to_list(cfg)
    cfg when is_list(cfg) -> cfg
    _other -> []
  end

jido_enabled =
  env!("AGENTJIDO_RUNTIME_ENABLED", :boolean, Keyword.get(jido_config, :enabled, true))

config :agent_jido, AgentJido.Jido, Keyword.put(jido_config, :enabled, jido_enabled)

# ContentOps chat
contentops_chat_config =
  case Application.get_env(:agent_jido, AgentJido.ContentOps.Chat, []) do
    cfg when is_map(cfg) -> Map.to_list(cfg)
    cfg when is_list(cfg) -> cfg
    _other -> []
  end

contentops_chat_enabled =
  if config_env() == :test do
    false
  else
    env!("CONTENTOPS_CHAT_ENABLED", :boolean, Keyword.get(contentops_chat_config, :enabled, false))
  end

contentops_chat_config = Keyword.put(contentops_chat_config, :enabled, contentops_chat_enabled)
config :agent_jido, AgentJido.ContentOps.Chat, contentops_chat_config

if contentops_chat_enabled do
  telegram_token =
    env!("TELEGRAM_BOT_TOKEN", :string, nil) ||
      raise "AgentJido.ContentOps.Chat enabled=true requires TELEGRAM_BOT_TOKEN."

  discord_token =
    env!("DISCORD_BOT_TOKEN", :string, nil) ||
      raise "AgentJido.ContentOps.Chat enabled=true requires DISCORD_BOT_TOKEN."

  config :telegex,
    token: telegram_token,
    caller_adapter: {Finch, []}

  config :nostrum,
    token: discord_token,
    gateway_intents: [:guilds, :guild_messages, :message_content, :direct_messages]

  # Override bindings from env if both platform IDs are provided
  telegram_chat_id = env!("TELEGRAM_CHAT_ID", :string, nil)
  discord_channel_id = env!("DISCORD_CHANNEL_ID", :string, nil)

  if telegram_chat_id && discord_channel_id do
    room_id = env!("CONTENTOPS_ROOM_ID", :string, "contentops:lobby")
    room_name = env!("CONTENTOPS_ROOM_NAME", :string, "ContentOps Lobby")

    env_bindings = [
      %{
        room_id: room_id,
        room_name: room_name,
        telegram_chat_id: telegram_chat_id,
        discord_channel_id: discord_channel_id
      }
    ]

    updated_cfg = Keyword.put(contentops_chat_config, :bindings, env_bindings)
    config :agent_jido, AgentJido.ContentOps.Chat, updated_cfg
  end
end

if env!("CONTENTOPS_GITHUB_MUTATIONS", :boolean, false) do
  github_live_cfg =
    case Application.get_env(:agent_jido, AgentJidoWeb.ContentOpsGithubLive, []) do
      cfg when is_map(cfg) -> Map.to_list(cfg)
      cfg when is_list(cfg) -> cfg
      _other -> []
    end

  config :agent_jido,
         AgentJidoWeb.ContentOpsGithubLive,
         Keyword.put(github_live_cfg, :github_mutations_enabled, true)
end

openai_api_key = env!("OPENAI_API_KEY", :string, nil)

arcana_llm =
  env!("ARCANA_LLM", :string, nil) ||
    if(config_env() == :dev and openai_api_key, do: "openai:gpt-4.1-nano")

if arcana_llm do
  config :arcana, llm: arcana_llm
end

content_assistant_config =
  case Application.get_env(:agent_jido, AgentJido.ContentAssistant, []) do
    cfg when is_map(cfg) -> Map.to_list(cfg)
    cfg when is_list(cfg) -> cfg
    _other -> []
  end

content_assistant_require_turnstile_default = if(config_env() == :prod, do: true, else: false)

content_assistant_require_turnstile =
  env!(
    "CONTENT_ASSISTANT_REQUIRE_TURNSTILE",
    :boolean,
    Keyword.get(content_assistant_config, :require_turnstile, content_assistant_require_turnstile_default)
  )

turnstile_site_key =
  env!(
    "CONTENT_ASSISTANT_TURNSTILE_SITE_KEY",
    :string,
    Keyword.get(content_assistant_config, :turnstile_site_key, nil)
  )

turnstile_secret_key =
  env!(
    "CONTENT_ASSISTANT_TURNSTILE_SECRET_KEY",
    :string,
    Keyword.get(content_assistant_config, :turnstile_secret_key, nil)
  )

content_assistant_config =
  content_assistant_config
  |> Keyword.put(:require_turnstile, content_assistant_require_turnstile)
  |> Keyword.put(:turnstile_site_key, turnstile_site_key)
  |> Keyword.put(:turnstile_secret_key, turnstile_secret_key)

config :agent_jido, AgentJido.ContentAssistant, content_assistant_config

analytics_ingestion_config =
  case Application.get_env(:agent_jido, AgentJido.Analytics.Ingestion, []) do
    cfg when is_map(cfg) -> Map.to_list(cfg)
    cfg when is_list(cfg) -> cfg
    _other -> []
  end

analytics_ingestion_config =
  analytics_ingestion_config
  |> Keyword.put(:github_token, env!("ANALYTICS_GITHUB_TOKEN", :string, nil))
  |> Keyword.put(
    :github_app_id,
    env!(
      "ANALYTICS_GITHUB_APP_ID",
      :string,
      env!("GITHUB_APP_ID", :string, Keyword.get(analytics_ingestion_config, :github_app_id, nil))
    )
  )
  |> Keyword.put(
    :github_app_installation_id,
    env!(
      "ANALYTICS_GITHUB_APP_INSTALLATION_ID",
      :string,
      env!("GITHUB_APP_INSTALLATION_ID", :string, Keyword.get(analytics_ingestion_config, :github_app_installation_id, nil))
    )
  )
  |> Keyword.put(
    :github_app_private_key,
    env!(
      "ANALYTICS_GITHUB_APP_PRIVATE_KEY",
      :string,
      env!("GITHUB_APP_PRIVATE_KEY", :string, Keyword.get(analytics_ingestion_config, :github_app_private_key, nil))
    )
  )
  |> Keyword.put(
    :github_app_private_key_path,
    env!(
      "ANALYTICS_GITHUB_APP_PRIVATE_KEY_PATH",
      :string,
      env!("GITHUB_APP_PRIVATE_KEY_PATH", :string, Keyword.get(analytics_ingestion_config, :github_app_private_key_path, nil))
    )
  )
  |> Keyword.put(:plausible_api_key, env!("PLAUSIBLE_STATS_API_KEY", :string, nil))
  |> Keyword.put(
    :plausible_site_id,
    env!("PLAUSIBLE_SITE_ID", :string, Keyword.get(analytics_ingestion_config, :plausible_site_id, nil))
  )
  |> Keyword.put(
    :search_console_site_url,
    env!("GOOGLE_SEARCH_CONSOLE_SITE_URL", :string, Keyword.get(analytics_ingestion_config, :search_console_site_url, nil))
  )
  |> Keyword.put(
    :search_console_credentials_json,
    env!("GOOGLE_SEARCH_CONSOLE_CREDENTIALS_JSON", :string, nil)
  )
  |> Keyword.put(
    :search_console_credentials_json_path,
    env!("GOOGLE_SEARCH_CONSOLE_CREDENTIALS_JSON_PATH", :string, nil)
  )
  |> Keyword.put(
    :search_console_quota_project,
    env!("GOOGLE_SEARCH_CONSOLE_QUOTA_PROJECT", :string, Keyword.get(analytics_ingestion_config, :search_console_quota_project, nil))
  )

config :agent_jido, AgentJido.Analytics.Ingestion, analytics_ingestion_config

if content_assistant_require_turnstile and (is_nil(turnstile_site_key) or is_nil(turnstile_secret_key)) do
  IO.warn("""
  CONTENT_ASSISTANT_REQUIRE_TURNSTILE is enabled, but CONTENT_ASSISTANT_TURNSTILE_SITE_KEY or CONTENT_ASSISTANT_TURNSTILE_SECRET_KEY is missing.
  Content assistant Turnstile verification will skip LLM enhancement until both keys are configured.
  """)
end

if is_binary(arcana_llm) and String.starts_with?(arcana_llm, "openai:") and is_nil(openai_api_key) do
  raise """
  ARCANA_LLM is configured to use OpenAI (#{inspect(arcana_llm)}) but OPENAI_API_KEY is missing.
  """
end

if arcana_embedder = env!("ARCANA_EMBEDDER", :string, nil) do
  case String.downcase(arcana_embedder) do
    "openai" ->
      config :arcana, embedder: :openai

    "local" ->
      raise """
      ARCANA_EMBEDDER=local is disabled for this project.
      Arcana must use remote embeddings (e.g. OpenAI) to avoid Nx/EXLA runtime dependencies.
      """

    other ->
      raise """
      environment variable ARCANA_EMBEDDER has invalid value: #{inspect(other)}.
      Supported values: "openai"
      """
  end
end

arcana_embedder = Application.get_env(:arcana, :embedder, :openai)

local_arcana_embedder? =
  case arcana_embedder do
    :local -> true
    {:local, _opts} -> true
    Arcana.Embedder.Local -> true
    {Arcana.Embedder.Local, _opts} -> true
    _other -> false
  end

if local_arcana_embedder? do
  raise """
  Arcana local embedders are disabled in this project.
  Configure Arcana with :openai (or a remote custom embedder), not :local.
  """
end

graph_resolution =
  case env!("ARCANA_GRAPH_RESOLUTION", :string, nil) do
    nil ->
      1.0

    value ->
      case Float.parse(value) do
        {resolution, ""} ->
          resolution

        _other ->
          raise """
          environment variable ARCANA_GRAPH_RESOLUTION has invalid value: #{inspect(value)}.
          Expected a float value, e.g. "1.0".
          """
      end
  end

graph_enabled_requested = env!("ARCANA_GRAPH_ENABLED", :boolean, config_env() == :dev)
graph_enabled = graph_enabled_requested and not is_nil(arcana_llm)

if graph_enabled_requested and is_nil(arcana_llm) do
  IO.warn("""
  ARCANA_GRAPH_ENABLED is true but ARCANA_LLM is not configured.
  Graph extraction has been disabled to avoid local Nx/EXLA extractors.
  """)
end

graph_config = [
  enabled: graph_enabled,
  community_levels: env!("ARCANA_GRAPH_COMMUNITY_LEVELS", :integer, if(config_env() == :prod, do: 3, else: 5)),
  resolution: graph_resolution
]

graph_config =
  if graph_config[:enabled] do
    graph_config
    |> Keyword.put(:extractor, Arcana.Graph.GraphExtractor.LLM)
    |> Keyword.put(:entity_extractor, Arcana.Graph.EntityExtractor.LLM)
    |> Keyword.put(:relationship_extractor, Arcana.Graph.RelationshipExtractor.LLM)
    |> Keyword.put_new(:community_summarizer, Arcana.Graph.CommunitySummarizer.LLM)
  else
    graph_config
  end

config :arcana, graph: graph_config

if config_env() != :prod and env!("MAILER_USE_BREVO", :boolean, false) do
  brevo_api_key =
    env!("BREVO_API_KEY", :string, nil) ||
      raise """
      MAILER_USE_BREVO=true requires BREVO_API_KEY.
      """

  config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: AgentJido.Finch

  config :agent_jido, AgentJido.Mailer,
    adapter: Swoosh.Adapters.Brevo,
    api_key: brevo_api_key
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  pool_size = String.to_integer(System.get_env("POOL_SIZE") || "10")
  socket_options = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :agent_jido, AgentJido.Repo,
    url: database_url,
    pool_size: pool_size,
    socket_options: socket_options

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  allowed_origin_hosts =
    [host, canonical_host, "agentjido.xyz"]
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()

  check_origin =
    Enum.flat_map(allowed_origin_hosts, fn origin_host ->
      ["https://#{origin_host}", "//#{origin_host}"]
    end)

  config :agent_jido, AgentJidoWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    check_origin: check_origin,
    secret_key_base: secret_key_base

  brevo_api_key =
    env!("BREVO_API_KEY", :string, nil) ||
      raise """
      environment variable BREVO_API_KEY is missing.
      """

  config :agent_jido, AgentJido.Mailer,
    adapter: Swoosh.Adapters.Brevo,
    api_key: brevo_api_key

  arcana_embedder = Application.get_env(:arcana, :embedder, :openai)

  openai_embedder? =
    case arcana_embedder do
      :openai -> true
      {:openai, _opts} -> true
      _other -> false
    end

  if openai_embedder? and is_nil(openai_api_key) do
    raise """
    environment variable OPENAI_API_KEY is required when Arcana embedder is :openai.
    """
  end

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :agent_jido, AgentJidoWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :agent_jido, AgentJidoWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
