defmodule BudgetSentinelWeb.ProjectLive.Show do
  use BudgetSentinelWeb, :live_view

  alias BudgetSentinel.Accounts.User
  alias BudgetSentinel.Procurement
  alias BudgetSentinel.Procurement.Expenditure

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = Procurement.get_project_with_expenditures!(id)
    user = socket.assigns.current_user

    if User.admin?(user) or project.ministry_id == user.ministry_id do
      {:ok, assign(socket, project: project, utilization: Procurement.budget_utilization_percent(project))}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have access to that project.")
       |> push_navigate(to: ~p"/projects")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, _params) do
    if User.can_manage?(socket.assigns.current_user) do
      assign(socket, :page_title, "Edit Project")
    else
      socket
      |> put_flash(:error, "You don't have permission to edit projects.")
      |> push_patch(to: ~p"/projects/#{socket.assigns.project.id}")
    end
  end

  defp apply_action(socket, :new_expenditure, _params) do
    if User.can_manage?(socket.assigns.current_user) do
      assign(socket, :expenditure, %Expenditure{})
    else
      socket
      |> put_flash(:error, "You don't have permission to add expenditures.")
      |> push_patch(to: ~p"/projects/#{socket.assigns.project.id}")
    end
  end

  defp apply_action(socket, :edit_expenditure, %{"expenditure_id" => expenditure_id}) do
    if User.can_manage?(socket.assigns.current_user) do
      assign(socket, :expenditure, Procurement.get_expenditure!(expenditure_id))
    else
      socket
      |> put_flash(:error, "You don't have permission to edit expenditures.")
      |> push_patch(to: ~p"/projects/#{socket.assigns.project.id}")
    end
  end

  defp apply_action(socket, _action, _params), do: socket

  @impl true
  def handle_event("delete_project", _params, socket) do
    if User.can_manage?(socket.assigns.current_user) do
      {:ok, _} = Procurement.delete_project(socket.assigns.project)

      {:noreply,
       socket
       |> put_flash(:info, "Project deleted")
       |> push_navigate(to: ~p"/projects")}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to delete projects.")}
    end
  end

  def handle_event("delete_expenditure", %{"id" => id}, socket) do
    if User.can_manage?(socket.assigns.current_user) do
      expenditure = Procurement.get_expenditure!(id)
      {:ok, _} = Procurement.delete_expenditure(expenditure)
      {:noreply, reload_project(socket)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to delete expenditures.")}
    end
  end

  @impl true
  def handle_info({BudgetSentinelWeb.ProjectLive.FormComponent, {:saved, _project}}, socket) do
    {:noreply, reload_project(socket)}
  end

  def handle_info({BudgetSentinelWeb.ExpenditureLive.FormComponent, {:saved, _expenditure}}, socket) do
    {:noreply, reload_project(socket)}
  end

  defp reload_project(socket) do
    project = Procurement.get_project_with_expenditures!(socket.assigns.project.id)
    assign(socket, project: project, utilization: Procurement.budget_utilization_percent(project))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-heading">
      <h1><%= @project.name %></h1>
      <div :if={User.can_manage?(@current_user)} class="row-actions">
        <.link patch={~p"/projects/#{@project.id}/edit"} class="btn btn--secondary">Edit</.link>
        <button class="btn btn--danger" phx-click="delete_project" data-confirm="Delete this project and all its data?">
          Delete
        </button>
      </div>
    </div>

    <div class="stat-row">
      <.stat_card label="Sector" value={@project.sector |> String.replace("_", " ") |> String.split() |> Enum.map_join(" ", &String.capitalize/1)} />
      <.stat_card label="Ministry" value={@project.ministry && @project.ministry.name} />
      <.stat_card label="Approved Budget" value={Decimal.to_string(@project.approved_budget)} />
      <.stat_card label="Completion" value={"#{@project.completion_rate}%"} accent="secondary" />
      <.stat_card label="Completion Date" value={if @project.completion_date, do: Date.to_string(@project.completion_date), else: "Not set"} />
      <.stat_card label="Budget Utilization" value={"#{@utilization}%"} accent="secondary" />
    </div>

    <div class="card">
      <div class="page-heading">
        <h2>Expenditures</h2>
        <.link :if={User.can_manage?(@current_user)} patch={~p"/projects/#{@project.id}/expenditures/new"} class="btn">
          Add Expenditure
        </.link>
      </div>
      <div :if={@project.expenditures == []} class="empty-state">
        No expenditures recorded for this project yet.
      </div>
      <table :if={@project.expenditures != []} class="data-table">
        <thead>
          <tr>
            <th>Date</th>
            <th>Contractor</th>
            <th>Milestone</th>
            <th>Amount</th>
            <th :if={User.can_manage?(@current_user)}>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={expenditure <- @project.expenditures}>
            <td><%= expenditure.paid_on %></td>
            <td><%= expenditure.contractor %></td>
            <td><%= String.capitalize(String.replace(expenditure.milestone, "_", " ")) %></td>
            <td><%= Decimal.to_string(expenditure.amount) %></td>
            <td :if={User.can_manage?(@current_user)}>
              <div class="row-actions">
                <.link patch={~p"/projects/#{@project.id}/expenditures/#{expenditure.id}/edit"} class="btn--link">
                  Edit
                </.link>
                <button
                  class="btn--link"
                  phx-click="delete_expenditure"
                  phx-value-id={expenditure.id}
                  data-confirm="Delete this expenditure?"
                >
                  Delete
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <.live_component
      :if={@live_action == :edit}
      module={BudgetSentinelWeb.ProjectLive.FormComponent}
      id="edit-project"
      action={:edit}
      project={@project}
      patch={~p"/projects/#{@project.id}"}
    />

    <.live_component
      :if={@live_action in [:new_expenditure, :edit_expenditure]}
      module={BudgetSentinelWeb.ExpenditureLive.FormComponent}
      id="expenditure-form"
      action={if @live_action == :new_expenditure, do: :new, else: :edit}
      expenditure={@expenditure}
      project_id={@project.id}
      patch={~p"/projects/#{@project.id}"}
    />
    """
  end
end
