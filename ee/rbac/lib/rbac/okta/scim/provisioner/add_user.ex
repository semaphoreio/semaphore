# credo:disable-for-this-file
defmodule Rbac.Okta.Scim.Provisioner.AddUser do
  @moduledoc """
  Procedure for creating a Semaphore user based on the received
  okta user payload.

  The assumed state of the system:
  - We have an okta_user record in the database
  - The okta_user.state is :pending
  - The okta_user.user_id is nil
  """

  require Logger

  alias Rbac.Repo.{OktaUser, RbacRole}
  alias Rbac.RoleBindingIdentification
  alias Rbac.RoleManagement

  @role_name "Member"

  def run(okta_user) do
    idempotency_token = "okta-user-#{okta_user.id}"
    email = OktaUser.email(okta_user)
    name = OktaUser.name(okta_user)

    user_params = %{
      email: email,
      name: name,
      idempotency_token: idempotency_token,
      creation_source: :okta,
      # TODO What is the idea behind the single_org_user and org_id fields
      single_org_user: true,
      org_id: okta_user.org_id
    }

    Logger.info("Provisioning #{okta_user.id}")

    with(
      {:ok, user} <- find_or_create_user(idempotency_token, user_params),
      {:ok, okta_user} <- OktaUser.connect_user(okta_user, user.id),
      :ok <- assign_role(user.id, okta_user.org_id, @role_name),
      {:ok, _okta_user} <- OktaUser.mark_as_processed(okta_user)
    ) do
      Logger.info("Provisioning #{okta_user.id} done.")

      :ok
    else
      err ->
        log_provisioning_error(okta_user, err)
        err
    end
  end

  defp find_or_create_user(idempotency_token, user_params) do
    case find_user_by_idempotency_token(idempotency_token) do
      nil ->
        case Rbac.Store.RbacUser.fetch_by_email(user_params.email) do
          {:error, :not_found} ->
            Logger.info("[Okta Provisioner] Creating new okta user #{inspect(user_params)}")

            Rbac.User.Actions.create(user_params)

          {:ok, user} ->
            Logger.info(
              "[Okta Provisioner] Adding idempotency token to existing user #{inspect(user_params)}"
            )

            Rbac.Store.User.Front.add_idempotency_token(user.id, idempotency_token)
            {:ok, user}
        end

      user ->
        {:ok, user}
    end
  end

  def find_user_by_idempotency_token(idempotency_token) do
    case Rbac.Store.User.Front.find_by_idempotency_token(idempotency_token) do
      {:error, :not_found} ->
        nil

      {:ok, user} ->
        Rbac.Store.RbacUser.fetch(user.id)
    end
  end

  defp assign_role(user_id, org_id, role_name) do
    if RoleManagement.user_part_of_org?(user_id, org_id) do
      :ok
    else
      with {:ok, rbi} <- RoleBindingIdentification.new(user_id: user_id, org_id: org_id),
           {:ok, role} <- RbacRole.get_role_by_name(role_name, "org_scope", org_id) do
        {:ok, nil} = RoleManagement.assign_role(rbi, role.id, :okta)

        Rbac.Events.UserJoinedOrganization.publish(user_id, org_id)
        :ok
      end
    end
  end

  defp log_provisioning_error(okta_user, err) do
    inspects = "okta user: #{inspect(okta_user)} error: #{inspect(err)}"

    Logger.error("SCIM Provisioner: Failed to provision #{inspects}")
  end
end
