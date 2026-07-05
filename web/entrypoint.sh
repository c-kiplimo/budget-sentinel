#!/bin/sh
set -e

echo "Running migrations..."
bin/budget_sentinel eval "BudgetSentinel.Release.migrate()"

echo "Starting server..."
exec bin/budget_sentinel start
