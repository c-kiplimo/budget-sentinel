defmodule BudgetSentinelWeb.ProjectLive.Index do
  use BudgetSentinelWeb, :live_view

  alias BudgetSentinel.Accounts.User
  alias BudgetSentinel.Procurement
  alias BudgetSentinel.Procurement.Project

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :projects, Procurement.list_projects(socket.assigns.current_user))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    if User.can_manage?(socket.assigns.current_user) do
      socket
      |> assign(:page_title, "New Project")
      |> assign(:project, %Project{})
    else
      socket
      |> put_flash(:error, "You don't have permission to create projects.")
      |> push_patch(to: ~p"/projects")
    end
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Gasabo District Projects")
  end

  @impl true
  def handle_info({BudgetSentinelWeb.ProjectLive.FormComponent, {:saved, _project}}, socket) do
    {:noreply, assign(socket, :projects, Procurement.list_projects(socket.assigns.current_user))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-heading">
      <h1>Gasabo District — Roads &amp; Infrastructure Projects</h1>
      <.link :if={User.can_manage?(@current_user)} patch={~p"/projects/new"} class="btn">
        New Project
      </.link>
    </div>

    <div class="card">
      <table class="data-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Sector</th>
            <th>Ministry</th>
            <th>Approved Budget</th>
            <th>Completion</th>
            <th>Budget Utilization</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={project <- @projects}>
            <td><.link navigate={~p"/projects/#{project.id}"}><%= project.name %></.link></td>
            <td><%= project.sector |> String.replace("_", " ") |> String.split() |> Enum.map_join(" ", &String.capitalize/1) %></td>
            <td><%= project.ministry && project.ministry.name %></td>
            <td><%= Decimal.to_string(project.approved_budget) %></td>
            <td><%= Decimal.to_string(project.completion_rate) %>%</td>
            <td><.budget_bar percent={Procurement.budget_utilization_percent(project)} /></td>
          </tr>
        </tbody>
      </table>
    </div>

    <.live_component
      :if={@live_action == :new}
      module={BudgetSentinelWeb.ProjectLive.FormComponent}
      id="new-project"
      action={:new}
      project={@project}
      patch={~p"/projects"}
    />
    """
  end
end
