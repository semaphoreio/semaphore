defmodule Rbac.Okta.Integration do
  @moduledoc """
  This module is a partially hardcoded implementation of the Okta Integrations.
  """

  require Ecto.Query
  alias Ecto.Query
  alias Rbac.Repo
  alias Rbac.Okta.Saml.Certificate

  #
  # Integration storage
  #

  def create_or_update(
        org_id,
        creator_id,
        sso_url,
        saml_issuer,
        certificate,
        jit_provisioning_enabled,
        idempotency_token \\ Ecto.UUID.generate()
      ) do
    with {:ok, fingerprint} <- Certificate.fingerprint(certificate),
         {:ok, integration} <-
           Rbac.Repo.OktaIntegration.insert_or_update(
             org_id: org_id,
             creator_id: creator_id,
             sso_url: sso_url,
             saml_issuer: saml_issuer,
             saml_certificate_fingerprint: Base.encode64(fingerprint),
             jit_provisioning_enabled: jit_provisioning_enabled,
             idempotency_token: idempotency_token
           ) do
      add_okta_to_allowed_id_providers(org_id)
      {:ok, integration}
    else
      e -> e
    end
  end

  defp add_okta_to_allowed_id_providers(org_id) do
    require Logger

    with {:ok, org} <- Rbac.Api.Organization.find_by_id(org_id),
         updated_providers <- Enum.uniq((org.allowed_id_providers || []) ++ ["okta"]),
         updated_org <- Map.put(org, :allowed_id_providers, updated_providers),
         {:ok, updated} <- Rbac.Api.Organization.update(updated_org) do
      {:ok, updated}
    else
      {:error, :not_found} ->
        Logger.error("Failed to update id_providers: Org #{org_id} not found")
        {:error, :organization_not_found}

      {:error, reason} ->
        Logger.error("Failed to update id_providers for org #{org_id}: #{inspect(reason)}")
        {:error, :update_failed}
    end
  end

  def generate_scim_token(integration) do
    token = Rbac.Okta.Scim.Token.generate()
    token_hash = Rbac.Okta.Scim.Token.hash(token)

    integration =
      Rbac.Repo.OktaIntegration.changeset(integration, %{
        scim_token_hash: Base.encode64(token_hash)
      })

    case Repo.update(integration) do
      {:ok, _} -> {:ok, token}
      e -> e
    end
  end

  def find_by_org_id(nil), do: {:error, :not_found}

  def find_by_org_id(org_id) do
    query = Query.where(Rbac.Repo.OktaIntegration, org_id: ^org_id)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      integration -> {:ok, integration}
    end
  end

  def find(id) do
    query = Query.where(Rbac.Repo.OktaIntegration, id: ^id)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      integration -> {:ok, integration}
    end
  end

  def list_for_org(org_id) do
    query = Query.where(Rbac.Repo.OktaIntegration, org_id: ^org_id)

    {:ok, Repo.all(query)}
  end

  alias Rbac.Repo.OktaUser

  @doc """
    Destroys okta integration and removes users from the organization

    Returns :ok | :error
  """
  def destroy(id) do
    {:ok, integration} = find(id)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:retract_roles_of_okta_users, fn _repo, _changeset ->
        {:ok, rbi} = Rbac.RoleBindingIdentification.new(org_id: integration.org_id)
        Rbac.RoleManagement.retract_roles(rbi, :okta)
        {:ok, :retracted_roles}
      end)
      |> Ecto.Multi.run(:delete_okta_users, fn _repo, _cahnges ->
        OktaUser.delete_all(id)
        {:ok, :okta_users_deleted}
      end)
      |> Ecto.Multi.delete(:delete_okta_integration, integration)
      |> Rbac.Repo.transaction(timeout: 60_000)

    elem(result, 0)
  end

  defdelegate find_user(integration, okta_user_id), to: OktaUser, as: :find

  def add_user(integration, payload) do
    with {:ok, okta_user} <- OktaUser.create(integration, payload) do
      Rbac.Okta.Scim.Provisioner.perform_now(okta_user.id)

      {:ok, okta_user}
    end
  end

  def update_user(integration, user_id, payload) do
    with {:ok, okta_user} <- OktaUser.update(integration, user_id, payload) do
      Rbac.Okta.Scim.Provisioner.perform_now(okta_user.id)

      {:ok, okta_user}
    end
  end
end
