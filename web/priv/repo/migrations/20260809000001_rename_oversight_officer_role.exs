defmodule BudgetSentinel.Repo.Migrations.RenameOversightOfficerRole do
  use Ecto.Migration

  def up do
    execute "UPDATE users SET role = 'finance_officer' WHERE role = 'oversight_officer'"
    execute "ALTER TABLE users ALTER COLUMN role SET DEFAULT 'finance_officer'"
  end

  def down do
    execute "UPDATE users SET role = 'oversight_officer' WHERE role = 'finance_officer'"
    execute "ALTER TABLE users ALTER COLUMN role SET DEFAULT 'oversight_officer'"
  end
end
