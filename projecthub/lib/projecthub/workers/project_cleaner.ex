defmodule Projecthub.Workers.ProjectCleaner do
  use Quantum, otp_app: :projecthub

  alias Projecthub.Models.Project

  require Logger

  def process do
    Project.find_candidates_for_hard_destroy()
    |> Enum.each(fn project ->
      Logger.info("Hard destroying project #{project.id}")
      Project.hard_destroy(project, project.deleted_by)
    end)

    :ok
  end
end
