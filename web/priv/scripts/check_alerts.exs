Application.ensure_all_started(:budget_sentinel)

import Ecto.Query
alias BudgetSentinel.{Repo, Audit}

IO.puts("=== SMTP Config ===")
mailer_config = Application.get_env(:budget_sentinel, BudgetSentinel.Notifications.Mailer)
IO.inspect(mailer_config)

IO.puts("\n=== Latest 10 Alerts ===")
alerts = Repo.all(
  from a in BudgetSentinel.Audit.Alert,
  order_by: [desc: a.id],
  limit: 10
)
Enum.each(alerts, fn a ->
  IO.puts("#{a.recipient} -> #{a.status} at #{a.dispatched_at}")
end)

IO.puts("\n=== Total alerts: #{length(alerts)} ===")
