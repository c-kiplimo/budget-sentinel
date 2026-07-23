alias BudgetSentinel.{Accounts, Audit, Ministries, Procurement, Repo}

:rand.seed(:exsplus, {42, 42, 42})

{:ok, ministry} =
  case Ministries.list_ministries() |> Enum.find(&(&1.code == "GASABO-INFRA")) do
    nil -> Ministries.create_ministry(%{name: "Gasabo District Infrastructure Department", code: "GASABO-INFRA"})
    existing -> {:ok, existing}
  end

if is_nil(Accounts.get_user_by_email("admin@budgetsentinel.online")) do
  {:ok, _} = Accounts.create_user_by_admin(%{
    email: "admin@budgetsentinel.online",
    password: "BudgetSentinel!1234",
    role: "admin"
  })
end

if is_nil(Accounts.get_user_by_email("uwasedorcas22@gmail.com")) do
  {:ok, _} = Accounts.create_user_by_admin(%{
    email: "uwasedorcas22@gmail.com",
    password: "BudgetSentinel!1234",
    role: "auditor",
    ministry_id: ministry.id
  })
end

milestones = ~w(site_clearing earthworks base_course tarmacking road_markings)
alert_recipients = ["uwasedorcas22@gmail.com", "admin@budgetsentinel.online"]

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
  for recipient <- alert_recipients, do: Audit.log_alert(anomaly, recipient, "sent")
  anomaly
end

# ═══════════════════════════════════════════════════════════════════════════════
# ORIGINAL 3 PROJECTS (real Gasabo District projects)
# ═══════════════════════════════════════════════════════════════════════════════

# ── Project 1: Zindiro–Masizi–Birembo–Kami Road Construction ─────────────────
# Location: Bumbogo and Kinyinya Sectors | Length: 14.7 km | Laterite road
# Budget: RWF 2.2B | Launched Feb 2017, 6-month duration | Completion: Aug 2017
{:ok, p1} = Procurement.create_project(%{
  name: "Zindiro–Masizi–Birembo–Kami Road Construction",
  sector: "road_construction",
  ministry_id: ministry.id,
  approved_budget: Decimal.new("2200000000"),
  market_benchmark: Decimal.new("1900000000"),
  completion_rate: Decimal.from_float(35.0),
  completion_date: ~D[2017-08-31],
  milestones: milestones
})

p1_exp = create_exp.(p1, 310_000_000.0, "site_clearing", "Unverified Contractor", paid.("2025-02-10"))
create_exp.(p1, 420_000_000.0, "earthworks",    "Unverified Contractor", paid.("2025-03-18"))
create_exp.(p1, 680_000_000.0, "tarmacking",    "Unverified Contractor", paid.("2025-05-30"))
Audit.record_anomaly(%{fraud_type: "unclassified_anomaly", risk_score: Decimal.from_float(22.0), severity: "low", anomaly_score: Decimal.from_float(0.22), explanation: "Budget variance reviewed; contractor rates verified and approved by district engineer.", project_id: p1.id, expenditure_id: p1_exp.id, detected_at: ~U[2025-03-20 09:00:00Z], status: "resolved"})

# ── Project 2: Cumi na Gatanu–Ndera–Kibenga Road ─────────────────────────────
# Location: Ndera Sector | Length: 2.7 km | Asphalt road | 2 phases
# Budget: RWF 2.5B | Contractor: HORIZON | Opened March 2019
{:ok, p2} = Procurement.create_project(%{
  name: "Cumi na Gatanu–Ndera–Kibenga Road",
  sector: "road_construction",
  ministry_id: ministry.id,
  approved_budget: Decimal.new("2500000000"),
  market_benchmark: Decimal.new("2300000000"),
  completion_rate: Decimal.from_float(100.0),
  completion_date: ~D[2019-03-15],
  milestones: milestones
})

p2_exp = create_exp.(p2, 380_000_000.0, "site_clearing", "HORIZON Ltd", paid.("2025-01-20"))
create_exp.(p2, 560_000_000.0, "earthworks",    "HORIZON Ltd", paid.("2025-02-28"))
create_exp.(p2, 490_000_000.0, "base_course",   "HORIZON Ltd", paid.("2025-04-05"))
create_exp.(p2, 720_000_000.0, "tarmacking",    "HORIZON Ltd", paid.("2025-05-12"))
Audit.record_anomaly(%{fraud_type: "unclassified_anomaly", risk_score: Decimal.from_float(18.0), severity: "low", anomaly_score: Decimal.from_float(0.18), explanation: "Two-phase payment structure reviewed; scope changes formally approved by procurement committee.", project_id: p2.id, expenditure_id: p2_exp.id, detected_at: ~U[2025-02-25 09:00:00Z], status: "resolved"})

