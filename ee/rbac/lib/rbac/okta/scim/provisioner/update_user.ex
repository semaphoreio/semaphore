# credo:disable-for-this-file
defmodule Rbac.Okta.Scim.Provisioner.UpdateUser do
  @moduledoc """
  Procedure for updating a Semaphore user based on the received
  okta user payload.

  The assumed state of the system:
  - We have an okta_user record in the database
  - The okta_user.state is :pending
  - The okta_user.user_id not nil, and points to a real user
  """

  require Logger

  alias Rbac.FrontRepo
  alias Rbac.Repo.OktaUser
  alias Rbac.FrontRepo.User

  def run(okta_user) do
    params = %{
      email: OktaUser.email(okta_user),
      name: OktaUser.name(okta_user),

      #
      # this part is important for okta user re-activation
      #
      deactivated: false,
      deactivated_at: nil
    }

    Logger.info("Updating okta_user #{okta_user.id}")

    with(
      {:ok, user} <- find_user(okta_user),
      cs <- User.changeset(user, params),
      {:ok, _user} <- FrontRepo.update(cs),
      :ok <- Rbac.Store.RbacUser.update(user.id, params),
      :ok <- assign_role(okta_user, "Member"),
      {:ok, _okta_user} <- OktaUser.mark_as_processed(okta_user)
    ) do
      Logger.info("Updating okta_user #{okta_user.id} done.")

      :ok
    else
      err ->
        log_provisioning_error(okta_user, err)
        err
    end
  end

  def find_user(okta_user) do
    case Rbac.FrontRepo.get(Rbac.FrontRepo.User, okta_user.user_id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  defp assign_role(okta_user, role_name) do
    alias Rbac.RoleBindingIdentification
    alias Rbac.RoleManagement
    alias Rbac.Repo.RbacRole

    user_id = okta_user.user_id
    org_id = okta_user.org_id

    if RoleManagement.user_part_of_org?(user_id, org_id) do
      :ok
    else
      with(
        {:ok, rbi} <- RoleBindingIdentification.new(user_id: user_id, org_id: org_id),
        {:ok, role} <- RbacRole.get_role_by_name(role_name, "org_scope", org_id)
      ) do
        {:ok, nil} = RoleManagement.assign_role(rbi, role.id, :okta)

        Rbac.Events.UserJoinedOrganization.publish(user_id, org_id)
        :ok
      end
    end
  end

  defp log_provisioning_error(okta_user, err) do
    inspects = "okta user: #{inspect(okta_user)} error: #{inspect(err)}"

    Logger.error("SCIM Provisioner: Failed to update #{inspects}")
  end
end
