defmodule PreFlightChecks.ReleaseTasks do
  @moduledoc """
  Operations that are easy to do with Mix but without Mix (in release)
  they have to be programmed.
  """

  @start_apps [
    :crypto,
    :ssl,
    :postgrex,
    :ecto,
    :ecto_sql
  ]

  @repos Application.compile_env(:pre_flight_checks, :ecto_repos, [])

  def migrate do
    start_dependencies()

    create_repos()

    start_repos()

    run_migrations()

    stop_services()
  end

  defp start_dependencies do
    IO.puts("Starting dependencies..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)
  end

  defp create_repos do
    IO.puts("Creating repos..")
    Enum.each(@repos, fn repo -> repo.__adapter__.storage_up(repo.config) end)
  end

  defp start_repos do
    IO.puts("Starting repos..")
    Enum.each(@repos, & &1.start_link(pool_size: 2))
  end

  defp stop_services do
    IO.puts("Success!")
    :init.stop()
  end

  defp run_migrations do
    Enum.each(@repos, &run_migrations_for/1)
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
end
