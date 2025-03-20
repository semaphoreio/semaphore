# credo:disable-for-this-file
defmodule Rbac.Okta.Saml.JitProvisioner.AddUser do
  @moduledoc """
  Procedure for creating a Semaphore user based on the received
  okta user payload.

  The assumed state of the system:
  - We have an okta_user record in the database
  - The okta_user.state is :pending
  - The okta_user.user_id is nil
  """

  require Logger
  import Logger, only: [info: 1, error: 1]

  alias Rbac.Repo.{SamlJitUser, RbacRole}
  alias Rbac.RoleBindingIdentification
  alias Rbac.RoleManagement

  @default_role "Member"

  def run(saml_jit_user) do
    idempotency_token = "okta-user-#{saml_jit_user.id}"
    email = saml_jit_user.email
    name = SamlJitUser.construct_name(saml_jit_user)

    user_params = %{
      email: email,
      name: name,
      idempotency_token: idempotency_token,
      creation_source: :saml_jit,
      single_org_user: true,
      org_id: saml_jit_user.org_id
    }

    info("Provisioning #{saml_jit_user.id}")

    with(
      {:ok, user} <- find_or_create_user(idempotency_token, user_params),
      {:ok, saml_jit_user} <- SamlJitUser.connect_user(saml_jit_user, user.id),
      {:ok, role_id} <- fetch_role_to_be_assigned(saml_jit_user),
      :ok <- assign_role(user.id, saml_jit_user.org_id, role_id),
      {:ok, saml_jit_user} <- SamlJitUser.mark_as_processed(saml_jit_user)
    ) do
      info("Provisioning #{saml_jit_user.id} done.")

      {:ok, saml_jit_user}
    else
      err ->
        log_provisioning_error(saml_jit_user, err)
        err
    end
  end

  defp find_or_create_user(idempotency_token, user_params) do
    case find_user_by_idempotency_token(idempotency_token) do
      nil ->
        case Rbac.Store.RbacUser.fetch_by_email(user_params.email) do
          {:error, :not_found} ->
            info("[Sam lJIT Provisioner] Creating new user #{inspect(user_params)}")
            Rbac.User.Actions.create(user_params)

          {:ok, user} ->
            info(
              "[Saml JIT Provisioner] Adding idempotency token to existing user #{inspect(user_params)}"
            )

            Rbac.Store.User.Front.add_idempotency_token(user.id, idempotency_token)
            {:ok, user}
        end

      user ->
        {:ok, user}
    end
  end

  defp find_user_by_idempotency_token(idempotency_token) do
    case Rbac.Store.User.Front.find_by_idempotency_token(idempotency_token) do
      {:error, :not_found} ->
        nil

      {:ok, user} ->
        Rbac.Store.RbacUser.fetch(user.id)
    end
  end

  defp fetch_role_to_be_assigned(jit_user) do
    case Rbac.Okta.IdpGroupMapping.map_roles(jit_user.org_id, jit_user.attributes["role"] || []) do
      {:ok, roles} when is_list(roles) and length(roles) > 0 ->
        {:ok, roles |> List.first()}

      e ->
        info("[Saml JIT Provisioner] Response from IdpGroupMapping.map_roles #{inspect(e)}")

        org_default_role_id(jit_user.org_id)
    end
  end

  def org_default_role_id(org_id) do
    case Rbac.Okta.IdpGroupMapping.get_for_organization(org_id) do
      {:ok, %{default_role_id: default_role_id}} when default_role_id not in [nil, ""] ->
        {:ok, default_role_id}

      _ ->
        fetch_default_role_id(org_id)
    end
  end

  defp fetch_default_role_id(org_id) do
    {:ok, role} = RbacRole.get_role_by_name(@default_role, "org_scope", org_id)
    {:ok, role.id}
  end

  defp assign_role(user_id, org_id, role_id) do
    if RoleManagement.user_part_of_org?(user_id, org_id) do
      :ok
    else
      {:ok, rbi} = RoleBindingIdentification.new(user_id: user_id, org_id: org_id)
      # Although this role is assigned through :saml_jit, it can be updated and
      # removed manually, hence it is marked as "manually_assigned"
      {:ok, nil} = RoleManagement.assign_role(rbi, role_id, :manually_assigned)

      Rbac.Events.UserJoinedOrganization.publish(user_id, org_id)
      :ok
    end
  end

  defp log_provisioning_error(okta_user, err) do
    inspects = "okta user: #{inspect(okta_user)} error: #{inspect(err)}"

    error("SamlJIT Provisioner: Failed to provision #{inspects}")
  end
end
