alias BudgetSentinel.{Accounts, Repo}
alias BudgetSentinel.Accounts.{User, UserToken}
import Ecto.Query

IO.puts("Removing all existing users...")
Repo.delete_all(UserToken)
Repo.delete_all(User)

IO.puts("Creating admin account...")
{:ok, u} = Accounts.create_user_by_admin(%{
  "email" => "uwasedorcas22@gmail.com",
  "password" => "BudgetSentinel!1234",
  "role" => "admin"
})
IO.puts("Done! Created: #{u.email} as #{u.role}")
