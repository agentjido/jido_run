import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :agent_jido, AgentJidoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "twi598leTbcJNAxvKitZGPMr8ZDu9ONMsUY1vk6ubAxy5Dmzx/7QrR9at+voP4X2",
  server: false

# In test we don't send emails.
config :agent_jido, AgentJido.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Database
config :agent_jido, AgentJido.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  database: "agent_jido_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :arcana,
  embedder: AgentJido.ArcanaTestEmbedder,
  graph: [enabled: false]

config :agent_jido, AgentJido.GithubStarsTracker, enabled: false
config :agent_jido, AgentJido.ContentIngest.EcosystemDocs.Crawler, enabled: false, startup_sync: false
config :agent_jido, :analytics_module, AgentJido.Analytics.Composite

config :agent_jido, Oban, testing: :manual

config :agent_jido, AgentJido.Analytics.Ingestion,
  github_token: "test-github-token",
  plausible_api_key: "test-plausible-key",
  plausible_site_id: "jido.run",
  search_console_site_url: "sc-domain:jido.run",
  search_console_credentials_json: ~s({"client_email":"search-console@example.test","private_key":"test-private-key"}),
  github_client: AgentJido.Analytics.Ingestion.GitHubTrafficClient,
  hex_client: AgentJido.Analytics.Ingestion.HexClient,
  plausible_client: AgentJido.Analytics.Ingestion.PlausibleClient,
  search_console_client: AgentJido.Analytics.Ingestion.SearchConsoleClient

config :agent_jido, :posthog,
  enabled: false,
  browser_enabled: false,
  server_enabled: false,
  autocapture_enabled: false,
  session_replay_enabled: false,
  session_replay_sample_rate: 0.25,
  api_key: "test-posthog-key",
  api_host: "https://us.i.posthog.com"

config :posthog,
  enable: true,
  enable_error_tracking: false,
  test_mode: true,
  api_key: "test-posthog-key",
  api_host: "https://us.i.posthog.com",
  in_app_otp_apps: [:agent_jido]

config :agent_jido, :dev_routes, true
