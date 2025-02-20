defmodule PreFlightChecks.ProjectPFC.Model.ProjectPFCQueries do
  @moduledoc """
  Database operations on project pre-flight checks
  """

  alias PreFlightChecks.ProjectPFC.Model.ProjectPFC
  alias PreFlightChecks.EctoRepo
  require Logger

  @doc """
  Looks up a pre-flight check for `project_id` in database
  """
  @spec find(String.t()) :: {:ok, ProjectPFC.t()} | {:error, {:not_found, String.t()}}
  def find(project_id) do
    case EctoRepo.get_by(ProjectPFC, project_id: project_id) do
      nil -> {:error, {:not_found, project_id}}
      pre_flight_check -> {:ok, pre_flight_check}
    end
  end

  @doc """
  Upserts a pre-flight check for `project_id` into database

  If pre-flight check for given project already exists,
  it overrides it with new definition. Otherwise, a new
  pre-flight check is created.
  """
  @spec upsert(map()) :: {:ok, ProjectPFC.t()} | {:error, any()}
  def upsert(params) do
    project_id = params[:project_id]

    %ProjectPFC{}
    |> ProjectPFC.changeset(params)
    |> EctoRepo.insert(
      conflict_target: [:project_id],
      on_conflict: {:replace, [:definition, :requester_id, :updated_at]},
      returning: true
    )
    |> case do
      {:ok, pre_flight_check} ->
        Logger.info(upsert_success_msg(project_id))
        {:ok, pre_flight_check}

      {:error, reason} ->
        Logger.error(upsert_failure_msg(project_id, reason))
        {:error, reason}
    end
  end

  @doc """
  Removes a project pre-flight check from database

  If pre-flight check for given project doesn't exist,
  it returns `{:error, {:not_found, project_id}}`
  """
  @spec remove(String.t()) :: {:ok, String.t()} | {:error, any()}
  def remove(project_id) do
    with {:ok, pre_flight_check} <- find(project_id),
         {:ok, _pre_flight_check} <- EctoRepo.delete(pre_flight_check) do
      Logger.info(remove_success_msg(project_id))
      {:ok, project_id}
    else
      {:error, {:not_found, ^project_id}} ->
        {:ok, project_id}

      {:error, reason} ->
        Logger.error(remove_failure_msg(project_id, reason))
        {:error, reason}
    end
  end

  #
  # Logger messages
  #

  defp upsert_success_msg(project_id),
    do: "Successfully created pre-flight check for project #{inspect(project_id)}"

  defp upsert_failure_msg(project_id, reason),
    do: "Unable to create pre-flight check for project #{inspect(project_id)}: #{inspect(reason)}"

  defp remove_success_msg(project_id),
    do: "Successfully deleted pre-flight check for project #{inspect(project_id)}"

  defp remove_failure_msg(project_id, reason),
    do: "Unable to remove pre-flight check for project #{inspect(project_id)}: #{inspect(reason)}"
end
