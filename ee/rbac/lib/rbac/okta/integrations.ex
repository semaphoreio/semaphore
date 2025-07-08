defmodule Rbac.Okta.Integration do
  @moduledoc """
  This module is a partially hardcoded implementation of the Okta Integrations.
  """

  require Ecto.Query
  require Logger

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
    Ecto.Multi.new()
    |> Ecto.Multi.run(:fingerprint, fn _repo, _changes ->
      Certificate.fingerprint(certificate)
    end)
    |> Ecto.Multi.run(:integration, fn _repo, %{fingerprint: fingerprint} ->
      Rbac.Repo.OktaIntegration.insert_or_update(
        org_id: org_id,
        creator_id: creator_id,
        sso_url: sso_url,
        saml_issuer: saml_issuer,
        saml_certificate_fingerprint: Base.encode64(fingerprint),
        jit_provisioning_enabled: jit_provisioning_enabled,
        idempotency_token: idempotency_token
      )
    end)
    |> Ecto.Multi.run(:allowed_id_providers, fn _repo, _changes ->
      add_okta_to_allowed_id_providers(org_id)
    end)
    |> Rbac.Repo.transaction()
    |> case do
      {:ok, %{integration: integration}} ->
        {:ok, integration}

      {:error, :fingerprint, reason, _changes} ->
        Logger.error("Failed to decode certificate for org #{org_id}: #{inspect(reason)}.")
        {:error, :cert_decode_error}

      {:error, :integration, reason, _changes} ->
        Logger.error(
          "Failed to create/update Okta integration for org #{org_id}: #{inspect(reason)}"
        )

        {:error, {:integration_failed, reason}}

      {:error, :allowed_id_providers, reason, _changes} ->
        Logger.error(
          "Failed to add Okta to allowed ID providers for org #{org_id}: #{inspect(reason)}"
        )

        {:error, {:allowed_id_providers_failed, reason}}

      {:error, operation, reason, _changes} ->
        Logger.error(
          "Unknown operation #{inspect(operation)} failed for org #{org_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp update_id_providers(org_id, operation, action) do
    with {:ok, org} <- Rbac.Api.Organization.find_by_id(org_id),
         updated_providers <- operation.(org.allowed_id_providers || []),
         updated_org <- Map.put(org, :allowed_id_providers, updated_providers),
         {:ok, updated} <- Rbac.Api.Organization.update(updated_org) do
      {:ok, updated}
    else
      {:error, :not_found} ->
        Logger.error("Failed to #{action} okta provider: Org #{org_id} not found")
        {:error, :organization_not_found}

      {:error, reason} ->
        Logger.error("Failed to #{action} okta provider for org #{org_id}: #{inspect(reason)}")

        {:error, :update_failed}
    end
  end

  defp add_okta_to_allowed_id_providers(org_id) do
    update_id_providers(org_id, &Enum.uniq(&1 ++ ["okta"]), "add")
  end

  defp remove_okta_from_allowed_id_providers(org_id) do
    update_id_providers(org_id, &Enum.reject(&1, fn provider -> provider == "okta" end), "remove")
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
      |> Ecto.Multi.run(:delete_okta_users, fn _repo, _changes ->
        OktaUser.delete_all(id)
        {:ok, :okta_users_deleted}
      end)
      |> Ecto.Multi.run(:remove_okta_from_allowed_id_providers, fn _repo, _changes ->
        remove_okta_from_allowed_id_providers(integration.org_id)
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
