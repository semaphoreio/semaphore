defmodule Rbac.Workers.GroupManagement do
  require Logger

  alias Rbac.Toolbox.{Periodic, Duration}
  alias Rbac.Repo.GroupManagementRequest, as: Request

  use Periodic

  def init(_opts) do
    super(%{
      name: "group_management_worker",
      naptime: Duration.seconds(2),
      timeout: Duration.seconds(60)
    })
  end

  def perform(_args \\ nil) do
    req = load_req_for_processing()

    if req != nil do
      Logger.info(
        "[RbacRefreshAllPermissionsRequest Worker] Performing a task on req: #{inspect(req)}"
      )

      try do
        {:ok, group} = Rbac.Store.Group.fetch_group(req.group_id)

        case req.action do
          :add ->
            :ok = Rbac.Store.Group.add_to_group(group, req.user_id)

          :remove ->
            :ok = Rbac.Store.Group.remove_from_group(group, req.user_id)

          other ->
            raise "Unknown action: #{inspect(other)}"
        end

        finish_processing(req)
      rescue
        error ->
          Logger.error(
            "[GroupManagement Worker] Error '#{inspect(error)}' occuerd while processing request #{inspect(req)}"
          )

          failed_processing(req)
      end

      perform_now()
    end
  end

  defdelegate load_req_for_processing, to: Request
  defdelegate finish_processing(req), to: Request
  defdelegate failed_processing(req), to: Request
end
