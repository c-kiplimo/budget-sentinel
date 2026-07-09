Application.ensure_all_started(:budget_sentinel)
import Swoosh.Email

IO.puts("Testing SMTP connection to smtp.gmail.com...")

email =
  new()
  |> to("uwasedorcas22@gmail.com")
  |> from({"BudgetSentinel", "uwasedorcas22@gmail.com"})
  |> subject("BudgetSentinel SMTP Test")
  |> text_body("This is a test email from BudgetSentinel on Railway.")

result = BudgetSentinel.Notifications.Mailer.deliver(email)
IO.inspect(result, label: "SMTP Result")
