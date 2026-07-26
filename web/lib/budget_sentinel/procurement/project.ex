defmodule BudgetSentinel.Procurement.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @sectors ~w(road_construction road_rehabilitation bridge_works drainage_works)

  schema "projects" do
    field :name, :string
    field :sector, :string
    field :approved_budget, :decimal
    field :market_benchmark, :decimal
    field :completion_rate, :decimal, default: Decimal.new("0")
    field :completion_date, :date
    field :milestones, {:array, :string}, default: []

    belongs_to :ministry, BudgetSentinel.Ministries.Ministry
    has_many :expenditures, BudgetSentinel.Procurement.Expenditure
    has_many :anomalies, BudgetSentinel.Audit.Anomaly

    timestamps(type: :utc_datetime)
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :name,
      :sector,
      :approved_budget,
      :market_benchmark,
      :completion_rate,
      :completion_date,
      :milestones,
      :ministry_id
    ])
    |> validate_required([:name, :sector, :approved_budget, :ministry_id])
    |> foreign_key_constraint(:ministry_id)
    |> validate_inclusion(:sector, @sectors)
    |> validate_number(:approved_budget, greater_than: 0)
    |> validate_number(:completion_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  def sectors, do: @sectors
end
