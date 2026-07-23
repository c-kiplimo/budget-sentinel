defmodule BudgetSentinel.Audit do
  @moduledoc """
  Context for detected anomalies, AI-generated audit reports, and dispatched alerts.
  """

  import Ecto.Query

  alias BudgetSentinel.Accounts.User
  alias BudgetSentinel.Audit.{Alert, Anomaly, AuditReport}
  alias BudgetSentinel.Repo

  def list_anomalies(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Anomaly
    |> maybe_filter_anomaly_status(Keyword.get(opts, :status))
    |> order_by(desc: :detected_at)
    |> limit(^limit)
    |> preload([:project, :expenditure, :audit_report])
    |> Repo.all()
  end

  @doc """
  Lists anomalies visible to the given user: admins see every anomaly,
  everyone else only sees anomalies for projects in their own ministry.
  Accepts an optional `:status` filter.
  """
  def list_anomalies(%User{role: "admin"}, opts), do: list_anomalies(opts)

  def list_anomalies(%User{ministry_id: ministry_id}, opts) do
    limit = Keyword.get(opts, :limit, 50)

    Anomaly
    |> join(:inner, [a], p in assoc(a, :project), on: p.ministry_id == ^ministry_id)
    |> maybe_filter_anomaly_status(Keyword.get(opts, :status))
    |> order_by(desc: :detected_at)
    |> limit(^limit)
    |> preload([:project, :expenditure, :audit_report])
    |> Repo.all()
  end

  defp maybe_filter_anomaly_status(query, nil), do: query
  defp maybe_filter_anomaly_status(query, status), do: from(a in query, where: a.status == ^status)

  @doc """
  Counts high-severity anomalies that are still outstanding (open or under
  review), scoped to the given user's ministry.
  """
  def count_open_high_risk(%User{role: "admin"}) do
    Anomaly
    |> where([a], a.severity == "high" and a.status in ["open", "under_review"])
    |> select([a], count(a.id))
    |> Repo.one()
  end

  def count_open_high_risk(%User{ministry_id: ministry_id}) do
    Anomaly
    |> join(:inner, [a], p in assoc(a, :project), on: p.ministry_id == ^ministry_id)
    |> where([a], a.severity == "high" and a.status in ["open", "under_review"])
    |> select([a], count(a.id))
    |> Repo.one()
  end

  def get_anomaly!(id) do
    Anomaly
    |> preload([:project, :expenditure, :audit_report, :alerts, :reviewed_by])
    |> Repo.get!(id)
  end

  def record_anomaly(attrs) do
    %Anomaly{}
    |> Anomaly.changeset(
      attrs
      |> Map.put_new(:detected_at, DateTime.utc_now() |> DateTime.truncate(:second))
      |> Map.put_new(:status, "open")
    )
    |> Repo.insert()
  end

  def anomaly_exists_for_expenditure?(expenditure_id) do
    Repo.exists?(from a in Anomaly, where: a.expenditure_id == ^expenditure_id)
  end

  @doc "Returns an `%Ecto.Changeset{}` for the anomaly status-update form."
  def change_anomaly_status(%Anomaly{} = anomaly, attrs \\ %{}) do
    Anomaly.status_changeset(anomaly, attrs)
  end

  @doc """
  Actions an anomaly: updates its status and resolution notes, recording who
  reviewed it and when.
  """
  def update_anomaly_status(%Anomaly{} = anomaly, attrs, %User{} = reviewer) do
    attrs =
      Map.merge(attrs, %{
        "reviewed_by_id" => reviewer.id,
        "reviewed_at" => DateTime.utc_now() |> DateTime.truncate(:second)
      })

    anomaly
    |> Anomaly.status_changeset(attrs)
    |> Repo.update()
  end

  def attach_report(%Anomaly{} = anomaly, attrs) do
    %AuditReport{}
    |> AuditReport.changeset(Map.put(attrs, "anomaly_id", anomaly.id))
    |> Repo.insert()
  end

  def log_alert(%Anomaly{} = anomaly, recipient, status) do
    dispatched_at = if status == "sent", do: DateTime.utc_now() |> DateTime.truncate(:second)

    %Alert{}
    |> Alert.changeset(%{
      anomaly_id: anomaly.id,
      recipient: recipient,
      status: status,
      dispatched_at: dispatched_at
    })
    |> Repo.insert()
  end

  @doc "Updates an existing alert's dispatch status, e.g. after a manual retry."
  def update_alert_status(%Alert{} = alert, status) do
    attrs =
      if status == "sent" do
        %{status: status, dispatched_at: DateTime.utc_now() |> DateTime.truncate(:second)}
      else
        %{status: status}
      end

    alert
    |> Alert.changeset(attrs)
    |> Repo.update()
  end

  def get_alert!(id) do
    Alert
    |> preload(anomaly: [:project, :expenditure, :audit_report])
    |> Repo.get!(id)
  end

  @doc """
  Lists dispatched alerts visible to the given user, optionally filtered by
  `:status` (e.g. "failed"). Admins see every alert; everyone else only sees
  alerts for anomalies in their own ministry.
  """
  def list_alerts(%User{role: "admin"}, opts), do: do_list_alerts(nil, opts)
  def list_alerts(%User{ministry_id: ministry_id}, opts), do: do_list_alerts(ministry_id, opts)

  defp do_list_alerts(ministry_id, opts) do
    status = Keyword.get(opts, :status)

    Alert
    |> join(:inner, [al], an in assoc(al, :anomaly))
    |> join(:inner, [al, an], p in assoc(an, :project))
    |> maybe_scope_ministry(ministry_id)
    |> maybe_filter_status(status)
    |> order_by(desc: :inserted_at)
    |> preload(anomaly: [:project, :expenditure])
    |> Repo.all()
  end

  defp maybe_scope_ministry(query, nil), do: query

  defp maybe_scope_ministry(query, ministry_id) do
    from [al, an, p] in query, where: p.ministry_id == ^ministry_id
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: from(al in query, where: al.status == ^status)

  @doc "Count of alerts that failed to send, scoped to the given user."
  def count_failed_alerts(user), do: user |> list_alerts(status: "failed") |> length()

  def high_risk?(%Anomaly{risk_score: risk_score}) do
    threshold = Application.get_env(:budget_sentinel, :high_risk_threshold, 70.0)
    Decimal.compare(risk_score, Decimal.from_float(threshold * 1.0)) != :lt
  end
end
