defmodule Guard.Store.ServiceAccount do
  @moduledoc """
  Store module for service account operations.

  Service accounts are built on top of the existing user infrastructure,
  with an additional service_accounts table for service account specific data.
  They reuse the user tables for authentication and RBAC integration.
  """

  require Logger
  import Ecto.Query
  import Guard.Utils, only: [valid_uuid?: 1]

  alias Guard.FrontRepo
  alias Guard.FrontRepo.{User, ServiceAccount}
  alias Guard.AuthenticationToken
  alias Ecto.Changeset

  @doc """
  Find a service account by ID.

  Returns the service account with its associated user data.
  """
  @spec find(String.t()) :: {:ok, map()} | {:error, :not_found}
  def find(service_account_id) when is_binary(service_account_id) do
    if valid_uuid?(service_account_id) do
      query =
        build_service_account_query()
        |> where([sa, u], sa.id == ^service_account_id)
        |> where([sa, u], is_nil(u.blocked_at))

      case FrontRepo.one(query) do
        nil -> {:error, :not_found}
        service_account -> {:ok, service_account}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Find multiple service accounts by IDs.

  Returns a list of service accounts for the given IDs.
  Invalid or non-existent IDs are filtered out.
  """
  @spec find_many([String.t()]) :: {:ok, [map()]} | {:error, term()}
  def find_many(service_account_ids) when is_list(service_account_ids) do
    # Filter out invalid UUIDs
    valid_ids = Enum.filter(service_account_ids, &valid_uuid?/1)

    if length(valid_ids) > 0 do
      query =
        build_service_account_query()
        |> where([sa, u], sa.id in ^valid_ids)
        |> where([sa, u], is_nil(u.blocked_at))
        |> order_by([sa, u], asc: u.created_at, asc: sa.id)

      service_accounts = FrontRepo.all(query)
      {:ok, service_accounts}
    else
      {:ok, []}
    end
  rescue
    e ->
      Logger.error(
        "Error during find_many for service accounts #{inspect(service_account_ids)}: #{inspect(e)}"
      )

      {:error, :internal_error}
  end

  @doc """
  Find service accounts by organization with pagination.

  Returns a list of service accounts for the given organization.
  """
  @spec find_by_org(String.t(), integer(), String.t() | nil) ::
          {:ok, %{service_accounts: [map()], next_page_token: String.t() | nil}}
          | {:error, term()}
  def find_by_org(org_id, page_size, page_token \\ nil)
      when is_binary(org_id) and is_integer(page_size) and page_size > 0 do
    if valid_uuid?(org_id) do
      # Simple offset-based pagination for now (can be enhanced later)
      offset = if page_token && page_token != "", do: String.to_integer(page_token), else: 0

      query =
        build_service_account_query()
        |> where([sa, u], u.org_id == ^org_id)
        |> where([sa, u], is_nil(u.blocked_at))
        |> order_by([sa, u], asc: u.created_at, asc: sa.id)
        # Get one extra to check if there are more
        |> limit(^(page_size + 1))
        |> offset(^offset)

      case FrontRepo.all(query) do
        service_accounts when length(service_accounts) <= page_size ->
          {:ok,
           %{
             service_accounts: service_accounts,
             next_page_token: nil
           }}

        service_accounts ->
          # More results available
          actual_results = Enum.take(service_accounts, page_size)
          next_token = Integer.to_string(offset + page_size)

          {:ok,
           %{
             service_accounts: actual_results,
             next_page_token: next_token
           }}
      end
    else
      {:error, :invalid_org_id}
    end
  end

  @doc """
  Create a new service account.

  Creates both the user record and the service account record in a transaction.
  Returns the service account data along with the plain text API token.
  """
  @spec create(map()) ::
          {:ok, %{service_account: map(), api_token: String.t()}}
          | {:error, term()}
  def create(params) do
    with {:ok, {plain_token, hashed_token}} <- generate_api_token(),
         {:ok, user} <- create_user_record(params, hashed_token),
         {:ok, service_account} <- create_service_account_record(user.id, params),
         service_account_data <- format_service_account_response(service_account, user) do
      {:ok, %{service_account: service_account_data, api_token: plain_token}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Update an existing service account.

  Only allows updating name and description.
  """
  @spec update(String.t(), map()) ::
          {:ok, map()}
          | {:error, :not_found | :internal_error | [{atom(), Changeset.error()}]}
  def update(service_account_id, params) when is_binary(service_account_id) do
    if valid_uuid?(service_account_id) do
      FrontRepo.transaction(fn ->
        with {:ok, _current_data} <- find(service_account_id),
             {:ok, updated_user} <- update_user_record(service_account_id, params),
             {:ok, updated_service_account} <-
               update_service_account_record(service_account_id, params) do
          format_service_account_response(updated_service_account, updated_user)
        else
          {:error, reason} ->
            FrontRepo.rollback(reason)
        end
      end)
    else
      {:error, :invalid_id}
    end
  rescue
    e ->
      Logger.error(
        "Error during service account update #{inspect(service_account_id)}: #{inspect(e)}"
      )

      {:error, :internal_error}
  end

  @doc """
  Deactivate a service account.

  Performs a soft delete by setting the user's deactivated flag to true.
  """
  @spec deactivate(String.t()) :: {:ok, :deactivated} | {:error, :not_found | :internal_error}
  def deactivate(service_account_id) when is_binary(service_account_id) do
    if valid_uuid?(service_account_id) do
      case FrontRepo.transaction(fn ->
             with {:ok, _current_data} <- find(service_account_id),
                  {:ok, _updated_user} <- deactivate_user_record(service_account_id) do
               :deactivated
             else
               {:error, :not_found} ->
                 FrontRepo.rollback(:not_found)

               {:error, _reason} ->
                 FrontRepo.rollback(:internal_error)
             end
           end) do
        {:ok, :deactivated} -> {:ok, :deactivated}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :invalid_id}
    end
  rescue
    e ->
      Logger.error(
        "Error during service account deactivation #{inspect(service_account_id)}: #{inspect(e)}"
      )

      {:error, :internal_error}
  end

  @doc """
  Reactivate a service account.

  Reactivates a previously deactivated service account by setting the user's deactivated flag to false.
  """
  @spec reactivate(String.t()) :: {:ok, :reactivated} | {:error, :not_found | :internal_error}
  def reactivate(service_account_id) when is_binary(service_account_id) do
    case FrontRepo.transaction(fn ->
           # Use a modified query that includes deactivated service accounts
           query =
             build_service_account_query()
             |> where([sa, u], sa.id == ^service_account_id)
             |> where([sa, u], is_nil(u.blocked_at))

           with service_account when not is_nil(service_account) <- FrontRepo.one(query),
                {:ok, _updated_user} <- reactivate_user_record(service_account_id) do
             :reactivated
           else
             nil ->
               FrontRepo.rollback(:not_found)

             {:error, _reason} ->
               FrontRepo.rollback(:internal_error)
           end
         end) do
      {:ok, :reactivated} -> {:ok, :reactivated}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e ->
      Logger.error(
        "Error during service account reactivation #{inspect(service_account_id)}: #{inspect(e)}"
      )

      {:error, :internal_error}
  end

  @doc """
  Destroy a service account.

  Permanently deletes the service account and associated user records from the database.
  This action cannot be undone.
  """
  @spec destroy(String.t()) :: {:ok, :destroyed} | {:error, :not_found | :internal_error}
  def destroy(service_account_id) when is_binary(service_account_id) do
    if valid_uuid?(service_account_id) do
      case FrontRepo.transaction(fn ->
             # Use a modified query that includes deactivated service accounts for destruction
             query =
               build_service_account_query()
               |> where([sa, u], sa.id == ^service_account_id)
               |> where([sa, u], is_nil(u.blocked_at))

             case FrontRepo.one(query) do
               nil ->
                 FrontRepo.rollback(:not_found)

               _service_account ->
                 with {:ok, _} <- destroy_service_account_record(service_account_id),
                      {:ok, _} <- destroy_user_record(service_account_id) do
                   :destroyed
                 else
                   {:error, _reason} -> FrontRepo.rollback(:internal_error)
                 end
             end
           end) do
        {:ok, :destroyed} -> {:ok, :destroyed}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :invalid_id}
    end
  rescue
    e ->
      Logger.error(
        "Error during service account destruction #{inspect(service_account_id)}: #{inspect(e)}"
      )

      {:error, :internal_error}
  end

  @doc """
  Regenerate API token for a service account.

  Generates a new token and updates the user's authentication_token field.
  """
  @spec regenerate_token(String.t()) ::
          {:ok, String.t()}
          | {:error, :not_found | :internal_error}
  def regenerate_token(service_account_id) when is_binary(service_account_id) do
    if valid_uuid?(service_account_id) do
      FrontRepo.transaction(fn ->
        with {:ok, _current_data} <- find(service_account_id),
             {:ok, {plain_token, hashed_token}} <- generate_api_token(),
             {:ok, _updated_user} <- update_user_token(service_account_id, hashed_token) do
          plain_token
        else
          {:error, reason} ->
            FrontRepo.rollback(reason)
        end
      end)
    else
      {:error, :invalid_id}
    end
  rescue
    e ->
      Logger.error(
        "Error during token regeneration for service account #{inspect(service_account_id)}: #{inspect(e)}"
      )

      {:error, :internal_error}
  end

  # Private helper functions

  defp build_service_account_query do
    from(sa in ServiceAccount,
      join: u in User,
      on: sa.id == u.id,
      where: u.creation_source == :service_account,
      select: %{
        id: sa.id,
        name: u.name,
        description: sa.description,
        org_id: u.org_id,
        creator_id: sa.creator_id,
        deactivated: u.deactivated,
        email: u.email,
        created_at: u.created_at,
        updated_at: u.updated_at
      }
    )
  end

  defp generate_api_token do
    # Use the existing User.reset_auth_token logic
    case FrontRepo.User.reset_auth_token(%User{}) do
      {:ok, plain_token} ->
        hashed_token = AuthenticationToken.hash_token(plain_token)
        {:ok, {plain_token, hashed_token}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_user_record(params, hashed_token) do
    # Generate synthetic email following the pattern from the implementation plan
    synthetic_email = generate_synthetic_email(params.name, params.org_id)

    user_params = %{
      email: synthetic_email,
      name: params.name,
      # Leave empty for service accounts
      company: "",
      org_id: params.org_id,
      single_org_user: true,
      creation_source: :service_account,
      deactivated: false,
      authentication_token: hashed_token
    }

    changeset = User.changeset(%User{}, user_params)

    case FrontRepo.insert(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  defp create_service_account_record(user_id, params) do
    service_account_params = %{
      id: user_id,
      description: Map.get(params, :description, ""),
      creator_id: params.creator_id
    }

    changeset = ServiceAccount.changeset(%ServiceAccount{}, service_account_params)

    case FrontRepo.insert(changeset) do
      {:ok, service_account} -> {:ok, service_account}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  defp update_user_record(user_id, params) do
    user = FrontRepo.get!(User, user_id)

    # Only allow updating name (which affects the synthetic email)
    update_params = %{}

    update_params =
      if Map.has_key?(params, :name),
        do: Map.put(update_params, :name, params.name),
        else: update_params

    # Update email if name changed
    update_params =
      if Map.has_key?(update_params, :name) do
        synthetic_email = generate_synthetic_email(params.name, user.org_id)
        Map.put(update_params, :email, synthetic_email)
      else
        update_params
      end

    changeset = User.changeset(user, update_params)

    case FrontRepo.update(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  defp update_service_account_record(service_account_id, params) do
    service_account = FrontRepo.get!(ServiceAccount, service_account_id)

    # Only allow updating description
    update_params = %{}

    update_params =
      if Map.has_key?(params, :description),
        do: Map.put(update_params, :description, params.description),
        else: update_params

    changeset = ServiceAccount.changeset(service_account, update_params)

    case FrontRepo.update(changeset) do
      {:ok, service_account} -> {:ok, service_account}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  defp deactivate_user_record(user_id) do
    user = FrontRepo.get!(User, user_id)

    changeset =
      User.changeset(user, %{
        deactivated: true,
        deactivated_at: DateTime.utc_now()
      })

    case FrontRepo.update(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  defp reactivate_user_record(user_id) do
    user = FrontRepo.get!(User, user_id)

    changeset =
      User.changeset(user, %{
        deactivated: false,
        deactivated_at: nil
      })

    case FrontRepo.update(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  defp destroy_service_account_record(service_account_id) do
    case FrontRepo.get(ServiceAccount, service_account_id) do
      nil ->
        {:error, :not_found}

      service_account ->
        case FrontRepo.delete(service_account) do
          {:ok, _} -> {:ok, :deleted}
          {:error, changeset} -> {:error, changeset.errors}
        end
    end
  end

  defp destroy_user_record(user_id) do
    case FrontRepo.get(User, user_id) do
      nil ->
        {:error, :not_found}

      user ->
        case FrontRepo.delete(user) do
          {:ok, _} -> {:ok, :deleted}
          {:error, changeset} -> {:error, changeset.errors}
        end
    end
  end

  defp update_user_token(user_id, hashed_token) do
    user = FrontRepo.get!(User, user_id)

    changeset = User.changeset(user, %{authentication_token: hashed_token})

    case FrontRepo.update(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  defp generate_synthetic_email(service_account_name, org_id) do
    # Get organization name for email generation via API
    base_domain = Application.fetch_env!(:guard, :base_domain)

    case Guard.Api.Organization.fetch(org_id) do
      %{org_username: org_username} ->
        # Sanitize names for email compatibility
        sanitized_name =
          String.downcase(service_account_name) |> String.replace(~r/[^a-z0-9\-]/, "-")

        sanitized_org = String.downcase(org_username) |> String.replace(~r/[^a-z0-9\-]/, "-")
        "#{sanitized_name}@service-accounts.#{sanitized_org}.#{base_domain}"

      _ ->
        # Fallback if org not found (shouldn't happen in normal flow)
        sanitized_name =
          String.downcase(service_account_name) |> String.replace(~r/[^a-z0-9\-]/, "-")

        "#{sanitized_name}@service-accounts.unknown.#{base_domain}"
    end
  end

  defp format_service_account_response(service_account, user) do
    %{
      id: service_account.id,
      name: user.name,
      description: service_account.description,
      org_id: user.org_id,
      creator_id: service_account.creator_id,
      deactivated: user.deactivated,
      user_id: user.id,
      email: user.email,
      user: user,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end
end
