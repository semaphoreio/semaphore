defmodule Projecthub.Workers.ProjectCleaner do
  use Quantum, otp_app: :projecthub

  alias Projecthub.Models.Project

  require Logger

  def process do
    Watchman.benchmark("projecthub_project_cleaner.duration", fn ->
      Logger.info("Starting project cleaner")

      Project.find_candidates_for_hard_destroy()
      |> Enum.each(fn project ->
        Logger.info("Hard destroying project #{project.id}")

        case Project.hard_destroy(project, project.deleted_by) do
          {:ok, _} -> Logger.info("Hard destroyed project #{project.id}")
          {:error, error} -> Logger.error("Failed to hard destroy project #{project.id}: #{error}")
        end
      end)

      :ok
    end)
  end
end
