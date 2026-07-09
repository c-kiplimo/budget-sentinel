Application.ensure_all_started(:budget_sentinel)

# Test if Railway allows outbound SMTP on non-standard port 2525
# Mailgun supports SMTP on port 2525 specifically to bypass firewall blocks
ports_to_test = [
  {"smtp.mailgun.org", 587},
  {"smtp.mailgun.org", 2525},
  {"smtp-relay.brevo.com", 587},
  {"smtp-relay.brevo.com", 2525},
  {"smtp.gmail.com", 587},
  {"smtp.gmail.com", 465}
]

Enum.each(ports_to_test, fn {host, port} ->
  case :gen_tcp.connect(String.to_charlist(host), port, [], 5000) do
    {:ok, socket} ->
      :gen_tcp.close(socket)
      IO.puts("#{host}:#{port} -> OPEN ✓")
    {:error, reason} ->
      IO.puts("#{host}:#{port} -> BLOCKED (#{reason})")
  end
end)
