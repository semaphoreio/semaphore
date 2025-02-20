defmodule Ppl.DeleteRequests.Model.DeleteRequestsQueries do
  @moduledoc """
  Queries and operations on DeleteRequests  type 
  """
  
  import Ecto.Query

  alias LogTee, as: LT
  alias Ppl.EctoRepo, as: Repo
  alias Util.ToTuple
  alias Ppl.DeleteRequests.Model.DeleteRequests
  
  @doc """
  Inserts new DeleteRequests record into DB with given parameters
  """
  def insert(params = %{project_id: _, requester: _}) do    
    params =  params
              |> Map.put(:state, "pending")
              |> Map.put(:in_scheduling, "false")
    try do
      %DeleteRequests{} |> DeleteRequests.changeset(params) |> Repo.insert()
      |> process_response(params.project_id)
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end
  def insert(%{requester: _}), do: {:error, "Missing required param: 'project_id'."}
  def insert(%{project_id: _}), do: {:error, "Missing required param: 'requester'."}
  def insert(), do: {:error, "Missing required params: project_id', 'requester'."}
  

  defp process_response({:error, %Ecto.Changeset{errors: [{key, message}]}}, _) do
    {:error, Map.put(%{}, key, message)}
  end
  defp process_response({:ok, dr}, project_id) do
    dr
    |> LT.info("Persisted delete_request for pipelines from project with project_id: #{project_id}")
    |> ToTuple.ok()
  end
  
  @doc """
  Returns true if there is delete_request for pipelines from project with given id.
  """
  def project_deletion_requested?(project_id) do
    (from dr in DeleteRequests, 
      where: dr.project_id == ^project_id,
      select: count(dr.id))
    |> Repo.one()
    |> Kernel.!=(0)
    |> ToTuple.ok()
    rescue
      e -> {:error, e}
  end
end