defmodule Rbac.Services.ProjectCreator do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "project_exchange",
    routing_key: "created",
    service: "guard.project_creator"

  def handle_message(message) do
    Watchman.benchmark("project_creator.duration", fn ->
      event = InternalApi.Projecthub.ProjectCreated.decode(message)

      Logger.info("Processing: #{event.project_id}")

      {:ok, project} = Rbac.Models.Project.find(event.project_id)

      Logger.info("Project Found: #{project.id}")

      {:ok, p} =
        Rbac.Store.Project.update(
          project.id,
          project.repository.full_name,
          project.org_id,
          project.repository.provider,
          project.repository.id
        )

      Logger.info("Project Saved: #{project.id}")

      Rbac.CollaboratorsRefresher.refresh(p)

      Logger.info("Processing finished. #{project.id}")
    end)
  end
end
