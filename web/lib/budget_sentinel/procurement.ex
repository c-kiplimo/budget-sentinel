defmodule BudgetSentinel.Procurement do
  @moduledoc """
  Context for government projects and their expenditure records.
  """

  import Ecto.Query

  alias BudgetSentinel.Accounts.User
  alias BudgetSentinel.Procurement.{Expenditure, Project}
  alias BudgetSentinel.Repo

  def list_projects do
    Project
    |> order_by(asc: :name)
    |> Repo.all()
    |> Repo.preload(:ministry)
  end

  @doc """
  Lists projects visible to the given user: admins see every project,
  everyone else only sees projects belonging to their own ministry.
  """
  def list_projects(%User{role: "admin"}) do
    list_projects()
  end

  def list_projects(%User{ministry_id: ministry_id}) do
    Project
    |> where(ministry_id: ^ministry_id)
    |> order_by(asc: :name)
    |> Repo.all()
    |> Repo.preload(:ministry)
  end

  def get_project!(id), do: Repo.get!(Project, id) |> Repo.preload(:ministry)

  def get_project_with_expenditures!(id) do
    Project
    |> Repo.get!(id)
    |> Repo.preload([:ministry, expenditures: from(e in Expenditure, order_by: [desc: e.paid_on])])
  end

  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  def create_project(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  def list_expenditures do
    Expenditure
    |> order_by(desc: :paid_on)
    |> Repo.all()
    |> Repo.preload(:project)
  end

  def list_expenditures_for_project(project_id) do
    Expenditure
    |> where(project_id: ^project_id)
    |> order_by(desc: :paid_on)
    |> Repo.all()
  end

  def list_expenditures_for_projects([]), do: []

  def list_expenditures_for_projects(project_ids) do
    Expenditure
    |> where([e], e.project_id in ^project_ids)
    |> order_by(desc: :paid_on)
    |> Repo.all()
  end

  def get_expenditure!(id), do: Repo.get!(Expenditure, id)

  def change_expenditure(%Expenditure{} = expenditure, attrs \\ %{}) do
    Expenditure.changeset(expenditure, attrs)
  end

  def create_expenditure(attrs) do
    %Expenditure{}
    |> Expenditure.changeset(attrs)
    |> Repo.insert()
  end

  def update_expenditure(%Expenditure{} = expenditure, attrs) do
    expenditure
    |> Expenditure.changeset(attrs)
    |> Repo.update()
  end

  def delete_expenditure(%Expenditure{} = expenditure) do
    Repo.delete(expenditure)
  end

  @doc "Total amount disbursed so far for a project."
  def total_disbursed(%Project{id: project_id}) do
    Expenditure
    |> where(project_id: ^project_id)
    |> select([e], sum(e.amount))
    |> Repo.one()
    |> case do
      nil -> Decimal.new("0")
      total -> total
    end
  end

  @doc "Budget utilization as a percentage of approved budget already disbursed."
  def budget_utilization_percent(%Project{approved_budget: budget} = project) do
    disbursed = total_disbursed(project)

    if Decimal.compare(budget, Decimal.new("0")) == :gt do
      disbursed
      |> Decimal.div(budget)
      |> Decimal.mult(100)
      |> Decimal.round(1)
    else
      Decimal.new("0")
    end
  end
end
