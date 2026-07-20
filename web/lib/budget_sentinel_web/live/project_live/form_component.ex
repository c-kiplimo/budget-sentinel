defmodule BudgetSentinelWeb.ProjectLive.FormComponent do
  use BudgetSentinelWeb, :live_component

  alias BudgetSentinel.{Ministries, Procurement}

  @impl true
  def update(%{project: project} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:ministries, Ministries.list_ministries())
     |> assign(:form, to_form(Procurement.change_project(project)))}
  end

  @impl true
  def handle_event("validate", %{"project" => params}, socket) do
    changeset = Procurement.change_project(socket.assigns.project, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"project" => params}, socket) do
    save_project(socket, socket.assigns.action, params)
  end

  defp save_project(socket, :new, params) do
    case Procurement.create_project(params) do
      {:ok, project} ->
        notify_parent({:saved, project})

        {:noreply,
         socket
         |> put_flash(:info, "Project created")
         |> push_patch(to: socket.assigns.patch)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_project(socket, :edit, params) do
    case Procurement.update_project(socket.assigns.project, params) do
      {:ok, project} ->
        notify_parent({:saved, project})

        {:noreply,
         socket
         |> put_flash(:info, "Project updated")
         |> push_patch(to: socket.assigns.patch)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal-backdrop" phx-click-away="cancel" phx-target={@myself}>
      <div class="modal-panel card">
        <h2><%= if @action == :new, do: "New Project", else: "Edit Project" %></h2>
        <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
          <div class="form-field">
            <label>Name</label>
            <input type="text" name="project[name]" value={@form[:name].value} />
            <p :for={msg <- @form[:name].errors |> Enum.map(&translate_error/1)} class="form-error"><%= msg %></p>
          </div>

          <div class="form-field">
            <label>Sector</label>
            <select name="project[sector]">
              <option :for={sector <- BudgetSentinel.Procurement.Project.sectors()} value={sector} selected={@form[:sector].value == sector}>
                <%= sector |> String.replace("_", " ") |> String.split() |> Enum.map_join(" ", &String.capitalize/1) %>
              </option>
            </select>
          </div>

          <div class="form-field">
            <label>Ministry</label>
            <select name="project[ministry_id]">
              <option value="">Select a ministry</option>
              <option :for={ministry <- @ministries} value={ministry.id} selected={to_string(@form[:ministry_id].value) == to_string(ministry.id)}>
                <%= ministry.name %>
              </option>
            </select>
            <p :for={msg <- @form[:ministry_id].errors |> Enum.map(&translate_error/1)} class="form-error"><%= msg %></p>
          </div>

          <div class="form-field">
            <label>Approved Budget</label>
            <input type="number" step="0.01" name="project[approved_budget]" value={@form[:approved_budget].value} />
            <p :for={msg <- @form[:approved_budget].errors |> Enum.map(&translate_error/1)} class="form-error"><%= msg %></p>
          </div>

          <div class="form-field">
            <label>Market Benchmark</label>
            <input type="number" step="0.01" name="project[market_benchmark]" value={@form[:market_benchmark].value} />
          </div>

          <div class="form-field">
            <label>Completion Rate (%)</label>
            <input type="number" step="0.1" name="project[completion_rate]" value={@form[:completion_rate].value} />
          </div>

          <div class="modal-actions">
            <.link patch={@patch} class="btn btn--secondary">Cancel</.link>
            <button type="submit" class="btn">Save</button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp translate_error({msg, _opts}), do: msg
end
