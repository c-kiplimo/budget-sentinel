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

contractors = [
  "Gasabo Roads Ltd",
  "Kigali Civil Engineering Co.",
  "Rusororo Construction Works",
  "Kimironko Infrastructure Group",
  "Remera Road Builders",
  "Gisozi Engineering Partners",
  "Bumbogo Civil Works",
  "Nduba Tarmac Contractors"
]

milestones = ~w(site_clearing earthworks base_course tarmacking road_markings)

random_date = fn ->
  Date.add(~D[2025-01-01], :rand.uniform(364))
end

gasabo_projects = [
  {"Kimironko–Remera Road Rehabilitation", "road_construction"},
  {"Remera Junction Drainage Improvement", "drainage"},
  {"Gisozi–Kimironko Road Expansion", "road_construction"},
  {"Bumbogo–Rusororo Bridge Works", "bridge_works"},
  {"Kibagabaga Road Widening Phase I", "road_construction"},
  {"Kacyiru Traffic Management Upgrade", "traffic_management"},
  {"Kacyiru–Kagugu Culvert Replacement", "culverts"},
  {"Nduba Road Surfacing Project", "road_construction"},
  {"Rutunga Road Construction", "road_construction"},
  {"Batsinda–Kinyinya Access Road", "road_construction"},
  {"Kimihurura Road Drainage Works", "drainage"},
  {"Jabana Road Base Course Works", "road_construction"},
  {"Ndera Road Construction Phase II", "road_construction"},
  {"Rusororo Traffic Signage Upgrade", "traffic_management"},
  {"Kinyinya Bridge Rehabilitation", "bridge_works"},
  {"Jabana–Rusororo Link Road", "road_construction"},
  {"Gikomero Road Phase I", "road_construction"},
  {"Jali Road Construction", "road_construction"},
  {"Gatsata–Gisozi Road Surfacing", "road_construction"},
  {"Gisozi Industrial Road Resurfacing", "road_construction"},
  {"Kinyinya–Ndera Road Expansion", "road_construction"},
  {"Nyacyonga Interchange Construction", "bridge_works"},
  {"Rusororo–Nduba Drainage Phase II", "drainage"},
  {"Karuruma Road Construction Project", "road_construction"},
  {"Nduba–Bumbogo Road Widening", "road_construction"}
]

projects =
  for {name, sector} <- gasabo_projects do
    budget = Float.round(50_000 + :rand.uniform() * 1_950_000, 2)
    completion = Float.round(10 + :rand.uniform() * 90, 1)
    benchmark = Float.round(budget * (0.85 + :rand.uniform() * 0.25), 2)

    {:ok, project} =
      Procurement.create_project(%{
        name: name,
        sector: sector,
        ministry_id: ministry.id,
        approved_budget: Decimal.from_float(budget),
        market_benchmark: Decimal.from_float(benchmark),
        completion_rate: Decimal.from_float(completion),
        milestones: milestones
      })

    project
  end

create_expenditure = fn project, amount, milestone ->
  Procurement.create_expenditure(%{
    project_id: project.id,
    contractor: Enum.random(contractors),
    amount: Decimal.from_float(Float.round(amount * 1.0, 2)),
    milestone: milestone,
    paid_on: random_date.()
  })
end

# 120 normal expenditures: 2-18% of each project's approved budget
for _ <- 1..120 do
  project = Enum.random(projects)
  budget = Decimal.to_float(project.approved_budget)
  fraction = 0.02 + :rand.uniform() * 0.16
  create_expenditure.(project, budget * fraction, Enum.random(milestones))
end

# Budget overrun x2 — cumulative spend exceeds approved budget
for project <- Enum.take_random(projects, 2) do
  budget = Decimal.to_float(project.approved_budget)
  create_expenditure.(project, budget * (1.3 + :rand.uniform() * 0.3), "tarmacking")
end

# Duplicate payment x2 — same contractor paid twice for the same milestone
for project <- Enum.take_random(projects, 2) do
  budget = Decimal.to_float(project.approved_budget)
  contractor = Enum.random(contractors)
  milestone = Enum.random(milestones)
  amount = budget * (0.2 + :rand.uniform() * 0.1)

  Enum.each(1..2, fn _ ->
    Procurement.create_expenditure(%{
      project_id: project.id,
      contractor: contractor,
      amount: Decimal.from_float(Float.round(amount, 2)),
      milestone: milestone,
      paid_on: random_date.()
    })
  end)
end

# Ghost project x2 — full payment against zero project completion
for project <- Enum.take_random(projects, 2) do
  {:ok, _} =
    project
    |> Ecto.Changeset.change(completion_rate: Decimal.new("0"))
    |> BudgetSentinel.Repo.update()

  budget = Decimal.to_float(project.approved_budget)
  create_expenditure.(project, budget * (0.4 + :rand.uniform() * 0.2), "road_markings")
end

# Inflated contract x2 — payment far above market benchmark
for project <- Enum.take_random(projects, 2) do
  benchmark = Decimal.to_float(project.market_benchmark || project.approved_budget)
  create_expenditure.(project, benchmark * (1.8 + :rand.uniform() * 0.4), "base_course")
end

# Premature payment x2 — large payment released ahead of reported completion
for project <- Enum.take_random(projects, 2) do
  budget = Decimal.to_float(project.approved_budget)
  create_expenditure.(project, budget * (0.55 + :rand.uniform() * 0.2), "earthworks")
end

IO.puts("Seeded #{length(projects)} Gasabo District road & infrastructure projects,")
IO.puts("Ministry of Roads and Infrastructure — including 10 embedded fraud scenarios.")
