defmodule EphemeralEnvironments.Release do
  @start_apps [:postgrex, :ecto, :ecto_sql, :ssl]

  def migrate do
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    for repo <- repos() do
      :ok = ensure_repo_created(repo)
    end

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          Ecto.Migrator.run(repo, [path()], :up, all: true)
        end)
    end
  end

  def rollback(repo, version) do
    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, fn repo ->
        Ecto.Migrator.run(repo, [path()], :down, to: version)
      end)
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

  defp repos do
    [EphemeralEnvironments.Repo]
  end

  defp path do
    Application.fetch_env!(:ephemeral_environments, :migrations_path)
  end
end
