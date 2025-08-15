defmodule Guard.ServiceAccount.Actions do
  @moduledoc """
  Business logic layer for service account operations.

  This module handles service account creation, updating, deletion, and token management
  following the existing patterns from Guard.User.Actions. Service accounts are built on
  top of the existing user infrastructure with an additional service_accounts table.
  """

  require Logger

  alias Guard.FrontRepo
  alias Guard.Store.ServiceAccount

  @type service_account_params :: %{
          org_id: String.t(),
          name: String.t(),
          description: String.t(),
          creator_id: String.t()
        }

  @doc """
  Create a new service account.

  This function follows the service account creation flow as specified in the implementation plan:
  1. Validates the request parameters
  2. Creates a user record with service account fields (synthetic email, creation source, etc.)
  3. Creates a service_account record
  4. Generates an API token
  5. Creates RBAC user record
  7. Publishes UserCreated event

  Returns {:ok, %{service_account: service_account, api_token: api_token}} or {:error, reason}
  """
  @spec create(service_account_params()) ::
          {:ok, %{service_account: map(), api_token: String.t()}} | {:error, atom() | list()}
  def create(
        %{
          org_id: _org_id,
          name: _name,
          description: _description,
          creator_id: _creator_id
        } = params
      ) do
    case _create(params) do
      {:ok, {service_account, api_token}} ->
        # Publish UserCreated event for RBAC and other integrations
        Guard.Events.UserCreated.publish(service_account.id, false)
        {:ok, %{service_account: service_account, api_token: api_token}}

      error ->
        error
    end
  end

  @doc """
  Update a service account's name and/or description.

  Updates are applied to both the user record (for name) and service_account record (for description).
  """
  @spec update(String.t(), %{name: String.t(), description: String.t()}) ::
          {:ok, map()} | {:error, atom() | list()}
  def update(service_account_id, %{name: name, description: description}) do
    case ServiceAccount.update(service_account_id, %{name: name, description: description}) do
      {:ok, service_account} ->
        {:ok, service_account}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Deactivate a service account by setting the user's deactivated flag to true.

  This marks the user as deactivated rather than physically deleting records,
  allowing for audit trails and potential recovery.
  """
  @spec deactivate(String.t()) :: {:ok, :deactivated} | {:error, atom()}
  def deactivate(service_account_id) do
    case ServiceAccount.deactivate(service_account_id) do
      {:ok, :deactivated} ->
        {:ok, :deactivated}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Reactivate a previously deactivated service account.

  This sets the user's deactivated flag to false, allowing the service account
  to be used again.
  """
  @spec reactivate(String.t()) :: {:ok, :reactivated} | {:error, atom()}
  def reactivate(service_account_id) do
    case ServiceAccount.reactivate(service_account_id) do
      {:ok, :reactivated} ->
        {:ok, :reactivated}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Permanently destroy a service account and all associated records.

  This physically deletes the service account and user records from the database.
  This action cannot be undone and should be used with caution.
  """
  @spec destroy(String.t()) :: {:ok, :destroyed} | {:error, atom()}
  def destroy(service_account_id) do
    case ServiceAccount.destroy(service_account_id) do
      {:ok, :destroyed} ->
        {:ok, :destroyed}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Regenerate the API token for a service account.

  Generates a new authentication token and invalidates the old one.
  Returns the new plain text token.
  """
  @spec regenerate_token(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def regenerate_token(service_account_id) do
    case ServiceAccount.regenerate_token(service_account_id) do
      {:ok, new_token} ->
        {:ok, new_token}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  List service accounts for an organization with pagination.

  Returns a paginated list of service accounts within the specified organization.
  Uses cursor-based pagination with the service account ID as the cursor.
  """
  @spec list_by_org(String.t(), %{page_size: integer(), page_token: String.t() | nil}) ::
          {:ok, %{service_accounts: [map()], next_page_token: String.t() | nil}}
          | {:error, atom()}
  def list_by_org(org_id, %{page_size: page_size, page_token: page_token}) do
    case ServiceAccount.find_by_org(org_id, page_size, page_token) do
      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        {:error, error}
    end
  end

  # Private helper functions

  defp _create(params) do
    FrontRepo.transaction(fn ->
      with {:ok, result} <- ServiceAccount.create(params),
           {:ok, _rbac_user} <- create_rbac_user(result.service_account) do
        # Return the service account data and API token
        {result.service_account, result.api_token}
      else
        {:error, error} ->
          FrontRepo.rollback(error)
      end
    end)
  end

  defp create_rbac_user(service_account) do
    # RBAC operations use Guard.Repo (different database from FrontRepo)
    case Guard.Store.RbacUser.create(
           service_account.id,
           service_account.email,
           service_account.name,
           "service_account"
         ) do
      :ok ->
        case Guard.Store.RbacUser.fetch(service_account.id) do
          nil -> {:error, :rbac_user_not_found}
          rbac_user -> {:ok, rbac_user}
        end

      :error ->
        {:error, :rbac_user_creation_failed}
    end
  end
end
