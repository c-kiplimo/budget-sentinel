Application.ensure_all_started(:budget_sentinel)

ai_url = System.get_env("AI_SERVICE_URL") || "http://ai_service.railway.internal:5000"
IO.puts("AI_SERVICE_URL = #{ai_url}")

urls_to_try = [
  ai_url <> "/api/v1/health",
  "http://ai_service.railway.internal:5000/api/v1/health",
  "http://ai-service.railway.internal:5000/api/v1/health",
  "http://aiservice.railway.internal:5000/api/v1/health"
]

Enum.each(urls_to_try, fn url ->
  result = Req.get(url, receive_timeout: 5_000)
  case result do
    {:ok, %{status: status}} -> IO.puts("#{url} -> #{status} OK")
    {:error, reason} -> IO.puts("#{url} -> FAILED: #{inspect(reason)}")
  end
end)
