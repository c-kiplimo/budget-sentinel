#!/bin/sh
SCRIPT=$(find /app/lib -name "setup_admin.exs" 2>/dev/null | head -1)
echo "Running setup from: $SCRIPT"
/app/bin/budget_sentinel eval "Code.eval_file(\"$SCRIPT\")"
