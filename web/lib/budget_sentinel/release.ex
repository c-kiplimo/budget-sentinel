defmodule BudgetSentinel.Release do
  @moduledoc """
  Migration and seed tasks runnable from a compiled release, where `mix` is not
  available (`bin/budget_sentinel eval "BudgetSentinel.Release.migrate()"`).
  """

  @app :budget_sentinel

  def migrate do
    Application.load(@app)

    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      {:ok, _} = Application.ensure_all_started(:ecto_sql)

      case repo.start_link(pool_size: 2) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      Ecto.Migrator.run(repo, :up, all: true)
    end

    System.halt(0)
  end

  def seed do
    Application.load(@app)
    path = Application.app_dir(@app, "priv/repo/seeds.exs")

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn repo ->
        count = repo.aggregate(BudgetSentinel.Ministries.Ministry, :count)

        if count == 0 do
          IO.puts("[seed] Running seeds from #{path}")
          Code.eval_file(path)
          IO.puts("[seed] Done.")
        else
          IO.puts("[seed] Database already seeded (#{count} ministries found), skipping.")
        end
      end)
    end
  end

  def rollback(repo, version) do
    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end
end
