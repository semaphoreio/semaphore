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
        idempotency_token \\ Ecto.UUID.generate()
      ) do
    with {:ok, fingerprint} <- Certificate.fingerprint(certificate),
         {:ok, integration} <-
           Rbac.Repo.OktaIntegration.insert_or_update(
             org_id: org_id,
             creator_id: creator_id,
             sso_url: sso_url,
             saml_issuer: saml_issuer,
             saml_certificate_fingerprint: fingerprint,
             idempotency_token: idempotency_token,
           ) do
      {:ok, integration}
    else
      e -> e
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
