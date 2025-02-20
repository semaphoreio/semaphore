defmodule Scheduler.FrontDB.Model.FrontDBQueries do
  @moduledoc """
  Read-only queries on different tables from front database.
  """

  import Ecto.Query

  alias Scheduler.FrontRepo
  alias Util.ToTuple

  @doc """
  Finds id of project with given name in given organization
  """
  def get_project_id(organization_id, project_name) do
    from(pr in "projects",
      where: pr.name == ^project_name,
      where: pr.organization_id == type(^organization_id, Ecto.UUID),
      select: type(pr.id, :string)
    )
    |> FrontRepo.one()
    |> return_tuple("Project with name '#{project_name}' not found.")
  rescue
    e -> {:error, e}
  end

  @doc """
  Finds name of project with given ID in given organization
  """
  def get_project_name(organization_id, project_id) do
    from(pr in "projects",
      where: pr.id == type(^project_id, Ecto.UUID),
      where: pr.organization_id == type(^organization_id, Ecto.UUID),
      select: pr.name
    )
    |> FrontRepo.one()
    |> return_tuple("Project with ID '#{project_id}' not found.")
  rescue
    e -> {:error, e}
  end

  @doc """
  Checks whether hook exists for given branch of given project
  """
  def hook_exists?(project_id, branch) do
    from(br in "branches",
      left_join: wf in "workflows",
      on: br.id == wf.branch_id,
      where: br.project_id == type(^project_id, Ecto.UUID),
      where: br.name == ^branch,
      select: count(wf.id)
    )
    |> FrontRepo.one()
    |> process_response()
  rescue
    e -> {:error, e}
  end

  defp process_response(n) when is_integer(n) and n > 0, do: {:ok, true}
  defp process_response(_n), do: {:ok, false}

  @doc """
  Returns all necessary hook data from front DB which is needed for workflow scheduling
  """
  def get_hook(project_id, branch) do
    from(br in "branches",
      left_join: pr in "projects",
      on: br.project_id == pr.id,
      left_join: wf in "workflows",
      on: br.id == wf.branch_id,
      left_join: rp in "repositories",
      on: rp.project_id == br.project_id,
      left_join: rha in "repo_host_accounts",
      on: rha.user_id == pr.creator_id,
      where: br.name == ^branch,
      where: br.project_id == type(^project_id, Ecto.UUID),
      order_by: [desc: wf.created_at],
      limit: 1,
      select: %{
        repo: %{
          owner: rp.owner,
          repo_name: rp.name,
          branch_name: br.name,
          payload: fragment("?->>'payload'", wf.request)
        },
        auth: %{
          access_token: rha.token
        },
        project_id: type(rp.project_id, :string),
        branch_id: type(br.id, :string),
        hook_id: type(wf.id, :string),
        label: br.name
      }
    )
    |> FrontRepo.one()
    |> return_tuple("Hook for project '#{project_id}' on branch '#{branch}' not found.")
  rescue
    e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _), do: ToTuple.ok(value)
end
