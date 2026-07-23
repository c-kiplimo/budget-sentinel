alias BudgetSentinel.{Accounts, Audit, Ministries, Procurement, Repo}

:rand.seed(:exsplus, {42, 42, 42})

# Single ministry: Ministry of Roads and Infrastructure — Gasabo District
{:ok, ministry} =
  case Ministries.list_ministries() |> Enum.find(&(&1.code == "GASABO-INFRA")) do
    nil -> Ministries.create_ministry(%{name: "Gasabo District Infrastructure Department", code: "GASABO-INFRA"})
    existing -> {:ok, existing}
  end

# Admin account
if is_nil(Accounts.get_user_by_email("admin@budgetsentinel.online")) do
  {:ok, _} = Accounts.create_user_by_admin(%{
    email: "admin@budgetsentinel.online",
    password: "BudgetSentinel!1234",
    role: "admin"
  })
end

# Auditor: Uwase Dorcas — Ministry of Roads and Infrastructure
if is_nil(Accounts.get_user_by_email("uwasedorcas22@gmail.com")) do
  {:ok, _} = Accounts.create_user_by_admin(%{
    email: "uwasedorcas22@gmail.com",
    password: "BudgetSentinel!1234",
    role: "auditor",
    ministry_id: ministry.id
  })
end

milestones = ~w(site_clearing earthworks base_course tarmacking road_markings)

paid = fn date_str -> Date.from_iso8601!(date_str) end

create_exp = fn project, amount, milestone, contractor, date ->
  {:ok, exp} = Procurement.create_expenditure(%{
    project_id: project.id,
    contractor: contractor,
    amount: Decimal.from_float(Float.round(amount, 2)),
    milestone: milestone,
    paid_on: date
  })
  exp
end

alert_recipients = ["uwasedorcas22@gmail.com", "admin@budgetsentinel.online"]

seed_anomaly = fn project, expenditure, fraud_type, risk_score, anomaly_score, explanation, report_summary, report_severity, report_actions ->
  {:ok, anomaly} = Audit.record_anomaly(%{
    fraud_type: fraud_type,
    risk_score: Decimal.from_float(risk_score * 1.0),
    severity: if(risk_score >= 70, do: "high", else: if(risk_score >= 40, do: "medium", else: "low")),
    anomaly_score: Decimal.from_float(anomaly_score * 1.0),
    explanation: explanation,
    project_id: project.id,
    expenditure_id: expenditure.id,
    detected_at: ~U[2025-06-15 08:30:00Z],
    status: "open"
  })

  Audit.attach_report(anomaly, %{
    "anomaly_id" => anomaly.id,
    "summary" => report_summary,
    "severity_assessment" => report_severity,
    "recommended_actions" => report_actions
  })

  for recipient <- alert_recipients do
    Audit.log_alert(anomaly, recipient, "sent")
  end

  anomaly
end

# ── Project 1: Inflated Contract ──────────────────────────────────────────────
{:ok, p1} = Procurement.create_project(%{
  name: "Kimironko–Remera Road Rehabilitation",
  sector: "road_construction",
  ministry_id: ministry.id,
  approved_budget: Decimal.from_float(1_200_000.00),
  market_benchmark: Decimal.from_float(1_100_000.00),
  completion_rate: Decimal.from_float(62.0),
  milestones: milestones
})

create_exp.(p1, 180_000.00, "site_clearing",  "Kimironko Infrastructure Group", paid.("2025-02-10"))
create_exp.(p1, 210_000.00, "earthworks",     "Remera Road Builders",           paid.("2025-03-18"))
create_exp.(p1, 155_000.00, "base_course",    "Kimironko Infrastructure Group", paid.("2025-04-22"))
tarmacking_exp = create_exp.(p1, 2_420_000.00, "tarmacking", "Gasabo Roads Ltd", paid.("2025-05-30"))

