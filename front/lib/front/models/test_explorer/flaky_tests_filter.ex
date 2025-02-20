defmodule Front.Models.TestExplorer.FlakyTestsFilter do
  alias __MODULE__
  alias Front.Clients.Velocity, as: VelocityClient
  alias InternalApi.Velocity, as: API
  require Logger

  defstruct [
    :id,
    :name,
    :value,
    :inserted_at,
    :updated_at,
    :project_id,
    :organization_id
  ]

  @type t :: %FlakyTestsFilter{
          id: String.t(),
          name: String.t(),
          value: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          project_id: String.t(),
          organization_id: String.t()
        }

  def filters(org_id, project_id) do
    VelocityClient.list_flaky_tests_filters(%API.ListFlakyTestsFiltersRequest{
      project_id: project_id,
      organization_id: org_id
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error listing filters: #{inspect(error)}")
        error
    end
  end

  def initialize_filters(org_id, project_id) do
    VelocityClient.initialize_flaky_tests_filters(%API.InitializeFlakyTestsFiltersRequest{
      project_id: project_id,
      organization_id: org_id
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error initializing filters: #{inspect(error)}")
        error
    end
  end

  def create_filter(org_id, project_id, filter) do
    VelocityClient.create_flaky_tests_filter(%API.CreateFlakyTestsFilterRequest{
      organization_id: org_id,
      project_id: project_id,
      name: filter["name"],
      value: filter["value"]
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error creating new filter: #{inspect(error)}")
        error
    end
  end

  def remove_filter(filter_id) do
    VelocityClient.remove_flaky_tests_filter(%API.RemoveFlakyTestsFilterRequest{
      id: filter_id
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error removing filter: #{inspect(error)}")
        error
    end
  end

  def update_filter(filter_id, filter) do
    VelocityClient.update_flaky_tests_filter(%API.UpdateFlakyTestsFilterRequest{
      id: filter_id,
      name: filter["name"],
      value: filter["value"]
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error creating new filter: #{inspect(error)}")
        error
    end
  end
end
