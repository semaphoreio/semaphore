defmodule Rbac.Okta.Scim.Provisioner.DeactivateUser do
  @moduledoc """
  Procedure for deactivating a Semaphore user based on the received
  okta user payload.

  The assumed state of the system:
  - We have an okta_user record in the database
  - The okta_user.state is :pending
  - The okta_user.user_id not nil, and points to a real user

  After the procedure is executed:
  - The Semaphore User will have gets its personal data anonimized
  - The Semaphore User will be marked as inactive
  - The Semaphore User will no longer be part of the RBAC system
  """

  require Logger
  alias Rbac.Repo.OktaUser
  alias Rbac.FrontRepo

  def run(okta_user) do
    Logger.info("Deactivating okta_user #{okta_user.id}")

    with(
      {:ok, user} <- find_user(okta_user),
      :ok <- anonymize_user_details(user, okta_user.id),
      :ok <- retract_roles(okta_user),
      {:ok, _okta_user} <- OktaUser.mark_as_processed(okta_user)
    ) do
      Logger.info("Deactivation of okta_user #{okta_user.id} done.")

      :ok
    else
      err ->
        log_provisioning_error(okta_user, err)
        err
    end
  end

  def anonymize_user_details(%{creation_source: source} = user, okta_id) when source == :okta do
    Logger.info("Deactivating user #{user.id} - Anonymizing User Details")

    params = %{
      email: "deactivated-okta-user-#{okta_id}@#{okta_id}.com",
      name: "Deactivated User #{String.slice(okta_id, 0..7)}",
      deactivated: true,
      deactivated_at: DateTime.utc_now()
    }

    with(
      cs <- FrontRepo.User.changeset(user, params),
      {:ok, _user} <- FrontRepo.update(cs)
    ) do
      Rbac.Store.RbacUser.update(user.id, params)
    end
  end

  def anonymize_user_details(_user, _okta_id), do: :ok

  defp retract_roles(okta_user) do
    Logger.info("Deactivating okta_user #{okta_user.id} - Retracting Roles")

    alias Rbac.RoleBindingIdentification, as: RBI

    with(
      {:ok, rbi} <- RBI.new(user_id: okta_user.user_id, org_id: okta_user.org_id),
      {:ok, nil} <- Rbac.RoleManagement.retract_roles(rbi)
    ) do
      Rbac.Events.UserLeftOrganization.publish(okta_user.user_id, okta_user.org_id)
      :ok
    end
  end

  defp find_user(okta_user) do
    case FrontRepo.get(FrontRepo.User, okta_user.user_id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  defp log_provisioning_error(okta_user, err) do
    inspects = "okta user: #{inspect(okta_user)} error: #{inspect(err)}"

    Logger.error("SCIM Provisioner: Failed to deactivate #{inspects}")
  end
end
