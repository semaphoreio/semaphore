defmodule Guard.Store.McpGrant do
  @moduledoc """
  Store module for MCP grant operations.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Guard.Repo
  alias Guard.Repo.{McpGrant, McpGrantOrgGrant, McpGrantProjectGrant}

  @org_view_permission "organization.view"
  @org_run_permission "project.run"

  @project_view_permission "project.view"
  @project_run_permission "project.run"
  @project_log_permissions ["job.view", "project.view"]

  @spec create(map()) :: {:ok, McpGrant.t()} | {:error, term()}
  def create(attrs) do
    attrs = normalize_attrs(attrs)
    org_grants = Map.get(attrs, :org_grants, [])
    project_grants = Map.get(attrs, :project_grants, [])

    Multi.new()
    |> Multi.insert(:grant, McpGrant.changeset(%McpGrant{}, attrs))
    |> Multi.run(:org_grants, fn repo, %{grant: grant} ->
      insert_org_grants(repo, grant.id, org_grants)
    end)
    |> Multi.run(:project_grants, fn repo, %{grant: grant} ->
      insert_project_grants(repo, grant.id, project_grants)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{grant: grant}} -> {:ok, preload_grant(grant)}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  @spec update(McpGrant.t(), map()) :: {:ok, McpGrant.t()} | {:error, term()}
  def update(%McpGrant{} = grant, attrs) do
    attrs = normalize_attrs(attrs)
    org_grants = Map.get(attrs, :org_grants, [])
    project_grants = Map.get(attrs, :project_grants, [])

    Multi.new()
    |> Multi.update(:grant, McpGrant.changeset(grant, attrs))
    |> Multi.delete_all(
      :delete_org_grants,
      from(og in McpGrantOrgGrant, where: og.grant_id == ^grant.id)
    )
    |> Multi.delete_all(
      :delete_project_grants,
      from(pg in McpGrantProjectGrant, where: pg.grant_id == ^grant.id)
    )
    |> Multi.run(:org_grants, fn repo, _changes ->
      insert_org_grants(repo, grant.id, org_grants)
    end)
    |> Multi.run(:project_grants, fn repo, _changes ->
      insert_project_grants(repo, grant.id, project_grants)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{grant: updated_grant}} -> {:ok, preload_grant(updated_grant)}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  @spec list_for_user(String.t(), map()) ::
          {:ok, %{grants: [McpGrant.t()], next_page_token: String.t()}}
  def list_for_user(user_id, opts \\ %{}) do
    include_revoked = Map.get(opts, :include_revoked, false)
    page_size = parse_page_size(Map.get(opts, :page_size, 20))
    offset = parse_page_token(Map.get(opts, :page_token, ""))

    base_query =
      from(g in McpGrant,
        where: g.user_id == ^user_id,
        order_by: [desc: g.created_at, desc: g.id]
      )
      |> maybe_filter_revoked(include_revoked)

    grants =
      base_query
      |> limit(^page_size)
      |> offset(^offset)
      |> Repo.all()
      |> Repo.preload([:org_grants, :project_grants])

    next_page_token =
      if length(grants) == page_size do
        Integer.to_string(offset + page_size)
      else
        ""
      end

    {:ok, %{grants: grants, next_page_token: next_page_token}}
  end

  @spec get(String.t()) :: {:ok, McpGrant.t()} | {:error, :not_found}
  def get(grant_id) when is_binary(grant_id) do
    McpGrant
    |> where([g], g.id == ^grant_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      grant -> {:ok, preload_grant(grant)}
    end
  end

  @spec get_for_user(String.t(), String.t()) :: {:ok, McpGrant.t()} | {:error, :not_found}
  def get_for_user(grant_id, user_id) when is_binary(grant_id) and is_binary(user_id) do
    McpGrant
    |> where([g], g.id == ^grant_id and g.user_id == ^user_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      grant -> {:ok, preload_grant(grant)}
    end
  end

  @spec delete_for_user(String.t(), String.t()) :: :ok | {:error, :not_found}
  def delete_for_user(grant_id, user_id) do
    case get_for_user(grant_id, user_id) do
      {:ok, grant} ->
        _ = Repo.delete(grant)
        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @spec revoke_for_user(String.t(), String.t()) :: {:ok, McpGrant.t()} | {:error, :not_found}
  def revoke_for_user(grant_id, user_id) do
    with {:ok, grant} <- get_for_user(grant_id, user_id) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      grant
      |> McpGrant.changeset(%{revoked_at: now})
      |> Repo.update()
      |> case do
        {:ok, revoked} -> {:ok, preload_grant(revoked)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @spec find_existing_valid_grant(String.t(), String.t()) ::
          {:ok, McpGrant.t()} | {:error, :not_found}
  def find_existing_valid_grant(user_id, client_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(g in McpGrant,
      where:
        g.user_id == ^user_id and g.client_id == ^client_id and is_nil(g.revoked_at) and
          (is_nil(g.expires_at) or g.expires_at > ^now),
      order_by: [desc: g.created_at, desc: g.id],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      grant -> {:ok, preload_grant(grant)}
    end
  end

  @spec valid?(McpGrant.t()) :: boolean()
  def valid?(%McpGrant{} = grant) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    is_nil(grant.revoked_at) and
      (is_nil(grant.expires_at) or DateTime.compare(grant.expires_at, now) == :gt)
  end

  @spec touch_last_used(String.t()) :: :ok
  def touch_last_used(grant_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(g in McpGrant, where: g.id == ^grant_id)
    |> Repo.update_all(set: [last_used_at: now])

    :ok
  end

  @spec check_org_access(McpGrant.t(), String.t()) :: %{
          allowed: boolean(),
          can_view: boolean(),
          can_run_workflows: boolean()
        }
  def check_org_access(%McpGrant{} = grant, org_id) do
    grant = preload_grant(grant)

    org_grant = Enum.find(grant.org_grants, fn g -> g.org_id == org_id end)

    if org_grant do
      %{
        allowed: org_grant.can_view or org_grant.can_run_workflows,
        can_view: org_grant.can_view,
        can_run_workflows: org_grant.can_run_workflows
      }
    else
      # Backward-compatible fallback: org is allowed if any project from that org is granted.
      project_grants = Enum.filter(grant.project_grants, fn g -> g.org_id == org_id end)

      can_view = Enum.any?(project_grants, & &1.can_view)
      can_run_workflows = Enum.any?(project_grants, & &1.can_run_workflows)

      %{
        allowed: can_view or can_run_workflows,
        can_view: can_view,
        can_run_workflows: can_run_workflows
      }
    end
  end

  @spec check_project_access(McpGrant.t(), String.t()) ::
          %{
            allowed: boolean(),
            can_view: boolean(),
            can_run_workflows: boolean(),
            can_view_logs: boolean()
          }
  def check_project_access(%McpGrant{} = grant, project_id) do
    grant = preload_grant(grant)

    case Enum.find(grant.project_grants, fn g -> g.project_id == project_id end) do
      nil ->
        %{allowed: false, can_view: false, can_run_workflows: false, can_view_logs: false}

      project_grant ->
        %{
          allowed:
            project_grant.can_view or project_grant.can_run_workflows or
              project_grant.can_view_logs,
          can_view: project_grant.can_view,
          can_run_workflows: project_grant.can_run_workflows,
          can_view_logs: project_grant.can_view_logs
        }
    end
  end

  @spec resolve_org_permissions(McpGrant.t()) :: [
          %{org_id: String.t(), permissions: [String.t()]}
        ]
  def resolve_org_permissions(%McpGrant{} = grant) do
    grant = preload_grant(grant)

    Enum.map(grant.org_grants, fn org_grant ->
      permissions =
        []
        |> maybe_add(org_grant.can_view, @org_view_permission)
        |> maybe_add(org_grant.can_run_workflows, @org_run_permission)

      %{org_id: org_grant.org_id, permissions: permissions}
    end)
  end

  @spec resolve_project_permissions(McpGrant.t()) ::
          [%{project_id: String.t(), org_id: String.t(), permissions: [String.t()]}]
  def resolve_project_permissions(%McpGrant{} = grant) do
    grant = preload_grant(grant)

    Enum.map(grant.project_grants, fn project_grant ->
      permissions =
        []
        |> maybe_add(project_grant.can_view, @project_view_permission)
        |> maybe_add(project_grant.can_run_workflows, @project_run_permission)
        |> maybe_add_many(project_grant.can_view_logs, @project_log_permissions)
        |> Enum.uniq()

      %{
        project_id: project_grant.project_id,
        org_id: project_grant.org_id,
        permissions: permissions
      }
    end)
  end

  @spec default_selection(McpGrant.t() | nil) :: %{
          tool_scopes: [String.t()],
          org_grants: [map()],
          project_grants: [map()]
        }
  def default_selection(nil), do: %{tool_scopes: [], org_grants: [], project_grants: []}

  def default_selection(%McpGrant{} = grant) do
    grant = preload_grant(grant)

    %{
      tool_scopes: grant.tool_scopes || [],
      org_grants:
        Enum.map(grant.org_grants, fn org_grant ->
          %{
            org_id: org_grant.org_id,
            can_view: org_grant.can_view,
            can_run_workflows: org_grant.can_run_workflows
          }
        end),
      project_grants:
        Enum.map(grant.project_grants, fn project_grant ->
          %{
            project_id: project_grant.project_id,
            org_id: project_grant.org_id,
            can_view: project_grant.can_view,
            can_run_workflows: project_grant.can_run_workflows,
            can_view_logs: project_grant.can_view_logs
          }
        end)
    }
  end

  defp maybe_filter_revoked(query, true), do: query
  defp maybe_filter_revoked(query, false), do: from(g in query, where: is_nil(g.revoked_at))

  defp parse_page_size(page_size)
       when is_integer(page_size) and page_size > 0 and page_size <= 100,
       do: page_size

  defp parse_page_size(_), do: 20

  defp parse_page_token(""), do: 0

  defp parse_page_token(page_token) when is_binary(page_token) do
    case Integer.parse(page_token) do
      {offset, _} when offset >= 0 -> offset
      _ -> 0
    end
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.update(:tool_scopes, [], fn scopes -> Enum.uniq(List.wrap(scopes)) end)
    |> Map.update(:org_grants, [], &List.wrap/1)
    |> Map.update(:project_grants, [], &List.wrap/1)
  end

  defp insert_org_grants(repo, grant_id, org_grants) do
    org_grants
    |> Enum.reduce_while({:ok, []}, fn org_grant, {:ok, acc} ->
      attrs =
        org_grant
        |> normalize_org_grant_attrs()
        |> Map.put(:grant_id, grant_id)

      case %McpGrantOrgGrant{} |> McpGrantOrgGrant.changeset(attrs) |> repo.insert() do
        {:ok, inserted} -> {:cont, {:ok, [inserted | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, inserted} -> {:ok, Enum.reverse(inserted)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_project_grants(repo, grant_id, project_grants) do
    project_grants
    |> Enum.reduce_while({:ok, []}, fn project_grant, {:ok, acc} ->
      attrs =
        project_grant
        |> normalize_project_grant_attrs()
        |> Map.put(:grant_id, grant_id)

      case %McpGrantProjectGrant{} |> McpGrantProjectGrant.changeset(attrs) |> repo.insert() do
        {:ok, inserted} -> {:cont, {:ok, [inserted | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, inserted} -> {:ok, Enum.reverse(inserted)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_org_grant_attrs(org_grant) do
    %{
      org_id: Map.get(org_grant, :org_id),
      org_name: Map.get(org_grant, :org_name) || "",
      can_view: truthy?(Map.get(org_grant, :can_view, false)),
      can_run_workflows: truthy?(Map.get(org_grant, :can_run_workflows, false))
    }
  end

  defp normalize_project_grant_attrs(project_grant) do
    %{
      project_id: Map.get(project_grant, :project_id),
      org_id: Map.get(project_grant, :org_id),
      project_name: Map.get(project_grant, :project_name) || "",
      can_view: truthy?(Map.get(project_grant, :can_view, false)),
      can_run_workflows: truthy?(Map.get(project_grant, :can_run_workflows, false)),
      can_view_logs: truthy?(Map.get(project_grant, :can_view_logs, false))
    }
  end

  defp truthy?(value), do: value in [true, 1, "1", "true", "TRUE"]

  defp maybe_add(permissions, true, permission) do
    if permission in permissions, do: permissions, else: [permission | permissions]
  end

  defp maybe_add(permissions, false, _permission), do: permissions

  defp maybe_add_many(permissions, false, _candidates), do: permissions

  defp maybe_add_many(permissions, true, candidates) do
    candidates
    |> Enum.reverse()
    |> Enum.reduce(permissions, fn permission, acc -> maybe_add(acc, true, permission) end)
  end

  defp preload_grant(%McpGrant{} = grant) do
    Repo.preload(grant, [:org_grants, :project_grants])
  end
end
