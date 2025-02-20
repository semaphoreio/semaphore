defmodule PreFlightChecks.OrganizationPFC.Model.OrganizationPFCQueries do
  @moduledoc """
  Database operations on organization pre-flight checks
  """

  alias PreFlightChecks.OrganizationPFC.Model.OrganizationPFC
  alias PreFlightChecks.EctoRepo
  require Logger

  @doc """
  Looks up a pre-flight check for `organization_id` in database
  """
  def find(organization_id) do
    case EctoRepo.get_by(OrganizationPFC, organization_id: organization_id) do
      nil -> {:error, {:not_found, organization_id}}
      pre_flight_check -> {:ok, pre_flight_check}
    end
  end

  @doc """
  Upserts a pre-flight check for `organization_id` into database

  If pre-flight check for given organization already exists,
  it overrides it with new definition. Otherwise, a new
  pre-flight check is created.
  """
  def upsert(params) do
    organization_id = params[:organization_id]

    %OrganizationPFC{}
    |> OrganizationPFC.changeset(params)
    |> EctoRepo.insert(
      conflict_target: [:organization_id],
      on_conflict: {:replace, [:definition, :requester_id, :updated_at]},
      returning: true
    )
    |> case do
      {:ok, pre_flight_check} ->
        Logger.info(upsert_success_msg(organization_id))
        {:ok, pre_flight_check}

      {:error, reason} ->
        Logger.error(upsert_failure_msg(organization_id, reason))
        {:error, reason}
    end
  end

  @doc """
  Removes a organization pre-flight check from database

  If pre-flight check for given organization doesn't exist,
  it returns `{:error, {:not_found, organization_id}}`
  """
  def remove(organization_id) do
    with {:ok, pre_flight_check} <- find(organization_id),
         {:ok, _pre_flight_check} <- EctoRepo.delete(pre_flight_check) do
      Logger.info(remove_success_msg(organization_id))
      {:ok, organization_id}
    else
      {:error, {:not_found, ^organization_id}} ->
        {:ok, organization_id}

      {:error, reason} ->
        Logger.error(remove_failure_msg(organization_id, reason))
        {:error, reason}
    end
  end

  #
  # Logger messages
  #

  defp upsert_success_msg(organization_id),
    do: "Successfully created pre-flight check for organization #{inspect(organization_id)}"

  defp upsert_failure_msg(organization_id, reason),
    do:
      "Unable to create pre-flight check for organization #{inspect(organization_id)}: #{inspect(reason)}"

  defp remove_success_msg(organization_id),
    do: "Successfully deleted pre-flight check for organization #{inspect(organization_id)}"

  defp remove_failure_msg(organization_id, reason),
    do:
      "Unable to remove pre-flight check for organization #{inspect(organization_id)}: #{inspect(reason)}"
end
