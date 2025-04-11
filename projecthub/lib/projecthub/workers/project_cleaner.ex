defmodule Projecthub.Workers.ProjectCleaner do
  use Quantum, otp_app: :projecthub

  alias Projecthub.Models.Project

  require Logger

  @chunk_size 10

  def process do
    Project.find_candidates_for_hard_destroy()
    |> Stream.chunk_every(@chunk_size)
    |> Stream.each(fn projects ->
      projects
      |> Task.async_stream(
        fn project ->
          Logger.info("Hard destroying project #{project.id}")
          Project.hard_destroy(project, project.deleted_by)
        end,
        max_concurrency: @chunk_size,
        timeout: :infinity
      )
      |> Stream.run()
    end)
    |> Stream.run()

    :ok
  end
end
