defmodule Rbac.Services.ProjectDestroyer do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "project_exchange",
    routing_key: "deleted",
    service: "guard.project_destroyer"

  def handle_message(message) do
    Watchman.benchmark("project_creator.duration", fn ->
      event = InternalApi.Projecthub.ProjectDeleted.decode(message)

      Logger.info("Processing: #{event.project_id}")

      Rbac.Store.Project.delete(event.project_id)

      # Removing rbac roles related to the given project
      {:ok, rbi} =
        Rbac.RoleBindingIdentification.new(
          org_id: event.org_id,
          project_id: event.project_id
        )

      Rbac.RoleManagement.retract_roles(rbi)

      Logger.info("Project Deleted: #{event.project_id}")

      Logger.info("Processing finished. #{event.project_id}")
    end)
  end
end
