defmodule RepositoryHub.WebhookEncryptor.ProjectSplitter do
  @moduledoc """
  ProjectMapper is responsible for mapping events to project events.

  After getting an event from FeatureFilter, it fetches all projects for the organization.
  We make use of all the repository info (from the feedback loop from projecthub) to enrich the event.
  """
  use GenStage
  require Logger

  def start_link(args) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    {:producer_consumer, args,
     subscribe_to: [
       {RepositoryHub.WebhookEncryptor.FeatureFilter, max_demand: 5}
     ]}
  end

  def handle_events(events, _from, state) do
    new_events =
      events
      |> Stream.map(&to_project_events/1)
      |> Stream.reject(&match?({:error, _}, &1))
      |> Enum.flat_map(&elem(&1, 1))

    {:noreply, new_events, state}
  end

  def to_project_events(%{org_id: org_id} = event) do
    case fetch_projects(event.org_id) do
      {:ok, projects} ->
        message = "ℹ️ Fetched #{length(projects)} projects"
        Logger.info(log_message(org_id, message))
        {:ok, form_new_events(projects, event)}

      {:error, reason} ->
        message = "❌ Unable to fetch all projects: #{inspect(reason)}"
        Logger.error(log_message(org_id, message))
        {:error, reason}
    end
  end

  defp fetch_projects(org_id, page_token \\ "", acc \\ []) do
    alias RepositoryHub.ProjecthubClient

    case ProjecthubClient.list_keyset(org_id, page_token: page_token) do
      {:ok, %{projects: projects, next_page_token: ""}} ->
        {:ok, acc ++ projects}

      {:ok, %{projects: projects, next_page_token: next_token}} ->
        fetch_projects(org_id, next_token, acc ++ projects)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp form_new_events(projects, event) do
    Enum.into(projects, [], fn project ->
      Map.merge(event, %{
        project_id: project.metadata.id,
        project_owner_id: project.metadata.owner_id,
        repository_id: project.spec.repository.id,
        git_repository: %{
          owner: project.spec.repository.owner,
          name: project.spec.repository.name
        },
        integration_type: integration_type(project.spec.repository)
      })
    end)
  end

  defp integration_type(repository),
    do: repository.integration_type |> Atom.to_string() |> String.downcase()

  defp log_message(org_id, message) do
    "[WebhookEncryptor][ProjectSplitter] {#{org_id}} #{message}"
  end
end
