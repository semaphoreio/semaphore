defmodule Rbac.Workers.RefreshAllPermissions do
  @moduledoc """
    Why is this worker needed?

    When we change the definition of any of the roles (add new or remove existing permissions), the cache storing all permissions
    for each user needs to be refreshed.

    There is a function within the UserPermissions module that recalculates all permissions within the entire
    application. That function does it in batches and can perform recalculation in about 10 minutes. But, for those
    10 minutes, there will be organizations that will lose access to Semaphore. That's why that function should be
    invoked only where necessary.

    This worker refreshes permissions organization by organization, which takes more time but doesn't cause downtime. The
    progress is updated every 50 orgs, so that it can be monitored.
  """
  require Logger

  alias Rbac.Toolbox.{Periodic, Duration}
  alias Rbac.Repo.RbacRefreshAllPermissionsRequest, as: Request
  import Ecto.Query, only: [select: 3, order_by: 3, limit: 2, offset: 2]

  use Periodic

  def init(_opts) do
    super(%{
      name: "recalculate_rbac_permissions_worker",
      naptime: Duration.seconds(60),
      timeout: Duration.seconds(60 * 5)
    })
  end

  @batch_size 50
  def perform(_args \\ nil) do
    req = load_req_for_processing()

    if req != nil do
      Logger.info(
        "[RbacRefreshAllPermissionsRequest Worker] Performing a task on req: #{inspect(req)}"
      )

      try do
        org_ids =
          Rbac.FrontRepo.Organization
          |> select([o], o.id)
          |> order_by([o], asc: o.created_at)
          |> offset(^req.organizations_updated)
          |> limit(@batch_size)
          |> Rbac.FrontRepo.all()

        Enum.each(org_ids, &refresh_permissions_for_org(&1))

        finish_processing_batch(req, length(org_ids))
      rescue
        error ->
          Logger.error(
            "[RbacRefreshAllPermissionsRequest Worker] Error '#{inspect(error)}' occuerd while processing request #{inspect(req)}"
          )

          failed_processing(req)
      end

      perform_now()
    end
  end

  def refresh_permissions_for_org(org_id) do
    alias Rbac.Store.UserPermissions
    alias Rbac.RoleBindingIdentification, as: RBI

    {:ok, rbi} = RBI.new(org_id: org_id)
    UserPermissions.add_permissions(rbi)
  end

  defdelegate load_req_for_processing, to: Request
  defdelegate finish_processing_batch(req, updated_orgs), to: Request
  defdelegate failed_processing(req), to: Request
end
