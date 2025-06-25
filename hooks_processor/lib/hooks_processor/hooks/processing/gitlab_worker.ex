defmodule HooksProcessor.Hooks.Processing.GitlabWorker do
  @moduledoc """
  It performs all necessary processing for received gitlab hooks, creates
  branches data and triggers workflow creation on Plumber.
  """
  use GenServer, restart: :transient

  alias HooksProcessor.Hooks.Model.HooksQueries
  alias HooksProcessor.Hooks.Payload.Gitlab, as: GitlabPayload

  alias HooksProcessor.Clients.ProjectHubClient

  alias LogTee, as: LT

  import HooksProcessor.Hooks.Processing.Utils,
    only: [
      whitelisted?: 3,
      get_requester_id: 3,
      schedule_workflow: 2,
      update_to_deleting_branch: 2
    ]

  def start_link(id) do
    name = {:via, Registry, {WorkersRegistry, "gitlab_worker-#{id}"}}
    GenServer.start_link(__MODULE__, id, name: name)
  end

  def init(id) do
    send(self(), :process_hook)

    {:ok, %{id: id}}
  end

  def handle_info(:process_hook, state = %{id: id}) do
    id |> HooksQueries.get_by_id() |> do_processing(state)
  end

  defp do_processing({:ok, webhook}, state) do
    with {:ok, project} <- ProjectHubClient.describe_project(webhook.project_id),
         hook_type <- GitlabPayload.hook_type(webhook.request),
         actor_id <- GitlabPayload.extract_actor_id(webhook.request),
         requester_id <- get_requester_id(webhook, actor_id, "gitlab"),
         {:ok, _webhook} <-
           process_webhook(hook_type, webhook, project.repository, requester_id) do
      "Processing finished successfully." |> graceful_exit(state)
    else
      error -> graceful_exit(error, state)
    end
  end

  defp do_processing({:error, error}, state) do
    "Failed to load webhook from database: '#{to_str(error)}'" |> restart(state)
  end

  defp process_webhook("push", webhook, repository, requester_id) do
    with action_type <- GitlabPayload.branch_action(webhook.request),
         parsed_data <- GitlabPayload.extract_data(webhook.request, "push", action_type),
         parsed_data <- Map.put(parsed_data, :requester_id, requester_id),
         parsed_data <- Map.put(parsed_data, :yml_file, repository.pipeline_file),
         parsed_data <- Map.put(parsed_data, :provider, "gitlab"),
         {:skip_ci, false} <- GitlabPayload.skip_ci_flag?(parsed_data),
         {:build, true} <- should_build?(repository, parsed_data, :BRANCHES) do
      perform_actions(webhook, parsed_data, "push", action_type)
    else
      {:skip_ci, true, parsed_data} ->
        HooksQueries.update_webhook(webhook, parsed_data, "skip_ci")

      {:build, {false, hook_state}, parsed_data} ->
        HooksQueries.update_webhook(webhook, parsed_data, hook_state)

      error ->
        error
    end
  end

  defp process_webhook("tag_push", webhook, repository, requester_id) do
    with parsed_data <- GitlabPayload.extract_data(webhook.request, "tag_push", "push"),
         parsed_data <- Map.put(parsed_data, :yml_file, repository.pipeline_file),
         parsed_data <- Map.put(parsed_data, :requester_id, requester_id),
         parsed_data <- Map.put(parsed_data, :provider, "gitlab"),
         {:skip_ci, false} <- GitlabPayload.skip_ci_flag?(parsed_data),
         {:build, true} <- should_build?(repository, parsed_data, :TAGS) do
      perform_actions(webhook, parsed_data, "tag_push", "new")
    else
      {:skip_ci, true, parsed_data} ->
        HooksQueries.update_webhook(webhook, parsed_data, "skip_ci")

      {:build, {false, hook_state}, parsed_data} ->
        HooksQueries.update_webhook(webhook, parsed_data, hook_state)

      error ->
        error
    end
  rescue
    e -> e
  end

  defp process_webhook(hook_type, webhook, _project, requester_id) do
    params = %{provider: "gitlab", requester_id: requester_id}
    HooksQueries.update_webhook(webhook, params, "failed", "BAD REQUEST")

    {:error, "Unsuported type of the hook: '#{hook_type}'"}
  end

  defp should_build?(repository, hook_data, hook_type) do
    cond do
      hook_type not in repository.run_on ->
        {:build, {false, hook_state(hook_type, :skip)}, hook_data}

      not whitelisted?(repository.whitelist, hook_data, hook_type) ->
        {:build, {false, hook_state(hook_type, :whitelist)}, hook_data}

      true ->
        {:build, true}
    end
  end

  defp perform_actions(webhook, parsed_data, hook_type, action_type)
       when hook_type in ["push", "tag_push"] and action_type in ["new", "push"] do
    schedule_workflow(webhook, parsed_data)
  end

  defp perform_actions(webhook, parsed_data, "push", "deleted") do
    update_to_deleting_branch(webhook, parsed_data)
  end

  defp hook_state(:BRANCHES, :skip), do: "skip_branch"
  defp hook_state(:BRANCHES, :whitelist), do: "whitelist_branch"
  defp hook_state(:TAGS, :skip), do: "skip_tag"
  defp hook_state(:TAGS, :whitelist), do: "whitelist_tag"

  defp graceful_exit(message, state) do
    message
    |> LT.info("Hook #{state.id} - gitlab worker process exits: ")

    {:stop, :normal, state}
  end

  defp restart(error, state) do
    error
    |> LT.warn("Hook #{state.id} - gitlab worker process failiure: ")

    {:stop, :restart, state}
  end

  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)
end
