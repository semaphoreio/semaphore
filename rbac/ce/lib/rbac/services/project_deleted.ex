defmodule Rbac.Services.ProjectDeleted do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "project_exchange",
    routing_key: "deleted",
    service: "rbac.project_deleted"

  def handle_message(message) do
    Watchman.benchmark("project_deleted.duration", fn ->
      event = InternalApi.Projecthub.ProjectDeleted.decode(message)

      Logger.info("[ProjectDeleted] Processing: #{event.project_id}")

      Rbac.Models.ProjectAssignment.delete_all_for_project(event.project_id)

      Logger.info("[ProjectDeleted] Processing finished. #{event.project_id}")
    end)
  end
end
