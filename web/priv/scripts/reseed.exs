Application.ensure_all_started(:budget_sentinel)

alias BudgetSentinel.{Accounts, Ministries, Repo}
alias BudgetSentinel.Accounts.{User, UserToken}
import Ecto.Query

IO.puts("Clearing all existing data...")

Repo.delete_all("alerts")
Repo.delete_all("audit_reports")
Repo.delete_all("anomalies")
Repo.delete_all("expenditures")
Repo.delete_all("projects")
Repo.delete_all(UserToken)
Repo.delete_all(User)
Repo.delete_all("ministries")

IO.puts("Cleared. Running fresh seeds...")

Code.eval_file("/app/lib/budget_sentinel-0.1.0/priv/repo/seeds.exs")

IO.puts("Reseed complete.")
IO.puts("Users in system:")
Repo.all(from u in User, select: {u.email, u.role})
|> Enum.each(fn {email, role} -> IO.puts("  #{email} — #{role}") end)
