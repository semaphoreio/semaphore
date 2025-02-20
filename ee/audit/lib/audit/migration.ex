defmodule Audit.Release do
  @app :audit

  @start_apps [:postgrex, :ecto, :ecto_sql, :ssl]

  def create_and_migrate do
    createdb()
    migrate()
  end

  def createdb do
    # Start postgrex and ecto
    IO.puts("Starting dependencies...")

    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    create_db_for(@app)
  end

  def create_db_for(app) do
    for repo <- get_repos() do
      :ok = ensure_repo_created(repo)
    end
  end

  defp ensure_repo_created(repo) do
    IO.puts("Create #{inspect(repo)} database if it doesn't exist")

    case repo.__adapter__.storage_up(repo.config) do
      :ok ->
        IO.puts("Database created!")
        :ok

      {:error, :already_up} ->
        IO.puts("Database already exists, skipping creation...")
        :ok

      {:error, term} ->
        {:error, term}
    end
  end

  defp migrate do
    IO.puts("Starting to run migrations...")

    for repo <- get_repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(
          repo,
          &Ecto.Migrator.run(&1, [path()], :up, all: true)
        )
    end

    IO.puts("Migration task done!")
  end

  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp get_repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp path do
    Application.fetch_env!(@app, :migrations_path)
  end
end
