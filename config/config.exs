# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :agent_jido, :scopes,
  user: [
    default: true,
    module: AgentJido.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: AgentJido.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

# Configures the endpoint
config :agent_jido,
  ecto_repos: [AgentJido.Repo]

config :agent_jido, AgentJido.Repo, types: AgentJido.PostgrexTypes

config :agent_jido, Oban,
  engine: Oban.Engines.Basic,
  repo: AgentJido.Repo,
  queues: [default: 10, analytics: 5],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"17 */6 * * *", AgentJido.Analytics.Ingestion.Workers.DispatcherWorker},
       {"23 */6 * * *", AgentJido.Analytics.Ingestion.Workers.PlausibleWorker},
       {"41 8 * * *", AgentJido.Analytics.Ingestion.Workers.SearchConsoleWorker},
       {"53 8 * * *", AgentJido.Analytics.Ingestion.Workers.HexWorker}
     ]}
  ]

config :git_hooks,
  project_path: Path.expand("..", __DIR__)

# Configures the endpoint
config :agent_jido, AgentJidoWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: AgentJidoWeb.ErrorHTML, json: AgentJidoWeb.ErrorJSON],
    layout: false,
    root_layout: [html: {AgentJidoWeb.Layouts, :root}]
  ],
  pubsub_server: AgentJido.PubSub,
  live_view: [signing_salt: "8Hv+cWMw"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :agent_jido, AgentJido.Mailer, adapter: Swoosh.Adapters.Local

config :agent_jido, AgentJido.Jido,
  enabled: true,
  max_tasks: 1000,
  agent_pools: []

config :agent_jido, :analytics_module, AgentJido.Analytics.Composite

config :agent_jido,
  content_gen_planner_model: "anthropic:claude-sonnet-4-5",
  content_gen_writer_model: "google:gemini-2.5-pro",
  content_gen_prompt_root: "priv/prompts/content_gen"

config :agent_jido, AgentJido.ContentAssistant,
  search_response_mode: :deterministic,
  search_retrieval_mode: :hybrid,
  progressive_swap_min_ms: 1_200

config :agent_jido, AgentJido.Analytics.Ingestion,
  request_timeout_ms: 15_000,
  github_api_version: "2026-03-10",
  github_app_id: nil,
  github_app_installation_id: nil,
  github_app_private_key: nil,
  github_app_private_key_path: nil,
  github_token: nil,
  plausible_api_base_url: "https://plausible.io",
  plausible_site_id: nil,
  plausible_window_days: 30,
  plausible_dimension_limit: 500,
  plausible_dimensions: [
    "event:page",
    "visit:source",
    "visit:channel",
    "visit:utm_campaign",
    "visit:utm_source",
    "visit:utm_medium",
    "visit:referrer",
    "visit:entry_page",
    "visit:exit_page",
    "visit:device",
    "visit:browser",
    "visit:os",
    "visit:country"
  ],
  search_console_site_url: nil,
  search_console_credentials_json_path: nil,
  search_console_quota_project: nil,
  search_console_window_days: 14,
  search_console_lag_days: 3,
  search_console_row_limit: 1_000,
  search_console_search_type: "web",
  search_console_dimension_sets: [
    ["date"],
    ["date", "page"],
    ["date", "query"],
    ["date", "query", "page"],
    ["date", "country"],
    ["date", "device"],
    ["date", "query", "country"],
    ["date", "query", "device"],
    ["date", "page", "country"],
    ["date", "page", "device"]
  ],
  hex_api_base_url: "https://hex.pm",
  hex_release_limit: 20,
  github_client: AgentJido.Analytics.Ingestion.GitHubTrafficClient,
  hex_client: AgentJido.Analytics.Ingestion.HexClient,
  plausible_client: AgentJido.Analytics.Ingestion.PlausibleClient,
  search_console_client: AgentJido.Analytics.Ingestion.SearchConsoleClient

config :agent_jido, AgentJido.MCP,
  protocol_version: "2025-11-25",
  server_name: "agent_jido_docs",
  http_max_body_bytes: 32_768,
  http_rate_limit_max_requests: 60,
  http_rate_limit_window_seconds: 60,
  search_limit: 10,
  query_max_length: 500

config :agent_jido, AgentJidoWeb.ContentOpsGithubLive,
  owner: "agentjido",
  repo: "agentjido_xyz",
  cache_ttl_minutes: 15,
  contentops_timeout_ms: 60_000,
  github_mutations_enabled: false

contentops_chat_bindings = [
  %{
    room_id: "contentops:lobby",
    room_name: "ContentOps Lobby",
    telegram_chat_id: "645038810",
    discord_channel_id: "1468796189997662487"
  }
]

config :agent_jido, AgentJido.ContentOps.Chat,
  enabled: false,
  bindings: contentops_chat_bindings,
  allowed_telegram_user_ids: ["645038810"],
  allowed_discord_user_ids: ["281856954903691264", "1235534042062131258"],
  bot_name: "AgentJido",
  command_prefix: "/ops",
  github_owner: "agentjido",
  github_repo: "agentjido_xyz",
  github_labels_base: ["contentops", "chatops"],
  github_labels_docs_note: ["docs-note"],
  mutation_tools_enabled: config_env() == :dev

config :agent_jido, AgentJido.GithubStarsTracker,
  enabled: true,
  refresh_interval_ms: :timer.hours(1),
  request_timeout_ms: 10_000,
  min_request_interval_ms: 200,
  rate_limit_cooldown_ms: :timer.minutes(15),
  use_auth_token: false,
  github_token: nil,
  fetcher: AgentJido.GithubStarsTracker.DefaultFetcher,
  repo_cache_timeout_ms: %{
    "ash_jido" => :timer.hours(24),
    "jido" => :timer.hours(24),
    "jido_action" => :timer.hours(24),
    "jido_behaviortree" => :timer.hours(24),
    "jido_browser" => :timer.hours(24),
    "jido_memory" => :timer.hours(24),
    "jido_messaging" => :timer.hours(24),
    "jido_otel" => :timer.hours(24),
    "jido_signal" => :timer.hours(24),
    "jido_studio" => :timer.hours(24),
    "llm_db" => :timer.hours(24),
    "req_llm" => :timer.hours(24)
  }

config :agent_jido, AgentJido.ContentIngest.EcosystemDocs.Crawler,
  enabled: true,
  refresh_interval_ms: :timer.hours(24),
  startup_sync: true,
  request_timeout_ms: 15_000,
  page_concurrency: 4

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.27.3",
  default: [
    args: ~w(
      js/app.js
      --bundle
      --target=es2020
      --format=esm
      --splitting
      --outdir=../priv/static/assets
      --external:/fonts/*
      --external:/images/*
    ),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.2.1",
  default: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Nx backend (Apple Silicon / EMLX) - used for local Nx/Bumblebee workloads
config :nx,
  default_backend: EMLX.Backend,
  default_defn_options: [compiler: EMLX]

# Arcana RAG
config :arcana,
  repo: AgentJido.Repo,
  embedder: :openai

config :agent_jido, arcana_graph_ingest_concurrency: 1

config :agent_jido, ash_domains: [AgentJido.Folio]

# Git hooks and git_ops configuration for conventional commits
# Only configure when the dependencies are actually available (dev environment)
if config_env() == :dev do
  config :git_hooks,
    auto_install: true,
    verbose: true,
    hooks: [
      commit_msg: [
        tasks: [
          {:cmd, "mix git_ops.check_message", include_hook_args: true}
        ]
      ],
      pre_push: [
        tasks: [
          {:cmd, "mix credo --strict"},
          {:mix_task, :test},
          {:mix_task, :dialyzer}
        ]
      ]
    ]

  config :git_ops,
    mix_project: AgentJido.MixProject,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/agentjido/agent_jido",
    manage_mix_version?: true,
    version_tag_prefix: "v",
    types: [
      feat: [header: "Features"],
      fix: [header: "Bug Fixes"],
      perf: [header: "Performance"],
      refactor: [header: "Refactoring"],
      docs: [hidden?: true],
      test: [hidden?: true],
      chore: [hidden?: true],
      ci: [hidden?: true]
    ]
end

config :jido, jido_instance: AgentJido.Jido
# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
