defmodule PipelinesAPI.Organizations.Onboarding do
  @moduledoc """
  Account-level organization creation: validate the name/username, check the
  billing gate (SaaS only), then create the org.
  """

  alias PipelinesAPI.OrganizationsClient

  @spec create_organization(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, tuple()}
  def create_organization(name, username, user_id) do
    with :ok <- OrganizationsClient.is_valid(name, username, user_id),
         :ok <- validate_billing(user_id) do
      OrganizationsClient.create(user_id, name, username)
    end
  end

  defp validate_billing(user_id) do
    # Billing only exists on SaaS; skip the gate on self-hosted installs.
    if saas?(), do: OrganizationsClient.can_setup_organization(user_id), else: :ok
  end

  defp saas?, do: not Application.fetch_env!(:pipelines_api, :on_prem?)
end
