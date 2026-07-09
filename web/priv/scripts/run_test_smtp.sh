#!/bin/sh
SCRIPT="/app/lib/budget_sentinel-0.1.0/priv/scripts/test_smtp.exs"
echo "Running SMTP test..."
/app/bin/budget_sentinel eval "Code.eval_file(\"$SCRIPT\")"
