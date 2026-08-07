import Config

if System.get_env("PHX_SERVER") do
  config :budget_sentinel, BudgetSentinelWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "environment variable DATABASE_URL is missing"

  config :budget_sentinel, BudgetSentinel.Repo,
    url: database_url,
    ssl: if(System.get_env("DB_SSL") != "false", do: [verify: :verify_none], else: false),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "environment variable SECRET_KEY_BASE is missing"

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")
  scheme = System.get_env("PHX_SCHEME") || "https"
  url_port = String.to_integer(System.get_env("PHX_URL_PORT") || if(scheme == "https", do: "443", else: to_string(port)))

  config :budget_sentinel, BudgetSentinelWeb.Endpoint,
    url: [host: host, port: url_port, scheme: scheme],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base

  config :budget_sentinel, :ai_service_base_url,
    System.get_env("AI_SERVICE_URL") || "http://localhost:5000"

  cond do
    (brevo_key = System.get_env("BREVO_API_KEY")) not in [nil, ""] ->
      config :budget_sentinel, BudgetSentinel.Notifications.Mailer,
        adapter: Swoosh.Adapters.Brevo,
        api_key: brevo_key

    (resend_key = System.get_env("RESEND_API_KEY")) not in [nil, ""] ->
      config :budget_sentinel, BudgetSentinel.Notifications.Mailer,
        adapter: Swoosh.Adapters.Resend,
        api_key: resend_key

    (smtp_relay = System.get_env("SMTP_RELAY")) not in [nil, ""] ->
      config :budget_sentinel, BudgetSentinel.Notifications.Mailer,
        adapter: Swoosh.Adapters.SMTP,
        relay: smtp_relay,
        username: System.get_env("SMTP_USERNAME"),
        password: System.get_env("SMTP_PASSWORD"),
        port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
        tls: :always,
        tls_options: [verify: :verify_none],
        auth: :always

    true ->
      :ok
  end
end
