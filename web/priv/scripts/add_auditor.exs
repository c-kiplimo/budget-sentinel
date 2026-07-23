Application.ensure_all_started(:budget_sentinel)

alias BudgetSentinel.{Accounts, Ministries}

ministry = Ministries.list_ministries() |> Enum.find(&(&1.code == "GASABO-INFRA"))
IO.puts("Using ministry: #{ministry.name}")

case Accounts.get_user_by_email("limokcollins@gmail.com") do
  nil ->
    {:ok, user} = Accounts.create_user_by_admin(%{
      "email"       => "limokcollins@gmail.com",
      "password"    => "BudgetSentinel!1234",
      "role"        => "auditor",
      "ministry_id" => to_string(ministry.id)
    })
    IO.puts("Created: #{user.email} | role: #{user.role} | ministry: #{ministry.name}")

  existing ->
    {:ok, user} = existing
    |> Ecto.Changeset.change(%{role: "auditor", ministry_id: ministry.id})
    |> BudgetSentinel.Repo.update()
    IO.puts("Updated: #{user.email} | role: #{user.role} | ministry: #{ministry.name}")
end
