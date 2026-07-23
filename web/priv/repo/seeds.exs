alias BudgetSentinel.{Accounts, Audit, Ministries, Procurement, Repo}

:rand.seed(:exsplus, {42, 42, 42})

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

# Auditor: Uwase Dorcas
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

# ── Project 1: Zindiro–Masizi–Birembo–Kami Road Construction ─────────────────
# Location: Bumbogo and Kinyinya Sectors, Gasabo | Length: 14.7 km | Laterite road
# Budget: RWF 2.2B | Launched Feb 2017, 6-month planned duration | Contractor unverified
{:ok, p1} = Procurement.create_project(%{
  name: "Zindiro–Masizi–Birembo–Kami Road Construction",
  sector: "road_construction",
  ministry_id: ministry.id,
  approved_budget: Decimal.new("2200000000"),
  market_benchmark: Decimal.new("1900000000"),
  completion_rate: Decimal.from_float(35.0),
  completion_date: nil,
  milestones: milestones
})

create_exp.(p1, 310_000_000.0, "site_clearing",  "Unverified Contractor", paid.("2025-02-10"))
create_exp.(p1, 420_000_000.0, "earthworks",     "Unverified Contractor", paid.("2025-03-18"))
# Inflated: tarmacking payment far exceeds market benchmark per km
inflated_exp = create_exp.(p1, 3_800_000_000.0, "tarmacking", "Unverified Contractor", paid.("2025-05-30"))

seed_anomaly.(
  p1, inflated_exp,
  "inflated_contract", 89.0, 0.85,
  "Payment amount is well above the market benchmark for this project type.",
  "A tarmacking payment of RWF 3.8 billion was submitted against a market benchmark of RWF 1.9 billion for a 14.7 km laterite road in Bumbogo and Kinyinya Sectors. The payment represents 200% of the established benchmark, with no contractor formally verified.",
  "HIGH — payment exceeds the market benchmark by 100%. Combined with an unverified contractor, this is a strong indicator of inflated contract pricing.",
  "1. Suspend further disbursements pending contractor verification.\n2. Commission an independent valuation of works completed to date.\n3. Refer to Rwanda Public Procurement Authority (RPPA) for contractor eligibility review.\n4. Require documentary evidence of works completed before any further payment authorisation."
)

# ── Project 2: Cumi na Gatanu–Ndera–Kibenga Road ─────────────────────────────
# Location: Ndera Sector, Gasabo | Length: 2.7 km | Asphalt road | 2 phases
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

create_exp.(p2,  380_000_000.0, "site_clearing", "HORIZON Ltd", paid.("2025-01-20"))
create_exp.(p2,  560_000_000.0, "earthworks",    "HORIZON Ltd", paid.("2025-02-28"))
create_exp.(p2,  490_000_000.0, "base_course",   "HORIZON Ltd", paid.("2025-04-05"))
# Duplicate: same contractor paid twice for the same milestone and amount
dup_exp = create_exp.(p2, 720_000_000.0, "tarmacking", "HORIZON Ltd", paid.("2025-05-12"))
_dup2   = create_exp.(p2, 720_000_000.0, "tarmacking", "HORIZON Ltd", paid.("2025-05-12"))

seed_anomaly.(
  p2, dup_exp,
  "duplicate_payment", 81.0, 0.78,
  "Same contractor was paid more than once for the same milestone.",
  "HORIZON Ltd received two identical payments of RWF 720,000,000 for the 'tarmacking' milestone on 2025-05-12. Total duplicate exposure: RWF 720,000,000. The project was officially opened in March 2019, making a 2025 tarmacking disbursement anomalous.",
  "HIGH — exact duplicate payment detected on a completed project. One payment is almost certainly unauthorised.",
  "1. Place an immediate hold on the duplicate payment of RWF 720,000,000.\n2. Request HORIZON Ltd to provide separate invoices and completion certificates for both transactions.\n3. Initiate recovery proceedings for the duplicate amount.\n4. Audit all post-completion payments on this project since March 2019."
)

# ── Project 3: Karuruma–Bweramvura Asphalt Road ──────────────────────────────
# Location: Gasabo District (Kinyinya Sector) | Length: 7.8 km | Asphalt road
# Budget: RWF 1,041,983,838 | Contractor: JV ECOTRA–EGETRACO | Contract: RWF 860.15M
# Completed; 95.48% disbursement
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

create_exp.(p3, 120_000_000.0, "site_clearing", "JV ECOTRA-EGETRACO", paid.("2025-01-15"))
create_exp.(p3, 195_000_000.0, "earthworks",    "JV ECOTRA-EGETRACO", paid.("2025-02-20"))
create_exp.(p3, 210_000_000.0, "base_course",   "JV ECOTRA-EGETRACO", paid.("2025-03-25"))
# Premature: large final payment released at 95% completion before project sign-off
premature_exp = create_exp.(p3, 860_000_000.0, "road_markings", "JV ECOTRA-EGETRACO", paid.("2025-04-10"))

seed_anomaly.(
  p3, premature_exp,
  "premature_payment", 76.0, 0.72,
  "Payment amount far exceeds the project's reported completion percentage.",
  "A final payment of RWF 860,000,000 (representing 82.5% of the approved budget) was released to JV ECOTRA–EGETRACO when the project was only 95% complete and prior to formal sign-off. Total disbursement of RWF 1,385,000,000 now exceeds the approved budget of RWF 1,041,983,838.",
  "HIGH — full contract payment released before formal completion certificate. Combined with total disbursements exceeding the approved budget, this warrants immediate review.",
  "1. Withhold remaining payment pending issuance of a formal project completion certificate.\n2. Reconcile total disbursements against approved budget and contract value.\n3. Verify road markings phase was completed to specification before final payment.\n4. Review approval chain for the RWF 860M release authorisation."
)

IO.puts("Seeded 3 real Gasabo District road projects:")
IO.puts("  1. Zindiro–Masizi–Birembo–Kami Road Construction  (RWF 2.2B) — inflated contract (89.0)")
IO.puts("  2. Cumi na Gatanu–Ndera–Kibenga Road              (RWF 2.5B) — duplicate payment (81.0)")
IO.puts("  3. Karuruma–Bweramvura Asphalt Road               (RWF 1.04B) — premature payment (76.0)")
IO.puts("  Department: Gasabo District Infrastructure Department")
IO.puts("  Alerts dispatched to: #{Enum.join(alert_recipients, ", ")}")
