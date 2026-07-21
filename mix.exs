defmodule AgentJido.MixProject do
  use Mix.Project

  def project do
    [
      app: :agent_jido,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers() ++ [:phoenix_live_view],
      listeners: [Phoenix.CodeReloader],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # Cowlib 2.18.0 is the latest release; acknowledge its two upstream advisories
      # until Nine Nines publishes a patched version.
      hex: [ignore_advisories: ["CVE-2026-43969", "CVE-2026-43966"]],
      dialyzer: dialyzer()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {AgentJido.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      # Phoenix / Web
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.6"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.8.7"},
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:heroicons, github: "tailwindlabs/heroicons", tag: "v2.2.0", app: false, compile: false, sparse: "optimized"},
      {:floki, "~> 0.38"},
      {:lazy_html, ">= 0.0.0"},
      # HTTP / Server
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.5"},
      {:bandit, "~> 1.0"},
      {:hackney, "~> 4.6.0", override: true},
      {:remote_ip, "~> 1.2"},
      {:plug_canonical_host, "~> 2.0"},
      {:multipart, "~> 0.4", override: true},
      {:phoenix_seo, "~> 0.3"},
      {:finch, "~> 0.13"},
      {:posthog, "~> 2.5"},
      {:swoosh, "~> 1.5"},
      {:goth, "~> 1.4"},

      # Assets
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},

      # Telemetry / i18n / Serialization
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},

      # Content / Markdown
      {:nimble_publisher, "~> 2.0"},
      {:makeup_elixir, "~> 1.0"},
      {:makeup_js, "~> 0.1.0"},
      {:makeup_html, "~> 0.2.0"},

      # DB / Ecto (required by Arcana)
      {:decimal, "~> 3.0", override: true},
      {:ecto_sql, "~> 3.14"},
      {:postgrex, "~> 0.19"},
      {:oban, "~> 2.23"},
      {:pgvector, "~> 0.3"},

      # RAG
      {:arcana, "~> 2.0"},
      {:leidenfold, "~> 0.3"},
      # leidenfold uses rustler_precompiled NIFs (rustler is optional there),
      # so override to satisfy extractous_ex (via jido_browser) needing ~> 0.37
      {:rustler, "~> 0.37", override: true},

      # Nx backend (Apple Silicon)
      {:emlx, "~> 0.2"},

      # AI / Jido
      {:jido, "~> 2.1", override: true},
      {:jido_action, "~> 2.1", override: true},
      {:jido_signal, "~> 2.0", override: true},
      {:jido_ai, "~> 2.0", override: true},
      {:jido_browser, "~> 2.1"},
      {:jido_runic, github: "agentjido/jido_runic", branch: "main"},
      {:jido_live_dashboard, github: "agentjido/jido_live_dashboard", branch: "main"},
      {:libgraph, github: "zblanco/libgraph", branch: "zw/multigraph-indexes", override: true},
      {:jido_studio, github: "agentjido/jido_studio", branch: "main"},
      {:jido_messaging, github: "agentjido/jido_messaging", branch: "main"},
      {:telegex, github: "mikehostetler/telegex", ref: "a07f4e1", override: true},
      {:nostrum, "~> 0.10", runtime: false},
      {:req_llm, "~> 1.7", override: true},
      {:timex, "~> 3.7", override: true},
      {:gettext, "~> 1.0", override: true},

      # Image generation (OG images)
      {:image, "~> 0.54"},

      # Schema validation
      {:zoi, "~> 0.18"},

      # Config / Env
      {:dotenvy, "~> 1.0"},

      # Dev Tools
      {:tidewave, "~> 0.5", only: :dev},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.9", only: :dev, runtime: false},
      {:git_hooks, "~> 0.8", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "git_hooks.install", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["cmd --cd assets npm ci", "tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      "arcana.refresh": [
        "content.ingest.local --graph-concurrency 1",
        "arcana.graph.detect_communities --quiet",
        "arcana.graph.summarize_communities --concurrency 1"
      ],
      s: ["agentjido.signal"],
      q: ["quality"],
      precommit: [
        "compile --no-deps-check --warnings-as-errors",
        "format --check-formatted"
      ],
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_add_apps: [:mix]
    ]
  end
end
