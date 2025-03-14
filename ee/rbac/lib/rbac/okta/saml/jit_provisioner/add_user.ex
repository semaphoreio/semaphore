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

    Logger.info("Provisioning #{saml_jit_user.id}")

    with(
      {:ok, user} <- find_or_create_user(idempotency_token, user_params),
      {:ok, saml_jit_user} <- SamlJitUser.connect_user(saml_jit_user, user.id),
      {:ok, role_id} <- fetch_role_to_be_assigned(saml_jit_user),
      :ok <- assign_role(user.id, saml_jit_user.org_id, role_id),
      {:ok, _saml_jit_user} <- SamlJitUser.mark_as_processed(saml_jit_user)
    ) do
      Logger.info("Provisioning #{saml_jit_user.id} done.")

      :ok
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
            Logger.info("[Sam lJIT Provisioner] Creating new user #{inspect(user_params)}")
            Rbac.User.Actions.create(user_params)

          {:ok, user} ->
            Logger.info(
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
    # If no role mappings are specified in the SAML request, just use empty list
    case Rbac.Okta.IdpGroupMapping.map_roles(jit_user.org_id, jit_user.attributes["role"] || []) do
      {:ok, roles_to_be_assigned} ->
        {:ok, roles_to_be_assigned |> List.first() || org_default_role_id(jit_user.org_id)}

      {:error, :not_found} ->
        Logger.info("[Saml JIT Provisioner] No role mappings for #{jit_user.org_id} integration")
        {:ok, org_default_role_id(jit_user.org_id)}

      {:error, e} ->
        Logger.error("[Saml JIT Provisioner] Error while fetching role mappings #{inspect(e)}")
        {:ok, org_default_role_id(jit_user.org_id)}
    end
  end

  def org_default_role_id(org_id) do
    case Rbac.Okta.IdpGroupMapping.get_for_organization(org_id) do
      {:error, e} ->
        RbacRole.get_role_by_name(@default_role_, "org_scope", org_id)

      {:ok, mapping} ->
        mapping.default_role_id || RbacRole.get_role_by_name(@default_role, "org_scope", org_id)
    end
  end

  defp assign_role(user_id, org_id, role_id) do
    if RoleManagement.user_part_of_org?(user_id, org_id) do
      :ok
    else
      {:ok, rbi} = RoleBindingIdentification.new(user_id: user_id, org_id: org_id)
      {:ok, nil} = RoleManagement.assign_role(rbi, role.id, :saml_jit)

      Rbac.Events.UserJoinedOrganization.publish(user_id, org_id)
      :ok
    end
  end

  defp log_provisioning_error(okta_user, err) do
    inspects = "okta user: #{inspect(okta_user)} error: #{inspect(err)}"

    Logger.error("SamlJIT Provisioner: Failed to provision #{inspects}")
  end
end
