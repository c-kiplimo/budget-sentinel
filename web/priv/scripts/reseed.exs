Application.ensure_all_started(:budget_sentinel)

alias BudgetSentinel.Repo
import Ecto.Query

IO.puts("Clearing existing procurement and audit data...")

# Delete in dependency order
Repo.delete_all("alerts")
Repo.delete_all("audit_reports")
Repo.delete_all("anomalies")
Repo.delete_all("expenditures")
Repo.delete_all("projects")

# Remove non-real users (local placeholder accounts from seeds)
from(u in "users", where: like(u.email, "%@budgetsentinel.local"))
|> Repo.delete_all()

Repo.delete_all("ministries")

IO.puts("Cleared. Running fresh seeds...")

Code.eval_file("/app/lib/budget_sentinel-0.1.0/priv/repo/seeds.exs")

IO.puts("Reseed complete.")

# Re-link real gmail auditor to the new ministry (ministry_id was nullified by cascade)
alias BudgetSentinel.{Accounts, Ministries}
ministry = Ministries.list_ministries() |> Enum.find(&(&1.code == "MININFRA"))

case Accounts.get_user_by_email("limokcollins@gmail.com") do
  nil -> IO.puts("Collins not found — skipping ministry re-link")
  user ->
    {:ok, _} =
      user
      |> Ecto.Changeset.change(%{role: "auditor", ministry_id: ministry.id})
      |> Repo.update()
    IO.puts("Re-linked limokcollins@gmail.com to #{ministry.name}")
end
