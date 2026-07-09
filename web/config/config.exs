import Config

config :budget_sentinel,
  ecto_repos: [BudgetSentinel.Repo],
  generators: [timestamp_type: :utc_datetime]

config :budget_sentinel, BudgetSentinelWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BudgetSentinelWeb.ErrorHTML, json: BudgetSentinelWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BudgetSentinel.PubSub,
  live_view: [signing_salt: "budgetsentinelsalt"]

config :budget_sentinel, BudgetSentinel.Notifications.Mailer, adapter: Swoosh.Adapters.Local

config :swoosh, :api_client, Swoosh.ApiClient.Finch
config :swoosh, :finch_name, BudgetSentinel.Finch

config :budget_sentinel, :ai_client, BudgetSentinel.Intelligence.HttpAIClient

config :budget_sentinel, :ai_service_base_url, System.get_env("AI_SERVICE_URL") || "http://localhost:5000"

config :budget_sentinel, :high_risk_threshold, 70.0

config :logger, :console, format: "$time $metadata[$level] $message\n"

config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.21.5",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

import_config "#{config_env()}.exs"
