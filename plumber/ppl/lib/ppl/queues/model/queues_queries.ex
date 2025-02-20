defmodule Ppl.Queues.Model.QueuesQueries do
  @moduledoc """
  Queries on Queues type
  """

  import Ecto.Query

  alias Ppl.Queues.Model.Queues
  alias Util.ToTuple
  alias LogTee, as: LT
  alias Ppl.EctoRepo, as: Repo

  @doc """
  Creates new queue for given params or returns already existing one
  """
  def get_or_insert_queue(params) do
    case get_by_name_and_id(params) do
      {:ok, queue} ->
          {:ok, queue}
      {:error, "Queue " <> _rest} ->
          insert_queue(params)
    end
  end

  @doc """
  Creates new DB record for queue with given params
  """
  def insert_queue(params) do
    queue_id = UUID.uuid4()
    params = Map.put(params, :queue_id, queue_id)

    %Queues{} |> Queues.changeset(params) |> Repo.insert()
    |> process_response(params)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  defp process_response({:error, %Ecto.Changeset{errors: [unique_queue_name_for_project: _message]}}, params) do
    LT.info("", "QueuesQueries.insert() - There is already queue caled '#{params.name}'"
                <> "for project with id '#{params.project_id}'")
    {:error, {:queue_exists, {params.name, params.project_id, "project"}}}
  end
  defp process_response({:error, %Ecto.Changeset{errors: [unique_queue_name_for_org: _message]}}, params) do
     LT.info("", "QueuesQueries.insert() - There is already queue caled '#{params.name}'"
                <> "for organization with id '#{params.organization_id}'")
    {:error, {:queue_exists, {params.name, params.organization_id, "organization"}}}
  end
  defp process_response(queue, _params) do
    LT.info(queue, "Queue persisted")
  end

  @doc """
  Returns paginated list of queues that match search criterias.
  """
  def list_queues(params, page, page_size) do
    Queues
    |> where_scope_and_id(params)
    |> where_type(params)
    |> order_by([q], q.inserted_at)
    |> select([q], %{
      queue_id: q.queue_id,
      name: q.name,
      type: fragment("case ? when true then 'user_generated' else 'implicit' end", q.user_generated),
      scope: q.scope,
      project_id: q.project_id,
      organization_id: q.organization_id,
      }
    )
    |> Repo.paginate(page: page, page_size: page_size)
    |> ToTuple.ok()
  end

  defp where_scope_and_id(query, params = %{org_id: :skip}) do
    query
    |> where([q], q.scope == "project")
    |> where([q], q.project_id == ^params.project_id)
  end

  defp where_scope_and_id(query, params = %{project_id: :skip}) do
    query
    |> where([q], q.scope == "organization")
    |> where([q], q.organization_id == ^params.org_id)
  end

  defp where_scope_and_id(query, params) do
    query
    |> where([q], q.scope == "project" and q.project_id == ^params.project_id)
    |> or_where([q], q.scope == "organization" and q.organization_id == ^params.org_id)
  end

  defp where_type(query, %{type: "implicit"}),
    do: query |> where([q], q.user_generated == false)
  defp where_type(query, %{type: "user_generated"}),
    do: query |> where([q], q.user_generated == true)
  defp where_type(query, %{type: "all"}), do: query

  @doc """
  Deletes queue with given queue_id
  """
  def delete_queue(queue_id) do
    (from q in Queues, where: q.queue_id == ^queue_id)
    |> Repo.delete_all()
    |> return_number()
  end

  @doc """
  Returns one project-scoped queue for given project
  """
  def get_one_project_scoped(project_id) do
    Queues
    |> where([q], q.scope == "project")
    |> where([q], q.project_id == ^project_id)
    |> Repo.one()
    |> return_tuple({:queue_not_found, "no queues were found for project #{project_id}"})
  end

  @doc """
  Finds queue with given name for given project or organization
  """
  def get_by_name_and_id(%{name: name, project_id: pr_id, scope: "project"}) do
    Queues
    |> where([q], q.name == ^name)
    |> where([q], q.scope == "project")
    |> where([q], q.project_id == ^pr_id)
    |> Repo.one()
    |> return_tuple("Queue #{name} for project #{pr_id} not found.")
  end
  def get_by_name_and_id(%{name: name, organization_id: org_id, scope: "organization"}) do
    Queues
    |> where([q], q.name == ^name)
    |> where([q], q.scope == "organization")
    |> where([q], q.organization_id == ^org_id)
    |> Repo.one()
    |> return_tuple("Queue #{name} for organization #{org_id} not found.")
  end
  def get_by_name_and_id(_), do: {:error, "Invalid parameters for getting a queue."}

  @doc """
  Finds queue by its id
  """
  def get_by_id(id) do
    Queues |> where(queue_id: ^id) |> Repo.one()
    |> return_tuple("Queue with id: '#{id}' not found")
  rescue
    e -> {:error, e}
  end

  # Utility

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _),     do: ToTuple.ok(value)

  defp return_number({number, _}) when is_integer(number),
    do: ToTuple.ok(number)
  defp return_number(error), do: ToTuple.error(error)
end