# ── Project 3: Karuruma–Bweramvura Asphalt Road ──────────────────────────────
# Location: Kinyinya Sector | Length: 7.8 km | Asphalt road
# Budget: RWF 1,041,983,838 | Contractor: JV ECOTRA–EGETRACO | Completed 2022
{:ok, p3} = Procurement.create_project(%{
  name: "Karuruma–Bweramvura Asphalt Road",
  sector: "road_construction",
  ministry_id: ministry.id,
  approved_budget: Decimal.new("1041983838"),
  market_benchmark: Decimal.new("900000000"),
  completion_rate: Decimal.from_float(95.0),
  completion_date: ~D[2022-06-30],
  milestones: milestones
})

p3_exp = create_exp.(p3, 120_000_000.0, "site_clearing", "JV ECOTRA-EGETRACO", paid.("2025-01-15"))
create_exp.(p3, 195_000_000.0, "earthworks",    "JV ECOTRA-EGETRACO", paid.("2025-02-20"))
create_exp.(p3, 210_000_000.0, "base_course",   "JV ECOTRA-EGETRACO", paid.("2025-03-25"))
create_exp.(p3, 340_000_000.0, "road_markings", "JV ECOTRA-EGETRACO", paid.("2025-04-10"))
Audit.record_anomaly(%{fraud_type: "unclassified_anomaly", risk_score: Decimal.from_float(15.0), severity: "low", anomaly_score: Decimal.from_float(0.15), explanation: "Sub-contractor rates and joint venture agreement reviewed; no irregularities found.", project_id: p3.id, expenditure_id: p3_exp.id, detected_at: ~U[2025-01-20 09:00:00Z], status: "resolved"})

# ═══════════════════════════════════════════════════════════════════════════════
# 3 ADDITIONAL GASABO DISTRICT PROJECTS WITH ANOMALIES
# ═══════════════════════════════════════════════════════════════════════════════

# ── Project 4: Jabana–Rusororo Bridge Construction ───────────────────────────
# Location: Jabana and Rusororo Sectors, Gasabo | Bridge works
# Budget: RWF 780M | Ghost project: 0% completion, large payment disbursed
{:ok, p4} = Procurement.create_project(%{
  name: "Jabana–Rusororo Bridge Construction",
  sector: "bridge_works",
  ministry_id: ministry.id,
  approved_budget: Decimal.new("780000000"),
  market_benchmark: Decimal.new("720000000"),
  completion_rate: Decimal.from_float(0.0),
  completion_date: ~D[2025-12-31],
  milestones: milestones
})

ghost_exp = create_exp.(p4, 590_000_000.0, "road_markings", "Rusororo Construction Works", paid.("2025-04-22"))

seed_anomaly.(
  p4, ghost_exp,
  "ghost_project", 93.0, 0.91,
  "Full payment was disbursed against a project reporting zero completion.",
  "RWF 590,000,000 (75.6% of approved budget) was disbursed to Rusororo Construction Works for road markings on the Jabana–Rusororo Bridge, yet the project records 0% physical completion. No site inspection report has been filed and no works have been verified.",
  "CRITICAL — significant payment disbursed against a project with no recorded site progress. This is consistent with a fictitious or ghost project.",
  "1. Immediately freeze all remaining funds allocated to this project.\n2. Conduct an urgent site inspection to verify whether any bridge works have commenced.\n3. Refer to the Office of the Auditor General (OAG) for forensic investigation.\n4. Suspend Rusororo Construction Works from future procurement pending outcome.\n5. Investigate the authorising officer who approved payment without site verification."
)

# ── Project 5: Nduba Sector Drainage Rehabilitation ──────────────────────────
# Location: Nduba Sector, Gasabo | Drainage works
# Budget: RWF 420M | Budget overrun: cumulative spending exceeds approved budget
{:ok, p5} = Procurement.create_project(%{
  name: "Nduba Sector Drainage Rehabilitation",
  sector: "drainage",
  ministry_id: ministry.id,
  approved_budget: Decimal.new("420000000"),
  market_benchmark: Decimal.new("390000000"),
  completion_rate: Decimal.from_float(78.0),
  completion_date: ~D[2025-09-30],
  milestones: milestones
})

