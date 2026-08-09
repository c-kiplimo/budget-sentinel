defmodule BudgetSentinel.Intelligence.AnalysisPipeline do
  @moduledoc """
  Orchestrates a full detection run: gather expenditure data, call the AI
  microservice, persist anomalies, generate audit reports for high-risk
  findings, dispatch alerts, and broadcast updates to the live dashboard.
  """

  alias BudgetSentinel.{Audit, Notifications, Procurement}
  alias BudgetSentinel.Audit.Anomaly

  @topic "anomalies:lobby"

  def topic, do: @topic

  def run_detection_scan do
    today = Date.utc_today()

    projects =
      Procurement.list_projects()
      |> Enum.reject(fn p ->
        not is_nil(p.completion_date) and Date.compare(p.completion_date, today) == :lt
      end)

    expenditures = Procurement.list_expenditures_for_projects(Enum.map(projects, & &1.id))

    if projects == [] do
      broadcast({:scan_completed, 0})
      {:ok, []}
    else
      project_payloads = Enum.map(projects, &project_payload/1)
      expenditure_payloads = Enum.map(expenditures, &expenditure_payload/1)

      with {:ok, raw_anomalies} <- ai_client().detect_anomalies(project_payloads, expenditure_payloads) do
        persisted = Enum.flat_map(raw_anomalies, &persist_anomaly/1)
        Enum.each(persisted, &handle_high_risk/1)
        broadcast({:scan_completed, length(persisted)})
        {:ok, persisted}
      else
        {:error, reason} ->
          require Logger
          Logger.error("[AnalysisPipeline] AI service error: #{inspect(reason)}")
          broadcast({:scan_completed, 0})
          {:error, reason}
      end
    end
  end

  defp persist_anomaly(raw) do
    expenditure_id = String.to_integer(raw["expenditure_id"])
    project_id = String.to_integer(raw["project_id"])

    if Audit.anomaly_exists_for_expenditure?(expenditure_id) do
      []
    else
      attrs = %{
        fraud_type: raw["fraud_type"],
        risk_score: Decimal.from_float(raw["risk_score"] * 1.0),
        severity: raw["severity"],
        anomaly_score: Decimal.from_float(raw["anomaly_score"] * 1.0),
        explanation: raw["explanation"],
        project_id: project_id,
        expenditure_id: expenditure_id
      }

      case Audit.record_anomaly(attrs) do
        {:ok, anomaly} ->
          broadcast({:anomaly_detected, anomaly})
          [Audit.get_anomaly!(anomaly.id)]

        {:error, _changeset} ->
          []
      end
    end
  end

  defp handle_high_risk(%Anomaly{} = anomaly) do
    if Audit.high_risk?(anomaly) do
      project = Procurement.get_project!(anomaly.project_id)
      expenditure = Enum.find(Procurement.list_expenditures_for_project(project.id), &(&1.id == anomaly.expenditure_id))

      with {:ok, report_body} <-
             ai_client().generate_report(anomaly_payload(anomaly), project_payload(project), expenditure_payload(expenditure)),
           {:ok, report} <- Audit.attach_report(anomaly, report_body) do
        broadcast({:report_generated, anomaly.id, report})
        Notifications.Dispatcher.dispatch(anomaly, report, project)
      else
        {:error, reason} ->
          require Logger
          Logger.error("[AnalysisPipeline] Report generation failed for anomaly #{anomaly.id}: #{inspect(reason)}")
      end
    end
  end

  defp project_payload(project) do
    %{
      id: to_string(project.id),
      sector: project.sector,
      approved_budget: Decimal.to_float(project.approved_budget),
      completion_rate: Decimal.to_float(project.completion_rate),
      market_benchmark: project.market_benchmark && Decimal.to_float(project.market_benchmark)
    }
  end

  defp expenditure_payload(expenditure) do
    %{
      id: to_string(expenditure.id),
      project_id: to_string(expenditure.project_id),
      contractor: expenditure.contractor,
      amount: Decimal.to_float(expenditure.amount),
      milestone: expenditure.milestone,
      date: Date.to_iso8601(expenditure.paid_on)
    }
  end

  defp anomaly_payload(anomaly) do
    %{
      fraud_type: anomaly.fraud_type,
      risk_score: Decimal.to_float(anomaly.risk_score),
      severity: anomaly.severity,
      anomaly_score: Decimal.to_float(anomaly.anomaly_score),
      explanation: anomaly.explanation
    }
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(BudgetSentinel.PubSub, @topic, message)
  end

  defp ai_client, do: Application.fetch_env!(:budget_sentinel, :ai_client)
end
