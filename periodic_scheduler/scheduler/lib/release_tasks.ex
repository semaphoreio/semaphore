defmodule ReleaseTasks do
  @moduledoc """
  Operations that are easy to do with Mix but without Mix (in release)
  they have to be programmed.
  FrontRepo is excluded because migrations for that repo are in Front app,
  and migrations in this app should only be used for testing.
  """

  @start_apps [
    :crypto,
    :ssl,
    :postgrex,
    :ecto,
    :jason
  ]

  defp repos(true) do
    Application.get_env(:scheduler, :ecto_repos, [])
  end

  defp repos(_) do
    :scheduler
    |> Application.get_env(:ecto_repos, [])
    |> Enum.reject(fn repo -> repo == Scheduler.FrontRepo end)
  end

  def migrate_all() do
    true |> repos() |> migrate_()
  end

  def migrate() do
    false |> repos() |> migrate_()
  end

  defp migrate_(repos) do
    start_dependencies()

    create_repos(repos)

    start_repos(repos)

    run_migrations(repos)

    stop_services()
  end

  defp start_dependencies do
    IO.puts("Starting dependencies..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)
  end

  defp create_repos(repos) do
    IO.puts("Creating repos..")
    Enum.each(repos, fn repo -> repo.__adapter__.storage_up(repo.config) end)
  end

  defp start_repos(repos) do
    IO.puts("Starting repos..")
    Enum.each(repos, & &1.start_link(pool_size: 2))
  end

  defp stop_services do
    IO.puts("Success!")
    :init.stop()
  end

  defp run_migrations(repos) do
    Enum.each(repos, &run_migrations_for/1)
  end

  defp run_migrations_for(repo) do
    app = Keyword.get(repo.config, :otp_app)
    IO.puts("Running migrations for #{app}")
    migrations_path = priv_path_for(repo, "migrations")
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config, :otp_app)

    repo_underscore =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    priv_dir = "#{:code.priv_dir(app)}"

    Path.join([priv_dir, repo_underscore, filename])
  end

  @doc """
  Seeds mocked front db. Will be used in staging enivironments.
  """
  def seed_mock_front() do
    repos = [Scheduler.FrontRepo]

    start_dependencies()

    start_repos(repos)

    run_seeds(repos)

    stop_services()
  end

  defp run_seeds(repos) do
    Enum.each(repos, &run_seeds_for/1)
  end

  defp run_seeds_for(repo) do
    # Run the seed script if it exists
    seed_script = priv_path_for(repo, "seeds/mock_front_seed.exs")

    if File.exists?(seed_script) do
      IO.puts("Running seed script..")
      Code.eval_file(seed_script)
    end
  end
end
