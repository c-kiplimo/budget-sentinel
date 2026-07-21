alias BudgetSentinel.{Accounts, Ministries, Procurement}

:rand.seed(:exsplus, {42, 42, 42})

# Single ministry scope: Ministry of Roads and Infrastructure — Gasabo District
{:ok, ministry} =
  case Ministries.list_ministries() |> Enum.find(&(&1.code == "MININFRA")) do
    nil -> Ministries.create_ministry(%{name: "Ministry of Roads and Infrastructure", code: "MININFRA"})
    existing -> {:ok, existing}
  end

if is_nil(Accounts.get_user_by_email("admin@budgetsentinel.local")) do
  {:ok, _admin} =
    Accounts.create_user_by_admin(%{
      email: "admin@budgetsentinel.local",
      password: "ChangeMe123456!",
      role: "admin"
    })

  IO.puts("Bootstrap admin created: admin@budgetsentinel.local / ChangeMe123456!")
end

for {role, prefix} <- [{"auditor", "auditor"}, {"oversight_officer", "oversight"}] do
  email = "#{prefix}.mininfra@budgetsentinel.local"

  if is_nil(Accounts.get_user_by_email(email)) do
    Accounts.create_user_by_admin(%{
      email: email,
      password: "ChangeMe123456!",
      role: role,
      ministry_id: ministry.id
    })
  end
end

milestones = ~w(site_clearing earthworks base_course tarmacking road_markings)

random_date = fn ->
  Date.add(~D[2025-01-01], :rand.uniform(364))
end

create_expenditure = fn project, amount, milestone, contractor ->
  Procurement.create_expenditure(%{
    project_id: project.id,
    contractor: contractor,
    amount: Decimal.from_float(Float.round(amount * 1.0, 2)),
    milestone: milestone,
    paid_on: random_date.()
  })
end

# ── Project 1: Inflated Contract ──────────────────────────────────────────────
# Payment far exceeds market benchmark → inflated_contract anomaly
{:ok, p1} = Procurement.create_project(%{
  name: "Kimironko–Remera Road Rehabilitation",
  sector: "road_construction",
  ministry_id: ministry.id,
  approved_budget: Decimal.from_float(1_200_000.00),
  market_benchmark: Decimal.from_float(1_100_000.00),
  completion_rate: Decimal.from_float(62.0),
  milestones: milestones
})

create_expenditure.(p1, 180_000.00, "site_clearing", "Kimironko Infrastructure Group")
create_expenditure.(p1, 210_000.00, "earthworks", "Remera Road Builders")
create_expenditure.(p1, 155_000.00, "base_course", "Kimironko Infrastructure Group")
# Inflated: 2.2x the market benchmark → triggers inflated_contract
create_expenditure.(p1, 2_420_000.00, "tarmacking", "Gasabo Roads Ltd")

# ── Project 2: Duplicate Payment ──────────────────────────────────────────────
# Same contractor paid twice for the same milestone → duplicate_payment anomaly
{:ok, p2} = Procurement.create_project(%{
  name: "Kinyinya Bridge Rehabilitation",
  sector: "bridge_works",
  ministry_id: ministry.id,
  approved_budget: Decimal.from_float(850_000.00),
  market_benchmark: Decimal.from_float(820_000.00),
  completion_rate: Decimal.from_float(45.0),
  milestones: milestones
})

create_expenditure.(p2, 95_000.00, "site_clearing", "Bumbogo Civil Works")
create_expenditure.(p2, 130_000.00, "earthworks", "Nduba Tarmac Contractors")
# Duplicate: same contractor + same milestone + same amount, paid twice
create_expenditure.(p2, 280_000.00, "base_course", "Rusororo Construction Works")
create_expenditure.(p2, 280_000.00, "base_course", "Rusororo Construction Works")

# ── Project 3: Ghost Project ──────────────────────────────────────────────────
# 0% completion but large payment disbursed → ghost_project anomaly
{:ok, p3} = Procurement.create_project(%{
  name: "Kacyiru–Kagugu Culvert Replacement",
  sector: "culverts",
  ministry_id: ministry.id,
  approved_budget: Decimal.from_float(620_000.00),
  market_benchmark: Decimal.from_float(590_000.00),
  completion_rate: Decimal.from_float(0.0),
  milestones: milestones
})

# Ghost: full handover payment despite 0% completion
create_expenditure.(p3, 490_000.00, "road_markings", "Gisozi Engineering Partners")

IO.puts("Seeded 3 Gasabo District road projects with embedded anomalies:")
IO.puts("  1. Kimironko–Remera Road Rehabilitation  — inflated contract")
IO.puts("  2. Kinyinya Bridge Rehabilitation         — duplicate payment")
IO.puts("  3. Kacyiru–Kagugu Culvert Replacement     — ghost project")
