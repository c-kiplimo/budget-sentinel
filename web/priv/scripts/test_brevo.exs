Application.ensure_all_started(:budget_sentinel)
import Swoosh.Email

IO.inspect(Application.get_env(:budget_sentinel, BudgetSentinel.Notifications.Mailer), label: "Config")

from_addr = System.get_env("MAIL_FROM") || "limokcollins@gmail.com"

email = new()
  |> to("limokcollins@gmail.com")
  |> from({"BudgetSentinel", from_addr})
  |> subject("[BudgetSentinel] Test alert")
  |> text_body("This is a test email from BudgetSentinel via Brevo.")

result = BudgetSentinel.Notifications.Mailer.deliver(email)
IO.inspect(result, label: "Result")
