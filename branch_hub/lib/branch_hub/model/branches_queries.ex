defmodule BranchHub.Model.BranchesQueries do
  @moduledoc """
  Branches Queries
  Operations on Branches type
  """

  import Ecto.Query

  alias BranchHub.Model.Branches
  alias Util.ToTuple
  alias LogTee, as: LT
  alias BranchHub.Repo, as: Repo

  @doc """
  Creates new DB record for branch with given params
  """
  def insert(params) do
    %Branches{}
    |> Branches.changeset(params)
    |> Repo.insert()
    |> process_response(params)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  def get_or_insert(params) do
    on_conflict = {:replace_all_except, [:id, :inserted_at]}
    conflict_target = [:project_id, :name]
    params = Map.merge(params, %{used_at: DateTime.utc_now(), archived_at: nil})

    %Branches{}
    |> Branches.changeset(params)
    |> Repo.insert(on_conflict: on_conflict, returning: true, conflict_target: conflict_target)
    |> process_response(params)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  defp process_response(branch, _params) do
    LT.info(branch, "Branch persisted")
  end

  @doc """
  Finds branch by its id
  """
  def get_by_id(id) do
    Branches
    |> where(id: ^id)
    |> Repo.one()
    |> return_tuple("Branch with id: '#{id}' not found.")
  rescue
    e -> {:error, e}
  end

  @doc """
  Finds branch by its id
  """
  def get_by_name(name, project_id) do
    Branches
    |> where(name: ^name, project_id: ^project_id)
    |> Repo.one()
    |> return_tuple("Branch with name: '#{name}' in Project with id: '#{project_id}' not found.")
  rescue
    e -> {:error, e}
  end

  def list(params, page, page_size) do
    Branches
    |> filter_by_project_id(params.project_id, params.name_contains)
    |> filter_by_name(params.name_contains)
    |> filter_by_archived(params.with_archived)
    |> filter_by_types(params.types)
    |> order_by([b], desc_nulls_last: b.used_at)
    |> Repo.paginate(page: page, page_size: page_size)
    |> return_tuple("")
  end

  @doc """
  Archives a branch by setting the archived_at timestamp
  """
  def archive(branch_id, archived_at \\ DateTime.utc_now()) do
    Branches
    |> where(id: ^branch_id)
    |> Repo.update_all(set: [archived_at: archived_at])
    |> case do
      {1, _} -> get_by_id(branch_id)
      {0, _} -> {:error, "Branch with id: '#{branch_id}' not found."}
    end
  rescue
    e -> {:error, e}
  end

  # Utility

  defp filter_by_project_id(query, :skip, _), do: query

  defp filter_by_project_id(query, project_id, name) when is_binary(name) do
    if String.length(name) < 3 do
      query |> where([b], b.project_id == ^project_id)
    else
      query |> filter_by_project_id(project_id, :skip)
    end
  end

  defp filter_by_project_id(query, project_id, _),
    do: query |> where([b], fragment("?::text=?::text", b.project_id, ^project_id))

  defp filter_by_name(query, :skip), do: query

  defp filter_by_name(query, name),
    do: query |> where([b], ilike(b.display_name, ^"%#{sanitize_like_param(name)}%"))

  defp filter_by_archived(query, :skip), do: query
  defp filter_by_archived(query, true), do: query

  defp filter_by_archived(query, false),
    do: query |> where([b], is_nil(b.archived_at))

  defp filter_by_types(query, :skip), do: query

  defp filter_by_types(query, types),
    do: query |> where([b], b.ref_type in ^types)

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _), do: ToTuple.ok(value)

  defp sanitize_like_param(string), do: String.replace(string, "%", "")
end
