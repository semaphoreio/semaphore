defmodule Guard.McpGrant.Actions do
  @moduledoc """
  Business logic layer for MCP grant operations.

  This module handles MCP OAuth grant creation, updating, revocation, and deletion
  with user ownership validation and business logic.
  """

  require Logger
  import Guard.Utils, only: [valid_uuid?: 1]

  alias Guard.Store.McpGrant
  alias Guard.Repo

  @type grant_params :: %{
          user_id: String.t(),
          client_id: String.t(),
          client_name: String.t() | nil,
          tool_scopes: [String.t()],
          org_grants: [map()] | nil,
          project_grants: [map()] | nil,
          expires_at: DateTime.t() | nil,
          created_by_ip: String.t() | nil,
          user_agent: String.t() | nil
        }

  @doc """
  Create a new MCP grant.

  Creates the grant with org and project access grants in a transaction.
  """
  @spec create(grant_params()) ::
          {:ok, Guard.Repo.McpGrant.t()} | {:error, term()}
  def create(params) do
    # Validate user_id
    case params[:user_id] do
      nil ->
        {:error, :missing_user_id}

      user_id ->
        if valid_uuid?(user_id) do
          McpGrant.create(params)
        else
          {:error, :invalid_user_id}
        end
    end
  end

  @doc """
  Update an existing MCP grant.

  Validates that the user owns the grant before updating.
  """
  @spec update(String.t(), String.t(), map()) ::
          {:ok, Guard.Repo.McpGrant.t()} | {:error, :not_found | :unauthorized | term()}
  def update(grant_id, user_id, params) do
    if valid_uuid?(grant_id) and valid_uuid?(user_id) do
      case McpGrant.find(grant_id) do
        {:ok, grant} ->
          # Verify user owns this grant
          if grant.user_id == user_id do
            McpGrant.update(grant, params)
          else
            {:error, :unauthorized}
          end

        {:error, :not_found} ->
          {:error, :not_found}
      end
    else
      {:error, :invalid_id}
    end
  end

  @doc """
  Revoke an MCP grant (soft delete).

  Validates that the user owns the grant before revoking.
  Sets the revoked_at timestamp.
  """
  @spec revoke(String.t(), String.t()) ::
          {:ok, Guard.Repo.McpGrant.t()} | {:error, :not_found | :unauthorized | term()}
  def revoke(grant_id, user_id) do
    if valid_uuid?(grant_id) and valid_uuid?(user_id) do
      case McpGrant.find(grant_id) do
        {:ok, grant} ->
          # Verify user owns this grant
          if grant.user_id == user_id do
            McpGrant.revoke(grant_id)
          else
            {:error, :unauthorized}
          end

        {:error, :not_found} ->
          {:error, :not_found}
      end
    else
      {:error, :invalid_id}
    end
  end

  @doc """
  Delete an MCP grant (hard delete).

  Validates that the user owns the grant before deleting.
  Permanently removes the grant and all associated org/project grants.
  """
  @spec delete(String.t(), String.t()) ::
          {:ok, :deleted} | {:error, :not_found | :unauthorized | term()}
  def delete(grant_id, user_id) do
    if valid_uuid?(grant_id) and valid_uuid?(user_id) do
      case McpGrant.find_including_revoked(grant_id) do
        {:ok, grant} ->
          # Verify user owns this grant
          if grant.user_id == user_id do
            McpGrant.delete(grant_id)
          else
            {:error, :unauthorized}
          end

        {:error, :not_found} ->
          {:error, :not_found}
      end
    else
      {:error, :invalid_id}
    end
  end

  @doc """
  List MCP grants for a user with pagination.

  Returns active (non-revoked) grants by default.
  """
  @spec list(String.t(), %{
          page_size: integer(),
          page_token: String.t() | nil,
          include_revoked: boolean()
        }) ::
          {:ok,
           %{
             grants: [Guard.Repo.McpGrant.t()],
             next_page_token: String.t() | nil,
             total_count: integer()
           }}
          | {:error, term()}
  def list(user_id, %{page_size: page_size} = params) do
    page_token = Map.get(params, :page_token)
    include_revoked = Map.get(params, :include_revoked, false)

    if valid_uuid?(user_id) do
      McpGrant.list_for_user(user_id, page_size, page_token, include_revoked: include_revoked)
    else
      {:error, :invalid_user_id}
    end
  end

  @doc """
  Get a single MCP grant by ID.

  Does not validate ownership - this is for read-only operations.
  Used by gRPC describe endpoint.
  """
  @spec describe(String.t()) ::
          {:ok, Guard.Repo.McpGrant.t()} | {:error, :not_found}
  def describe(grant_id) do
    if valid_uuid?(grant_id) do
      McpGrant.find(grant_id)
    else
      {:error, :not_found}
    end
  end

  @doc """
  Find existing valid grant for a user and client.

  Returns the most recent non-revoked, non-expired grant for the given user and client.
  Used by Keycloak Required Action to check if grant selection can be skipped.
  """
  @spec find_existing_grant(String.t(), String.t()) ::
          {:ok, Guard.Repo.McpGrant.t()} | {:error, :not_found | :invalid_params}
  def find_existing_grant(user_id, client_id) do
    if valid_uuid?(user_id) and is_binary(client_id) and String.trim(client_id) != "" do
      import Ecto.Query

      query =
        from(g in Guard.Repo.McpGrant,
          where: g.user_id == ^user_id and g.client_id == ^client_id,
          where: is_nil(g.revoked_at),
          where: is_nil(g.expires_at) or g.expires_at > ^DateTime.utc_now(),
          order_by: [desc: g.created_at],
          limit: 1,
          preload: [:org_grants, :project_grants]
        )

      case Repo.one(query) do
        nil -> {:error, :not_found}
        grant -> {:ok, grant}
      end
    else
      {:error, :invalid_params}
    end
  end

  @doc """
  Check if a grant has access to an organization.

  Used by MCP server for authorization checks (Phase 3).
  """
  @spec check_org_access(String.t(), String.t()) ::
          {:ok, %{allowed: boolean(), can_view: boolean(), can_run_workflows: boolean()}}
          | {:error, :not_found}
  def check_org_access(grant_id, org_id) do
    McpGrant.check_org_access(grant_id, org_id)
  end

  @doc """
  Check if a grant has access to a project.

  Used by MCP server for authorization checks (Phase 3).
  """
  @spec check_project_access(String.t(), String.t()) ::
          {:ok,
           %{
             allowed: boolean(),
             can_view: boolean(),
             can_run_workflows: boolean(),
             can_view_logs: boolean()
           }}
          | {:error, :not_found}
  def check_project_access(grant_id, project_id) do
    McpGrant.check_project_access(grant_id, project_id)
  end
end
