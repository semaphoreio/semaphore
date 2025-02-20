defmodule Rbac.Workers.RefreshProjectAccess do
  @moduledoc """
    Why is this worker needed?
    - When "Refresh collaborators" action is performed, all projects from a given organization are synced
    with GH/BB repositories, and users are removed/added to them. This can result in 100s or even 1000s of
    "assign_role" and "retract_role" operations at once, for bigger organizations. If we just shoot a new
    process for each of those actions, our DB connection pool will be emptied quickly, and other requests
    will start timing out.

    This worker takes requests one by one, and assigns/retracts roles sequentially, so that no more than 2
    connections are used up by this process at any time.

    It also perform an important optimization. Instead of calculating permissions (which is by far the slowest
    operation, taking around 10s) each time role is assigned/retracted to any user within any project, it first
    assignes/retracts roles to one user for all of the projects he will be a part of, and than recalculates new
    permissions just once at the end.
  """
  require Logger

  alias Rbac.Toolbox.{Periodic, Duration}
  alias Rbac.Repo.RbacRefreshProjectAccessRequest, as: Request

  use Periodic

  def init(_opts) do
    super(%{
      name: "recalculate_rbac_permissions_worker",
      naptime: Duration.seconds(60),
      timeout: Duration.seconds(90)
    })
  end

  # 1) Load one request for assigning/removing rbac project access request
  #       Each request is for one user within one org, and has list of project_actions
  #       Each project action contains project id, action that needs to be performed (add or remove access), and
  #       role to be assigned, if action is 'add access'
  # 2) Start a transaction
  # 3) Go through each project request, if action is add, add subject role binding, if action is remove, remove access
  #     from user_permissions store and project access store, and than delete subject role binding
  # 4) Once all project requests have been processed, recalculate user_permissions and project access for that user
  #     within the given org
  # 5) Finish a transaction

  def perform(_args \\ nil) do
    req = load_req_for_processing()

    if req != nil do
      Logger.info("[RefresProjectAccess Worker] Performing a task on req: #{inspect(req)}")

      try do
        Rbac.Repo.transaction(
          fn ->
            req.projects |> Enum.each(&process_project(req.org_id, req.user_id, &1))

            {:ok, rbi} =
              Rbac.RoleBindingIdentification.new(
                org_id: req.org_id,
                user_id: req.user_id
              )

            Rbac.Store.UserPermissions.add_permissions(rbi)
            Rbac.Store.ProjectAccess.add_project_access(rbi)
            finish_processing(req)
          end,
          timeout: 50_000
        )
      rescue
        error ->
          Logger.error(
            "[RefresProjectAccess Worker] Error '#{inspect(error)}' occuerd while processing request #{inspect(req)}"
          )

          failed_processing(req)
      end

      perform_now()
    end
  end

  defp process_project(org_id, user_id, %Request.ProjectRequest{} = project)
       when project.action == :add do
    if Rbac.RoleManagement.user_part_of_org?(user_id, org_id) do
      Rbac.Repo.SubjectRoleBinding.create(
        org_id,
        project.id,
        user_id,
        project.provider,
        project.role_to_be_assigned
      )
    end
  end

  @user_permissions_store_name Application.compile_env(:rbac, :user_permissions_store_name)
  @store_backend Application.compile_env(:rbac, :key_value_store_backend)
  defp process_project(org_id, user_id, %Request.ProjectRequest{} = project)
       when project.action == :remove do
    # Removing access to the project directly in user_permissions store.
    # This should not be copied!!!
    # Management of this store is done exclusivly through Rbac.Store.UserPermissions module
    key = "user:#{user_id}_org:#{org_id}_project:#{project.id}"
    @store_backend.delete(@user_permissions_store_name, key)

    Rbac.Store.ProjectAccess.remove_project_access(user_id, org_id, project.id)

    Rbac.Repo.SubjectRoleBinding.delete(org_id, project.id, user_id, project.provider)
  end

  defdelegate load_req_for_processing, to: Request
  defdelegate finish_processing(req), to: Request
  defdelegate failed_processing(req), to: Request
end
