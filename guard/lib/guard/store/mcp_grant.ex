defmodule Guard.Store.McpGrant do
  @moduledoc """
  Store module for MCP grant operations.

  Provides query functions for managing MCP OAuth grants, including
  organization and project access grants.
  """

  require Logger
  import Ecto.Query
  import Guard.Utils, only: [valid_uuid?: 1]

  alias Guard.Repo
  alias Guard.Repo.{McpGrant, McpGrantOrg, McpGrantProject}

  @doc """
  Find an MCP grant by ID.

  Preloads org_grants and project_grants associations.
  Filters out revoked grants.
  """
  @spec find(String.t()) :: {:ok, McpGrant.t()} | {:error, :not_found}
  def find(grant_id) when is_binary(grant_id) do
    if valid_uuid?(grant_id) do
      query =
        from(g in McpGrant,
          where: g.id == ^grant_id and is_nil(g.revoked_at),
          preload: [:org_grants, :project_grants]
        )

      case Repo.one(query) do
        nil -> {:error, :not_found}
        grant -> {:ok, grant}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Find an MCP grant by ID, including revoked grants.

  Used for operations that need to access revoked grants (e.g., for display purposes).
  """
  @spec find_including_revoked(String.t()) :: {:ok, McpGrant.t()} | {:error, :not_found}
  def find_including_revoked(grant_id) when is_binary(grant_id) do
    if valid_uuid?(grant_id) do
      query =
        from(g in McpGrant,
          where: g.id == ^grant_id,
          preload: [:org_grants, :project_grants]
        )

      case Repo.one(query) do
        nil -> {:error, :not_found}
        grant -> {:ok, grant}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  List MCP grants for a specific user with pagination.

  Returns active (non-revoked) grants by default.
  """
  @spec list_for_user(String.t(), integer(), String.t() | nil, keyword()) ::
          {:ok,
           %{
             grants: [McpGrant.t()],
             next_page_token: String.t() | nil,
             total_count: integer()
           }}
          | {:error, term()}
  def list_for_user(user_id, page_size, page_token \\ nil, opts \\ [])
      when is_binary(user_id) and is_integer(page_size) and page_size > 0 do
    if valid_uuid?(user_id) do
      include_revoked = Keyword.get(opts, :include_revoked, false)

      # Simple offset-based pagination
      offset = if page_token && page_token != "", do: String.to_integer(page_token), else: 0

      base_query =
        from(g in McpGrant,
          where: g.user_id == ^user_id,
          preload: [:org_grants, :project_grants]
        )

      query =
        if include_revoked do
          base_query
        else
          from(g in base_query, where: is_nil(g.revoked_at))
        end

      # Get total count
      count_query = from(g in query, select: count(g.id))
      total_count = Repo.one(count_query)

      # Get paginated results
      results_query =
        from(g in query,
          order_by: [desc: g.created_at, desc: g.id],
          limit: ^(page_size + 1),
          offset: ^offset
        )

      results = Repo.all(results_query)

      case results do
        grants when length(grants) <= page_size ->
          {:ok,
           %{
             grants: grants,
             next_page_token: nil,
             total_count: total_count
           }}

        grants ->
          # More results available
          actual_results = Enum.take(grants, page_size)
          next_token = Integer.to_string(offset + page_size)

          {:ok,
           %{
             grants: actual_results,
             next_page_token: next_token,
             total_count: total_count
           }}
      end
    else
      {:error, :invalid_user_id}
    end
  rescue
    e ->
      Logger.error("Error listing MCP grants for user #{user_id}: #{inspect(e)}")
      {:error, :internal_error}
  end

  @doc """
  Create an MCP grant with org and project grants in a transaction.

  Expects params map with:
  - user_id (required)
  - client_id (required)
  - client_name (optional)
  - tool_scopes (optional, list of strings)
  - org_grants (optional, list of maps)
  - project_grants (optional, list of maps)
  - expires_at (optional, DateTime)
  - created_by_ip (optional, string)
  - user_agent (optional, string)
  """
  @spec create(map()) :: {:ok, McpGrant.t()} | {:error, term()}
  def create(params) do
    Repo.transaction(fn ->
      # Create main grant
      grant_params = %{
        user_id: params[:user_id],
        client_id: params[:client_id],
        client_name: params[:client_name],
        tool_scopes: params[:tool_scopes] || [],
        expires_at: params[:expires_at],
        created_by_ip: params[:created_by_ip],
        user_agent: params[:user_agent]
      }

      grant_changeset = McpGrant.changeset(%McpGrant{}, grant_params)

      case Repo.insert(grant_changeset) do
        {:ok, grant} ->
          # Create org grants if provided
          org_grants =
            case params[:org_grants] do
              nil ->
                []

              org_grant_inputs ->
                Enum.map(org_grant_inputs, fn og ->
                  og_params = Map.put(og, :grant_id, grant.id)
                  og_changeset = McpGrantOrg.changeset(%McpGrantOrg{}, og_params)

                  case Repo.insert(og_changeset) do
                    {:ok, og} -> og
                    {:error, changeset} -> Repo.rollback(changeset)
                  end
                end)
            end

          # Create project grants if provided
          project_grants =
            case params[:project_grants] do
              nil ->
                []

              project_grant_inputs ->
                Enum.map(project_grant_inputs, fn pg ->
                  pg_params = Map.put(pg, :grant_id, grant.id)
                  pg_changeset = McpGrantProject.changeset(%McpGrantProject{}, pg_params)

                  case Repo.insert(pg_changeset) do
                    {:ok, pg} -> pg
                    {:error, changeset} -> Repo.rollback(changeset)
                  end
                end)
            end

          # Return grant with associations populated
          %{grant | org_grants: org_grants, project_grants: project_grants}

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  rescue
    e ->
      Logger.error("Error creating MCP grant: #{inspect(e)}")
      {:error, :internal_error}
  end

  @doc """
  Update an MCP grant.

  Replaces org_grants and project_grants if provided.
  """
  @spec update(McpGrant.t(), map()) :: {:ok, McpGrant.t()} | {:error, term()}
  def update(%McpGrant{} = grant, params) do
    Repo.transaction(fn ->
      # Update main grant
      grant_changeset = McpGrant.changeset(grant, params)

      case Repo.update(grant_changeset) do
        {:ok, updated_grant} ->
          # Replace org grants if provided
          org_grants =
            if params[:org_grants] do
              # Delete existing org grants
              from(og in McpGrantOrg, where: og.grant_id == ^updated_grant.id)
              |> Repo.delete_all()

              # Create new org grants
              Enum.map(params[:org_grants], fn og ->
                og_params = Map.put(og, :grant_id, updated_grant.id)
                og_changeset = McpGrantOrg.changeset(%McpGrantOrg{}, og_params)

                case Repo.insert(og_changeset) do
                  {:ok, og} -> og
                  {:error, changeset} -> Repo.rollback(changeset)
                end
              end)
            else
              updated_grant.org_grants
            end

          # Replace project grants if provided
          project_grants =
            if params[:project_grants] do
              # Delete existing project grants
              from(pg in McpGrantProject, where: pg.grant_id == ^updated_grant.id)
              |> Repo.delete_all()

              # Create new project grants
              Enum.map(params[:project_grants], fn pg ->
                pg_params = Map.put(pg, :grant_id, updated_grant.id)
                pg_changeset = McpGrantProject.changeset(%McpGrantProject{}, pg_params)

                case Repo.insert(pg_changeset) do
                  {:ok, pg} -> pg
                  {:error, changeset} -> Repo.rollback(changeset)
                end
              end)
            else
              updated_grant.project_grants
            end

          # Return grant with associations populated
          %{updated_grant | org_grants: org_grants, project_grants: project_grants}

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  rescue
    e ->
      Logger.error("Error updating MCP grant: #{inspect(e)}")
      {:error, :internal_error}
  end

  @doc """
  Revoke an MCP grant (soft delete).

  Sets revoked_at timestamp.
  """
  @spec revoke(String.t()) :: {:ok, McpGrant.t()} | {:error, :not_found | term()}
  def revoke(grant_id) when is_binary(grant_id) do
    case find(grant_id) do
      {:ok, grant} ->
        changeset = McpGrant.changeset(grant, %{revoked_at: DateTime.utc_now()})

        case Repo.update(changeset) do
          {:ok, revoked_grant} -> {:ok, revoked_grant}
          {:error, changeset} -> {:error, changeset}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  rescue
    e ->
      Logger.error("Error revoking MCP grant #{grant_id}: #{inspect(e)}")
      {:error, :internal_error}
  end

  @doc """
  Delete an MCP grant (hard delete).

  Permanently removes the grant and all associated org/project grants.
  """
  @spec delete(String.t()) :: {:ok, :deleted} | {:error, :not_found | term()}
  def delete(grant_id) when is_binary(grant_id) do
    case find_including_revoked(grant_id) do
      {:ok, grant} ->
        case Repo.delete(grant) do
          {:ok, _} -> {:ok, :deleted}
          {:error, changeset} -> {:error, changeset}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  rescue
    e ->
      Logger.error("Error deleting MCP grant #{grant_id}: #{inspect(e)}")
      {:error, :internal_error}
  end

  @doc """
  Check organization access for a grant.

  Returns access details if the grant has access to the org.
  """
  @spec check_org_access(String.t(), String.t()) ::
          {:ok, %{allowed: boolean(), can_view: boolean(), can_run_workflows: boolean()}}
          | {:error, :not_found}
  def check_org_access(grant_id, org_id)
      when is_binary(grant_id) and is_binary(org_id) do
    if valid_uuid?(grant_id) and valid_uuid?(org_id) do
      query =
        from(og in McpGrantOrg,
          join: g in McpGrant,
          on: og.grant_id == g.id,
          where:
            og.grant_id == ^grant_id and og.org_id == ^org_id and is_nil(g.revoked_at) and
              (is_nil(g.expires_at) or g.expires_at > ^DateTime.utc_now()),
          select: %{
            can_view: og.can_view,
            can_run_workflows: og.can_run_workflows
          }
        )

      case Repo.one(query) do
        nil ->
          {:ok, %{allowed: false, can_view: false, can_run_workflows: false}}

        access ->
          {:ok, Map.put(access, :allowed, true)}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Check project access for a grant.

  Returns access details if the grant has access to the project.
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
  def check_project_access(grant_id, project_id)
      when is_binary(grant_id) and is_binary(project_id) do
    if valid_uuid?(grant_id) and valid_uuid?(project_id) do
      query =
        from(pg in McpGrantProject,
          join: g in McpGrant,
          on: pg.grant_id == g.id,
          where:
            pg.grant_id == ^grant_id and pg.project_id == ^project_id and is_nil(g.revoked_at) and
              (is_nil(g.expires_at) or g.expires_at > ^DateTime.utc_now()),
          select: %{
            can_view: pg.can_view,
            can_run_workflows: pg.can_run_workflows,
            can_view_logs: pg.can_view_logs
          }
        )

      case Repo.one(query) do
        nil ->
          {:ok,
           %{allowed: false, can_view: false, can_run_workflows: false, can_view_logs: false}}

        access ->
          {:ok, Map.put(access, :allowed, true)}
      end
    else
      {:error, :not_found}
    end
  end
end
