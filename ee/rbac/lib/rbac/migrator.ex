defmodule Rbac.Release do
  @app :rbac

  @start_apps [:postgrex, :ecto, :ecto_sql, :ssl]

  def create_and_migrate do
    createdb()
    migrate()
    seed_data()
  end

  defp ensure_all_started do
    # Start postgrex and ecto
    IO.puts("Starting dependencies...")

    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)
  end

  def createdb do
    ensure_all_started()

    create_db_for(@app)
  end

  def create_db_for(_app) do
    for repo <- get_repos() do
      :ok = ensure_repo_created(repo)
    end
  end

  defp ensure_repo_created(repo) do
    IO.puts("Create #{inspect(repo)} database if it doesn't exist")

    case repo.__adapter__().storage_up(repo.config()) do
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

  def migrate do
    IO.puts("Starting to run migrations...")

    for repo <- get_repos() do
      path = priv_path_for(repo, "migrations")

      {:ok, _, _} =
        Ecto.Migrator.with_repo(
          repo,
          &Ecto.Migrator.run(&1, path, :up, all: true)
        )
    end

    IO.puts("Migration task done!")
  end

  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp get_repos do
    [Rbac.Repo]
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config(), :otp_app)

    repo_underscore =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    priv_dir = "#{:code.priv_dir(app)}"

    Path.join([priv_dir, repo_underscore, filename])
  end

  def seed_data do
    ensure_all_started()

    {:ok, _} = Rbac.Repo.start_link(pool_size: 2)

    IO.puts("Seeding data - Inserting scopes...")

    {:ok, _} =
      %Rbac.Repo.Scope{scope_name: "org_scope"} |> Rbac.Repo.insert(on_conflict: :nothing)

    {:ok, _} =
      %Rbac.Repo.Scope{scope_name: "project_scope"} |> Rbac.Repo.insert(on_conflict: :nothing)

    IO.puts("Seeding data - Inserting permissions...")
    Rbac.Repo.Permission.insert_default_permissions()
  end
end
