#!/bin/sh
SCRIPT="/app/lib/budget_sentinel-0.1.0/priv/scripts/check_alerts.exs"
echo "Running: $SCRIPT"
/app/bin/budget_sentinel eval "Code.eval_file(\"$SCRIPT\")"
