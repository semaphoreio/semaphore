defmodule Rbac.Okta.Integration do
  @moduledoc """
  This module is a partially hardcoded implementation of the Okta Integrations.
  """

  require Ecto.Query
  require Logger

  alias Ecto.Query
  alias Rbac.Repo
  alias Rbac.Okta.Saml.Certificate

  alias Rbac.Okta.SessionExpiration
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
        idempotency_token \\ Ecto.UUID.generate(),
        session_expiration_minutes \\ nil
      ) do
    existing = fetch_existing(org_id)

    resolved =
      resolve_inputs(existing, %{
        sso_url: sso_url,
        saml_issuer: saml_issuer,
        certificate: certificate,
        jit_provisioning_enabled: jit_provisioning_enabled,
        session_expiration_minutes: session_expiration_minutes
      })

    case resolve_fingerprint(existing, resolved.certificate, org_id) do
      {:ok, fingerprint_base64} ->
        reset_scim_token =
          should_reset_scim_token?(
            existing,
            resolved.sso_url,
            resolved.saml_issuer,
            fingerprint_base64,
            resolved.jit_provisioning_enabled,
            resolved.certificate
          )

        org_id
        |> persist_integration(
          integration_attrs(
            org_id,
            creator_id,
            resolved,
            fingerprint_base64,
            idempotency_token
          ),
          reset_scim_token
        )
        |> handle_create_or_update_result(org_id)

      {:error, reason} ->
        Logger.error("Failed to resolve certificate for org #{org_id}: #{inspect(reason)}.")
        {:error, :cert_decode_error}
    end
  end

  defp fetch_existing(org_id) do
    case Rbac.Repo.OktaIntegration.fetch_for_org(org_id) do
      {:ok, integration} -> integration
      _ -> nil
    end
  end

  defp resolve_inputs(existing, inputs) do
    sso_url = resolve_existing_value(existing, inputs.sso_url, :sso_url)
    saml_issuer = resolve_existing_value(existing, inputs.saml_issuer, :saml_issuer)

    credentials_present? =
      present?(inputs.sso_url) or present?(inputs.saml_issuer) or present?(inputs.certificate)

    jit_provisioning_enabled =
      resolve_jit_provisioning(existing, inputs.jit_provisioning_enabled, credentials_present?)

    session_expiration_minutes =
      resolve_session_expiration(existing, inputs.session_expiration_minutes, inputs.certificate)

    %{
      sso_url: sso_url,
      saml_issuer: saml_issuer,
      certificate: inputs.certificate,
      jit_provisioning_enabled: jit_provisioning_enabled,
      session_expiration_minutes: session_expiration_minutes
    }
  end

  defp resolve_existing_value(nil, value, _field), do: value

  defp resolve_existing_value(existing, value, field) do
    if present?(value), do: value, else: Map.get(existing, field)
  end

  defp resolve_jit_provisioning(nil, value, _credentials_present?), do: value

  defp resolve_jit_provisioning(existing, nil, _credentials_present?),
    do: existing.jit_provisioning_enabled

  defp resolve_jit_provisioning(existing, _value, false),
    do: existing.jit_provisioning_enabled

  defp resolve_jit_provisioning(_existing, value, true), do: value

  defp resolve_session_expiration(existing, session_expiration_minutes, certificate) do
    cond do
      existing && present?(certificate) ->
        existing.session_expiration_minutes

      is_integer(session_expiration_minutes) and session_expiration_minutes > 0 ->
        session_expiration_minutes

      existing ->
        existing.session_expiration_minutes

      true ->
        SessionExpiration.default_minutes()
    end
  end

  defp integration_attrs(org_id, creator_id, resolved, fingerprint_base64, idempotency_token) do
    [
      org_id: org_id,
      creator_id: creator_id,
      sso_url: resolved.sso_url,
      saml_issuer: resolved.saml_issuer,
      saml_certificate_fingerprint: fingerprint_base64,
      jit_provisioning_enabled: resolved.jit_provisioning_enabled,
      session_expiration_minutes: resolved.session_expiration_minutes,
      idempotency_token: idempotency_token
    ]
  end

  defp persist_integration(org_id, attrs, reset_scim_token) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:integration, fn _repo, _changes ->
      Rbac.Repo.OktaIntegration.insert_or_update(attrs, reset_scim_token: reset_scim_token)
    end)
    |> Ecto.Multi.run(:allowed_id_providers, fn _repo, _changes ->
      add_okta_to_allowed_id_providers(org_id)
    end)
    |> Rbac.Repo.transaction()
  end

  defp handle_create_or_update_result({:ok, %{integration: integration}}, _org_id),
    do: {:ok, integration}

  defp handle_create_or_update_result({:error, :integration, reason, _changes}, org_id) do
    Logger.error("Failed to create/update Okta integration for org #{org_id}: #{inspect(reason)}")
    {:error, {:integration_failed, reason}}
  end

  defp handle_create_or_update_result({:error, :allowed_id_providers, reason, _changes}, org_id) do
    Logger.error(
      "Failed to add Okta to allowed ID providers for org #{org_id}: #{inspect(reason)}"
    )

    {:error, {:allowed_id_providers_failed, reason}}
  end

  defp handle_create_or_update_result({:error, operation, reason, _changes}, org_id) do
    Logger.error(
      "Unknown operation #{inspect(operation)} failed for org #{org_id}: #{inspect(reason)}"
    )

    {:error, reason}
  end

  defp resolve_fingerprint(nil, certificate, _org_id) when certificate in [nil, ""] do
    {:error, :missing_certificate}
  end

  defp resolve_fingerprint(existing, certificate, _org_id) when certificate in [nil, ""] do
    {:ok, existing.saml_certificate_fingerprint}
  end

  defp resolve_fingerprint(_existing, certificate, _org_id) do
    with {:ok, fingerprint} <- Certificate.fingerprint(certificate) do
      {:ok, Base.encode64(fingerprint)}
    end
  end

  defp present?(value), do: value not in [nil, ""]

  defp should_reset_scim_token?(nil, _sso_url, _saml_issuer, _fingerprint, _jit, _certificate),
    do: true

  defp should_reset_scim_token?(
         existing,
         sso_url,
         saml_issuer,
         fingerprint_base64,
         jit_provisioning_enabled,
         certificate
       ) do
    certificate_changed? = present?(certificate)

    sso_url != existing.sso_url or saml_issuer != existing.saml_issuer or
      fingerprint_base64 != existing.saml_certificate_fingerprint or
      jit_provisioning_enabled != existing.jit_provisioning_enabled or
      certificate_changed?
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