create_exp.(p5,  85_000_000.0, "site_clearing", "Nduba Tarmac Contractors", paid.("2025-01-08"))
create_exp.(p5, 110_000_000.0, "earthworks",    "Nduba Tarmac Contractors", paid.("2025-02-14"))
create_exp.(p5,  95_000_000.0, "base_course",   "Nduba Tarmac Contractors", paid.("2025-03-20"))
overrun_exp = create_exp.(p5, 310_000_000.0, "tarmacking", "Nduba Tarmac Contractors", paid.("2025-05-08"))

seed_anomaly.(
  p5, overrun_exp,
  "budget_overrun", 83.0, 0.80,
  "Cumulative project spending has exceeded the approved budget.",
  "Cumulative expenditure on the Nduba Sector Drainage Rehabilitation project has reached RWF 600,000,000 against an approved budget of RWF 420,000,000 — a 42.9% overrun. The tarmacking payment of RWF 310,000,000 pushed spending RWF 180,000,000 beyond the authorised limit.",
  "HIGH — budget overrun of 42.9% with no supplementary budget authorisation on record.",
  "1. Immediately halt further payments until a budget revision is approved by the appropriate authority.\n2. Require the project manager to submit a written justification for the cost overrun.\n3. Commission a value-for-money audit on all expenditures to date.\n4. Verify that scope changes, if any, were formally approved before additional costs were incurred."
)

# ── Project 6: Gisozi–Kacyiru Road Culvert Works ─────────────────────────────
# Location: Gisozi and Kacyiru Sectors, Gasabo | Culvert works
# Budget: RWF 310M | Duplicate payment on foundation works
{:ok, p6} = Procurement.create_project(%{
  name: "Gisozi–Kacyiru Road Culvert Works",
  sector: "culverts",
  ministry_id: ministry.id,
  approved_budget: Decimal.new("310000000"),
  market_benchmark: Decimal.new("285000000"),
  completion_rate: Decimal.from_float(55.0),
  completion_date: ~D[2025-11-30],
  milestones: milestones
})

create_exp.(p6, 42_000_000.0, "site_clearing", "Gisozi Engineering Partners", paid.("2025-01-25"))
create_exp.(p6, 68_000_000.0, "earthworks",    "Gisozi Engineering Partners", paid.("2025-03-10"))
dup6_exp = create_exp.(p6, 95_000_000.0, "base_course", "Gisozi Engineering Partners", paid.("2025-04-18"))
_dup6b   = create_exp.(p6, 95_000_000.0, "base_course", "Gisozi Engineering Partners", paid.("2025-04-18"))

seed_anomaly.(
  p6, dup6_exp,
  "duplicate_payment", 77.0, 0.74,
  "Same contractor was paid more than once for the same milestone.",
  "Gisozi Engineering Partners received two identical payments of RWF 95,000,000 for the 'base_course' milestone on 2025-04-18, resulting in a duplicate disbursement of RWF 95,000,000. Total payments on this milestone alone exceed the originally scoped amount.",
  "HIGH — exact duplicate payment of RWF 95,000,000 detected. The erroneous payment represents 30.6% of the total project budget.",
  "1. Place an immediate hold on the second payment of RWF 95,000,000.\n2. Require Gisozi Engineering Partners to return the duplicate payment within 14 days.\n3. Review the payment approval workflow for missing dual-authorisation controls on this contract.\n4. Verify that base course works were completed to specification before either payment was released."
)

IO.puts("Seeded 6 Gasabo District projects:")
IO.puts("  No anomalies:")
IO.puts("    1. Zindiro-Masizi-Birembo-Kami Road Construction  (RWF 2.2B)")
IO.puts("    2. Cumi na Gatanu-Ndera-Kibenga Road              (RWF 2.5B)")
IO.puts("    3. Karuruma-Bweramvura Asphalt Road               (RWF 1.04B)")
IO.puts("  With anomalies and alerts:")
IO.puts("    4. Jabana-Rusororo Bridge Construction  (RWF 780M)  — ghost project    (93.0)")
IO.puts("    5. Nduba Sector Drainage Rehabilitation (RWF 420M)  — budget overrun   (83.0)")
IO.puts("    6. Gisozi-Kacyiru Road Culvert Works   (RWF 310M)  — duplicate payment (77.0)")
IO.puts("  Alerts dispatched to: #{Enum.join(alert_recipients, ", ")}")