seed_anomaly.(
  p1, tarmacking_exp,
  "inflated_contract", 87.5, 0.82,
  "Payment amount is well above the market benchmark for this project type.",
  "A tarmacking payment of RWF 2,420,000 was made against a market benchmark of RWF 1,100,000 — representing 220% of the expected rate. This is a strong indicator of contract price inflation.",
  "HIGH — payment exceeds market benchmark by 120%. Likely collusion between contractor and procurement officer.",
  "1. Suspend further payments to Gasabo Roads Ltd pending investigation.\n2. Commission an independent valuation of tarmacking works completed.\n3. Forward to Rwanda Public Procurement Authority (RPPA) for audit.\n4. Review all contracts awarded to this contractor in the last 24 months."
)

# ── Project 2: Duplicate Payment ─────────────────────────────────────────────
{:ok, p2} = Procurement.create_project(%{
  name: "Kinyinya Bridge Rehabilitation",
  sector: "bridge_works",
  ministry_id: ministry.id,
  approved_budget: Decimal.from_float(850_000.00),
  market_benchmark: Decimal.from_float(820_000.00),
  completion_rate: Decimal.from_float(45.0),
  milestones: milestones
})

create_exp.(p2,  95_000.00, "site_clearing", "Bumbogo Civil Works",         paid.("2025-01-20"))
create_exp.(p2, 130_000.00, "earthworks",    "Nduba Tarmac Contractors",    paid.("2025-02-28"))
dup_exp1 = create_exp.(p2, 280_000.00, "base_course", "Rusororo Construction Works", paid.("2025-04-05"))
_dup_exp2 = create_exp.(p2, 280_000.00, "base_course", "Rusororo Construction Works", paid.("2025-04-05"))

seed_anomaly.(
  p2, dup_exp1,
  "duplicate_payment", 79.0, 0.76,
  "Same contractor was paid more than once for the same milestone.",
  "Rusororo Construction Works received two identical payments of RWF 280,000 for the 'base_course' milestone on the same date (2025-04-05). Total duplicate exposure: RWF 280,000.",
  "HIGH — exact duplicate payment detected. One payment is likely unauthorised.",
  "1. Place an immediate hold on the second payment of RWF 280,000.\n2. Require Rusororo Construction Works to provide invoices for both transactions.\n3. Initiate recovery proceedings for the duplicate amount.\n4. Review payment approval workflow for missing dual-authorisation controls."
)

# ── Project 3: Ghost Project ──────────────────────────────────────────────────
{:ok, p3} = Procurement.create_project(%{
  name: "Kacyiru–Kagugu Culvert Replacement",
  sector: "culverts",
  ministry_id: ministry.id,
  approved_budget: Decimal.from_float(620_000.00),
  market_benchmark: Decimal.from_float(590_000.00),
  completion_rate: Decimal.from_float(0.0),
  milestones: milestones
})

ghost_exp = create_exp.(p3, 490_000.00, "road_markings", "Gisozi Engineering Partners", paid.("2025-03-12"))

seed_anomaly.(
  p3, ghost_exp,
  "ghost_project", 93.0, 0.91,
  "Full payment was disbursed against a project reporting zero completion.",
  "RWF 490,000 (79% of approved budget) was disbursed to Gisozi Engineering Partners for road markings, yet the project records 0% physical completion. No site work has been verified.",
  "CRITICAL — payment disbursed against a non-existent or uninitiated project. High likelihood of fictitious contract.",
  "1. Immediately freeze all remaining funds allocated to this project.\n2. Conduct an urgent site inspection to verify whether any works have commenced.\n3. Refer to the Office of the Auditor General (OAG) for forensic investigation.\n4. Suspend Gisozi Engineering Partners from future procurement pending outcome.\n5. Investigate the authorising officer who approved payment without site verification."
)

IO.puts("Seeded 3 Gasabo District projects with anomalies and alerts:")
IO.puts("  1. Kimironko–Remera Road Rehabilitation  — inflated contract   (risk: 87.5)")
IO.puts("  2. Kinyinya Bridge Rehabilitation         — duplicate payment   (risk: 79.0)")
IO.puts("  3. Kacyiru–Kagugu Culvert Replacement     — ghost project       (risk: 93.0)")
IO.puts("  Department: Gasabo District Infrastructure Department")
IO.puts("  Alerts dispatched to: #{Enum.join(alert_recipients, ", ")}")
